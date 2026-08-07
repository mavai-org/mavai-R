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

test_that("the explore validator refuses an exemplar without its held flag", {
  validator <- jsonvalidate::json_validator(
    file.path(repo_root, "schema", "mavai-explore-1.schema.json"),
    engine = "ajv"
  )
  doc <- yaml::read_yaml(
    file.path(repo_root, "inst", "interchange", "explore-typical.yaml"),
    handlers = list(seq = function(x) as.list(x))
  )
  rows <- doc$statistics$criteria$`valid-json`$standings$rows
  structured <- which(vapply(rows, function(r) !is.null(r$observed), logical(1)))[1]
  row <- rows[[structured]]
  obs <- lapply(row$observed, as.list)
  obs[[1]][["held"]] <- NULL
  row["observed"] <- list(obs)
  doc$statistics$criteria$`valid-json`$standings$rows[[structured]] <- row
  expect_false(validator(jsonlite::toJSON(doc, auto_unbox = TRUE, digits = NA)))
})

test_that("the explore validator refuses an over-bound obtained excerpt", {
  validator <- jsonvalidate::json_validator(
    file.path(repo_root, "schema", "mavai-explore-1.schema.json"),
    engine = "ajv"
  )
  doc <- yaml::read_yaml(
    file.path(repo_root, "inst", "interchange", "explore-typical.yaml"),
    handlers = list(seq = function(x) as.list(x))
  )
  rows <- doc$statistics$criteria$`valid-json`$standings$rows
  structured <- which(vapply(rows, function(r) !is.null(r$observed), logical(1)))[1]
  row <- rows[[structured]]
  obs <- lapply(row$observed, as.list)
  obs[[1]][["excerpt"]] <- strrep("x", 257L)
  row["observed"] <- list(obs)
  doc$statistics$criteria$`valid-json`$standings$rows[[structured]] <- row
  expect_false(validator(jsonlite::toJSON(doc, auto_unbox = TRUE, digits = NA)))
})

test_that("a verdict-1.4 record with unstructured rows remains valid", {
  skip_if_not_installed("xml2")
  xsd <- xml2::read_xml(file.path(repo_root, "schema", "verdict-1.4.xsd"))
  # The 1.3 worked example, restamped 1.4: every row unstructured — valid.
  body <- readLines(
    file.path(repo_root, "inst", "interchange", "verdict-1.3-typical.xml")
  )
  restamped <- sub('version="1.3"', 'version="1.4"', body)
  expect_true(isTRUE(xml2::xml_validate(
    xml2::read_xml(paste(restamped, collapse = "\n")), xsd
  )))
})

test_that("the explore validator refuses an empty configuration name", {
  # The name is stated only when authored. An empty string is neither
  # authored nor absent — it is a name a consumer would faithfully show a
  # reader, who would learn nothing. Absence is how an author says nothing.
  validator <- jsonvalidate::json_validator(
    file.path(repo_root, "schema", "mavai-explore-1.schema.json"),
    engine = "ajv"
  )
  doc <- yaml::read_yaml(
    file.path(repo_root, "inst", "interchange", "explore-typical.yaml"),
    handlers = list(seq = function(x) as.list(x))
  )
  doc$configurationName <- ""
  expect_false(validator(jsonlite::toJSON(doc, auto_unbox = TRUE, digits = NA)))

  # Prose is bounded, like every other displayable value in the format.
  doc$configurationName <- strrep("x", 257)
  expect_false(validator(jsonlite::toJSON(doc, auto_unbox = TRUE, digits = NA)))

  # Absent is valid: an emitter that has not adopted the field, or an author
  # who named nothing, still emits conformant documents.
  doc$configurationName <- NULL
  expect_true(validator(jsonlite::toJSON(doc, auto_unbox = TRUE, digits = NA)))
})

test_that("a configuration name is not identity — two documents may share one", {
  # Prose carries no uniqueness guarantee. Two configurations stating the
  # same name stay two configurations, distinguished by `configuration`.
  validator <- jsonvalidate::json_validator(
    file.path(repo_root, "schema", "mavai-explore-1.schema.json"),
    engine = "ajv"
  )
  doc <- yaml::read_yaml(
    file.path(repo_root, "inst", "interchange", "explore-typical.yaml"),
    handlers = list(seq = function(x) as.list(x))
  )
  sibling <- doc
  sibling$configuration <- "small-model_t0.9"
  expect_true(validator(jsonlite::toJSON(doc, auto_unbox = TRUE, digits = NA)))
  expect_true(validator(jsonlite::toJSON(sibling, auto_unbox = TRUE, digits = NA)))
})

test_that("the explore validator refuses a negated base-configuration marker", {
  # The marker is stated only on the base, and only ever as true: `false`
  # would invite consumers to read absence as a stated "not the base",
  # when absence means the emitter said nothing at all.
  validator <- jsonvalidate::json_validator(
    file.path(repo_root, "schema", "mavai-explore-1.schema.json"),
    engine = "ajv"
  )
  doc <- yaml::read_yaml(
    file.path(repo_root, "inst", "interchange", "explore-typical.yaml"),
    handlers = list(seq = function(x) as.list(x))
  )
  doc$baseConfiguration <- FALSE
  expect_false(validator(jsonlite::toJSON(doc, auto_unbox = TRUE, digits = NA)))

  # Absent is valid: an emitter that has not adopted the field still emits
  # conformant documents.
  doc$baseConfiguration <- NULL
  expect_true(validator(jsonlite::toJSON(doc, auto_unbox = TRUE, digits = NA)))
})

