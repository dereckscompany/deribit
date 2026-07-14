# Live tests against www.deribit.com. All gate on DERIBIT_LIVE_TESTS = "true" so
# a normal R CMD check never hits the network. The public market-data endpoints
# need no key, so the only gate is that flag. These prove the real wire shapes
# still satisfy the typed return contracts.

skip_unless_live <- function() {
  if (!identical(Sys.getenv("DERIBIT_LIVE_TESTS"), "true")) {
    skip("DERIBIT_LIVE_TESTS != 'true'")
  }
  return(invisible(NULL))
}

test_that("live: get_instruments returns the real option universe", {
  skip_unless_live()
  md <- DeribitMarketData$new(max_tries = 3L)
  opt <- md$get_instruments("BTC", kind = "option")
  expect_s3_class(opt, "data.table")
  expect_gt(nrow(opt), 0L)
  expect_true(all(opt$kind == "option"))
  expect_false(any(is.na(opt$strike)))
})

test_that("live: get_ticker satisfies the typed contract for a perpetual and an option", {
  skip_unless_live()
  md <- DeribitMarketData$new(max_tries = 3L)
  perp <- md$get_ticker("BTC-PERPETUAL")
  expect_identical(nrow(perp), 1L)
  expect_false(is.na(perp$mark_price))

  options <- md$get_instruments("BTC", kind = "option")
  opt <- md$get_ticker(options$instrument_name[[1L]])
  expect_identical(nrow(opt), 1L)
})

test_that("live: get_order_book returns a long depth table", {
  skip_unless_live()
  md <- DeribitMarketData$new(max_tries = 3L)
  book <- md$get_order_book("BTC-PERPETUAL", depth = 5)
  expect_gt(nrow(book), 0L)
  expect_true(all(book$side %in% c("bid", "ask")))
})

test_that("live: get_index_price and get_volatility_index_data return typed tables", {
  skip_unless_live()
  md <- DeribitMarketData$new(max_tries = 3L)
  idx <- md$get_index_price("btc_usd")
  expect_identical(idx$index_name, "btc_usd")
  expect_false(is.na(idx$index_price))

  end <- lubridate::now("UTC")
  start <- end - lubridate::days(2)
  dvol <- md$get_volatility_index_data("BTC", start, end, resolution = "3600")
  expect_gt(nrow(dvol), 0L)
  expect_false(any(is.na(dvol$close)))
})

test_that("live: get_funding_rate_history returns a typed table for a perpetual", {
  skip_unless_live()
  md <- DeribitMarketData$new(max_tries = 3L)
  end <- lubridate::now("UTC")
  start <- end - lubridate::days(2)
  fh <- md$get_funding_rate_history("BTC-PERPETUAL", start, end)
  expect_gt(nrow(fh), 0L)
  expect_true(all(fh$instrument_name == "BTC-PERPETUAL"))
})

test_that("live: get_book_summary_by_currency serves the option chain", {
  skip_unless_live()
  md <- DeribitMarketData$new(max_tries = 3L)
  chain <- md$get_option_chain("BTC")
  expect_gt(nrow(chain), 0L)
  expect_false(any(is.na(chain$mark_iv)))
})

test_that("live: an invalid instrument raises a typed deribit_api_error", {
  skip_unless_live()
  md <- DeribitMarketData$new()
  err <- tryCatch(md$get_ticker("NOT-A-REAL-INSTRUMENT-XYZ"), error = function(e) e)
  expect_s3_class(err, "deribit_api_error")
  expect_s3_class(err, "connectcore_error")
})
