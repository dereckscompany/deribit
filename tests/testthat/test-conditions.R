# Typed deribit conditions. Validation aborts are deribit_validation_error ->
# deribit_error (the domain root, parallel to and never meeting connectcore_error);
# transport aborts layer deribit_api_error IN FRONT of the connectcore chain and
# carry the JSON-RPC code + reason/param detail.

test_that("abort_deribit_validation_error layers deribit_validation_error then deribit_error", {
  err <- tryCatch(abort_deribit_validation_error("boom"), error = function(e) e)
  expect_identical(
    class(err),
    c("deribit_validation_error", "deribit_error", "rlang_error", "error", "condition")
  )
  expect_identical(conditionMessage(err), "boom")
})

test_that("deribit_validation_error is caught by deribit_error but is NOT a transport error", {
  caught <- tryCatch(abort_deribit_validation_error("x"), deribit_error = function(e) "root")
  expect_identical(caught, "root")
  err <- tryCatch(abort_deribit_validation_error("x"), error = function(e) e)
  expect_false(inherits(err, "connectcore_error"))
})

test_that("abort_deribit_error layers the deribit and connectcore api-error families", {
  err <- tryCatch(
    abort_deribit_error(
      status = 400L,
      code = -32602L,
      message = "Deribit API error -32602: Invalid params",
      reason = "wrong format",
      param = "instrument_name",
      url = "https://www.deribit.com/api/v2/public/ticker?instrument_name=INVALID",
      body = "b"
    ),
    error = function(e) e
  )
  expect_s3_class(err, "deribit_api_error_400")
  expect_s3_class(err, "deribit_api_error")
  expect_s3_class(err, "connectcore_api_error_400")
  expect_s3_class(err, "connectcore_api_error")
  expect_s3_class(err, "connectcore_error")
  expect_identical(err$status, 400L)
  expect_identical(err$code, -32602L)
  expect_identical(err$reason, "wrong format")
  expect_identical(err$param, "instrument_name")
})

test_that("abort_deribit_error stores NA_integer_ code when the failure has no JSON-RPC code", {
  err <- tryCatch(
    abort_deribit_error(status = 500L, message = "Deribit HTTP error 500"),
    error = function(e) e
  )
  expect_s3_class(err, "deribit_api_error_500")
  expect_true(is.na(err$code))
})
