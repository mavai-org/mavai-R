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
read_yaml_as_json <- function(path) {
  doc <- yaml::read_yaml(path, handlers = list(seq = function(x) as.list(x)))
  jsonlite::toJSON(doc, auto_unbox = TRUE, digits = NA)
}

formats <- list(
  explore  = "schema/mavai-explore-1.schema.json",
  optimize = "schema/mavai-optimize-1.schema.json"
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

if (failures > 0L) {
  cat(sprintf("\n%d interchange validation failure(s)\n", failures))
  quit(status = 1L)
}
cat("\nall interchange schemas and worked examples valid\n")
