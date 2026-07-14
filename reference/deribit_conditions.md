# Typed deribit conditions

`deribit` raises **classed conditions** so a caller branches on error
*type* and reads structured *fields* instead of matching the message
text.

## Details

### Class taxonomy

- **Transport / API failures** nest specific -\> general as
  `deribit_api_error_<status>` -\> `deribit_api_error` -\>
  `connectcore_api_error_<status>` -\> `connectcore_api_error` -\>
  `connectcore_error`, carrying the fields `status` (the HTTP status),
  `code` (Deribit's JSON-RPC error code, e.g. `-32602`), `reason` and
  `param` (the JSON-RPC `error.data` detail, when present), `url`, and
  `body_snippet`. Raised whenever a Deribit response carries a JSON-RPC
  `error` object (which arrives with an HTTP 400), or for any other
  non-2xx HTTP status.

- **Validation failures** nest `deribit_validation_error` -\>
  `deribit_error` (the domain root). Raised for a malformed argument
  (e.g. an unknown `resolution` or `kind`, or `end_timestamp` before
  `start_timestamp`) before any request is made.

Deribit signs no public request, so no request URL carries a secret; the
`url` is nonetheless stored through
[`connectcore::scrub_url()`](https://dereckscompany.github.io/connectcore/reference/scrub_url.html)
for fleet uniformity, so any future authenticated surface inherits the
redaction for free.

## See also

[connectcore::connectcore_conditions](https://dereckscompany.github.io/connectcore/reference/connectcore_conditions.html)
