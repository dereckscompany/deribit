# DeribitMarketData: Deribit Public Market-Data Client

The R6 client for Deribit's public market-data surface — the instrument
universe, live quotes, the DVOL volatility index, perpetual funding,
public trades, and option-chain book summaries. Every method speaks
Deribit's JSON-RPC 2.0 over HTTP GET and returns a tidy
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
typed per
[deribit_shapes](https://dereckscompany.github.io/deribit/reference/deribit_shapes.md).

## Details

The class inherits the generic transport (the single sync/async request
funnel, retry, throttle) from
[connectcore::RestClient](https://dereckscompany.github.io/connectcore/reference/RestClient.html)
and customises only the `.parse_envelope()` seam (via the internal
`parse_deribit_response()`), which unwraps the JSON-RPC `result` and
raises a typed
[deribit_conditions](https://dereckscompany.github.io/deribit/reference/deribit_conditions.md)
error when the response carries an `error` object.

### Sync vs async

The `async` argument selects the execution mode for every method:

- `async = FALSE` (default): methods return a
  [data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html).

- `async = TRUE`: methods return a
  [promises::promise](https://rstudio.github.io/promises/reference/promise.html)
  that resolves to the same `data.table`.

The mode is stored once as `private$.is_async` and threaded through
every method's
`connectcore::then_or_now(res, ..., is_async = private$.is_async)` tail;
nothing hardcodes it. Consume promises with
[`coro::async()`](https://coro.r-lib.org/reference/async.html) and
`await()`; drive the loop in a script with
`while (!later::loop_empty()) later::run_now()`.

### No API key

The `public/*` endpoints require no credential, so the client is
constructed with no key. `max_tries` opts idempotent GET reads into
retry on a transient failure (public reads are GET, so retry is always
safe here).

## Super class

[`connectcore::RestClient`](https://dereckscompany.github.io/connectcore/reference/RestClient.html)
-\> `DeribitMarketData`

## Methods

### Public methods

- [`DeribitMarketData$new()`](#method-DeribitMarketData-new)

- [`DeribitMarketData$get_instruments()`](#method-DeribitMarketData-get_instruments)

- [`DeribitMarketData$get_currencies()`](#method-DeribitMarketData-get_currencies)

- [`DeribitMarketData$get_ticker()`](#method-DeribitMarketData-get_ticker)

- [`DeribitMarketData$get_order_book()`](#method-DeribitMarketData-get_order_book)

- [`DeribitMarketData$get_index_price()`](#method-DeribitMarketData-get_index_price)

- [`DeribitMarketData$get_volatility_index_data()`](#method-DeribitMarketData-get_volatility_index_data)

- [`DeribitMarketData$get_volatility_index_data_raw()`](#method-DeribitMarketData-get_volatility_index_data_raw)

- [`DeribitMarketData$get_funding_rate_history()`](#method-DeribitMarketData-get_funding_rate_history)

- [`DeribitMarketData$get_funding_rate_value()`](#method-DeribitMarketData-get_funding_rate_value)

- [`DeribitMarketData$get_last_trades_by_instrument()`](#method-DeribitMarketData-get_last_trades_by_instrument)

- [`DeribitMarketData$get_book_summary_by_currency()`](#method-DeribitMarketData-get_book_summary_by_currency)

- [`DeribitMarketData$get_book_summary_by_currency_raw()`](#method-DeribitMarketData-get_book_summary_by_currency_raw)

- [`DeribitMarketData$get_book_summary_by_instrument()`](#method-DeribitMarketData-get_book_summary_by_instrument)

- [`DeribitMarketData$get_option_chain()`](#method-DeribitMarketData-get_option_chain)

- [`DeribitMarketData$get_option_chain_raw()`](#method-DeribitMarketData-get_option_chain_raw)

- [`DeribitMarketData$clone()`](#method-DeribitMarketData-clone)

------------------------------------------------------------------------

### Method `new()`

Initialise a DeribitMarketData client.

#### Usage

    DeribitMarketData$new(
      base_url = deribit_base_url(),
      async = FALSE,
      max_tries = 1L,
      throttle_rate = NULL
    )

#### Arguments

- `base_url`:

  (scalar\<character\>) the Deribit API base URL. Defaults to
  [`deribit_base_url()`](https://dereckscompany.github.io/deribit/reference/deribit_base_url.md).

- `async`:

  (scalar\<logical\>) if `TRUE`, methods return promises. Default
  `FALSE`.

- `max_tries`:

  (scalar\<count in \[1, Inf\[\>) retry an idempotent GET up to this
  many times on a transient failure (408, 429, any 5xx, or a connection
  failure). Every public read is a GET, so retry is always safe. Default
  `1` (no retry).

- `throttle_rate`:

  (scalar\<numeric in \]0, Inf\[\> \| NULL) client-side rate cap in
  requests/second. Default `NULL` (no throttle).

#### Returns

(class\<DeribitMarketData\>) invisibly, self.

------------------------------------------------------------------------

### Method `get_instruments()`

Retrieve the tradeable instrument universe for a currency.

#### Usage

    DeribitMarketData$get_instruments(currency, kind = NULL, expired = FALSE)

#### Arguments

- `currency`:

  (scalar\<character\>) the currency, e.g. `"BTC"`.

- `kind`:

  (scalar\<character\> \| NULL) the instrument-kind filter, one of
  `names(INSTRUMENT_KIND)` ("future", "option", "spot", "future_combo",
  "option_combo"); `NULL` returns every kind. Default `NULL`.

- `expired`:

  (scalar\<logical\>) if `TRUE`, return expired instruments instead of
  the live universe. Default `FALSE`.

#### Returns

(Instruments \| promise\<Instruments\>) one row per instrument, or a
promise thereof.

------------------------------------------------------------------------

### Method `get_currencies()`

List the currencies Deribit supports.

#### Usage

    DeribitMarketData$get_currencies()

#### Returns

(Currencies \| promise\<Currencies\>) one row per currency, or a promise
thereof.

------------------------------------------------------------------------

### Method `get_ticker()`

Retrieve the combined stats/quote ticker for one instrument.

#### Usage

    DeribitMarketData$get_ticker(instrument_name)

#### Arguments

- `instrument_name`:

  (scalar\<character\>) the instrument, e.g. `"BTC-PERPETUAL"`.

#### Returns

(Ticker \| promise\<Ticker\>) a one-row ticker table, or a promise
thereof.

------------------------------------------------------------------------

### Method `get_order_book()`

Retrieve the order book for one instrument as a long (one-row-per-level)
table.

#### Usage

    DeribitMarketData$get_order_book(instrument_name, depth = NULL)

#### Arguments

- `instrument_name`:

  (scalar\<character\>) the instrument, e.g. `"BTC-PERPETUAL"`.

- `depth`:

  (scalar\<count in \[1, Inf\[\> \| NULL) the number of price levels per
  side; `NULL` uses the venue default. Default `NULL`.

#### Returns

(OrderBook \| promise\<OrderBook\>) one row per price level (bids then
asks), or a promise thereof.

------------------------------------------------------------------------

### Method `get_index_price()`

Retrieve the current value of a price index.

#### Usage

    DeribitMarketData$get_index_price(index_name)

#### Arguments

- `index_name`:

  (scalar\<character\>) the index name, e.g. `"btc_usd"`.

#### Returns

(IndexPrice \| promise\<IndexPrice\>) a one-row index-price table, or a
promise thereof.

------------------------------------------------------------------------

### Method `get_volatility_index_data()`

Retrieve DVOL volatility-index candles over a time window. A single call
returns up to ~1000 candles; page a longer range by moving
`end_timestamp` back to the earliest returned candle's time.

#### Usage

    DeribitMarketData$get_volatility_index_data(
      currency,
      start_timestamp,
      end_timestamp,
      resolution
    )

#### Arguments

- `currency`:

  (scalar\<character\>) the currency, e.g. `"BTC"`.

- `start_timestamp`:

  (class\<POSIXct\>) the window start (inclusive).

- `end_timestamp`:

  (class\<POSIXct\>) the window end (inclusive). Must not precede
  `start_timestamp`.

- `resolution`:

  (scalar\<character\>) the candle resolution, one of `DVOL_RESOLUTIONS`
  ("1", "60", "3600", "43200" seconds, or "1D" daily).

#### Returns

(DvolCandles \| promise\<DvolCandles\>) one row per candle, or a promise
thereof.

------------------------------------------------------------------------

### Method `get_volatility_index_data_raw()`

Retrieve a DVOL window as the venue's own **raw object** — the parsed
JSON `{ data, continuation }` exactly as Deribit returns it. This is the
lossless counterpart to `get_volatility_index_data()`: that method
returns tidy candle rows and drops the paging cursor, whereas this
preserves both the raw `[timestamp_ms, open, high, low, close]` `data`
rows and the `continuation` cursor Deribit returns when more history
remains (its next `end_timestamp` in ms, or JSON `null` when the range
is exhausted). A backfill pages a range longer than one response by
feeding `continuation` back as the next `end_timestamp`.

#### Usage

    DeribitMarketData$get_volatility_index_data_raw(
      currency,
      start_timestamp,
      end_timestamp,
      resolution
    )

#### Arguments

- `currency`:

  (scalar\<character\>) the currency, e.g. `"BTC"`.

- `start_timestamp`:

  (class\<POSIXct\>) the window start (inclusive).

- `end_timestamp`:

  (class\<POSIXct\>) the window end (inclusive). Must not precede
  `start_timestamp`.

- `resolution`:

  (scalar\<character\>) the candle resolution, one of `DVOL_RESOLUTIONS`
  ("1", "60", "3600", "43200" seconds, or "1D" daily).

#### Returns

(list \| promise\<list\>) the raw `{ data, continuation }` object, or a
promise thereof.

------------------------------------------------------------------------

### Method `get_funding_rate_history()`

Retrieve the funding-rate history for a perpetual over a window.

#### Usage

    DeribitMarketData$get_funding_rate_history(
      instrument_name,
      start_timestamp,
      end_timestamp
    )

#### Arguments

- `instrument_name`:

  (scalar\<character\>) the perpetual, e.g. `"BTC-PERPETUAL"`.

- `start_timestamp`:

  (class\<POSIXct\>) the window start (inclusive).

- `end_timestamp`:

  (class\<POSIXct\>) the window end (inclusive). Must not precede
  `start_timestamp`.

#### Returns

(FundingRateHistory \| promise\<FundingRateHistory\>) one row per
sample, or a promise thereof.

------------------------------------------------------------------------

### Method `get_funding_rate_value()`

Retrieve the aggregate funding rate for a perpetual over a window (the
current funding when the window is the last 8 hours).

#### Usage

    DeribitMarketData$get_funding_rate_value(
      instrument_name,
      start_timestamp,
      end_timestamp
    )

#### Arguments

- `instrument_name`:

  (scalar\<character\>) the perpetual, e.g. `"BTC-PERPETUAL"`.

- `start_timestamp`:

  (class\<POSIXct\>) the window start (inclusive).

- `end_timestamp`:

  (class\<POSIXct\>) the window end (inclusive). Must not precede
  `start_timestamp`.

#### Returns

(FundingRateValue \| promise\<FundingRateValue\>) a one-row aggregate
funding table, or a promise thereof.

------------------------------------------------------------------------

### Method `get_last_trades_by_instrument()`

Retrieve the most recent public trades for one instrument.

#### Usage

    DeribitMarketData$get_last_trades_by_instrument(
      instrument_name,
      count = NULL,
      start_timestamp = NULL,
      end_timestamp = NULL,
      sorting = NULL
    )

#### Arguments

- `instrument_name`:

  (scalar\<character\>) the instrument, e.g. `"BTC-PERPETUAL"`.

- `count`:

  (scalar\<count in \[1, Inf\[\> \| NULL) the maximum number of trades
  to return; `NULL` uses the venue default. Default `NULL`.

- `start_timestamp`:

  (class\<POSIXct\> \| NULL) the earliest trade time to include; `NULL`
  omits the bound. Default `NULL`.

- `end_timestamp`:

  (class\<POSIXct\> \| NULL) the latest trade time to include; `NULL`
  omits the bound. Default `NULL`.

- `sorting`:

  (scalar\<character\> \| NULL) the sort order, one of `TRADE_SORTING`
  ("asc", "desc", "default"); `NULL` uses the venue default. Default
  `NULL`.

#### Returns

(Trade \| promise\<Trade\>) one row per trade, or a promise thereof.

------------------------------------------------------------------------

### Method `get_book_summary_by_currency()`

Retrieve the book summary for every live instrument of a currency (with
`kind = "option"` this is the option-chain snapshot the fleet consumes).

#### Usage

    DeribitMarketData$get_book_summary_by_currency(currency, kind = NULL)

#### Arguments

- `currency`:

  (scalar\<character\>) the currency, e.g. `"BTC"`.

- `kind`:

  (scalar\<character\> \| NULL) the instrument-kind filter, one of
  `names(INSTRUMENT_KIND)` ("future", "option", "spot", "future_combo",
  "option_combo"); `NULL` returns every kind. Default `NULL`.

#### Returns

(BookSummary \| promise\<BookSummary\>) one row per instrument, or a
promise thereof.

------------------------------------------------------------------------

### Method `get_book_summary_by_currency_raw()`

Retrieve the book summary for every live instrument of a currency as the
venue's own **raw records** — the parsed JSON array exactly as Deribit
returns it, in venue order, with every field preserved (including
`creation_timestamp`, which the typed table derives away) and a JSON
`null` kept distinct from an absent field. This is the lossless
counterpart to `get_book_summary_by_currency()`: where that method
returns a tidy typed `data.table`, this returns the untouched records a
bronze passthrough archives verbatim. Each element is one instrument's
book summary as a named list.

#### Usage

    DeribitMarketData$get_book_summary_by_currency_raw(currency, kind = NULL)

#### Arguments

- `currency`:

  (scalar\<character\>) the currency, e.g. `"BTC"`.

- `kind`:

  (scalar\<character\> \| NULL) the instrument-kind filter, one of
  `names(INSTRUMENT_KIND)` ("future", "option", "spot", "future_combo",
  "option_combo"); `NULL` returns every kind. Default `NULL`.

#### Returns

(list \| promise\<list\>) the raw book-summary records (one named list
per instrument), or a promise thereof.

------------------------------------------------------------------------

### Method `get_book_summary_by_instrument()`

Retrieve the book summary for one instrument.

#### Usage

    DeribitMarketData$get_book_summary_by_instrument(instrument_name)

#### Arguments

- `instrument_name`:

  (scalar\<character\>) the instrument, e.g. `"BTC-PERPETUAL"`.

#### Returns

(BookSummary \| promise\<BookSummary\>) a one-row book-summary table, or
a promise thereof.

------------------------------------------------------------------------

### Method `get_option_chain()`

Retrieve the option-chain snapshot for a currency. A convenience wrapper
over `get_book_summary_by_currency(currency, kind = "option")` — the one
Deribit call the scraper's option-chain collector consumes.

#### Usage

    DeribitMarketData$get_option_chain(currency)

#### Arguments

- `currency`:

  (scalar\<character\>) the currency, e.g. `"BTC"`.

#### Returns

(BookSummary \| promise\<BookSummary\>) one row per live option, or a
promise thereof.

------------------------------------------------------------------------

### Method `get_option_chain_raw()`

Retrieve the option-chain snapshot for a currency as the venue's own
**raw records** (the lossless counterpart to `get_option_chain()`): a
convenience wrapper over
`get_book_summary_by_currency_raw(currency, kind = "option")` — the one
Deribit call the scraper's option-chain collector archives verbatim as
bronze.

#### Usage

    DeribitMarketData$get_option_chain_raw(currency)

#### Arguments

- `currency`:

  (scalar\<character\>) the currency, e.g. `"BTC"`.

#### Returns

(list \| promise\<list\>) the raw option book-summary records (one named
list per live option), or a promise thereof.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    DeribitMarketData$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
if (FALSE) { # \dontrun{
md <- DeribitMarketData$new()

# The option universe and a single chain snapshot:
options <- md$get_instruments("BTC", kind = "option")
chain <- md$get_book_summary_by_currency("BTC", kind = "option")

# The DVOL volatility index (the regime dial):
dvol <- md$get_volatility_index_data(
  "BTC",
  start_timestamp = lubridate::now("UTC") - lubridate::days(7),
  end_timestamp = lubridate::now("UTC"),
  resolution = "3600"
)

# Perpetual funding:
funding <- md$get_funding_rate_history(
  "BTC-PERPETUAL",
  start_timestamp = lubridate::now("UTC") - lubridate::days(7),
  end_timestamp = lubridate::now("UTC")
)

# Asynchronous:
md_async <- DeribitMarketData$new(async = TRUE)
main <- coro::async(function() {
  ticker <- await(md_async$get_ticker("BTC-PERPETUAL"))
  print(ticker)
})
main()
while (!later::loop_empty()) later::run_now()
} # }
```
