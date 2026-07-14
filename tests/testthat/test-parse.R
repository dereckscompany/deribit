# Offline parser + envelope tests. The parsers are exercised directly against the
# parsed `result` of the synthetic fixtures (no transport), and the JSON-RPC
# envelope seam is exercised against hand-built httr2 responses.

box::use(./mock_router[.fixture_result, .fixture_body])

test_that("parse_instruments preserves faithful fields and types the kind-specific columns | NA", {
  fut <- parse_instruments(.fixture_result("instruments_future"))
  opt <- parse_instruments(.fixture_result("instruments_option"))

  expect_identical(nrow(fut), 2L)
  expect_true(all(fut$kind == "future"))
  expect_s3_class(fut$expiration_datetime, "POSIXct")
  expect_s3_class(fut$creation_datetime, "POSIXct")
  expect_type(fut$instrument_id, "integer")
  expect_type(fut$is_active, "logical")
  # Futures carry max_leverage but no strike / option_type.
  expect_true(all(is.na(fut$strike)))
  expect_true(all(is.na(fut$option_type)))
  expect_false(any(is.na(fut$max_leverage)))

  # Options carry strike + option_type but no max_leverage.
  expect_true(all(opt$kind == "option"))
  expect_identical(sort(opt$option_type), c("call", "put"))
  expect_false(any(is.na(opt$strike)))
  expect_true(all(is.na(opt$max_leverage)))
})

test_that("parse_ticker flattens nested stats/greeks with parent prefixes", {
  perp <- parse_ticker(.fixture_result("ticker_perp"))
  opt <- parse_ticker(.fixture_result("ticker_option"))

  expect_identical(nrow(perp), 1L)
  expect_identical(perp$instrument_name, "BTC-PERPETUAL")
  expect_s3_class(perp$datetime, "POSIXct")
  expect_identical(perp$stats_volume_notional, 60000000.0)
  # Perpetual has funding, no greeks / mark_iv.
  expect_false(is.na(perp$current_funding))
  expect_true(is.na(perp$mark_iv))
  expect_true(is.na(perp$greeks_delta))

  # Option has greeks + mark_iv; the null stats fields land as NA.
  expect_identical(opt$greeks_delta, 0.55)
  expect_false(is.na(opt$mark_iv))
  expect_true(is.na(opt$stats_high))
  expect_true(is.na(opt$current_funding))
})

test_that("parse_order_book returns a long bid/ask table with 1-based levels", {
  book <- parse_order_book(.fixture_result("order_book"))
  expect_named(book, c("instrument_name", "datetime", "side", "level", "price", "amount"))
  expect_identical(nrow(book), 5L)
  expect_identical(sort(unique(book$side)), c("ask", "bid"))
  bids <- book[side == "bid"]
  expect_identical(bids$level, 1:3)
  expect_identical(bids$price[1L], 50004.0)
  expect_type(book$level, "integer")
})

test_that("parse_dvol flattens the candle array and sorts ascending", {
  dvol <- parse_dvol(.fixture_result("dvol"), "BTC", "3600")
  expect_named(dvol, c("currency", "datetime", "resolution", "open", "high", "low", "close"))
  expect_identical(nrow(dvol), 3L)
  expect_true(all(dvol$currency == "BTC"))
  expect_true(all(dvol$resolution == "3600"))
  expect_false(is.unsorted(dvol$datetime))
  expect_identical(dvol$open[1L], 38.0)
})

test_that("parse_funding_rate_history stamps the instrument and sorts ascending", {
  fh <- parse_funding_rate_history(.fixture_result("funding_history"), "BTC-PERPETUAL")
  expect_identical(nrow(fh), 3L)
  expect_true(all(fh$instrument_name == "BTC-PERPETUAL"))
  expect_false(is.unsorted(fh$datetime))
  expect_false(any(is.na(fh$interest_8h)))
})

test_that("parse_funding_rate_value wraps the scalar with the queried window", {
  start_dt <- lubridate::ymd_hms("2023-11-01 00:00:00", tz = "UTC")
  end_dt <- lubridate::ymd_hms("2023-11-08 00:00:00", tz = "UTC")
  fv <- parse_funding_rate_value(0.0010353, "BTC-PERPETUAL", start_dt, end_dt)
  expect_identical(nrow(fv), 1L)
  expect_identical(fv$funding_rate_value, 0.0010353)
  expect_identical(fv$start_datetime, start_dt)
  expect_identical(fv$end_datetime, end_dt)
})

test_that("parse_trades types option iv and perpetual contracts | NA by kind", {
  perp <- parse_trades(.fixture_result("trades_perp"))
  opt <- parse_trades(.fixture_result("trades_option"))
  expect_identical(nrow(perp), 2L)
  expect_type(perp$trade_id, "character")
  expect_false(any(is.na(perp$contracts)))
  expect_true(all(is.na(perp$iv)))
  # The liquidation flag is present on one perpetual trade, NA on the other.
  expect_identical(sum(!is.na(perp$liquidation)), 1L)
  # Option trades carry iv, no contracts.
  expect_false(is.na(opt$iv))
  expect_true(all(is.na(opt$contracts)))
})

test_that("parse_book_summary unifies option and perpetual rows with | NA fields", {
  opt <- parse_book_summary(.fixture_result("book_summary_option"))
  perp <- parse_book_summary(.fixture_result("book_summary_perp"))
  # The authored option fixture carries one null bid_price / mid_price.
  expect_true(any(is.na(opt$bid_price)))
  expect_true(any(is.na(opt$mid_price)))
  expect_false(any(is.na(opt$mark_iv)))
  # Perpetual summary has funding + volume_notional, no option greeks/iv.
  expect_false(is.na(perp$funding_8h))
  expect_false(is.na(perp$volume_notional))
  expect_true(is.na(perp$mark_iv))
})

test_that("parse_currencies keeps the flat scalar fields", {
  cur <- parse_currencies(.fixture_result("currencies"))
  expect_identical(nrow(cur), 2L)
  expect_true(all(c("BTC", "ETH") %in% cur$currency))
  expect_type(cur$decimals, "integer")
  expect_type(cur$in_cross_collateral_pool, "logical")
})

test_that("parse_deribit_response unwraps result on success", {
  resp <- httr2::response(
    status_code = 200L,
    headers = list("content-type" = "application/json"),
    body = charToRaw(.fixture_body("index_price"))
  )
  result <- parse_deribit_response(resp)
  expect_identical(result[["index_price"]], 50000.0)
})

test_that("parse_deribit_response raises a typed deribit_api_error on a JSON-RPC error body", {
  resp <- httr2::response(
    status_code = 400L,
    headers = list("content-type" = "application/json"),
    body = charToRaw(paste0(
      "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32602,\"data\":",
      "{\"reason\":\"wrong format\",\"param\":\"instrument_name\"},\"message\":\"Invalid params\"}}"
    ))
  )
  err <- tryCatch(parse_deribit_response(resp), error = function(e) e)
  expect_s3_class(err, "deribit_api_error_400")
  expect_s3_class(err, "connectcore_api_error")
  expect_identical(err$code, -32602L)
  expect_identical(err$param, "instrument_name")
  expect_match(conditionMessage(err), "Invalid params")
})
