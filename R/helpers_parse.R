# File: R/helpers_parse.R
# The JSON -> data.table parse layer. Each Deribit `result` (a list, array, or
# scalar from the envelope) is shaped into one of the typed shapes documented in
# R/types_deribit.R. Faithful field names are preserved and only snake_cased;
# nested objects (ticker stats/greeks) are flattened with a parent prefix. Every
# parser's empty branch returns a fully-typed zero-row table via an `empty_dt_*()`
# constructor, so a caller's column contract holds on an empty result.

# ---- Small coercers + column extractors -------------------------------------

#' Coerce a possibly-NULL scalar to integer, or NA
#'
#' @param x (any | NULL) a scalar value (number, string, or `NULL`).
#' @return (scalar<integer | NA>) the parsed integer, or `NA_integer_`.
#' @keywords internal
#' @noassert
#' @noRd
deribit_int_or_na <- function(x) {
  out <- NA_integer_
  if (!is.null(x) && length(x) > 0L) {
    out <- suppressWarnings(as.integer(x[[1L]]))
  }
  return(out)
}

# Per-column extractors: map a scalar coercer across a list of records, always
# returning a vector of the record count (so column presence never depends on a
# field being populated in any given record).
.num_col <- function(records, field) {
  return(vapply(records, function(r) connectcore::num_or_na(r[[field]]), numeric(1L)))
}
.chr_col <- function(records, field) {
  return(vapply(records, function(r) connectcore::chr_or_na(r[[field]]), character(1L)))
}
.lgl_col <- function(records, field) {
  return(vapply(records, function(r) connectcore::lgl_or_na(r[[field]]), logical(1L)))
}
.int_col <- function(records, field) {
  return(vapply(records, function(r) deribit_int_or_na(r[[field]]), integer(1L)))
}

# ---- Instruments ------------------------------------------------------------

#' The typed zero-row Instruments table
#'
#' @return (Instruments) a zero-row, fully-typed instruments table.
#' @importFrom lubridate as_datetime
#' @keywords internal
#' @noRd
empty_dt_instruments <- function() {
  return(assert_return_empty_dt_instruments(data.table::data.table(
    instrument_name = character(0L),
    instrument_id = integer(0L),
    kind = character(0L),
    instrument_type = character(0L),
    base_currency = character(0L),
    quote_currency = character(0L),
    counter_currency = character(0L),
    settlement_currency = character(0L),
    settlement_period = character(0L),
    price_index = character(0L),
    is_active = logical(0L),
    state = character(0L),
    expiration_datetime = lubridate::as_datetime(numeric(0L), tz = "UTC"),
    creation_datetime = lubridate::as_datetime(numeric(0L), tz = "UTC"),
    contract_size = numeric(0L),
    tick_size = numeric(0L),
    min_trade_amount = numeric(0L),
    maker_commission = numeric(0L),
    taker_commission = numeric(0L),
    strike = numeric(0L),
    option_type = character(0L),
    max_leverage = numeric(0L)
  )))
}

#' Parse a get_instruments result into the Instruments shape
#'
#' @param result (list | NULL) the array of instrument objects, or `NULL`.
#' @return (Instruments) one row per instrument.
#' @importFrom data.table data.table setorderv
#' @keywords internal
#' @noassert
#' @noRd
parse_instruments <- function(result) {
  out <- empty_dt_instruments()
  if (!is.null(result) && length(result) > 0L) {
    out <- data.table::data.table(
      instrument_name = .chr_col(result, "instrument_name"),
      instrument_id = .int_col(result, "instrument_id"),
      kind = .chr_col(result, "kind"),
      instrument_type = .chr_col(result, "instrument_type"),
      base_currency = .chr_col(result, "base_currency"),
      quote_currency = .chr_col(result, "quote_currency"),
      counter_currency = .chr_col(result, "counter_currency"),
      settlement_currency = .chr_col(result, "settlement_currency"),
      settlement_period = .chr_col(result, "settlement_period"),
      price_index = .chr_col(result, "price_index"),
      is_active = .lgl_col(result, "is_active"),
      state = .chr_col(result, "state"),
      expiration_datetime = connectcore::ms_to_datetime(.num_col(result, "expiration_timestamp")),
      creation_datetime = connectcore::ms_to_datetime(.num_col(result, "creation_timestamp")),
      contract_size = .num_col(result, "contract_size"),
      tick_size = .num_col(result, "tick_size"),
      min_trade_amount = .num_col(result, "min_trade_amount"),
      maker_commission = .num_col(result, "maker_commission"),
      taker_commission = .num_col(result, "taker_commission"),
      strike = .num_col(result, "strike"),
      option_type = .chr_col(result, "option_type"),
      max_leverage = .num_col(result, "max_leverage")
    )
    data.table::setorderv(out, c("kind", "instrument_name"))
  }
  return(out)
}

