#!/usr/bin/env Rscript
# Validate the interchange schemas and their worked examples.
#
# Two checks per format:
#   1. The JSON Schema itself compiles under ajv (draft 2020-12) — a schema
#      that does not compile is refused before it can mis-validate anything.
#   2. Every worked example in inst/interchange/ validates against its schema.
#
# Run from the repository root: Rscript scripts/validate_interchange.R
# Exits non-zero on the first failing check, printing every error found.
# Requires: jsonvalidate, yaml, jsonlite (Suggests).

suppressPackageStartupMessages({
  library(jsonvalidate)
  library(jsonlite)
})

# YAML sequences must stay JSON arrays even at length 1 (e.g. a single-entry
# failureDistribution or a one-sample sortedPassingLatenciesMs); the default
# reader simplifies them to atomic vectors, which auto_unbox would then
# collapse to scalars.
# An explicit YAML null must survive as a JSON null. The default reader maps
# it to R NULL, which jsonlite renders as {} — so a STATED null (mavai-baseline-1
# uses one for wilsonLowerBound at zero trials, where "no evidence" must be
# distinguishable from "field absent") would fail validation as an object.
# Mapping it to NA and emitting with na = "null" preserves it.
read_yaml_as_json <- function(path) {
  doc <- yaml::read_yaml(
    path,
    handlers = list(seq = function(x) as.list(x), "null" = function(x) NA)
  )
  jsonlite::toJSON(doc, auto_unbox = TRUE, digits = NA, na = "null")
}

formats <- list(
  explore  = "schema/mavai-explore-1.schema.json",
  optimize = "schema/mavai-optimize-1.schema.json",
  baseline = "schema/mavai-baseline-1.schema.json"
)

failures <- 0L

for (name in names(formats)) {
  schema_path <- formats[[name]]

  validator <- tryCatch(
    jsonvalidate::json_validator(schema_path, engine = "ajv"),
    error = function(e) e
  )
  if (inherits(validator, "error")) {
    cat(sprintf("FAIL  %s does not compile: %s\n",
                schema_path, conditionMessage(validator)))
    failures <- failures + 1L
    next
  }
  cat(sprintf("ok    %s compiles (ajv, draft 2020-12)\n", schema_path))

  examples <- sort(Sys.glob(sprintf("inst/interchange/%s-*.yaml", name)))
  if (length(examples) == 0L) {
    cat(sprintf("FAIL  no worked examples found for %s\n", name))
    failures <- failures + 1L
    next
  }

  for (example in examples) {
    ok <- validator(read_yaml_as_json(example), verbose = TRUE)
    if (isTRUE(ok)) {
      cat(sprintf("ok    %s validates against %s\n", example, schema_path))
    } else {
      cat(sprintf("FAIL  %s does not validate against %s\n",
                  example, schema_path))
      print(attr(ok, "errors"))
      failures <- failures + 1L
    }
  }
}

# The verdict XML interchange: every verdict-*.xml worked example validates
# against the XSD its filename names (verdict-1.3-typical.xml -> verdict-1.3.xsd).
# Requires xml2 (Suggests); the section is skipped with a notice when absent
# so environments without it still validate the YAML formats.
if (requireNamespace("xml2", quietly = TRUE)) {
  verdict_examples <- sort(Sys.glob("inst/interchange/verdict-*.xml"))
  for (example in verdict_examples) {
    revision <- sub("^verdict-([0-9]+\\.[0-9]+).*$", "\\1",
                    basename(example))
    xsd_path <- sprintf("schema/verdict-%s.xsd", revision)
    if (!file.exists(xsd_path)) {
      cat(sprintf("FAIL  %s names no published XSD (%s)\n", example, xsd_path))
      failures <- failures + 1L
      next
    }
    ok <- xml2::xml_validate(xml2::read_xml(example), xml2::read_xml(xsd_path))
    if (isTRUE(ok)) {
      cat(sprintf("ok    %s validates against %s\n", example, xsd_path))
    } else {
      cat(sprintf("FAIL  %s does not validate against %s\n", example, xsd_path))
      print(attr(ok, "errors"))
      failures <- failures + 1L
    }
  }
} else {
  cat("note  xml2 not installed; verdict XSD validation skipped\n")
}

if (failures > 0L) {
  cat(sprintf("\n%d interchange validation failure(s)\n", failures))
  quit(status = 1L)
}
cat("\nall interchange schemas and worked examples valid\n")
