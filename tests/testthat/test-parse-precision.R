# Precision regression: every numeric field Deribit reports must survive
# parsing at full double precision. No round(), signif(), sprintf("%.Nf"),
# format(nsmall = ), or other narrowing cast may ever sit between the venue's
# JSON number and the value stored in a returned data.table column.
#
# Why this test exists: on 2026-09-13 the fleet found every Hyperliquid candle
# in the data lake had been stored to four decimal places for months -- a coin
# priced below a cent (e.g. "0.000212") lost almost all of its information,
# and a strategy that ranks coins by calmness ranked them wrongly as a direct
# result. The cause traced to a re-serialisation default in the data scraper
# (since fixed), NOT to the venue connectors: this package's own parse path
# (connectcore::num_or_na() -> as.numeric(), threaded through
# R/helpers_parse.R's `.num_col()`) was proven correct. This test pins that
# fact for Deribit specifically so the layer that is currently correct STAYS
# correct: if anyone later adds a round()/signif()/sprintf("%.4f")/
# format(nsmall = ) or a narrowing cast to a parse helper, it fails
# immediately.
#
# Drives the real public client methods (get_ticker / get_book_summary_by_currency
# / get_funding_rate_history) through the shared connectcore mock harness
# (a URL-pattern route table + local_mock_api()), exactly as
# test-client-endpoints.R does. Unlike Hyperliquid, Deribit's wire format sends
# numbers as bare JSON numeric literals (never quoted strings), so the fixture
# bodies below are raw JSON TEXT strings -- served verbatim by
# connectcore::mock_response()'s character-body path -- so the real
# jsonlite::fromJSON() parse of a many-significant-digit literal is exercised,
# never a private helper reimplemented here. Uses expect_identical() throughout,
# never expect_equal()'s tolerance, because tolerance is exactly what would
# hide this defect.

# ---- fixture: JSON numeric literals with many significant digits ------------

# A value just under 2^53 (the largest integer a double represents exactly),
# used as a character-typed identifier (`instrument_name`) to prove an
# identifier column is never accidentally coerced to numeric.
.precision_big_id <- "9007199254740991"

.precision_strings <- list(
  a = "0.00023456789",
  b = "12345.678901234",
  c = "0.000000123456",
  d = "1e-10"
)

# Raw JSON-RPC envelopes, authored as literal text (never built from an R
# list + jsonlite::toJSON()) so the exact wire digits below are what
# jsonlite::fromJSON() actually parses, matching the real transport.
.precision_ticker_json <- sprintf(
  paste0(
    '{"jsonrpc":"2.0","result":{"instrument_name":"%s","timestamp":1700000000000,',
    '"state":"open","mark_price":%s,"index_price":%s,"last_price":%s,"mark_iv":%s}}'
  ),
  .precision_big_id,
  .precision_strings$a,
  .precision_strings$b,
  .precision_strings$c,
  .precision_strings$d
)

.precision_book_summary_json <- sprintf(
  paste0(
    '{"jsonrpc":"2.0","result":[{"instrument_name":"%s","base_currency":"BTC",',
    '"quote_currency":"BTC","creation_timestamp":1700000000000,"mark_price":%s,',
    '"mark_iv":%s,"mid_price":%s,"bid_price":%s,"ask_price":%s,"underlying_price":%s}]}'
  ),
  .precision_big_id,
  .precision_strings$a,
  .precision_strings$b,
  .precision_strings$c,
  .precision_strings$d,
  .precision_strings$a,
  .precision_strings$b
)

.precision_funding_history_json <- sprintf(
  paste0(
    '{"jsonrpc":"2.0","result":[{"timestamp":1700000000000,"index_price":%s,',
    '"prev_index_price":%s,"interest_8h":%s,"interest_1h":%s}]}'
  ),
  .precision_strings$a,
  .precision_strings$b,
  .precision_strings$c,
  .precision_strings$d
)