# ---- Currencies -------------------------------------------------------------

#' The typed zero-row Currencies table
#'
#' @return (Currencies) a zero-row, fully-typed currencies table.
#' @keywords internal
#' @noRd
empty_dt_currencies <- function() {
  return(assert_return_empty_dt_currencies(data.table::data.table(
    currency = character(0L),
    currency_long = character(0L),
    coin_type = character(0L),
    decimals = integer(0L),
    min_confirmations = integer(0L),
    min_withdrawal_fee = numeric(0L),
    withdrawal_fee = numeric(0L),
    network_fee = numeric(0L),
    in_cross_collateral_pool = logical(0L)
  )))
}

#' Parse a get_currencies result into the Currencies shape
#'
#' @param result (list | NULL) the array of currency objects, or `NULL`.
#' @return (Currencies) one row per currency.
#' @importFrom data.table data.table setorderv
#' @keywords internal
#' @noassert
#' @noRd
parse_currencies <- function(result) {
  out <- empty_dt_currencies()
  if (!is.null(result) && length(result) > 0L) {
    out <- data.table::data.table(
      currency = .chr_col(result, "currency"),
      currency_long = .chr_col(result, "currency_long"),
      coin_type = .chr_col(result, "coin_type"),
      decimals = .int_col(result, "decimals"),
      min_confirmations = .int_col(result, "min_confirmations"),
      min_withdrawal_fee = .num_col(result, "min_withdrawal_fee"),
      withdrawal_fee = .num_col(result, "withdrawal_fee"),
      network_fee = .num_col(result, "network_fee"),
      in_cross_collateral_pool = .lgl_col(result, "in_cross_collateral_pool")
    )
    data.table::setorderv(out, "currency")
  }
  return(out)
}

# ---- Ticker (single instrument, nested stats/greeks) ------------------------

#' The typed zero-row Ticker table
#'
#' @return (Ticker) a zero-row, fully-typed ticker table.
#' @importFrom lubridate as_datetime
#' @keywords internal
#' @noRd
empty_dt_ticker <- function() {
  return(assert_return_empty_dt_ticker(data.table::data.table(
    instrument_name = character(0L),
    datetime = lubridate::as_datetime(numeric(0L), tz = "UTC"),
    state = character(0L),
    last_price = numeric(0L),
    mark_price = numeric(0L),
    index_price = numeric(0L),
    best_bid_price = numeric(0L),
    best_bid_amount = numeric(0L),
    best_ask_price = numeric(0L),
    best_ask_amount = numeric(0L),
    settlement_price = numeric(0L),
    min_price = numeric(0L),
    max_price = numeric(0L),
    open_interest = numeric(0L),
    mark_iv = numeric(0L),
    underlying_price = numeric(0L),
    interest_rate = numeric(0L),
    interest_value = numeric(0L),
    current_funding = numeric(0L),
    funding_8h = numeric(0L),
    estimated_delivery_price = numeric(0L),
    stats_high = numeric(0L),
    stats_low = numeric(0L),
    stats_price_change = numeric(0L),
    stats_volume = numeric(0L),
    stats_volume_usd = numeric(0L),
    stats_volume_notional = numeric(0L),
    greeks_delta = numeric(0L),
    greeks_gamma = numeric(0L),
    greeks_vega = numeric(0L),
    greeks_theta = numeric(0L),
    greeks_rho = numeric(0L)
  )))
}

