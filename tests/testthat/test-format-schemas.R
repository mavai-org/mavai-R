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

test_that("the manifest and the corpus tree agree both ways", {
  # The two-way coverage check: every declared refusal category has at
  # least one corpus case, every case's category is declared, every case
  # cites its mandating spec section, and the manifest mirrors the tree
  # on disk exactly — a file without an entry, or an entry without a
  # file, fails the build.
  manifest <- yaml::read_yaml(file.path(repo_root, "inst", "formats", "manifest.yaml"))
  entries <- manifest$corpus
  categories <- manifest$categories
  files <- vapply(entries, function(e) e$file, "")
  outcomes <- vapply(entries, function(e) e$outcome, "")

  expect_equal(anyDuplicated(files), 0L)
  valid_disk <- basename(Sys.glob(file.path(repo_root, "inst", "formats", "corpus", "valid", "*.yaml")))
  invalid_disk <- basename(Sys.glob(file.path(repo_root, "inst", "formats", "corpus", "invalid", "*.yaml")))
  expect_setequal(files[outcomes == "loads"], valid_disk)
  expect_setequal(files[outcomes == "refused"], invalid_disk)

  refused_categories <- vapply(entries[outcomes == "refused"], function(e) e$category %||% "", "")
  expect_true(all(nzchar(refused_categories)))
  expect_setequal(unique(refused_categories), names(categories))

  expect_true(all(vapply(categories, function(c) isTRUE(nzchar(c$spec)), TRUE)))
  expect_true(all(vapply(categories, function(c) c$refusal %in% c("structural", "semantic"), TRUE)))
  expect_true(all(vapply(entries[outcomes == "loads"], function(e) isTRUE(nzchar(e$spec)), TRUE)))
})

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

test_that("parses: inside per-input expected is refused", {
  # Clarified 2026-07-25: parseability is a criterion-level form.
  doc <- minimal_contract()
  doc$transforms <- list(basket = "json")
  doc$inputs <- list(list(input = "Alice", expected = list(list(parses = "basket"))))
  expect_false(contract_validator()(as_json(doc)))
})

test_that("a file-sourced part input with expectations validates", {
  doc <- minimal_contract()
  doc$inputs <- list(
    list(input = list(list(audio = "./audio/clip-01.m4a")),
         expected = list(list(contains = "fox"))),
    list(list(text = "What colour dominates?"), list(image = "./images/swatch.png"))
  )
  expect_true(contract_validator()(as_json(doc)))
})

test_that("a list mixing scalars and parts is refused", {
  doc <- minimal_contract()
  doc$inputs <- list(list("a scalar", list(image = "./images/swatch.png")))
  expect_false(contract_validator()(as_json(doc)))
})

test_that("an unknown input part key is refused", {
  doc <- minimal_contract()
  doc$inputs <- list(list(list(video = "./clip.mp4")))
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
  doc$services$greeter$configuration$flavour <- "vanilla"
  expect_false(services_validator()(as_json(doc)))
})

test_that("a max-tokens ceiling above the bound is refused", {
  doc <- minimal_services()
  doc$services$greeter$configuration$`max-tokens` <- 20000L
  expect_false(services_validator()(as_json(doc)))
})

test_that("an unknown provider is refused", {
  doc <- minimal_services()
  doc$services$greeter$configuration$provider <- "acme"
  expect_false(services_validator()(as_json(doc)))
})

test_that("a capability allowance validates and an unknown capability is refused", {
  doc <- minimal_services()
  doc$services$greeter$configuration$capabilities <- list("image-input")
  expect_true(services_validator()(as_json(doc)))
  doc$services$greeter$configuration$capabilities <- list("telepathy")
  expect_false(services_validator()(as_json(doc)))
})

test_that("an optimizations section validates", {
  doc <- minimal_services()
  doc$services$greeter$optimizations <- list(list(
    id = "prompt-tuning",
    stepper = "prompt-engineer",
    `stepper-config` = list(model = "gpt-4o", `max-exemplars` = 1L),
    `max-iterations` = 8L,
    `no-improvement-window` = 2L
  ))
  expect_true(services_validator()(as_json(doc)))
})

test_that("an optimization entry without max-iterations is refused", {
  doc <- minimal_services()
  doc$services$greeter$optimizations <- list(list(stepper = "linear-sweep"))
  expect_false(services_validator()(as_json(doc)))
})

test_that("an optimization entry with an unknown key is refused", {
  doc <- minimal_services()
  doc$services$greeter$optimizations <- list(list(
    stepper = "linear-sweep", `max-iterations` = 5L, epochs = 3L
  ))
  expect_false(services_validator()(as_json(doc)))
})
