# File: R/types_deribit.R
# Reusable roxyassert `@type` shapes for the data.tables the public surface
# returns. Each request-making method documents its return as one of these named
# shapes via `(Shape | promise<Shape>)`; the contract roclet expands the shape
# into that method's generated `assert_return_*` helper, so every column's
# presence and type is enforced at the public boundary -- for both the
# synchronous value and the resolved value of a promise (wired through
# `connectcore::then_or_now()`). The parsers in R/helpers_parse.R build the same
# shapes and their empty branches return the fully-typed zero-row table
# (`empty_dt_*()`), so a shape's column contract holds even on an empty result.

#' @title deribit return shapes
#' @description Reusable roxyassert `@type` shapes for the parsed deribit
#' `data.table`s. Measurement columns (market prices, sizes, greeks, funding, and
#' any venue field that is legitimately absent for a given instrument kind) are
#' typed `| NA`; structural columns (identifiers, instrument descriptors, sides,
#' period timestamps, and flags) are strict. Faithful field names are preserved
#' verbatim and only snake_cased; nested JSON objects are flattened with the
#' parent field as a prefix (`stats.high` -> stats_high, `greeks.delta` ->
#' greeks_delta). `deribit` is a leaf connector: nothing internal calls a
#' per-shape validator and no downstream package validates against these shapes,
#' so there is no `@genassert` and no `@exportassert`; the shapes exist only to be
#' expanded into each method's own return contract.
#' @name deribit_shapes
#'
#' @type Instruments (data.table) one row per tradeable instrument, as parsed from `public/get_instruments`:
#' - instrument_name (character) the venue instrument name, e.g. "BTC-PERPETUAL"; structural.
#' - instrument_id (integer) the venue numeric instrument id; structural.
#' - kind (character) the instrument kind: "future", "option", "spot", "future_combo", "option_combo"; structural.
#' - instrument_type (character) the settlement type, "reversed" (inverse) or "linear"; structural.
#' - base_currency (character) the base currency, e.g. "BTC"; structural.
#' - quote_currency (character) the quote currency; structural.
#' - counter_currency (character) the counter currency; structural.
#' - settlement_currency (character | NA) the settlement currency; NA for a combo with no single settlement currency.
#' - settlement_period (character) the settlement period: "perpetual", "day", "week", "month", ...; structural.
#' - price_index (character) the price index the instrument settles against, e.g. "btc_usd"; structural.
#' - is_active (logical) whether the instrument is currently tradeable; structural.
#' - state (character) the instrument state, e.g. "open"; structural.
#' - expiration_datetime (POSIXct) the expiration time in UTC (a far-future sentinel for perpetuals); structural.
#' - creation_datetime (POSIXct) the listing/creation time in UTC; structural.
#' - contract_size (numeric) the contract size; structural.
#' - tick_size (numeric) the minimum price increment; structural.
#' - min_trade_amount (numeric) the minimum order amount; structural.
#' - maker_commission (numeric) the maker fee rate; structural.
#' - taker_commission (numeric) the taker fee rate; structural.
#' - strike (numeric | NA) the option strike price; NA for non-options.
#' - option_type (character | NA) "call" or "put"; NA for non-options.
#' - max_leverage (numeric | NA) the maximum leverage; NA for options.
#'
#' @type Currencies (data.table) one row per supported currency, as parsed from `public/get_currencies`:
#' - currency (character) the currency symbol, e.g. "BTC"; structural.
#' - currency_long (character) the human-readable name, e.g. "Bitcoin"; structural.
#' - coin_type (character) the coin type / network family, e.g. "BTC"; structural.
#' - decimals (integer | NA) the on-chain decimal precision; NA when absent.
#' - min_confirmations (integer | NA) confirmations required for a deposit; NA when absent.
#' - min_withdrawal_fee (numeric | NA) the minimum withdrawal fee; NA when absent.
#' - withdrawal_fee (numeric | NA) the standard withdrawal fee; NA when absent.
#' - network_fee (numeric | NA) the on-chain network fee; NA when absent.
#' - in_cross_collateral_pool (logical | NA) whether the currency is in the cross-collateral pool; NA when absent.
#'
#' @type Ticker (data.table) one row, the combined stats/quote snapshot for one instrument, from `public/ticker`:
#' - instrument_name (character) the instrument name; structural.
#' - datetime (POSIXct) the ticker timestamp in UTC; structural.
#' - state (character) the instrument state, e.g. "open"; structural.
#' - last_price (numeric | NA) the last trade price; NA when the instrument has not traded.
#' - mark_price (numeric | NA) the mark price; measurement.
#' - index_price (numeric | NA) the underlying index price; measurement.
#' - best_bid_price (numeric | NA) the best bid price; NA when there is no bid.
#' - best_bid_amount (numeric | NA) the size at the best bid; measurement.
#' - best_ask_price (numeric | NA) the best ask price; NA when there is no ask.
#' - best_ask_amount (numeric | NA) the size at the best ask; measurement.
#' - settlement_price (numeric | NA) the last settlement price; measurement.
#' - min_price (numeric | NA) the current lower price band; measurement.
#' - max_price (numeric | NA) the current upper price band; measurement.
#' - open_interest (numeric | NA) the open interest; measurement.
#' - mark_iv (numeric | NA) the mark implied volatility (options only); NA for non-options.
#' - underlying_price (numeric | NA) the option underlying price (options only); NA for non-options.
#' - interest_rate (numeric | NA) the option interest rate (options only); NA for non-options.
#' - interest_value (numeric | NA) the accrued interest value (futures only); NA otherwise.
#' - current_funding (numeric | NA) the current funding rate (perpetuals only); NA otherwise.
#' - funding_8h (numeric | NA) the 8-hour funding rate (perpetuals only); NA otherwise.
#' - estimated_delivery_price (numeric | NA) the estimated delivery price; measurement.
#' - stats_high (numeric | NA) the 24h high (stats.high); measurement.
#' - stats_low (numeric | NA) the 24h low (stats.low); measurement.
#' - stats_price_change (numeric | NA) the 24h percentage price change (stats.price_change); measurement.
#' - stats_volume (numeric | NA) the 24h volume in base currency (stats.volume); measurement.
#' - stats_volume_usd (numeric | NA) the 24h volume in USD (stats.volume_usd); measurement.
#' - stats_volume_notional (numeric | NA) the 24h notional volume (stats.volume_notional); measurement.
#' - greeks_delta (numeric | NA) option delta (greeks.delta); NA for non-options.
#' - greeks_gamma (numeric | NA) option gamma (greeks.gamma); NA for non-options.
#' - greeks_vega (numeric | NA) option vega (greeks.vega); NA for non-options.
#' - greeks_theta (numeric | NA) option theta (greeks.theta); NA for non-options.
#' - greeks_rho (numeric | NA) option rho (greeks.rho); NA for non-options.
#'
#' @type OrderBook (data.table) one row per price level, long form, from `public/get_order_book`:
#' - instrument_name (character) the instrument name; structural.
#' - datetime (POSIXct) the book timestamp in UTC; structural.
#' - side (character) the book side, "bid" or "ask"; structural.
#' - level (integer) the 1-based depth rank within the side (1 = best); structural.
#' - price (numeric) the price at this level; structural to the level row.
#' - amount (numeric) the size at this level; structural to the level row.
#'
#' @type IndexPrice (data.table) one row, an index price, from `public/get_index_price`:
#' - index_name (character) the index name, e.g. "btc_usd"; structural.
#' - index_price (numeric | NA) the current index price; measurement.
#' - estimated_delivery_price (numeric | NA) the estimated delivery price; measurement.
#'
#' @type DvolCandles (data.table) one row per DVOL candle, from `public/get_volatility_index_data`:
#' - currency (character) the currency the DVOL index is for, e.g. "BTC"; structural.
#' - datetime (POSIXct) the candle open time in UTC; structural.
#' - resolution (character) the candle resolution token, e.g. "3600"; structural.
#' - open (numeric) the candle open volatility; structural to the candle.
#' - high (numeric) the candle high volatility; structural to the candle.
#' - low (numeric) the candle low volatility; structural to the candle.
#' - close (numeric) the candle close volatility; structural to the candle.
#'
#' @type FundingRateHistory (data.table) one row per funding sample, from `public/get_funding_rate_history`:
#' - instrument_name (character) the perpetual instrument name; structural.
#' - datetime (POSIXct) the sample timestamp in UTC; structural.
#' - index_price (numeric | NA) the index price at the sample; measurement.
#' - prev_index_price (numeric | NA) the prior index price; measurement.
#' - interest_8h (numeric | NA) the 8-hour interest (funding) rate; measurement.
#' - interest_1h (numeric | NA) the 1-hour interest (funding) rate; measurement.
#'
#' @type FundingRateValue (data.table) one row, aggregate funding over a window (`public/get_funding_rate_value`):
#' - instrument_name (character) the perpetual instrument name; structural.
#' - start_datetime (POSIXct) the window start in UTC; structural.
#' - end_datetime (POSIXct) the window end in UTC; structural.
#' - funding_rate_value (numeric | NA) the aggregate funding rate over the window; measurement.
#'
#' @type Trade (data.table) one row per public trade, from `public/get_last_trades_by_instrument`:
#' - trade_id (character) the venue trade id; structural.
#' - instrument_name (character) the instrument name; structural.
#' - datetime (POSIXct) the trade time in UTC; structural.
#' - trade_seq (integer | NA) the per-instrument trade sequence number; structural.
#' - direction (character) the taker direction, "buy" or "sell"; structural.
#' - price (numeric) the execution price; structural to the trade.
#' - amount (numeric) the traded amount; structural to the trade.
#' - index_price (numeric | NA) the index price at the trade; measurement.
#' - mark_price (numeric | NA) the mark price at the trade; measurement.
#' - iv (numeric | NA) the trade implied volatility (options only); NA for non-options.
#' - tick_direction (integer | NA) the tick-direction flag (0-3); measurement.
#' - contracts (numeric | NA) the number of contracts (perpetuals/futures); NA otherwise.
#' - liquidation (character | NA) the liquidation flag ("M"/"T"/"MT") when the trade was a liquidation; NA otherwise.
#'
#' @type BookSummary (data.table) one row per instrument, the chain/quote summary (`public/get_book_summary_*`):
#' - instrument_name (character) the instrument name; structural.
#' - base_currency (character) the base currency; structural.
#' - quote_currency (character) the quote currency; structural.
#' - datetime (POSIXct) the summary creation time in UTC; structural.
#' - mid_price (numeric | NA) the mid price; NA when a side is empty.
#' - bid_price (numeric | NA) the best bid price; NA when there is no bid.
#' - ask_price (numeric | NA) the best ask price; NA when there is no ask.
#' - last (numeric | NA) the last trade price; NA when the instrument has not traded.
#' - mark_price (numeric | NA) the mark price; measurement.
#' - high (numeric | NA) the 24h high; measurement.
#' - low (numeric | NA) the 24h low; measurement.
#' - open_interest (numeric | NA) the open interest; measurement.
#' - volume (numeric | NA) the 24h volume in base currency; measurement.
#' - volume_usd (numeric | NA) the 24h volume in USD; measurement.
#' - volume_notional (numeric | NA) the 24h notional volume (futures only); NA otherwise.
#' - price_change (numeric | NA) the 24h percentage price change; measurement.
#' - estimated_delivery_price (numeric | NA) the estimated delivery price; measurement.
#' - mark_iv (numeric | NA) the mark implied volatility (options only); NA for non-options.
#' - underlying_price (numeric | NA) the option underlying price (options only); NA for non-options.
#' - underlying_index (character | NA) the option underlying index name (options only); NA for non-options.
#' - interest_rate (numeric | NA) the option interest rate (options only); NA for non-options.
#' - current_funding (numeric | NA) the current funding rate (perpetuals only); NA otherwise.
#' - funding_8h (numeric | NA) the 8-hour funding rate (perpetuals only); NA otherwise.
NULL