#' Parse a ticker result into the Ticker shape
#'
#' @param result (list | NULL) the single ticker object, or `NULL`.
#' @return (Ticker) a one-row ticker table (empty when `result` is `NULL`).
#' @importFrom data.table data.table
#' @keywords internal
#' @noassert
#' @noRd
parse_ticker <- function(result) {
  out <- empty_dt_ticker()
  if (!is.null(result) && length(result) > 0L) {
    stats <- result[["stats"]]
    greeks <- result[["greeks"]]
    out <- data.table::data.table(
      instrument_name = connectcore::chr_or_na(result[["instrument_name"]]),
      datetime = connectcore::ms_to_datetime(connectcore::num_or_na(result[["timestamp"]])),
      state = connectcore::chr_or_na(result[["state"]]),
      last_price = connectcore::num_or_na(result[["last_price"]]),
      mark_price = connectcore::num_or_na(result[["mark_price"]]),
      index_price = connectcore::num_or_na(result[["index_price"]]),
      best_bid_price = connectcore::num_or_na(result[["best_bid_price"]]),
      best_bid_amount = connectcore::num_or_na(result[["best_bid_amount"]]),
      best_ask_price = connectcore::num_or_na(result[["best_ask_price"]]),
      best_ask_amount = connectcore::num_or_na(result[["best_ask_amount"]]),
      settlement_price = connectcore::num_or_na(result[["settlement_price"]]),
      min_price = connectcore::num_or_na(result[["min_price"]]),
      max_price = connectcore::num_or_na(result[["max_price"]]),
      open_interest = connectcore::num_or_na(result[["open_interest"]]),
      mark_iv = connectcore::num_or_na(result[["mark_iv"]]),
      underlying_price = connectcore::num_or_na(result[["underlying_price"]]),
      interest_rate = connectcore::num_or_na(result[["interest_rate"]]),
      interest_value = connectcore::num_or_na(result[["interest_value"]]),
      current_funding = connectcore::num_or_na(result[["current_funding"]]),
      funding_8h = connectcore::num_or_na(result[["funding_8h"]]),
      estimated_delivery_price = connectcore::num_or_na(result[["estimated_delivery_price"]]),
      stats_high = connectcore::num_or_na(stats[["high"]]),
      stats_low = connectcore::num_or_na(stats[["low"]]),
      stats_price_change = connectcore::num_or_na(stats[["price_change"]]),
      stats_volume = connectcore::num_or_na(stats[["volume"]]),
      stats_volume_usd = connectcore::num_or_na(stats[["volume_usd"]]),
      stats_volume_notional = connectcore::num_or_na(stats[["volume_notional"]]),
      greeks_delta = connectcore::num_or_na(greeks[["delta"]]),
      greeks_gamma = connectcore::num_or_na(greeks[["gamma"]]),
      greeks_vega = connectcore::num_or_na(greeks[["vega"]]),
      greeks_theta = connectcore::num_or_na(greeks[["theta"]]),
      greeks_rho = connectcore::num_or_na(greeks[["rho"]])
    )
  }
  return(out)
}

# ---- Order book (long) ------------------------------------------------------

#' The typed zero-row OrderBook table
#'
#' @return (OrderBook) a zero-row, fully-typed order-book table.
#' @importFrom lubridate as_datetime
#' @keywords internal
#' @noRd
empty_dt_order_book <- function() {
  return(assert_return_empty_dt_order_book(data.table::data.table(
    instrument_name = character(0L),
    datetime = lubridate::as_datetime(numeric(0L), tz = "UTC"),
    side = character(0L),
    level = integer(0L),
    price = numeric(0L),
    amount = numeric(0L)
  )))
}

# Build one side's long rows from an array of [price, amount] pairs.
.book_side_rows <- function(levels, side, instrument_name, book_datetime) {
  rows <- empty_dt_order_book()
  if (!is.null(levels) && length(levels) > 0L) {
    rows <- data.table::data.table(
      instrument_name = instrument_name,
      datetime = book_datetime,
      side = side,
      level = seq_along(levels),
      price = vapply(levels, function(lvl) connectcore::nth_num(lvl, 1L), numeric(1L)),
      amount = vapply(levels, function(lvl) connectcore::nth_num(lvl, 2L), numeric(1L))
    )
  }
  return(rows)
}

