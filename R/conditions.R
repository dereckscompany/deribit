# File: R/conditions.R
# The typed condition family for deribit. Two roots, mirroring the fleet split:
#   * deribit_api_error   -> layered IN FRONT of connectcore's transport chain,
#     so a caller can catch deribit_api_error (any Deribit API failure),
#     connectcore_api_error (any HTTP failure fleet-wide), or connectcore_error
#     (any transport failure) and read $status / $code / $reason / $param / $url.
#   * deribit_validation_error -> deribit_error, the connector's DOMAIN root,
#     parallel to connectcore_error and never meeting it (a validation failure is
#     not a transport failure) -- the same split census/coinbase/aisstream use.

#' Typed deribit conditions
#'
#' `deribit` raises **classed conditions** so a caller branches on error *type*
#' and reads structured *fields* instead of matching the message text.
#'
#' ### Class taxonomy
#'
#' - **Transport / API failures** nest specific -> general as
#'   `deribit_api_error_<status>` -> `deribit_api_error` ->
#'   `connectcore_api_error_<status>` -> `connectcore_api_error` ->
#'   `connectcore_error`, carrying the fields `status` (the HTTP status),
#'   `code` (Deribit's JSON-RPC error code, e.g. `-32602`), `reason` and `param`
#'   (the JSON-RPC `error.data` detail, when present), `url`, and `body_snippet`.
#'   Raised whenever a Deribit response carries a JSON-RPC `error` object (which
#'   arrives with an HTTP 400), or for any other non-2xx HTTP status.
#' - **Validation failures** nest `deribit_validation_error` -> `deribit_error`
#'   (the domain root). Raised for a malformed argument (e.g. an unknown
#'   `resolution` or `kind`, or `end_timestamp` before `start_timestamp`) before
#'   any request is made.
#'
#' Deribit signs no public request, so no request URL carries a secret; the `url`
#' is nonetheless stored through [connectcore::scrub_url()] for fleet uniformity,
#' so any future authenticated surface inherits the redaction for free.
#'
#' @seealso [connectcore::connectcore_conditions]
#' @name deribit_conditions
NULL

#' Raise a typed Deribit JSON-RPC / HTTP API error
#'
#' Signals a condition classed
#' `c("deribit_api_error_<status>", "deribit_api_error",`
#' `"connectcore_api_error_<status>", "connectcore_api_error", "connectcore_error")`
#' carrying the HTTP `status`, Deribit's JSON-RPC error `code`, the JSON-RPC
#' `error.data` `reason` and `param` detail, the request `url` (redacted with
#' [connectcore::scrub_url()]), and a truncated `body_snippet`. See
#' [deribit_conditions] for the taxonomy.
#'
#' @param status (scalar<count>) the HTTP status code. Also names the most
#'   specific classes.
#' @param code (scalar<integer> | NULL) Deribit's JSON-RPC error code (e.g.
#'   `-32602` for invalid params), or `NULL` when the failure has no JSON-RPC
#'   error object. Default `NULL`.
#' @param message (scalar<character>) the condition message.
#' @param reason (scalar<character> | NULL) the JSON-RPC `error.data.reason`
#'   detail, when present. Default `NULL`.
#' @param param (scalar<character> | NULL) the JSON-RPC `error.data.param`
#'   detail (the offending parameter), when present. Default `NULL`.
#' @param url (scalar<character> | NULL) the request URL; stored redacted.
#'   Default `NULL`.
#' @param body (scalar<character> | NULL) the response body text; stored
#'   truncated on the `body_snippet` field (named `body_snippet`, not `body`,
#'   because `rlang::abort()` reserves `body`). Default `NULL`.
#' @return (class<connectcore_error>) never returns normally; signals the classed
#'   condition described above.
#' @importFrom rlang abort caller_env
#' @keywords internal
#' @noassert
#' @noRd
abort_deribit_error <- function(status, code = NULL, message, reason = NULL, param = NULL, url = NULL, body = NULL) {
  return(rlang::abort(
    message = message,
    class = c(
      sprintf("deribit_api_error_%d", as.integer(status)),
      "deribit_api_error",
      sprintf("connectcore_api_error_%d", as.integer(status)),
      "connectcore_api_error",
      "connectcore_error"
    ),
    status = as.integer(status),
    code = if (is.null(code)) NA_integer_ else as.integer(code),
    reason = reason,
    param = param,
    url = connectcore::scrub_url(url),
    body_snippet = body,
    call = rlang::caller_env()
  ))
}

#' Raise a typed Deribit input-validation error
#'
#' Signals a condition classed `c("deribit_validation_error", "deribit_error")`
#' for a NON-transport failure: an argument is malformed or violates a rule
#' before any request is made. `deribit_error` is the connector's DOMAIN root,
#' parallel to the transport `connectcore_error` root; the two never meet. See
#' [deribit_conditions] for the taxonomy.
#'
#' @param message (scalar<character>) the condition message, passed through
#'   verbatim to [rlang::abort()].
#' @param ... structured fields stored on the condition, read with `e[["field"]]`.
#' @param call (environment) the environment blamed in the traceback; defaults to
#'   the caller.
#' @return (class<deribit_error>) never returns normally; signals the classed
#'   condition described above.
#' @importFrom rlang abort caller_env
#' @keywords internal
#' @noassert
#' @noRd
abort_deribit_validation_error <- function(message, ..., call = rlang::caller_env()) {
  return(rlang::abort(
    message = message,
    class = c("deribit_validation_error", "deribit_error"),
    ...,
    call = call
  ))
}
