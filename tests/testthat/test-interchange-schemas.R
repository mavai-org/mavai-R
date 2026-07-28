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

test_that("the explore validator refuses a standings row without the optional flag", {
  # Every standings row states whether its check is optional — explicitly,
  # so consumers can flag partial credit without reading the contract.
  validator <- jsonvalidate::json_validator(
    file.path(repo_root, "schema", "mavai-explore-1.schema.json"),
    engine = "ajv"
  )
  doc <- yaml::read_yaml(
    file.path(repo_root, "inst", "interchange", "explore-typical.yaml"),
    handlers = list(seq = function(x) as.list(x))
  )
  doc$statistics$criteria$`valid-json`$standings$rows[[1]]$optional <- NULL
  expect_false(validator(jsonlite::toJSON(doc, auto_unbox = TRUE, digits = NA)))
})

test_that("the explore validator refuses a bare-fraction optional slack", {
  # The declared budget travels verbatim: digits, or digits + %. A bare
  # fraction ("0.2") is refused at authoring time by the contract format and
  # must not appear in an artefact either.
  validator <- jsonvalidate::json_validator(
    file.path(repo_root, "schema", "mavai-explore-1.schema.json"),
    engine = "ajv"
  )
  doc <- yaml::read_yaml(
    file.path(repo_root, "inst", "interchange", "explore-typical.yaml"),
    handlers = list(seq = function(x) as.list(x))
  )
  doc$statistics$criteria$`valid-json`$standings$optionalSlack <- "0.2"
  expect_false(validator(jsonlite::toJSON(doc, auto_unbox = TRUE, digits = NA)))
})

test_that("the verdict-1.3 XSD refuses a standings row without the optional flag", {
  skip_if_not_installed("xml2")
  xsd <- xml2::read_xml(file.path(repo_root, "schema", "verdict-1.3.xsd"))
  body <- readLines(
    file.path(repo_root, "inst", "interchange", "verdict-1.3-typical.xml")
  )
  mutated <- sub(' optional="false" passed="20" failed="0" skipped="0" observed-fraction="1.0" />',
                 ' passed="20" failed="0" skipped="0" observed-fraction="1.0" />',
                 body)
  expect_false(isTRUE(xml2::xml_validate(
    xml2::read_xml(paste(mutated, collapse = "\n")), xsd
  )))
})

test_that("a verdict-1.3 record without the standings element remains valid", {
  skip_if_not_installed("xml2")
  xsd <- xml2::read_xml(file.path(repo_root, "schema", "verdict-1.3.xsd"))
  doc <- xml2::read_xml(
    file.path(repo_root, "inst", "interchange", "verdict-1.3-typical.xml")
  )
  standings <- xml2::xml_find_first(
    doc, ".//d1:postcondition-standings", xml2::xml_ns(doc)
  )
  xml2::xml_remove(standings)
  expect_true(isTRUE(xml2::xml_validate(doc, xsd)))
})
