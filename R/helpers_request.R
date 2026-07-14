# File: R/helpers_request.R
# Deribit-specific request machinery layered on connectcore's transport base.
# The generic funnel (sync/async branch, retry, throttle) lives in connectcore;
# this file keeps only what is Deribit-specific: the JSON-RPC envelope seam
# (`.parse_envelope`, which unwraps `result` and raises a typed error on an
# `error` object) and the tiny query-value coercers that keep an epoch-ms
# timestamp out of scientific notation and encode a logical as the lowercase
# `true`/`false` Deribit expects.

#' Parse and validate a Deribit JSON-RPC response (the `.parse_envelope()` seam)
#'
#' The Deribit implementation of connectcore's `.parse_envelope(resp)` seam.
#' Every Deribit response is a JSON-RPC 2.0 envelope: on success a `result`
#' field, on failure an `error` object `{ code, message, data: { reason, param } }`
#' that arrives with an HTTP 400. This unwraps `result` on success and raises a
#' typed [deribit_conditions] error otherwise:
#' 1. **JSON-RPC error.** A body carrying a non-null `error` object is raised as
#'    `deribit_api_error_<status>` with `code` (the JSON-RPC code) and the
#'    `reason`/`param` detail.
#' 2. **Non-2xx without an error object** (defensive): raised as
#'    `deribit_api_error_<status>` with the body as `body_snippet`.
#' 3. **Non-JSON body** (defensive): raised as a `deribit_api_error`.
#' 4. **Success**: the `result` value (a list, a scalar, or `NULL`), returned to
#'    the per-endpoint parser.
#'
#' @param resp (class<httr2_response>) the response to parse.
#' @return (any | NULL) the JSON-RPC `result` value, or `NULL` when the body has
#'   no `result`.
#' @importFrom httr2 resp_status resp_body_string
#' @keywords internal
#' @noassert
#' @noRd
parse_deribit_response <- function(resp) {
  status <- httr2::resp_status(resp)
  final_url <- resp$url
  body_text <- tryCatch(httr2::resp_body_string(resp), error = function(e) "")
  parsed <- NULL
  if (nzchar(trimws(body_text))) {
    parsed <- tryCatch(jsonlite::fromJSON(body_text, simplifyVector = FALSE), error = function(e) NULL)
  }
  err <- if (is.list(parsed)) parsed[["error"]] else NULL

  result <- NULL
  if (!is.null(err)) {
    code <- err[["code"]]
    msg <- connectcore::chr_or_na(err[["message"]])
    data <- err[["data"]]
    reason <- if (is.list(data) && !is.null(data[["reason"]])) as.character(data[["reason"]]) else NULL
    param <- if (is.list(data) && !is.null(data[["param"]])) as.character(data[["param"]]) else NULL
    abort_deribit_error(
      status = status,
      code = code,
      message = sprintf("Deribit API error %s: %s", connectcore::coalesce_null(code, "?"), msg),
      reason = reason,
      param = param,
      url = final_url,
      body = body_text
    )
  } else if (status < 200L || status >= 300L) {
    abort_deribit_error(
      status = status,
      message = paste0("Deribit HTTP error ", status, "\n", body_text),
      url = final_url,
      body = body_text
    )
  } else if (is.null(parsed)) {
    abort_deribit_error(
      status = status,
      message = paste0("Deribit returned a non-JSON body on HTTP ", status, "."),
      url = final_url,
      body = body_text
    )
  } else {
    result <- parsed[["result"]]
  }
  return(result)
}

#' Encode a logical as Deribit's lowercase `true`/`false`
#'
#' Deribit's query grammar expects the literal lowercase `true`/`false`, so a
#' logical flag is stringified here rather than relying on httr2's default
#' formatting.
#'
#' @param x (scalar<logical>) the flag.
#' @return (scalar<character>) `"true"` or `"false"`.
#' @keywords internal
#' @noassert
#' @noRd
deribit_bool <- function(x) {
  return(if (isTRUE(x)) "true" else "false")
}

#' Format an epoch-millisecond POSIXct as a non-scientific query string
#'
#' A 13-digit epoch-ms would otherwise be formatted in scientific notation
#' (`1.78e+12`) in the URL, which Deribit rejects. This converts a POSIXct to
#' epoch ms (via [connectcore::datetime_to_ms()]) and renders it as a plain
#' integer string.
#'
#' @param datetime (class<POSIXct>) the timestamp to convert.
#' @return (scalar<character>) the epoch-millisecond value as a plain integer
#'   string.
#' @keywords internal
#' @noassert
#' @noRd
deribit_ms <- function(datetime) {
  return(sprintf("%.0f", connectcore::datetime_to_ms(datetime)))
}
