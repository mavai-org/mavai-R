# The declarative format schemas are published artefacts (formats-vX.Y.Z.zip);
# this test is the build step that refuses to let an invalid schema or a
# drifted corpus ship. The validation logic lives in
# scripts/validate_formats.R (single source, also run by release CI); the
# negative cases here prove the schemas refuse, not just accept.

skip_if_not_installed("jsonvalidate")
skip_if_not_installed("yaml")

repo_root <- normalizePath(file.path(testthat::test_path(), "..", ".."))

contract_validator <- function() {
  jsonvalidate::json_validator(
    file.path(repo_root, "inst", "formats", "schemas", "mavai-contract-1.schema.json"),
    engine = "ajv"
  )
}

services_validator <- function() {
  jsonvalidate::json_validator(
    file.path(repo_root, "inst", "formats", "schemas", "mavai-services-1.schema.json"),
    engine = "ajv"
  )
}

as_json <- function(doc) jsonlite::toJSON(doc, auto_unbox = TRUE, digits = NA)

# The frozen specification's own minimal contract (Part I) as parsed data.
minimal_contract <- function() {
  list(
    format = "mavai-contract/1",
    contract = "greeting-service-is-polite",
    service = "greeting-service",
    criteria = list(list(threshold = 0.95, contains = "hello")),
    inputs = list("Alice", "Bob", "Charlie")
  )
}

minimal_services <- function() {
  list(
    format = "mavai-services/1",
    services = list(
      greeter = list(
        type = "language-model",
        configuration = list(`system-prompt` = "You are a polite greeter.")
      )
    )
  )
}

test_that("format schemas compile and the corpus tree validates", {
  old_wd <- setwd(repo_root)
  on.exit(setwd(old_wd), add = TRUE)
  result <- suppressWarnings(system2(
    "Rscript", file.path("scripts", "validate_formats.R"),
    stdout = TRUE, stderr = TRUE
  ))
  status <- attr(result, "status")
  expect_true(is.null(status) || status == 0L,
              info = paste(result, collapse = "\n"))
})

test_that("the specification's minimal contract validates", {
  expect_true(contract_validator()(as_json(minimal_contract())))
})

test_that("a reserved seam key is refused", {
  doc <- minimal_contract()
  doc$facets <- list(refund = list())
  expect_false(contract_validator()(as_json(doc)))
})

test_that("a withdrawn sizing key is refused", {
  doc <- minimal_contract()
  doc$samples <- 100L
  expect_false(contract_validator()(as_json(doc)))
})

test_that("tolerate alongside threshold is refused", {
  doc <- minimal_contract()
  doc$criteria <- list(list(threshold = 0.95, tolerate = 0.9, contains = "hello"))
  expect_false(contract_validator()(as_json(doc)))
})

test_that("a criterion without any postcondition form is refused", {
  doc <- minimal_contract()
  doc$criteria <- list(list(threshold = 0.95))
  expect_false(contract_validator()(as_json(doc)))
})

test_that("path without in: is refused", {
  doc <- minimal_contract()
  doc$criteria <- list(list(
    threshold = 0.95,
    postconditions = list(list(path = "$.items[*].name", matches = "\\w"))
  ))
  expect_false(contract_validator()(as_json(doc)))
})

test_that("path on a non-string form is refused", {
  doc <- minimal_contract()
  doc$transforms <- list(basket = "json")
  doc$criteria <- list(list(
    threshold = 0.95,
    postconditions = list(list(`in` = "basket", path = "$.x", satisfies = "check"))
  ))
  expect_false(contract_validator()(as_json(doc)))
})

test_that("declaring a view named raw is refused", {
  doc <- minimal_contract()
  doc$transforms <- list(raw = "json")
  expect_false(contract_validator()(as_json(doc)))
})

test_that("threshold: empirical stays reserved", {
  doc <- minimal_contract()
  doc$criteria <- list(list(threshold = "empirical", contains = "hello"))
  expect_false(contract_validator()(as_json(doc)))
})

test_that("contradictory latency shapes are refused", {
  doc <- minimal_contract()
  doc$latency <- list(p95 = 500L, empirical = list("p99"))
  expect_false(contract_validator()(as_json(doc)))
})

test_that("the specification's minimal services file validates", {
  expect_true(services_validator()(as_json(minimal_services())))
})

test_that("a language-model configuration without a system prompt is refused", {
  doc <- minimal_services()
  doc$services$greeter$configuration <- list(model = "gpt-4o-mini")
  expect_false(services_validator()(as_json(doc)))
})

test_that("a parameter outside the configuration block is refused", {
  doc <- minimal_services()
  doc$services$greeter$temperature <- 0.2
  expect_false(services_validator()(as_json(doc)))
})

test_that("an unknown language-model configuration key is refused", {
  doc <- minimal_services()
  doc$services$greeter$configuration$`max-tokens` <- 100L
  expect_false(services_validator()(as_json(doc)))
})

test_that("an unknown provider is refused", {
  doc <- minimal_services()
  doc$services$greeter$configuration$provider <- "acme"
  expect_false(services_validator()(as_json(doc)))
})
