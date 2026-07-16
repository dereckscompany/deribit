# End-to-end tests: drive every public method through the shared mock_router
# (the same synthetic fixtures the README renders against). These cover the
# wiring around the parsers -- endpoint strings, the query, the JSON-RPC envelope
# seam, each method's .parser closure, and the return contract.

box::use(./mock_router[.mock_routes])

.start <- lubridate::ymd_hms("2023-11-01 00:00:00", tz = "UTC")
.end <- lubridate::ymd_hms("2023-11-08 00:00:00", tz = "UTC")

test_that("get_instruments round-trips both kinds through the router", {
  connectcore::local_mock_api(.mock_routes)
  md <- DeribitMarketData$new()
  fut <- md$get_instruments("BTC", kind = "future")
  opt <- md$get_instruments("BTC", kind = "option")
  expect_s3_class(fut, "data.table")
  expect_true(all(fut$kind == "future"))
  expect_true(all(opt$kind == "option"))
  expect_true("BTC-PERPETUAL" %in% fut$instrument_name)
  expect_false(any(is.na(opt$strike)))
})

test_that("get_currencies round-trips the currency list", {
  connectcore::local_mock_api(.mock_routes)
  cur <- DeribitMarketData$new()$get_currencies()
  expect_named(
    cur,
    c(
      "currency",
      "currency_long",
      "coin_type",
      "decimals",
      "min_confirmations",
      "min_withdrawal_fee",
      "withdrawal_fee",
      "network_fee",
      "in_cross_collateral_pool"
    )
  )
  expect_identical(nrow(cur), 2L)
})

test_that("get_ticker returns a one-row typed table for perpetual and option", {
  connectcore::local_mock_api(.mock_routes)
  md <- DeribitMarketData$new()
  perp <- md$get_ticker("BTC-PERPETUAL")
  opt <- md$get_ticker("BTC-31JUL26-50000-C")
  expect_identical(nrow(perp), 1L)
  expect_identical(nrow(opt), 1L)
  expect_false(is.na(perp$funding_8h))
  expect_false(is.na(opt$greeks_delta))
  expect_true(is.na(opt$stats_high))
})

test_that("get_order_book returns a long depth table", {
  connectcore::local_mock_api(.mock_routes)
  book <- DeribitMarketData$new()$get_order_book("BTC-PERPETUAL", depth = 3)
  expect_identical(nrow(book), 5L)
  expect_identical(sort(unique(book$side)), c("ask", "bid"))
})

test_that("get_index_price stamps the queried index name", {
  connectcore::local_mock_api(.mock_routes)
  idx <- DeribitMarketData$new()$get_index_price("btc_usd")
  expect_identical(idx$index_name, "btc_usd")
  expect_identical(idx$index_price, 50000.0)
})

test_that("get_volatility_index_data returns the DVOL candle table", {
  connectcore::local_mock_api(.mock_routes)
  dvol <- DeribitMarketData$new()$get_volatility_index_data("BTC", .start, .end, resolution = "3600")
  expect_named(dvol, c("currency", "datetime", "resolution", "open", "high", "low", "close"))
  expect_identical(nrow(dvol), 3L)
  expect_true(all(dvol$currency == "BTC"))
})

test_that("get_funding_rate_history and get_funding_rate_value round-trip", {
  connectcore::local_mock_api(.mock_routes)
  md <- DeribitMarketData$new()
  fh <- md$get_funding_rate_history("BTC-PERPETUAL", .start, .end)
  fv <- md$get_funding_rate_value("BTC-PERPETUAL", .start, .end)
  expect_identical(nrow(fh), 3L)
  expect_true(all(fh$instrument_name == "BTC-PERPETUAL"))
  expect_identical(nrow(fv), 1L)
  expect_identical(fv$funding_rate_value, 0.0010353)
  expect_identical(fv$start_datetime, .start)
})

test_that("get_last_trades_by_instrument round-trips the trade table", {
  connectcore::local_mock_api(.mock_routes)
  trades <- DeribitMarketData$new()$get_last_trades_by_instrument("BTC-PERPETUAL", count = 2)
  expect_identical(nrow(trades), 2L)
  expect_true(all(trades$instrument_name == "BTC-PERPETUAL"))
  expect_false(any(is.na(trades$contracts)))
})

test_that("book-summary methods and the option-chain convenience round-trip", {
  connectcore::local_mock_api(.mock_routes)
  md <- DeribitMarketData$new()
  opt <- md$get_book_summary_by_currency("BTC", kind = "option")
  perp <- md$get_book_summary_by_instrument("BTC-PERPETUAL")
  chain <- md$get_option_chain("BTC")
  expect_true(any(is.na(opt$bid_price)))
  expect_false(is.na(perp$funding_8h))
  # get_option_chain is get_book_summary_by_currency(kind = "option").
  expect_identical(chain, opt)
})