test_that("the explore validator refuses an unknown failure kind", {
  # The discriminator is closed: `delivery` or `evaluated`. A third value
  # invented by an emitter is a distinction no consumer knows how to render,
  # and would arrive as one that reads plausibly rather than as a refusal.
  validator <- jsonvalidate::json_validator(
    file.path(repo_root, "schema", "mavai-explore-1.schema.json"),
    engine = "ajv"
  )
  doc <- yaml::read_yaml(
    file.path(repo_root, "inst", "interchange", "explore-mixed-delivery.yaml"),
    handlers = list(seq = function(x) as.list(x))
  )
  doc$statistics$failureDistribution[[1]]$kind <- "partial"
  expect_false(validator(jsonlite::toJSON(doc, auto_unbox = TRUE, digits = NA)))
})

test_that("the explore validator refuses a free-text delivery cause", {
  # The whole point of the amendment: a delivery entry's condition is drawn
  # from the closed cause vocabulary. The message below is what the emitters
  # used to put there — unbounded, ungroupable, and carrying an endpoint.
  validator <- jsonvalidate::json_validator(
    file.path(repo_root, "schema", "mavai-explore-1.schema.json"),
    engine = "ajv"
  )
  doc <- yaml::read_yaml(
    file.path(repo_root, "inst", "interchange", "explore-nothing-delivered.yaml"),
    handlers = list(seq = function(x) as.list(x))
  )
  doc$statistics$failureDistribution[[1]]$condition <-
    "service unreachable at https://gateway.example/v1/chat/completions: timed out"
  expect_false(validator(jsonlite::toJSON(doc, auto_unbox = TRUE, digits = NA)))

  # And a cause from the vocabulary is accepted in its place.
  doc$statistics$failureDistribution[[1]]$condition <- "peer-timeout"
  expect_true(validator(jsonlite::toJSON(doc, auto_unbox = TRUE, digits = NA)))
})

test_that("an ordinary condition is unconstrained where no kind is stated", {
  # The vocabulary binds delivery entries only. A pre-amendment document —
  # every entry a declared condition, no kind anywhere — is still valid, and
  # a consumer reads that absence as "not stated", never as "evaluated".
  validator <- jsonvalidate::json_validator(
    file.path(repo_root, "schema", "mavai-explore-1.schema.json"),
    engine = "ajv"
  )
  doc <- yaml::read_yaml(
    file.path(repo_root, "inst", "interchange", "explore-typical.yaml"),
    handlers = list(seq = function(x) as.list(x))
  )
  expect_null(doc$statistics$failureDistribution[[1]]$kind)
  expect_true(validator(jsonlite::toJSON(doc, auto_unbox = TRUE, digits = NA)))

  # An evaluated-kind entry states its condition as before: naming the kind
  # constrains nothing that was not already constrained.
  doc$statistics$failureDistribution[[1]]$kind <- "evaluated"
  expect_true(validator(jsonlite::toJSON(doc, auto_unbox = TRUE, digits = NA)))
})

test_that("the optimize and baseline validators carry the same rule", {
  # One entry shape across the family: an amendment that reached only the
  # format a report happens to read is how the last one went unnoticed.
  for (format in c("mavai-optimize-1", "mavai-baseline-1")) {
    validator <- jsonvalidate::json_validator(
      file.path(repo_root, "schema", paste0(format, ".schema.json")),
      engine = "ajv"
    )
    example <- if (format == "mavai-optimize-1") "optimize-typical.yaml" else "baseline-typical.yaml"
    doc <- yaml::read_yaml(
      file.path(repo_root, "inst", "interchange", example),
      handlers = list(seq = function(x) as.list(x), "null" = function(x) NA)
    )
    entry <- list(condition = "unreachable", kind = "delivery", count = 1L)
    if (format == "mavai-optimize-1") {
      doc$iterations[[1]]$statistics$failureDistribution <- list(entry)
    } else {
      doc$criteria[[1]]$failureDistribution <- list(entry)
    }
    expect_true(validator(jsonlite::toJSON(doc, auto_unbox = TRUE, digits = NA, na = "null")),
                info = format)

    entry$condition <- "the gateway said no"
    if (format == "mavai-optimize-1") {
      doc$iterations[[1]]$statistics$failureDistribution <- list(entry)
    } else {
      doc$criteria[[1]]$failureDistribution <- list(entry)
    }
    expect_false(validator(jsonlite::toJSON(doc, auto_unbox = TRUE, digits = NA, na = "null")),
                 info = format)
  }
})

test_that("the verdict-1.5 XSD refuses an unknown failure kind", {
  skip_if_not_installed("xml2")
  xsd <- xml2::read_xml(file.path(repo_root, "schema", "verdict-1.5.xsd"))
  body <- readLines(
    file.path(repo_root, "inst", "interchange", "verdict-1.5-typical.xml")
  )
  mutated <- sub('kind="delivery"', 'kind="partial"', body, fixed = TRUE)
  expect_false(isTRUE(xml2::xml_validate(
    xml2::read_xml(paste(mutated, collapse = "\n")), xsd
  )))
})

test_that("a 1.4-shaped check is a valid 1.5 check", {
  # The attribute is optional, so an emitter that has not adopted the kind
  # still writes conformant 1.5 records.
  skip_if_not_installed("xml2")
  xsd <- xml2::read_xml(file.path(repo_root, "schema", "verdict-1.5.xsd"))
  body <- readLines(
    file.path(repo_root, "inst", "interchange", "verdict-1.5-typical.xml")
  )
  mutated <- gsub(' kind="delivery"| kind="evaluated"', "", body)
  expect_true(isTRUE(xml2::xml_validate(
    xml2::read_xml(paste(mutated, collapse = "\n")), xsd
  )))
})
