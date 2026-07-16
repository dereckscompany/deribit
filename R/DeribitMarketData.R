# File: R/DeribitMarketData.R
# The public market-data client. Deribit's public JSON-RPC 2.0 methods are called
# over HTTP GET (query-encoded, no auth), so this class inherits connectcore's
# generic transport (sync/async funnel, retry, throttle) from
# connectcore::RestClient and customises only the one Deribit-specific seam: the
# JSON-RPC envelope (.parse_envelope, which unwraps `result` and raises a typed
# error on an `error` object). There is no `.sign()` override -- the public
# surface signs nothing.

#' DeribitMarketData: Deribit Public Market-Data Client
#'
#' @description
#' The R6 client for Deribit's public market-data surface — the instrument
#' universe, live quotes, the DVOL volatility index, perpetual funding, public
#' trades, and option-chain book summaries. Every method speaks Deribit's
#' JSON-RPC 2.0 over HTTP GET and returns a tidy [data.table::data.table] typed
#' per [deribit_shapes].
#'
#' @details
#' The class inherits the generic transport (the single sync/async request
#' funnel, retry, throttle) from [connectcore::RestClient] and customises only the
#' `.parse_envelope()` seam (via the internal `parse_deribit_response()`), which
#' unwraps the JSON-RPC `result` and raises a typed [deribit_conditions] error
#' when the response carries an `error` object.
#'
#' ### Sync vs async
#' The `async` argument selects the execution mode for every method:
#' - `async = FALSE` (default): methods return a [data.table::data.table].
#' - `async = TRUE`: methods return a [promises::promise] that resolves to the
#'   same `data.table`.
#'
#' The mode is stored once as `private$.is_async` and threaded through every
#' method's `connectcore::then_or_now(res, ..., is_async = private$.is_async)`
#' tail; nothing hardcodes it. Consume promises with [coro::async()] and `await()`;
#' drive the loop in a script with `while (!later::loop_empty()) later::run_now()`.
#'
#' ### No API key
#' The `public/*` endpoints require no credential, so the client is constructed
#' with no key. `max_tries` opts idempotent GET reads into retry on a transient
#' failure (public reads are GET, so retry is always safe here).
#'
#' @examples
#' \dontrun{
#' md <- DeribitMarketData$new()
#'
#' # The option universe and a single chain snapshot:
#' options <- md$get_instruments("BTC", kind = "option")
#' chain <- md$get_book_summary_by_currency("BTC", kind = "option")
#'
#' # The DVOL volatility index (the regime dial):
#' dvol <- md$get_volatility_index_data(
#'   "BTC",
#'   start_timestamp = lubridate::now("UTC") - lubridate::days(7),
#'   end_timestamp = lubridate::now("UTC"),
#'   resolution = "3600"
#' )
#'
#' # Perpetual funding:
#' funding <- md$get_funding_rate_history(
#'   "BTC-PERPETUAL",
#'   start_timestamp = lubridate::now("UTC") - lubridate::days(7),
#'   end_timestamp = lubridate::now("UTC")
#' )
#'
#' # Asynchronous:
#' md_async <- DeribitMarketData$new(async = TRUE)
#' main <- coro::async(function() {
#'   ticker <- await(md_async$get_ticker("BTC-PERPETUAL"))
#'   print(ticker)
#' })
#' main()
#' while (!later::loop_empty()) later::run_now()
#' }
#'
#' @import data.table
#' @importFrom R6 R6Class
#' @export
DeribitMarketData <- R6::R6Class(
  "DeribitMarketData",
  inherit = connectcore::RestClient,
  public = list(
    #' @description Initialise a DeribitMarketData client.
    #' @param base_url (scalar<character>) the Deribit API base URL. Defaults to
    #'   [deribit_base_url()].
    #' @param async (scalar<logical>) if `TRUE`, methods return promises. Default
    #'   `FALSE`.
    #' @param max_tries (scalar<count in [1, Inf[>) retry an idempotent GET up to
    #'   this many times on a transient failure (408, 429, any 5xx, or a connection
    #'   failure). Every public read is a GET, so retry is always safe. Default `1`
    #'   (no retry).
    #' @param throttle_rate (scalar<numeric in ]0, Inf[> | NULL) client-side rate
    #'   cap in requests/second. Default `NULL` (no throttle).
    #' @return (class<DeribitMarketData>) invisibly, self.
    initialize = function(base_url = deribit_base_url(), async = FALSE, max_tries = 1L, throttle_rate = NULL) {
      assert_args_DeribitMarketData__initialize(base_url, async, max_tries, throttle_rate)
      super$initialize(
        keys = NULL,
        base_url = base_url,
        async = async,
        body_format = "none",
        user_agent = "dereckscompany/deribit",
        max_tries = max_tries,
        throttle_rate = throttle_rate
      )
      return(invisible(assert_return_DeribitMarketData__initialize(self)))
    },

    #' @description Retrieve the tradeable instrument universe for a currency.
    #' @param currency (scalar<character>) the currency, e.g. `"BTC"`.
    #' @param kind (scalar<character> | NULL) the instrument-kind filter, one of
    #'   `names(INSTRUMENT_KIND)` ("future", "option", "spot", "future_combo",
    #'   "option_combo"); `NULL` returns every kind. Default `NULL`.
    #' @param expired (scalar<logical>) if `TRUE`, return expired instruments
    #'   instead of the live universe. Default `FALSE`.
    #' @return (Instruments | promise<Instruments>) one row per instrument, or a
    #'   promise thereof.
    get_instruments = function(currency, kind = NULL, expired = FALSE) {
      assert_args_DeribitMarketData__get_instruments(currency, kind, expired)
      private$.validate_kind(kind)
      res <- private$.request(
        endpoint = "/public/get_instruments",
        query = list(currency = currency, kind = kind, expired = deribit_bool(expired)),
        .parser = parse_instruments
      )
      return(connectcore::then_or_now(
        res,
        assert_return_DeribitMarketData__get_instruments,
        is_async = private$.is_async
      ))
    },

    #' @description List the currencies Deribit supports.
    #' @return (Currencies | promise<Currencies>) one row per currency, or a
    #'   promise thereof.
    get_currencies = function() {
      res <- private$.request(
        endpoint = "/public/get_currencies",
        .parser = parse_currencies
      )
      return(connectcore::then_or_now(
        res,
        assert_return_DeribitMarketData__get_currencies,
        is_async = private$.is_async
      ))
    },

    #' @description Retrieve the combined stats/quote ticker for one instrument.
    #' @param instrument_name (scalar<character>) the instrument, e.g.
    #'   `"BTC-PERPETUAL"`.
    #' @return (Ticker | promise<Ticker>) a one-row ticker table, or a promise
    #'   thereof.
    get_ticker = function(instrument_name) {
      assert_args_DeribitMarketData__get_ticker(instrument_name)
      res <- private$.request(
        endpoint = "/public/ticker",
        query = list(instrument_name = instrument_name),
        .parser = parse_ticker
      )
      return(connectcore::then_or_now(
        res,
        assert_return_DeribitMarketData__get_ticker,
        is_async = private$.is_async
      ))
    },

    #' @description Retrieve the order book for one instrument as a long
    #'   (one-row-per-level) table.
    #' @param instrument_name (scalar<character>) the instrument, e.g.
    #'   `"BTC-PERPETUAL"`.
    #' @param depth (scalar<count in [1, Inf[> | NULL) the number of price levels
    #'   per side; `NULL` uses the venue default. Default `NULL`.
    #' @return (OrderBook | promise<OrderBook>) one row per price level (bids then
    #'   asks), or a promise thereof.
    get_order_book = function(instrument_name, depth = NULL) {
      assert_args_DeribitMarketData__get_order_book(instrument_name, depth)
      res <- private$.request(
        endpoint = "/public/get_order_book",
        query = list(instrument_name = instrument_name, depth = depth),
        .parser = parse_order_book
      )
      return(connectcore::then_or_now(
        res,
        assert_return_DeribitMarketData__get_order_book,
        is_async = private$.is_async
      ))
    },

    #' @description Retrieve the current value of a price index.
    #' @param index_name (scalar<character>) the index name, e.g. `"btc_usd"`.
    #' @return (IndexPrice | promise<IndexPrice>) a one-row index-price table, or a
    #'   promise thereof.
    get_index_price = function(index_name) {
      assert_args_DeribitMarketData__get_index_price(index_name)
      res <- private$.request(
        endpoint = "/public/get_index_price",
        query = list(index_name = index_name),
        .parser = function(result) parse_index_price(result, index_name)
      )
      return(connectcore::then_or_now(
        res,
        assert_return_DeribitMarketData__get_index_price,
        is_async = private$.is_async
      ))
    },

    #' @description Retrieve DVOL volatility-index candles over a time window. A
    #'   single call returns up to ~1000 candles; page a longer range by moving
    #'   `end_timestamp` back to the earliest returned candle's time.
    #' @param currency (scalar<character>) the currency, e.g. `"BTC"`.
    #' @param start_timestamp (class<POSIXct>) the window start (inclusive).
    #' @param end_timestamp (class<POSIXct>) the window end (inclusive). Must not
    #'   precede `start_timestamp`.
    #' @param resolution (scalar<character>) the candle resolution, one of
    #'   `DVOL_RESOLUTIONS` ("1", "60", "3600", "43200" seconds, or "1D" daily).
    #' @return (DvolCandles | promise<DvolCandles>) one row per candle, or a promise
    #'   thereof.
    get_volatility_index_data = function(currency, start_timestamp, end_timestamp, resolution) {
      assert_args_DeribitMarketData__get_volatility_index_data(
        currency,
        start_timestamp,
        end_timestamp,
        resolution
      )
      private$.validate_choice(resolution, unlist(DVOL_RESOLUTIONS, use.names = FALSE), "resolution")
      private$.require_window(start_timestamp, end_timestamp)
      res <- private$.request(
        endpoint = "/public/get_volatility_index_data",
        query = list(
          currency = currency,
          start_timestamp = deribit_ms(start_timestamp),
          end_timestamp = deribit_ms(end_timestamp),
          resolution = resolution
        ),
        .parser = function(result) parse_dvol(result, currency, resolution)
      )
      return(connectcore::then_or_now(
        res,
        assert_return_DeribitMarketData__get_volatility_index_data,
        is_async = private$.is_async
      ))
    },

    #' @description Retrieve a DVOL window as the venue's own **raw object** — the
    #'   parsed JSON `{ data, continuation }` exactly as Deribit returns it. This
    #'   is the lossless counterpart to `get_volatility_index_data()`: that method
    #'   returns tidy candle rows and drops the paging cursor, whereas this
    #'   preserves both the raw `[timestamp_ms, open, high, low, close]` `data`
    #'   rows and the `continuation` cursor Deribit returns when more history
    #'   remains (its next `end_timestamp` in ms, or JSON `null` when the range is
    #'   exhausted). A backfill pages a range longer than one response by feeding
    #'   `continuation` back as the next `end_timestamp`.
    #' @param currency (scalar<character>) the currency, e.g. `"BTC"`.
    #' @param start_timestamp (class<POSIXct>) the window start (inclusive).
    #' @param end_timestamp (class<POSIXct>) the window end (inclusive). Must not
    #'   precede `start_timestamp`.
    #' @param resolution (scalar<character>) the candle resolution, one of
    #'   `DVOL_RESOLUTIONS` ("1", "60", "3600", "43200" seconds, or "1D" daily).
    #' @return (list | promise<list>) the raw `{ data, continuation }` object, or
    #'   a promise thereof.
    get_volatility_index_data_raw = function(currency, start_timestamp, end_timestamp, resolution) {
      assert_args_DeribitMarketData__get_volatility_index_data_raw(
        currency,
        start_timestamp,
        end_timestamp,
        resolution
      )
      private$.validate_choice(resolution, unlist(DVOL_RESOLUTIONS, use.names = FALSE), "resolution")
      private$.require_window(start_timestamp, end_timestamp)
      res <- private$.request(
        endpoint = "/public/get_volatility_index_data",
        query = list(
          currency = currency,
          start_timestamp = deribit_ms(start_timestamp),
          end_timestamp = deribit_ms(end_timestamp),
          resolution = resolution
        ),
        .parser = identity
      )
      return(connectcore::then_or_now(
        res,
        assert_return_DeribitMarketData__get_volatility_index_data_raw,
        is_async = private$.is_async
      ))
    },

    #' @description Retrieve the funding-rate history for a perpetual over a
    #'   window.
    #' @param instrument_name (scalar<character>) the perpetual, e.g.
    #'   `"BTC-PERPETUAL"`.
    #' @param start_timestamp (class<POSIXct>) the window start (inclusive).
    #' @param end_timestamp (class<POSIXct>) the window end (inclusive). Must not
    #'   precede `start_timestamp`.
    #' @return (FundingRateHistory | promise<FundingRateHistory>) one row per
    #'   sample, or a promise thereof.
    get_funding_rate_history = function(instrument_name, start_timestamp, end_timestamp) {
      assert_args_DeribitMarketData__get_funding_rate_history(
        instrument_name,
        start_timestamp,
        end_timestamp
      )
      private$.require_window(start_timestamp, end_timestamp)
      res <- private$.request(
        endpoint = "/public/get_funding_rate_history",
        query = list(
          instrument_name = instrument_name,
          start_timestamp = deribit_ms(start_timestamp),
          end_timestamp = deribit_ms(end_timestamp)
        ),
        .parser = function(result) parse_funding_rate_history(result, instrument_name)
      )
      return(connectcore::then_or_now(
        res,
        assert_return_DeribitMarketData__get_funding_rate_history,
        is_async = private$.is_async
      ))
    },

    #' @description Retrieve the aggregate funding rate for a perpetual over a
    #'   window (the current funding when the window is the last 8 hours).
    #' @param instrument_name (scalar<character>) the perpetual, e.g.
    #'   `"BTC-PERPETUAL"`.
    #' @param start_timestamp (class<POSIXct>) the window start (inclusive).
    #' @param end_timestamp (class<POSIXct>) the window end (inclusive). Must not
    #'   precede `start_timestamp`.
    #' @return (FundingRateValue | promise<FundingRateValue>) a one-row aggregate
    #'   funding table, or a promise thereof.
    get_funding_rate_value = function(instrument_name, start_timestamp, end_timestamp) {
      assert_args_DeribitMarketData__get_funding_rate_value(
        instrument_name,
        start_timestamp,
        end_timestamp
      )
      private$.require_window(start_timestamp, end_timestamp)
      res <- private$.request(
        endpoint = "/public/get_funding_rate_value",
        query = list(
          instrument_name = instrument_name,
          start_timestamp = deribit_ms(start_timestamp),
          end_timestamp = deribit_ms(end_timestamp)
        ),
        .parser = function(result) {
          return(parse_funding_rate_value(result, instrument_name, start_timestamp, end_timestamp))
        }
      )
      return(connectcore::then_or_now(
        res,
        assert_return_DeribitMarketData__get_funding_rate_value,
        is_async = private$.is_async
      ))
    },

    #' @description Retrieve the most recent public trades for one instrument.
    #' @param instrument_name (scalar<character>) the instrument, e.g.
    #'   `"BTC-PERPETUAL"`.
    #' @param count (scalar<count in [1, Inf[> | NULL) the maximum number of trades
    #'   to return; `NULL` uses the venue default. Default `NULL`.
    #' @param start_timestamp (class<POSIXct> | NULL) the earliest trade time to
    #'   include; `NULL` omits the bound. Default `NULL`.
    #' @param end_timestamp (class<POSIXct> | NULL) the latest trade time to
    #'   include; `NULL` omits the bound. Default `NULL`.
    #' @param sorting (scalar<character> | NULL) the sort order, one of
    #'   `TRADE_SORTING` ("asc", "desc", "default"); `NULL` uses the venue default.
    #'   Default `NULL`.
    #' @return (Trade | promise<Trade>) one row per trade, or a promise thereof.
    get_last_trades_by_instrument = function(
      instrument_name,
      count = NULL,
      start_timestamp = NULL,
      end_timestamp = NULL,
      sorting = NULL
    ) {
      assert_args_DeribitMarketData__get_last_trades_by_instrument(
        instrument_name,
        count,
        start_timestamp,
        end_timestamp,
        sorting
      )
      private$.validate_choice(sorting, unlist(TRADE_SORTING, use.names = FALSE), "sorting")
      res <- private$.request(
        endpoint = "/public/get_last_trades_by_instrument",
        query = list(
          instrument_name = instrument_name,
          count = count,
          start_timestamp = if (is.null(start_timestamp)) NULL else deribit_ms(start_timestamp),
          end_timestamp = if (is.null(end_timestamp)) NULL else deribit_ms(end_timestamp),
          sorting = sorting
        ),
        .parser = parse_trades
      )
      return(connectcore::then_or_now(
        res,
        assert_return_DeribitMarketData__get_last_trades_by_instrument,
        is_async = private$.is_async
      ))
    },

    #' @description Retrieve the book summary for every live instrument of a
    #'   currency (with `kind = "option"` this is the option-chain snapshot the
    #'   fleet consumes).
    #' @param currency (scalar<character>) the currency, e.g. `"BTC"`.
    #' @param kind (scalar<character> | NULL) the instrument-kind filter, one of
    #'   `names(INSTRUMENT_KIND)` ("future", "option", "spot", "future_combo",
    #'   "option_combo"); `NULL` returns every kind. Default `NULL`.
    #' @return (BookSummary | promise<BookSummary>) one row per instrument, or a
    #'   promise thereof.
    get_book_summary_by_currency = function(currency, kind = NULL) {
      assert_args_DeribitMarketData__get_book_summary_by_currency(currency, kind)
      private$.validate_kind(kind)
      res <- private$.request(
        endpoint = "/public/get_book_summary_by_currency",
        query = list(currency = currency, kind = kind),
        .parser = parse_book_summary
      )
      return(connectcore::then_or_now(
        res,
        assert_return_DeribitMarketData__get_book_summary_by_currency,
        is_async = private$.is_async
      ))
    },

    #' @description Retrieve the book summary for every live instrument of a
    #'   currency as the venue's own **raw records** — the parsed JSON array
    #'   exactly as Deribit returns it, in venue order, with every field preserved
    #'   (including `creation_timestamp`, which the typed table derives away) and a
    #'   JSON `null` kept distinct from an absent field. This is the lossless
    #'   counterpart to `get_book_summary_by_currency()`: where that method returns
    #'   a tidy typed `data.table`, this returns the untouched records a bronze
    #'   passthrough archives verbatim. Each element is one instrument's book
    #'   summary as a named list.
    #' @param currency (scalar<character>) the currency, e.g. `"BTC"`.
    #' @param kind (scalar<character> | NULL) the instrument-kind filter, one of
    #'   `names(INSTRUMENT_KIND)` ("future", "option", "spot", "future_combo",
    #'   "option_combo"); `NULL` returns every kind. Default `NULL`.
    #' @return (list | promise<list>) the raw book-summary records (one named list
    #'   per instrument), or a promise thereof.
    get_book_summary_by_currency_raw = function(currency, kind = NULL) {
      assert_args_DeribitMarketData__get_book_summary_by_currency_raw(currency, kind)
      private$.validate_kind(kind)
      res <- private$.request(
        endpoint = "/public/get_book_summary_by_currency",
        query = list(currency = currency, kind = kind),
        .parser = identity
      )
      return(connectcore::then_or_now(
        res,
        assert_return_DeribitMarketData__get_book_summary_by_currency_raw,
        is_async = private$.is_async
      ))
    },

    #' @description Retrieve the book summary for one instrument.
    #' @param instrument_name (scalar<character>) the instrument, e.g.
    #'   `"BTC-PERPETUAL"`.
    #' @return (BookSummary | promise<BookSummary>) a one-row book-summary table,
    #'   or a promise thereof.
    get_book_summary_by_instrument = function(instrument_name) {
      assert_args_DeribitMarketData__get_book_summary_by_instrument(instrument_name)
      res <- private$.request(
        endpoint = "/public/get_book_summary_by_instrument",
        query = list(instrument_name = instrument_name),
        .parser = parse_book_summary
      )
      return(connectcore::then_or_now(
        res,
        assert_return_DeribitMarketData__get_book_summary_by_instrument,
        is_async = private$.is_async
      ))
    },

    #' @description Retrieve the option-chain snapshot for a currency. A
    #'   convenience wrapper over `get_book_summary_by_currency(currency,
    #'   kind = "option")` — the one Deribit call the scraper's option-chain
    #'   collector consumes.
    #' @param currency (scalar<character>) the currency, e.g. `"BTC"`.
    #' @return (BookSummary | promise<BookSummary>) one row per live option, or a
    #'   promise thereof.
    #' @noassert
    get_option_chain = function(currency) {
      return(self$get_book_summary_by_currency(currency = currency, kind = INSTRUMENT_KIND$option))
    },

    #' @description Retrieve the option-chain snapshot for a currency as the
    #'   venue's own **raw records** (the lossless counterpart to
    #'   `get_option_chain()`): a convenience wrapper over
    #'   `get_book_summary_by_currency_raw(currency, kind = "option")` — the one
    #'   Deribit call the scraper's option-chain collector archives verbatim as
    #'   bronze.
    #' @param currency (scalar<character>) the currency, e.g. `"BTC"`.
    #' @return (list | promise<list>) the raw option book-summary records (one
    #'   named list per live option), or a promise thereof.
    #' @noassert
    get_option_chain_raw = function(currency) {
      return(self$get_book_summary_by_currency_raw(currency = currency, kind = INSTRUMENT_KIND$option))
    }
  ),
  private = list(
    # The one Deribit-specific seam: unwrap the JSON-RPC `result` and raise a
    # typed error on an `error` object. (.sign stays the default no-op -- the
    # public surface signs nothing.)
    .parse_envelope = function(resp) {
      return(parse_deribit_response(resp))
    },

    # Reject an unknown instrument kind before spending a request.
    .validate_kind = function(kind) {
      if (!is.null(kind) && !kind %in% names(INSTRUMENT_KIND)) {
        abort_deribit_validation_error(paste0(
          "Invalid instrument kind '",
          kind,
          "'. Valid kinds: ",
          paste(names(INSTRUMENT_KIND), collapse = ", "),
          "."
        ))
      }
      return(invisible(kind))
    },
    # Reject a value outside a fixed vocabulary (NULL passes -- the arg is optional).
    .validate_choice = function(value, allowed, name) {
      if (!is.null(value) && !value %in% allowed) {
        abort_deribit_validation_error(paste0(
          "Invalid ",
          name,
          " '",
          value,
          "'. Valid values: ",
          paste(allowed, collapse = ", "),
          "."
        ))
      }
      return(invisible(value))
    },
    # Reject a window whose end precedes its start.
    .require_window = function(start_timestamp, end_timestamp) {
      if (end_timestamp < start_timestamp) {
        abort_deribit_validation_error(
          "`end_timestamp` must not precede `start_timestamp`."
        )
      }
      return(invisible(NULL))
    }
  )
)