#' Parse a get_order_book result into the OrderBook shape
#'
#' @param result (list | NULL) the single order-book object, or `NULL`.
#' @return (OrderBook) one row per price level, bids then asks.
#' @importFrom data.table rbindlist
#' @keywords internal
#' @noassert
#' @noRd
parse_order_book <- function(result) {
  out <- empty_dt_order_book()
  if (!is.null(result) && length(result) > 0L) {
    instrument_name <- connectcore::chr_or_na(result[["instrument_name"]])
    book_datetime <- connectcore::ms_to_datetime(connectcore::num_or_na(result[["timestamp"]]))
    out <- data.table::rbindlist(list(
      .book_side_rows(result[["bids"]], "bid", instrument_name, book_datetime),
      .book_side_rows(result[["asks"]], "ask", instrument_name, book_datetime)
    ))
  }
  return(out)
}

# ---- Index price ------------------------------------------------------------

#' The typed zero-row IndexPrice table
#'
#' @return (IndexPrice) a zero-row, fully-typed index-price table.
#' @keywords internal
#' @noRd
empty_dt_index_price <- function() {
  return(assert_return_empty_dt_index_price(data.table::data.table(
    index_name = character(0L),
    index_price = numeric(0L),
    estimated_delivery_price = numeric(0L)
  )))
}

#' Parse a get_index_price result into the IndexPrice shape
#'
#' @param result (list | NULL) the single index-price object, or `NULL`.
#' @param index_name (scalar<character>) the queried index name (the result does
#'   not echo it).
#' @return (IndexPrice) a one-row index-price table.
#' @importFrom data.table data.table
#' @keywords internal
#' @noassert
#' @noRd
parse_index_price <- function(result, index_name) {
  out <- empty_dt_index_price()
  if (!is.null(result) && length(result) > 0L) {
    out <- data.table::data.table(
      index_name = index_name,
      index_price = connectcore::num_or_na(result[["index_price"]]),
      estimated_delivery_price = connectcore::num_or_na(result[["estimated_delivery_price"]])
    )
  }
  return(out)
}

# ---- DVOL -------------------------------------------------------------------

#' The typed zero-row DvolCandles table
#'
#' @return (DvolCandles) a zero-row, fully-typed DVOL candle table.
#' @importFrom lubridate as_datetime
#' @keywords internal
#' @noRd
empty_dt_dvol_candles <- function() {
  return(assert_return_empty_dt_dvol_candles(data.table::data.table(
    currency = character(0L),
    datetime = lubridate::as_datetime(numeric(0L), tz = "UTC"),
    resolution = character(0L),
    open = numeric(0L),
    high = numeric(0L),
    low = numeric(0L),
    close = numeric(0L)
  )))
}

#' Parse a get_volatility_index_data result into the DvolCandles shape
#'
#' @param result (list | NULL) the object `{ data, continuation }`, or `NULL`.
#'   `data` is an array of `[timestamp_ms, open, high, low, close]` rows.
#' @param currency (scalar<character>) the queried currency (a constant column).
#' @param resolution (scalar<character>) the queried resolution (a constant
#'   column).
#' @return (DvolCandles) one row per candle, sorted by time ascending.
#' @importFrom data.table data.table setorderv
#' @keywords internal
#' @noassert
#' @noRd
parse_dvol <- function(result, currency, resolution) {
  out <- empty_dt_dvol_candles()
  rows <- if (is.list(result)) result[["data"]] else NULL
  if (!is.null(rows) && length(rows) > 0L) {
    out <- data.table::data.table(
      currency = currency,
      datetime = connectcore::ms_to_datetime(vapply(rows, function(r) connectcore::nth_num(r, 1L), numeric(1L))),
      resolution = resolution,
      open = vapply(rows, function(r) connectcore::nth_num(r, 2L), numeric(1L)),
      high = vapply(rows, function(r) connectcore::nth_num(r, 3L), numeric(1L)),
      low = vapply(rows, function(r) connectcore::nth_num(r, 4L), numeric(1L)),
      close = vapply(rows, function(r) connectcore::nth_num(r, 5L), numeric(1L))
    )
    data.table::setorderv(out, "datetime")
  }
  return(out)
}