# A tiny URL-pattern route table covering exactly the three endpoints this test
# drives, built the same way the shared mock_router.R does (a `pattern` +
# `fixture` list dispatched by connectcore::mock_router() / local_mock_api()),
# but with a synthetic high-precision fixture instead of the captured
# real-shaped fixtures.
precision_routes <- function() {
  return(list(
    list(pattern = "/public/ticker", fixture = .precision_ticker_json),
    list(pattern = "/public/get_book_summary_by_currency", fixture = .precision_book_summary_json),
    list(pattern = "/public/get_funding_rate_history", fixture = .precision_funding_history_json)
  ))
}

# A shared digit-level check: sprintf("%.17g", .) prints enough significant
# digits to uniquely round-trip an IEEE-754 double, so if the parser silently
# narrowed the value (round()/signif()/a %.Nf format), the 17-digit rendering
# of the parsed value would diverge from the 17-digit rendering of the
# fixture's own as.numeric() value.
expect_full_precision <- function(actual, fixture_string) {
  expected <- as.numeric(fixture_string)
  expect_identical(actual, expected)
  return(expect_identical(sprintf("%.17g", actual), sprintf("%.17g", expected)))
}

# ---- ticker/market-data snapshot path: get_ticker ----------------------------

test_that("get_ticker preserves full price/IV precision through the real parse path", {
  connectcore::local_mock_api(precision_routes())
  md <- DeribitMarketData$new()
  dt <- md$get_ticker("BTC-PERPETUAL")

  expect_identical(nrow(dt), 1L)
  expect_full_precision(dt$mark_price, .precision_strings$a)
  expect_full_precision(dt$index_price, .precision_strings$b)
  expect_full_precision(dt$last_price, .precision_strings$c)
  expect_full_precision(dt$mark_iv, .precision_strings$d)
  # the identifier stays character, byte-identical, never coerced to numeric.
  expect_type(dt$instrument_name, "character")
  expect_identical(dt$instrument_name, .precision_big_id)
})

# ---- option-chain book summary path: get_book_summary_by_currency -----------
# (mark price and implied volatility -- the path implicated in the 2026-09-13
# incident.)

test_that("get_book_summary_by_currency preserves full mark-price/IV precision", {
  connectcore::local_mock_api(precision_routes())
  md <- DeribitMarketData$new()
  dt <- md$get_book_summary_by_currency("BTC", kind = "option")

  expect_identical(nrow(dt), 1L)
  expect_full_precision(dt$mark_price, .precision_strings$a)
  expect_full_precision(dt$mark_iv, .precision_strings$b)
  expect_full_precision(dt$mid_price, .precision_strings$c)
  expect_full_precision(dt$bid_price, .precision_strings$d)
  expect_full_precision(dt$ask_price, .precision_strings$a)
  expect_full_precision(dt$underlying_price, .precision_strings$b)
  # the identifier stays character, byte-identical, never coerced to numeric.
  expect_type(dt$instrument_name, "character")
  expect_identical(dt$instrument_name, .precision_big_id)
})

# ---- funding/rate path: get_funding_rate_history -----------------------------

test_that("get_funding_rate_history preserves full rate precision", {
  connectcore::local_mock_api(precision_routes())
  md <- DeribitMarketData$new()
  start <- lubridate::ymd_hms("2023-11-01 00:00:00", tz = "UTC")
  end <- lubridate::ymd_hms("2023-11-08 00:00:00", tz = "UTC")
  dt <- md$get_funding_rate_history(.precision_big_id, start_timestamp = start, end_timestamp = end)

  expect_identical(nrow(dt), 1L)
  expect_full_precision(dt$index_price, .precision_strings$a)
  expect_full_precision(dt$prev_index_price, .precision_strings$b)
  expect_full_precision(dt$interest_8h, .precision_strings$c)
  expect_full_precision(dt$interest_1h, .precision_strings$d)
  # the identifier stays character, byte-identical, never coerced to numeric
  # (it is the caller's own argument, echoed as a constant column).
  expect_type(dt$instrument_name, "character")
  expect_identical(dt$instrument_name, .precision_big_id)
})
