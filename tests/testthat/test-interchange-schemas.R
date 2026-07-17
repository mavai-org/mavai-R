# The interchange schemas and worked examples are published artefacts
# (interchange-vX.Y.Z.zip); this test is the build step that refuses to let
# an invalid schema or a drifted example ship. The validation logic lives in
# scripts/validate_interchange.R (single source, also run by release CI);
# the negative cases here prove the validator refuses, not just accepts.

skip_if_not_installed("jsonvalidate")
skip_if_not_installed("yaml")

repo_root <- normalizePath(file.path(testthat::test_path(), "..", ".."))

test_that("interchange schemas compile and all worked examples validate", {
  old_wd <- setwd(repo_root)
  on.exit(setwd(old_wd), add = TRUE)
  result <- suppressWarnings(system2(
    "Rscript", file.path("scripts", "validate_interchange.R"),
    stdout = TRUE, stderr = TRUE
  ))
  status <- attr(result, "status")
  expect_true(is.null(status) || status == 0L,
              info = paste(result, collapse = "\n"))
})

test_that("the explore validator refuses a mapping-shaped failureDistribution", {
  # The withdrawn pre-amendment shape (failure counts keyed by check name)
  # must no longer validate: keys derived from input content are what made
  # emitted artefacts exceed YAML's implicit-key limit.
  validator <- jsonvalidate::json_validator(
    file.path(repo_root, "schema", "mavai-explore-1.schema.json"),
    engine = "ajv"
  )
  doc <- yaml::read_yaml(
    file.path(repo_root, "inst", "interchange", "explore-typical.yaml"),
    handlers = list(seq = function(x) as.list(x))
  )
  doc$statistics$failureDistribution <- list(`valid-json` = 2L)
  expect_false(validator(jsonlite::toJSON(doc, auto_unbox = TRUE, digits = NA)))
})

test_that("the explore validator refuses an entry without a condition", {
  validator <- jsonvalidate::json_validator(
    file.path(repo_root, "schema", "mavai-explore-1.schema.json"),
    engine = "ajv"
  )
  doc <- yaml::read_yaml(
    file.path(repo_root, "inst", "interchange", "explore-typical.yaml"),
    handlers = list(seq = function(x) as.list(x))
  )
  doc$statistics$failureDistribution <- list(list(count = 2L))
  expect_false(validator(jsonlite::toJSON(doc, auto_unbox = TRUE, digits = NA)))
})

test_that("the explore validator refuses an over-bound condition identity", {
  # 256 characters is the key-discipline bound; emitters truncate above it.
  validator <- jsonvalidate::json_validator(
    file.path(repo_root, "schema", "mavai-explore-1.schema.json"),
    engine = "ajv"
  )
  doc <- yaml::read_yaml(
    file.path(repo_root, "inst", "interchange", "explore-typical.yaml"),
    handlers = list(seq = function(x) as.list(x))
  )
  doc$statistics$failureDistribution <- list(
    list(condition = strrep("x", 257L), count = 2L)
  )
  expect_false(validator(jsonlite::toJSON(doc, auto_unbox = TRUE, digits = NA)))
})