# ---- Funding rate history ---------------------------------------------------

#' The typed zero-row FundingRateHistory table
#'
#' @return (FundingRateHistory) a zero-row, fully-typed funding-history table.
#' @importFrom lubridate as_datetime
#' @keywords internal
#' @noRd
empty_dt_funding_rate_history <- function() {
  return(assert_return_empty_dt_funding_rate_history(data.table::data.table(
    instrument_name = character(0L),
    datetime = lubridate::as_datetime(numeric(0L), tz = "UTC"),
    index_price = numeric(0L),
    prev_index_price = numeric(0L),
    interest_8h = numeric(0L),
    interest_1h = numeric(0L)
  )))
}

#' Parse a get_funding_rate_history result into the FundingRateHistory shape
#'
#' @param result (list | NULL) the array of funding samples, or `NULL`.
#' @param instrument_name (scalar<character>) the queried instrument (the samples
#'   do not echo it).
#' @return (FundingRateHistory) one row per sample, sorted by time ascending.
#' @importFrom data.table data.table setorderv
#' @keywords internal
#' @noassert
#' @noRd
parse_funding_rate_history <- function(result, instrument_name) {
  out <- empty_dt_funding_rate_history()
  if (!is.null(result) && length(result) > 0L) {
    out <- data.table::data.table(
      instrument_name = instrument_name,
      datetime = connectcore::ms_to_datetime(.num_col(result, "timestamp")),
      index_price = .num_col(result, "index_price"),
      prev_index_price = .num_col(result, "prev_index_price"),
      interest_8h = .num_col(result, "interest_8h"),
      interest_1h = .num_col(result, "interest_1h")
    )
    data.table::setorderv(out, "datetime")
  }
  return(out)
}

# ---- Funding rate value (scalar) --------------------------------------------

#' The typed zero-row FundingRateValue table
#'
#' @return (FundingRateValue) a zero-row, fully-typed funding-value table.
#' @importFrom lubridate as_datetime
#' @keywords internal
#' @noRd
empty_dt_funding_rate_value <- function() {
  return(assert_return_empty_dt_funding_rate_value(data.table::data.table(
    instrument_name = character(0L),
    start_datetime = lubridate::as_datetime(numeric(0L), tz = "UTC"),
    end_datetime = lubridate::as_datetime(numeric(0L), tz = "UTC"),
    funding_rate_value = numeric(0L)
  )))
}

#' Parse a get_funding_rate_value result (a bare scalar) into the FundingRateValue shape
#'
#' @param result (scalar<numeric> | NULL) the aggregate funding value, or `NULL`.
#' @param instrument_name (scalar<character>) the queried instrument.
#' @param start_datetime (class<POSIXct>) the window start.
#' @param end_datetime (class<POSIXct>) the window end.
#' @return (FundingRateValue) a one-row funding-value table.
#' @importFrom data.table data.table
#' @keywords internal
#' @noassert
#' @noRd
parse_funding_rate_value <- function(result, instrument_name, start_datetime, end_datetime) {
  return(data.table::data.table(
    instrument_name = instrument_name,
    start_datetime = start_datetime,
    end_datetime = end_datetime,
    funding_rate_value = connectcore::num_or_na(result)
  ))
}

# ---- Trades -----------------------------------------------------------------

#' The typed zero-row Trade table
#'
#' @return (Trade) a zero-row, fully-typed trade table.
#' @importFrom lubridate as_datetime
#' @keywords internal
#' @noRd
empty_dt_trade <- function() {
  return(assert_return_empty_dt_trade(data.table::data.table(
    trade_id = character(0L),
    instrument_name = character(0L),
    datetime = lubridate::as_datetime(numeric(0L), tz = "UTC"),
    trade_seq = integer(0L),
    direction = character(0L),
    price = numeric(0L),
    amount = numeric(0L),
    index_price = numeric(0L),
    mark_price = numeric(0L),
    iv = numeric(0L),
    tick_direction = integer(0L),
    contracts = numeric(0L),
    liquidation = character(0L)
  )))
}

