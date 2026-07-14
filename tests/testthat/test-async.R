# The async (promise) path must agree with the sync path. The connectcore mock
# harness intercepts req_perform AND req_perform_promise, so the SAME router
# serves both. is_async threads from the constructor through every method's
# then_or_now() tail; these prove a promise is returned and resolves to the same
# table the sync call returns.

box::use(./mock_router[.mock_routes])

.start <- lubridate::ymd_hms("2023-11-01 00:00:00", tz = "UTC")
.end <- lubridate::ymd_hms("2023-11-08 00:00:00", tz = "UTC")

resolve_promise <- function(p) {
  done <- FALSE
  val <- NULL
  err <- NULL
  promises::then(
    p,
    onFulfilled = function(v) {
      val <<- v
      done <<- TRUE
      return(invisible(NULL))
    },
    onRejected = function(e) {
      err <<- e
      done <<- TRUE
      return(invisible(NULL))
    }
  )
  for (i in seq_len(1000L)) {
    if (done) {
      break
    }
    later::run_now(timeout = 0.01)
  }
  if (!is.null(err)) {
    stop(err)
  }
  return(val)
}

test_that("get_instruments async returns a promise resolving to the sync table", {
  skip_if_not_installed("promises")
  skip_if_not_installed("later")
  connectcore::local_mock_api(.mock_routes)
  sync <- DeribitMarketData$new(async = FALSE)$get_instruments("BTC", kind = "option")
  p <- DeribitMarketData$new(async = TRUE)$get_instruments("BTC", kind = "option")
  expect_true(inherits(p, "promise"))
  expect_equal(resolve_promise(p), sync)
})

test_that("get_volatility_index_data async agrees with sync", {
  skip_if_not_installed("promises")
  skip_if_not_installed("later")
  connectcore::local_mock_api(.mock_routes)
  sync <- DeribitMarketData$new(async = FALSE)$get_volatility_index_data("BTC", .start, .end, "3600")
  p <- DeribitMarketData$new(async = TRUE)$get_volatility_index_data("BTC", .start, .end, "3600")
  expect_true(inherits(p, "promise"))
  expect_equal(resolve_promise(p), sync)
})

test_that("an async JSON-RPC error rejects the promise", {
  skip_if_not_installed("promises")
  skip_if_not_installed("later")
  connectcore::local_mock_api(.mock_routes)
  p <- DeribitMarketData$new(async = TRUE)$get_ticker("INVALID")
  expect_true(inherits(p, "promise"))
  err <- tryCatch(resolve_promise(p), error = function(e) e)
  expect_s3_class(err, "deribit_api_error_400")
})
