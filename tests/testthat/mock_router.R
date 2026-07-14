# Shared mock HTTP router for the deribit README and tests.
#
# The THIN deribit-specific layer over connectcore's shared mock harness
# (connectcore::mock_router / with_mock_api / local_mock_api / load_fixtures /
# mock_response). connectcore owns the response builder, the dispatch loop, and
# the scoped-activation helpers; this file only declares the route table (URL
# pattern -> fixture) and loads the fixtures from disk.
#
# Every fixture is FULLY SYNTHETIC authored JSON (never captured from the live
# API), shaped exactly per Deribit's documented JSON-RPC 2.0 envelope. The
# fixtures carry representative bodies: a null option bid_price / mid_price and
# null option stats (to exercise the `| NA` columns), a perpetual ticker with no
# greeks and an option ticker with greeks, and a liquidation trade. Because the
# public methods carry no key, no secret ever appears in a mocked URL.

box::use(
  connectcore[load_fixtures]
)

# Load every synthetic fixture as its raw JSON string, keyed by file basename
# (dvol.json -> "dvol"). Resolved relative to THIS module file so it works from
# the package root (README) and tests/testthat alike.
.fixtures <- load_fixtures(box::file("fixtures"))

# Deribit answers a bad parameter with an HTTP 400 carrying a JSON-RPC `error`
# object; this thunk reproduces that surface so the envelope's typed-error path
# is exercised end-to-end.
#' @export
.invalid_params_response <- function() {
  return(httr2::response(
    status_code = 400L,
    headers = list("content-type" = "application/json"),
    body = charToRaw(paste0(
      "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":-32602,\"data\":",
      "{\"reason\":\"wrong format\",\"param\":\"instrument_name\"},",
      "\"message\":\"Invalid params\"},\"testnet\":false,\"usIn\":1700000000000000}"
    ))
  ))
}

# The raw JSON envelope string of a named fixture (for the envelope tests).
#' @export
.fixture_body <- function(name) {
  return(.fixtures[[name]])
}

# The parsed JSON-RPC `result` of a named fixture, for the offline parser tests
# (which exercise the parsers directly, without the transport/envelope layer).
#' @export
.fixture_result <- function(name) {
  return(jsonlite::fromJSON(.fixtures[[name]], simplifyVector = FALSE)[["result"]])
}

# A URL predicate: the request path contains `method` AND the query carries the
# given `token` (e.g. "kind=option"). Used where a single method serves two
# fixtures discriminated by a query value.
.url_has <- function(method, token) {
  return(function(req) {
    return(grepl(method, req$url, fixed = TRUE) && grepl(token, req$url, fixed = TRUE))
  })
}

#' Route table: URL pattern (or predicate) -> synthetic-fixture JSON string.
#'
#' Order matters: the error route and the query-discriminated (option) routes
#' precede the bare method routes.
#' @export
.mock_routes <- list(
  # ---- Error surface (end-to-end) ----
  list(
    match = function(req) grepl("instrument_name=INVALID", req$url, fixed = TRUE),
    fixture = .invalid_params_response
  ),

  # ---- Instruments (kind-discriminated) ----
  list(match = .url_has("get_instruments", "kind=option"), fixture = .fixtures$instruments_option),
  list(pattern = "get_instruments", fixture = .fixtures$instruments_future),

  # ---- Currencies ----
  list(pattern = "get_currencies", fixture = .fixtures$currencies),

  # ---- Ticker (option vs perpetual by instrument name) ----
  list(match = .url_has("/public/ticker", "50000-C"), fixture = .fixtures$ticker_option),
  list(pattern = "/public/ticker", fixture = .fixtures$ticker_perp),

  # ---- Order book / index ----
  list(pattern = "get_order_book", fixture = .fixtures$order_book),
  list(pattern = "get_index_price", fixture = .fixtures$index_price),

  # ---- DVOL ----
  list(pattern = "get_volatility_index_data", fixture = .fixtures$dvol),

  # ---- Funding ----
  list(pattern = "get_funding_rate_history", fixture = .fixtures$funding_history),
  list(pattern = "get_funding_rate_value", fixture = .fixtures$funding_value),

  # ---- Trades (option vs perpetual by instrument name) ----
  list(match = .url_has("get_last_trades_by_instrument", "50000-C"), fixture = .fixtures$trades_option),
  list(pattern = "get_last_trades_by_instrument", fixture = .fixtures$trades_perp),

  # ---- Book summaries (option vs perpetual) ----
  list(match = .url_has("get_book_summary_by_currency", "kind=option"), fixture = .fixtures$book_summary_option),
  list(pattern = "get_book_summary_by_currency", fixture = .fixtures$book_summary_perp),
  list(pattern = "get_book_summary_by_instrument", fixture = .fixtures$book_summary_perp)
)
