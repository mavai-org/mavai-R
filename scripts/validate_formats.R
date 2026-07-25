#!/usr/bin/env Rscript
# Validate the declarative format schemas and their conformance corpus.
#
# Checks:
#   1. Each JSON Schema in inst/formats/schemas/ compiles under ajv
#      (draft 2020-12) — a schema that does not compile is refused before
#      it can mis-validate anything.
#   2. Every corpus file under inst/formats/corpus/valid/ validates against
#      the schema its format: identifier selects.
#   3. Every corpus file under inst/formats/corpus/invalid/ whose manifest
#      entry classifies it as structurally invalid is refused by its schema.
#      (Semantically invalid files — refusals the schema cannot express —
#      are structurally well-formed and are asserted by each framework's
#      loader conformance test against the manifest, not here.)
#
# Run from the repository root: Rscript scripts/validate_formats.R
# Exits non-zero on the first failing check, printing every error found.
# Requires: jsonvalidate, yaml, jsonlite (Suggests).

suppressPackageStartupMessages({
  library(jsonvalidate)
  library(jsonlite)
})

# YAML sequences must stay JSON arrays even at length 1 (e.g. a single-entry
# one-of: or a one-entry explorations: list); the default reader simplifies
# them to atomic vectors, which auto_unbox would then collapse to scalars.
read_yaml_as_json <- function(path) {
  doc <- yaml::read_yaml(path, handlers = list(seq = function(x) as.list(x)))
  jsonlite::toJSON(doc, auto_unbox = TRUE, digits = NA)
}

schemas <- list(
  "mavai-contract/1" = "inst/formats/schemas/mavai-contract-1.schema.json",
  "mavai-services/1" = "inst/formats/schemas/mavai-services-1.schema.json"
)

failures <- 0L
validators <- list()

for (format_id in names(schemas)) {
  schema_path <- schemas[[format_id]]
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
  validators[[format_id]] <- validator
}

# A corpus file's schema is selected by its own format: identifier — the
# same dispatch a reader performs. A file whose format: matches no schema
# is a corpus defect.
validator_for <- function(path) {
  doc <- yaml::read_yaml(path)
  format_id <- doc[["format"]]
  if (is.null(format_id) || is.null(validators[[format_id]])) {
    return(NULL)
  }
  validators[[format_id]]
}

manifest_path <- "inst/formats/manifest.yaml"
manifest <- if (file.exists(manifest_path)) yaml::read_yaml(manifest_path) else NULL

valid_files <- sort(Sys.glob("inst/formats/corpus/valid/*.yaml"))
for (path in valid_files) {
  validator <- validator_for(path)
  if (is.null(validator)) {
    cat(sprintf("FAIL  %s: format: matches no published schema\n", path))
    failures <- failures + 1L
    next
  }
  ok <- validator(read_yaml_as_json(path), verbose = TRUE)
  if (isTRUE(ok)) {
    cat(sprintf("ok    %s validates\n", path))
  } else {
    cat(sprintf("FAIL  %s does not validate\n", path))
    print(attr(ok, "errors"))
    failures <- failures + 1L
  }
}

# invalid/ files are checked only when the manifest classifies them: an
# entry with refusal: structural must be refused by the schema; an entry
# with refusal: semantic must (deliberately) pass the schema — its refusal
# is the consuming loader's obligation.
invalid_files <- sort(Sys.glob("inst/formats/corpus/invalid/*.yaml"))
if (length(invalid_files) > 0L && is.null(manifest)) {
  cat(sprintf("FAIL  %d invalid/ corpus file(s) but no %s to classify them\n",
              length(invalid_files), manifest_path))
  failures <- failures + 1L
}
if (!is.null(manifest)) {
  entries <- manifest[["corpus"]]
  by_file <- stats::setNames(entries, vapply(entries, `[[`, "", "file"))
  for (path in invalid_files) {
    entry <- by_file[[basename(path)]]
    if (is.null(entry)) {
      cat(sprintf("FAIL  %s has no manifest entry\n", path))
      failures <- failures + 1L
      next
    }
    validator <- validator_for(path)
    if (is.null(validator)) {
      cat(sprintf("FAIL  %s: format: matches no published schema\n", path))
      failures <- failures + 1L
      next
    }
    ok <- isTRUE(validator(read_yaml_as_json(path)))
    structural <- identical(entry[["refusal"]], "structural")
    if (structural && ok) {
      cat(sprintf("FAIL  %s is classified structural but the schema accepts it\n", path))
      failures <- failures + 1L
    } else if (!structural && !ok) {
      cat(sprintf("FAIL  %s is classified semantic but the schema refuses it\n", path))
      failures <- failures + 1L
    } else {
      cat(sprintf("ok    %s (%s refusal)\n", path,
                  if (structural) "structural" else "semantic"))
    }
  }
}

if (failures > 0L) {
  cat(sprintf("\n%d format validation failure(s)\n", failures))
  quit(status = 1L)
}
cat("\nall format schemas compile and the corpus validates\n")