#' Parse a get_last_trades_by_instrument result into the Trade shape
#'
#' @param result (list | NULL) the object `{ trades, has_more }`, or `NULL`.
#' @return (Trade) one row per trade.
#' @importFrom data.table data.table
#' @keywords internal
#' @noassert
#' @noRd
parse_trades <- function(result) {
  out <- empty_dt_trade()
  trades <- if (is.list(result)) result[["trades"]] else NULL
  if (!is.null(trades) && length(trades) > 0L) {
    out <- data.table::data.table(
      trade_id = .chr_col(trades, "trade_id"),
      instrument_name = .chr_col(trades, "instrument_name"),
      datetime = connectcore::ms_to_datetime(.num_col(trades, "timestamp")),
      trade_seq = .int_col(trades, "trade_seq"),
      direction = .chr_col(trades, "direction"),
      price = .num_col(trades, "price"),
      amount = .num_col(trades, "amount"),
      index_price = .num_col(trades, "index_price"),
      mark_price = .num_col(trades, "mark_price"),
      iv = .num_col(trades, "iv"),
      tick_direction = .int_col(trades, "tick_direction"),
      contracts = .num_col(trades, "contracts"),
      liquidation = .chr_col(trades, "liquidation")
    )
  }
  return(out)
}

# ---- Book summary -----------------------------------------------------------

#' The typed zero-row BookSummary table
#'
#' @return (BookSummary) a zero-row, fully-typed book-summary table.
#' @importFrom lubridate as_datetime
#' @keywords internal
#' @noRd
empty_dt_book_summary <- function() {
  return(assert_return_empty_dt_book_summary(data.table::data.table(
    instrument_name = character(0L),
    base_currency = character(0L),
    quote_currency = character(0L),
    datetime = lubridate::as_datetime(numeric(0L), tz = "UTC"),
    mid_price = numeric(0L),
    bid_price = numeric(0L),
    ask_price = numeric(0L),
    last = numeric(0L),
    mark_price = numeric(0L),
    high = numeric(0L),
    low = numeric(0L),
    open_interest = numeric(0L),
    volume = numeric(0L),
    volume_usd = numeric(0L),
    volume_notional = numeric(0L),
    price_change = numeric(0L),
    estimated_delivery_price = numeric(0L),
    mark_iv = numeric(0L),
    underlying_price = numeric(0L),
    underlying_index = character(0L),
    interest_rate = numeric(0L),
    current_funding = numeric(0L),
    funding_8h = numeric(0L)
  )))
}

#' Parse a get_book_summary_* result into the BookSummary shape
#'
#' @param result (list | NULL) the array of book-summary objects, or `NULL`.
#' @return (BookSummary) one row per instrument.
#' @importFrom data.table data.table setorderv
#' @keywords internal
#' @noassert
#' @noRd
parse_book_summary <- function(result) {
  out <- empty_dt_book_summary()
  if (!is.null(result) && length(result) > 0L) {
    out <- data.table::data.table(
      instrument_name = .chr_col(result, "instrument_name"),
      base_currency = .chr_col(result, "base_currency"),
      quote_currency = .chr_col(result, "quote_currency"),
      datetime = connectcore::ms_to_datetime(.num_col(result, "creation_timestamp")),
      mid_price = .num_col(result, "mid_price"),
      bid_price = .num_col(result, "bid_price"),
      ask_price = .num_col(result, "ask_price"),
      last = .num_col(result, "last"),
      mark_price = .num_col(result, "mark_price"),
      high = .num_col(result, "high"),
      low = .num_col(result, "low"),
      open_interest = .num_col(result, "open_interest"),
      volume = .num_col(result, "volume"),
      volume_usd = .num_col(result, "volume_usd"),
      volume_notional = .num_col(result, "volume_notional"),
      price_change = .num_col(result, "price_change"),
      estimated_delivery_price = .num_col(result, "estimated_delivery_price"),
      mark_iv = .num_col(result, "mark_iv"),
      underlying_price = .num_col(result, "underlying_price"),
      underlying_index = .chr_col(result, "underlying_index"),
      interest_rate = .num_col(result, "interest_rate"),
      current_funding = .num_col(result, "current_funding"),
      funding_8h = .num_col(result, "funding_8h")
    )
    data.table::setorderv(out, "instrument_name")
  }
  return(out)
}
