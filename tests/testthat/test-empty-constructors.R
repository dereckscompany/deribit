# Guards the typed-empty invariant: every parser's empty branch must return a
# zero-row data.table that still carries its full typed column set (and no list
# column), never a column-less data.table() -- which would silently violate the
# methods' column @return contracts on an empty result.

box::use(./mock_router[.fixture_result])

test_that("the typed-empty constructors return zero-row typed tables", {
  empties <- list(
    instruments = empty_dt_instruments(),
    currencies = empty_dt_currencies(),
    ticker = empty_dt_ticker(),
    order_book = empty_dt_order_book(),
    index_price = empty_dt_index_price(),
    dvol_candles = empty_dt_dvol_candles(),
    funding_rate_history = empty_dt_funding_rate_history(),
    funding_rate_value = empty_dt_funding_rate_value(),
    trade = empty_dt_trade(),
    book_summary = empty_dt_book_summary()
  )
  for (nm in names(empties)) {
    dt <- empties[[nm]]
    expect_s3_class(dt, "data.table")
    expect_identical(nrow(dt), 0L, label = nm)
    expect_true(ncol(dt) > 0L, label = paste(nm, "columns"))
    expect_false(any(vapply(dt, is.list, logical(1L))), label = paste(nm, "list column"))
  }
})

test_that("empty constructors expose the documented column sets", {
  expect_named(
    empty_dt_order_book(),
    c("instrument_name", "datetime", "side", "level", "price", "amount")
  )
  expect_named(
    empty_dt_index_price(),
    c("index_name", "index_price", "estimated_delivery_price")
  )
  expect_named(
    empty_dt_dvol_candles(),
    c("currency", "datetime", "resolution", "open", "high", "low", "close")
  )
  expect_named(
    empty_dt_funding_rate_value(),
    c("instrument_name", "start_datetime", "end_datetime", "funding_rate_value")
  )
  expect_true("strike" %in% names(empty_dt_instruments()))
  expect_true(all(c("greeks_delta", "stats_volume_notional") %in% names(empty_dt_ticker())))
})

test_that("empty and populated agree on column names and types (drift guard)", {
  cases <- list(
    instruments = list(
      empty = empty_dt_instruments(),
      populated = parse_instruments(.fixture_result("instruments_future"))
    ),
    ticker = list(
      empty = empty_dt_ticker(),
      populated = parse_ticker(.fixture_result("ticker_option"))
    ),
    order_book = list(
      empty = empty_dt_order_book(),
      populated = parse_order_book(.fixture_result("order_book"))
    ),
    book_summary = list(
      empty = empty_dt_book_summary(),
      populated = parse_book_summary(.fixture_result("book_summary_option"))
    )
  )
  for (nm in names(cases)) {
    empty <- cases[[nm]]$empty
    populated <- cases[[nm]]$populated
    expect_gt(nrow(populated), 0L)
    expect_identical(names(populated), names(empty), label = paste(nm, "names"))
    expect_identical(
      vapply(populated, function(x) class(x)[1L], ""),
      vapply(empty, function(x) class(x)[1L], ""),
      label = paste(nm, "types")
    )
  }
})

test_that("every parser returns a typed zero-row empty on empty / null input", {
  cases <- list(
    instruments = parse_instruments(NULL),
    instruments_empty = parse_instruments(list()),
    currencies = parse_currencies(NULL),
    ticker = parse_ticker(NULL),
    order_book = parse_order_book(NULL),
    index_price = parse_index_price(NULL, "btc_usd"),
    dvol = parse_dvol(NULL, "BTC", "3600"),
    dvol_no_data = parse_dvol(list(continuation = NULL, data = list()), "BTC", "3600"),
    funding_history = parse_funding_rate_history(NULL, "BTC-PERPETUAL"),
    trades = parse_trades(NULL),
    trades_no_trades = parse_trades(list(has_more = FALSE, trades = list())),
    book_summary = parse_book_summary(NULL)
  )
  for (nm in names(cases)) {
    dt <- cases[[nm]]
    expect_s3_class(dt, "data.table")
    expect_identical(nrow(dt), 0L, label = nm)
    expect_true(ncol(dt) > 0L, label = paste(nm, "columns"))
    expect_false(any(vapply(dt, is.list, logical(1L))), label = paste(nm, "list column"))
  }
})
