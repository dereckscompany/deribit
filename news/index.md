# Changelog

## deribit 0.2.2

Fix the rendered README: a cross-reference to the promises package was
showing up as literal escaped brackets instead of a link.

In plain English: the README described asynchronous calls using an R
help-page cross-reference syntax that only resolves inside R’s own help
viewer. GitHub does not understand that syntax, so the rendered README
on GitHub showed the literal text “\[promise\]\[promises::promise\]”
instead of a working link. This release replaces it with a plain
markdown link, matching the fix already shipped in the hyperliquid and
polymarket connectors.

- README.Rmd: replaced the Rd-style `[promise][promises::promise]`
  cross-reference with a plain markdown link to
  <https://rstudio.github.io/promises/>, and re-rendered README.md via
  `scripts/BUILD.sh readme`.

## deribit 0.2.1

**A regression test that guards against price data ever being truncated
again.** In plain English: on 2026-09-13 the fleet discovered that every
Hyperliquid candle in the data lake had been stored to four decimal
places for months, so a coin priced below a cent lost almost all of its
information, and a strategy that ranks coins by calmness ranked them
wrongly as a result. The cause was traced and proved NOT to be in the
venue connector packages — this package’s parse path turns Deribit’s own
JSON numbers into R numbers at full precision, with no truncation — it
was a re-serialisation default in the data scraper, since fixed. This
release adds a test that pins that correctness in place for Deribit
specifically: if anyone later introduces
[`round()`](https://rdrr.io/r/base/Round.html),
[`signif()`](https://rdrr.io/r/base/Round.html), `sprintf("%.4f")`,
`format(nsmall = )`, or a narrowing cast into a parse helper, the test
fails immediately.

- Added `tests/testthat/test-parse-precision.R`: drives `get_ticker()`,
  `get_book_summary_by_currency()` (the option-chain snapshot, mark
  price and implied volatility), and `get_funding_rate_history()`
  through the real public client, via synthetic high-precision JSON-RPC
  fixtures (authored as raw wire text, matching Deribit’s
  bare-JSON-number format) routed through the shared `connectcore` mock
  harness. Every numeric column is asserted `expect_identical()` (never
  tolerance-based) against
  [`as.numeric()`](https://rdrr.io/r/base/numeric.html) of the fixture’s
  own decimal literal, and a big-integer-looking `instrument_name` is
  asserted to stay character and unchanged.
- No behaviour change: the parse path
  ([`connectcore::num_or_na()`](https://dereckscompany.github.io/connectcore/reference/num_or_na.html)
  -\> [`as.numeric()`](https://rdrr.io/r/base/numeric.html), threaded
  through `R/helpers_parse.R`) was already correct and is untouched.

## deribit 0.2.0

Lossless raw accessors alongside the typed surface, for byte-faithful
bronze archival.

In plain English: the typed `data.table` methods are the right default
for analysis, but a raw-data archive wants the exchange’s own records
untouched — every field, in the venue’s order, with a genuine “no value”
(a JSON `null`) kept distinct from “field not sent”. This release adds
raw siblings for the two surfaces the scraper’s `deribit-options`
collector archives, so the archive stores exactly what Deribit sent and
the tidy tables remain the analysis convenience.

- `get_book_summary_by_currency_raw()` and its option-chain convenience
  `get_option_chain_raw()`: the parsed JSON array of book-summary
  records exactly as Deribit returns it — one named list per instrument,
  in venue order, every field preserved (including the raw
  `creation_timestamp` the typed table derives into `datetime` and
  drops), a JSON `null` kept as R `NULL` (distinct from an absent
  field), and no invented columns (an option never carries
  `volume_notional`/`current_funding`/`funding_8h`, so the raw record
  simply omits them where the typed table fills all-NA columns).
- `get_volatility_index_data_raw()`: the raw `{ data, continuation }`
  object exactly as Deribit returns it, exposing both the untouched
  `[timestamp_ms, open, high, low, close]` `data` rows and the
  `continuation` paging cursor that the typed
  `get_volatility_index_data()` drops — so a backfill can page a range
  longer than one response by feeding `continuation` back as the next
  `end_timestamp`.
- Each raw method carries a roxyassert `(list | promise<list>)` contract
  and threads sync/async from the constructor exactly like its typed
  sibling; both are covered end-to-end against the synthetic mock router
  (a new paged DVOL fixture carries a non-null continuation cursor). The
  typed methods are unchanged.

## deribit 0.1.0

Initial release: the Deribit crypto-derivatives exchange in the fleet’s
connector idiom — public market data only.

In plain English: Deribit is where the crypto options market lives, and
this package fetches its public market data — the option and futures
universe, live quotes and order books, the DVOL volatility index (our
regime dial), perpetual funding rates, recent trades, and the whole
option-chain snapshot — through one typed, tested interface that works
both synchronously and asynchronously, so our research and any future
strategy can consume Deribit data exactly the way it consumes every
other exchange’s. There is no trading and no login in this phase;
everything here is the public, keyless surface.

- `DeribitMarketData`: the public market-data client over the shared
  `connectcore` transport base. It covers the instrument universe
  (`get_instruments`, `get_currencies`), live quotes (`get_ticker`,
  `get_order_book`, `get_index_price`), the DVOL volatility index
  (`get_volatility_index_data`), perpetual funding
  (`get_funding_rate_history`, `get_funding_rate_value`), public trades
  (`get_last_trades_by_instrument`), and the option-chain book summaries
  (`get_book_summary_by_currency`, `get_book_summary_by_instrument`, and
  the `get_option_chain` convenience). Sync and async threaded from the
  constructor via `connectcore`.
- Faithful typed shapes (Instruments, Ticker, OrderBook, IndexPrice,
  DvolCandles, FundingRateHistory, FundingRateValue, Trade, BookSummary,
  Currencies) with every column documented as typed bullets. Faithful
  venue field names are preserved and only snake_cased; nested JSON
  objects (ticker `stats`/`greeks`) are flattened with the parent field
  as a prefix. Measurement columns and any field that is legitimately
  absent for a given instrument kind (an option’s greeks, a perpetual’s
  funding, a null bid) are typed `| NA`; structural columns are strict.
- Typed conditions from birth: `deribit_api_error` layered in front of
  the `connectcore` transport chain (carrying the HTTP `status`,
  Deribit’s JSON-RPC `code`, and the `reason`/`param` detail unwrapped
  from the JSON-RPC `error` object), and `deribit_validation_error`
  under the `deribit_error` domain root for a bad argument caught before
  any request.
- Grounded against the live public API and served offline by fully
  synthetic mock fixtures (a null option bid/mid and null option stats
  to exercise the `| NA` columns, a liquidation trade, and both kinds of
  ticker). Three design facts corrected against reality: the ticker
  endpoint is `public/ticker` (not `public/get_ticker`); a business
  error arrives as an HTTP 400 carrying a JSON-RPC `error` object;
  `get_funding_rate_value` returns a bare scalar, wrapped here into a
  one-row window table.

Not built in this release (deliberately out of scope): the private
authenticated surface (orders, positions, account) and the WebSocket
subscription streams. The scraper’s `deribit-options` collector is the
intended future dogfood consumer of this package’s
`get_volatility_index_data` and `get_book_summary_by_currency`.
