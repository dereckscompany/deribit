# File: R/deribit-package.R
# Package-level documentation and shared imports.

#' deribit: API Wrapper to the Deribit Crypto Derivatives Exchange
#'
#' A connector for the public market-data surface of the Deribit crypto
#' options and derivatives exchange (`deribit.com`), built on the shared
#' [connectcore::RestClient] transport base. It speaks Deribit's JSON-RPC 2.0
#' over HTTP GET (the `public/*` methods, which need no API key) and returns
#' tidy [data.table::data.table]s.
#'
#' ### What is covered in this version
#' Phase 1 is **public market data only** (no trading, no authenticated
#' surface). [DeribitMarketData] covers the instrument universe
#' (`get_instruments`, `get_currencies`), live quotes (`get_ticker`,
#' `get_order_book`, `get_index_price`), the DVOL volatility index
#' (`get_volatility_index_data`), perpetual funding (`get_funding_rate_history`,
#' `get_funding_rate_value`), public trades (`get_last_trades_by_instrument`),
#' and the option-chain book summaries (`get_book_summary_by_currency`,
#' `get_book_summary_by_instrument`, `get_option_chain`).
#'
#' ### Sync and async
#' Every request-making surface supports both a synchronous mode (returns a
#' `data.table`) and an asynchronous mode (returns a [promises::promise]
#' resolving to the same `data.table`), selected by the `async` argument at
#' construction. There is a single sync/async branch point, inherited from
#' `connectcore`. See [DeribitMarketData] for the shared mechanism.
#'
#' ### No API key
#' The `public/*` endpoints this package wraps require no credential, so a
#' `DeribitMarketData` client is constructed with no key. The private trading
#' surface (orders, positions, account) is deliberately out of scope for this
#' phase.
#'
#' ### Typed errors
#' Every failure is a classed condition — [deribit_conditions]: a Deribit
#' JSON-RPC error surfaces as a `deribit_api_error` layered onto the shared
#' `connectcore_api_error` chain (carrying the HTTP `status`, the JSON-RPC
#' `code`, and the `reason`/`param` detail), and an input-validation failure
#' surfaces as `deribit_validation_error` under the `deribit_error` domain root.
#'
#' @keywords internal
#' @import data.table
#' @import assert
"_PACKAGE"

# Quiet R CMD check's "no visible binding" notes for the data.table columns
# referenced unquoted (`:=` / column symbols) in the parsers and methods.
utils::globalVariables(c(
  "datetime",
  "side",
  "level",
  "price",
  "amount"
))