test_that("get_book_summary_by_currency_raw is a lossless passthrough of the venue records", {
  connectcore::local_mock_api(.mock_routes)
  md <- DeribitMarketData$new()
  raw <- md$get_book_summary_by_currency_raw("BTC", kind = "option")
  typed <- md$get_book_summary_by_currency("BTC", kind = "option")

  # A list of raw records, one per instrument, NOT a data.table.
  expect_type(raw, "list")
  expect_false(data.table::is.data.table(raw))
  expect_length(raw, 2L)
  expect_true(all(vapply(raw, is.list, logical(1L))))

  # The venue's own creation_timestamp (raw epoch ms) survives verbatim — the
  # typed table derives it into `datetime` and drops the raw field.
  expect_identical(raw[[1L]]$creation_timestamp, 1700000000000)
  expect_false("creation_timestamp" %in% names(typed))

  # A JSON null is preserved as R NULL (distinct from an absent field), where the
  # typed table collapses it to NA. The second option has null bid_price/mid_price.
  expect_true("bid_price" %in% names(raw[[2L]]))
  expect_null(raw[[2L]]$bid_price)
  expect_null(raw[[2L]]$mid_price)

  # No phantom columns: fields the venue never sends for an option
  # (volume_notional, current_funding, funding_8h) are ABSENT from the raw
  # records, whereas the typed table invents them as all-NA columns.
  expect_false(any(c("volume_notional", "current_funding", "funding_8h") %in% names(raw[[1L]])))
  expect_true(all(c("volume_notional", "current_funding", "funding_8h") %in% names(typed)))
  expect_true(all(is.na(typed$volume_notional)))
})

test_that("get_option_chain_raw mirrors get_book_summary_by_currency_raw(kind = option)", {
  connectcore::local_mock_api(.mock_routes)
  md <- DeribitMarketData$new()
  expect_identical(
    md$get_option_chain_raw("BTC"),
    md$get_book_summary_by_currency_raw("BTC", kind = "option")
  )
})

test_that("get_volatility_index_data_raw exposes the continuation cursor and raw data rows", {
  connectcore::local_mock_api(.mock_routes)
  md <- DeribitMarketData$new()

  # BTC window is exhausted: continuation is a preserved JSON null.
  btc <- md$get_volatility_index_data_raw("BTC", .start, .end, resolution = "3600")
  expect_type(btc, "list")
  expect_true(all(c("data", "continuation") %in% names(btc)))
  expect_null(btc$continuation)
  expect_length(btc$data, 3L)

  # ETH window has more history: the non-null continuation cursor survives, where
  # the typed get_volatility_index_data() drops it entirely.
  eth <- md$get_volatility_index_data_raw("ETH", .start, .end, resolution = "3600")
  expect_identical(eth$continuation, 1699996400000)
  expect_length(eth$data, 2L)
  # Each raw data row is the venue's [timestamp_ms, o, h, l, c] array, untouched.
  expect_identical(eth$data[[1L]][[1L]], 1700000000000)
})

test_that("a JSON-RPC error surfaces as a typed deribit_api_error_400 end-to-end", {
  connectcore::local_mock_api(.mock_routes)
  md <- DeribitMarketData$new()
  err <- tryCatch(md$get_ticker("INVALID"), error = function(e) e)
  expect_s3_class(err, "deribit_api_error_400")
  expect_s3_class(err, "connectcore_error")
  expect_identical(err$code, -32602L)
  expect_identical(err$param, "instrument_name")
})

test_that("input validation rejects a bad kind / resolution / window before any request", {
  md <- DeribitMarketData$new()
  err_kind <- tryCatch(md$get_instruments("BTC", kind = "bogus"), error = function(e) e)
  expect_s3_class(err_kind, "deribit_validation_error")
  expect_match(conditionMessage(err_kind), "Invalid instrument kind")

  err_res <- tryCatch(
    md$get_volatility_index_data("BTC", .start, .end, resolution = "99"),
    error = function(e) e
  )
  expect_s3_class(err_res, "deribit_validation_error")
  expect_match(conditionMessage(err_res), "Invalid resolution")

  err_win <- tryCatch(
    md$get_funding_rate_history("BTC-PERPETUAL", .end, .start),
    error = function(e) e
  )
  expect_s3_class(err_win, "deribit_validation_error")
  expect_match(conditionMessage(err_win), "must not precede")
})
