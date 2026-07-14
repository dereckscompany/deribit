
# deribit

R API wrapper to the [Deribit](https://www.deribit.com) crypto options
and derivatives exchange, supporting both synchronous and asynchronous
(promise based) operations. Provides an R6 market-data client for the
public JSON-RPC endpoints — instruments, ticker, order book, index
price, DVOL volatility index, funding rates, trades, and option-chain
book summaries — built on the shared
[connectcore](https://github.com/dereckscompany/connectcore) transport
base.

## What this is

Deribit is where the crypto **options** market lives — the deepest venue
for BTC and ETH options, the perpetual and dated futures alongside them,
and the **DVOL** volatility index that the whole desk watches as a
regime dial. This package gives you Deribit’s public market data as tidy
`data.table`s: the instrument universe, live quotes and order books,
DVOL candles, perpetual funding, recent trades, and the full
option-chain snapshot.

It is a faithful, low-level wrapper: it speaks Deribit’s JSON-RPC 2.0
wire format and returns clean tables, preserving the venue’s own field
names (only snake_cased), but it does not editorialise the data. **Phase
1 is public market data only** — there is no trading and no
authenticated surface, and the public endpoints need no API key.

## Design philosophy

- **`data.table` everywhere, no list columns.** Every method returns one
  flat `data.table`; measurement columns (and any field legitimately
  absent for a given instrument kind — an option’s greeks, a perpetual’s
  funding, a null bid) are typed nullable, structural columns strict.
- **Sync and async.** Every request-making surface works in both modes.
  `async = TRUE` returns a \[promise\]\[promises::promise\]; otherwise
  the table is returned directly. There is a single sync/async branch
  point (inherited from `connectcore`).
- **Faithful field names.** Venue-native names are preserved and only
  snake_cased; nested objects (a ticker’s `stats`/`greeks`) are
  flattened with the parent field as a prefix (`stats_high`,
  `greeks_delta`).
- **Typed errors.** Every failure is a classed condition
  (`deribit_api_error`, `deribit_validation_error`) carrying structured
  fields — you branch on the type, never grep the message.

## Installation

This project uses [`renv`](https://rstudio.github.io/renv/). Add
`deribit` to your lockfile and restore:

``` r
renv::install("dereckscompany/deribit")
# or, without renv:
# remotes::install_github("dereckscompany/deribit")
```

## The instrument universe

Every method hangs off one client. The public endpoints need no key, so
construction takes no credential.

``` r
md <- DeribitMarketData$new()

options <- md$get_instruments("BTC", kind = "option")
options[, .(instrument_name, option_type, strike, expiration_datetime)]
```

    #>        instrument_name option_type strike expiration_datetime
    #>                 <char>      <char>  <num>              <POSc>
    #> 1: BTC-31JUL26-40000-P         put  40000 2026-07-31 08:00:00
    #> 2: BTC-31JUL26-50000-C        call  50000 2026-07-31 08:00:00

`get_currencies()` lists the settlement currencies, and `kind` filters
the universe (`"future"`, `"option"`, `"spot"`, `"future_combo"`,
`"option_combo"`).

## Live quotes

The ticker combines the 24h stats, the top of book, and — for options —
the greeks and implied volatility, flattened into one row:

``` r
perp <- md$get_ticker("BTC-PERPETUAL")
perp[, .(instrument_name, mark_price, index_price, current_funding, funding_8h)]
```

    #>    instrument_name mark_price index_price current_funding funding_8h
    #>             <char>      <num>       <num>           <num>      <num>
    #> 1:   BTC-PERPETUAL      50005       50000               0      2e-05

The order book comes back long — one row per price level, bids then
asks:

``` r
md$get_order_book("BTC-PERPETUAL", depth = 3)
```

    #>    instrument_name            datetime   side level   price amount
    #>             <char>              <POSc> <char> <int>   <num>  <num>
    #> 1:   BTC-PERPETUAL 2023-11-14 22:13:20    bid     1 50004.0   2000
    #> 2:   BTC-PERPETUAL 2023-11-14 22:13:20    bid     2 50003.5   1500
    #> 3:   BTC-PERPETUAL 2023-11-14 22:13:20    bid     3 50003.0   1000
    #> 4:   BTC-PERPETUAL 2023-11-14 22:13:20    ask     1 50006.0    800
    #> 5:   BTC-PERPETUAL 2023-11-14 22:13:20    ask     2 50006.5   1200

## The DVOL volatility index

`get_volatility_index_data()` returns the DVOL candles over a window —
the regime dial. Timestamps are `lubridate` POSIXct; a single call
returns up to ~1000 candles, and a longer range pages by moving
`end_timestamp` back:

``` r
dvol <- md$get_volatility_index_data(
    "BTC",
    start_timestamp = lubridate::ymd_hms("2023-11-01 00:00:00", tz = "UTC"),
    end_timestamp = lubridate::ymd_hms("2023-11-08 00:00:00", tz = "UTC"),
    resolution = "3600"
)
dvol
```

    #>    currency            datetime resolution  open  high   low close
    #>      <char>              <POSc>     <char> <num> <num> <num> <num>
    #> 1:      BTC 2023-11-14 22:13:20       3600  38.0  38.5  37.9  38.2
    #> 2:      BTC 2023-11-14 23:13:20       3600  38.2  38.6  38.1  38.4
    #> 3:      BTC 2023-11-15 00:13:20       3600  38.4  38.7  38.3  38.5

## Perpetual funding

``` r
funding <- md$get_funding_rate_history(
    "BTC-PERPETUAL",
    start_timestamp = lubridate::ymd_hms("2023-11-01 00:00:00", tz = "UTC"),
    end_timestamp = lubridate::ymd_hms("2023-11-08 00:00:00", tz = "UTC")
)
funding
```

    #>    instrument_name            datetime index_price prev_index_price interest_8h
    #>             <char>              <POSc>       <num>            <num>       <num>
    #> 1:   BTC-PERPETUAL 2023-11-14 22:13:20       50000            49900       4e-05
    #> 2:   BTC-PERPETUAL 2023-11-14 23:13:20       50100            50000       3e-05
    #> 3:   BTC-PERPETUAL 2023-11-15 00:13:20       50050            50100       5e-05
    #>    interest_1h
    #>          <num>
    #> 1:     1.5e-06
    #> 2:     1.2e-06
    #> 3:     1.8e-06

## The option chain

`get_book_summary_by_currency(currency, kind = "option")` is the whole
chain in one call — mark IV, open interest, volume, and the (null-able)
bid/ask/mid for every live option. `get_option_chain()` is the
convenience wrapper:

``` r
chain <- md$get_option_chain("BTC")
chain[, .(instrument_name, mark_iv, bid_price, ask_price, open_interest, volume)]
```

    #>        instrument_name mark_iv bid_price ask_price open_interest volume
    #>                 <char>   <num>     <num>     <num>         <num>  <num>
    #> 1: BTC-31JUL26-40000-P    55.7    0.0024    0.0028         395.0    3.6
    #> 2: BTC-31JUL26-60000-C    78.5        NA    0.0002         168.6    0.0

## Asynchronous usage

Set `async = TRUE` and consume the promise with `coro::async` / `await`,
driving the event loop with `later`:

``` r
box::use(coro, later)

md_async <- DeribitMarketData$new(async = TRUE)

main <- coro::async(function() {
    dvol <- await(md_async$get_volatility_index_data(
        "BTC",
        start_timestamp = lubridate::now("UTC") - lubridate::days(7),
        end_timestamp = lubridate::now("UTC"),
        resolution = "3600"
    ))
    chain <- await(md_async$get_option_chain("BTC"))
    print(list(dvol = dvol, chain = chain))
})

main()
while (!later::loop_empty()) later::run_now()
```

## Error handling

A bad argument is caught before any request as a
`deribit_validation_error`; a Deribit JSON-RPC error surfaces as a typed
`deribit_api_error` carrying the HTTP status, the JSON-RPC code, and the
offending parameter:

``` r
result <- tryCatch(
    md$get_volatility_index_data("BTC", lubridate::now("UTC"), lubridate::now("UTC"), resolution = "99"),
    deribit_validation_error = function(e) paste("caught:", conditionMessage(e))
)
result
```

    #> [1] "caught: Invalid resolution '99'. Valid values: 1, 60, 3600, 43200, 1D."
