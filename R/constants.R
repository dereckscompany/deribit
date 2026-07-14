# File: R/constants.R
# Package constants and the environment-backed URL getter. No bare constants
# are hoisted at the top of other module files; every vocabulary value lives
# here with roxygen documentation, per the house convention.

#' Deribit API base URL (the `/api/v2` root)
#'
#' The root under which every public JSON-RPC method is addressed (e.g.
#' `/api/v2/public/get_instruments`, `/api/v2/public/ticker`). Overridable with
#' the `DERIBIT_BASE_URL` environment variable (e.g. point it at
#' `https://test.deribit.com/api/v2` for the testnet).
#'
#' @param url (scalar<character>) an explicit base URL override. Defaults to the
#'   `DERIBIT_BASE_URL` environment variable, or the public host when unset.
#' @return (scalar<character>) the base URL.
#' @export
deribit_base_url <- connectcore::url_getter("DERIBIT_BASE_URL", "https://www.deribit.com/api/v2")

#' Deribit instrument kinds
#'
#' The `kind` values the instrument and book-summary endpoints accept as a
#' filter. The name and value coincide (the value *is* the wire token); a `NULL`
#' `kind` returns every kind. `future_combo` and `option_combo` are Deribit's
#' multi-leg structured products.
#'
#' @format A named `list` of `scalar<character>` wire tokens:
#' - future: linear/inverse futures and perpetuals.
#' - option: calls and puts.
#' - spot: spot pairs.
#' - future_combo: multi-leg futures structures.
#' - option_combo: multi-leg option structures.
#' @export
INSTRUMENT_KIND <- list(
  future = "future",
  option = "option",
  spot = "spot",
  future_combo = "future_combo",
  option_combo = "option_combo"
)

#' DVOL volatility-index candle resolutions
#'
#' The `resolution` values `get_volatility_index_data()` accepts, in seconds
#' (plus the `"1D"` daily token). The named list is the whitelist the method
#' validates its `resolution` argument against.
#'
#' @format A named `list` of `scalar<character>` wire tokens: `1`, `60`, `3600`,
#'   `43200`, `1D`.
#' @export
DVOL_RESOLUTIONS <- list(
  s1 = "1",
  m1 = "60",
  h1 = "3600",
  h12 = "43200",
  d1 = "1D"
)

#' Trade sort order
#'
#' The `sorting` values the trade endpoints accept: ascending, descending, or
#' the venue default (no explicit sort).
#'
#' @format A named `list` of `scalar<character>` wire tokens: `asc`, `desc`,
#'   `default`.
#' @export
TRADE_SORTING <- list(
  asc = "asc",
  desc = "desc",
  default = "default"
)
