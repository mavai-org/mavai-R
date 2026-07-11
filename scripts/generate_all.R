#!/usr/bin/env Rscript
#
# Regenerate all conformance reference data.
#
# Usage:
#   Rscript scripts/generate_all.R
#
# This writes JSON files to inst/cases/. These files are committed to the
# repository so that consumers (punit, feotest, baseltest, ...) can read
# them without needing R installed.

# Source all R files (works without installing the package)
r_files <- list.files("R", pattern = "\\.R$", full.names = TRUE)
for (f in r_files) source(f)

output_dir <- file.path("inst", "cases")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

suites <- list(
  wilson_ci = generate_wilson_ci_cases(),
  wilson_lower = generate_wilson_lower_cases(),
  threshold_derivation = generate_threshold_derivation_cases(),
  power_analysis = generate_power_analysis_cases(),
  feasibility = generate_feasibility_cases(),
  verdict = generate_verdict_cases(),
  latency_percentile = generate_latency_percentile_cases(),
  latency_threshold = generate_latency_threshold_cases(),
  latency_threshold_bootstrap = generate_latency_threshold_bootstrap_cases(),
  latency_percentile_minimums = generate_latency_percentile_minimums_cases(),
  regression_decision = generate_regression_decision_cases(),
  risk_driven_sizing = generate_risk_driven_sizing_cases(),
  # Multi-criteria model fixtures (per DIR-MULTI-CRITERIA-FIXTURES-javai-R):
  criterion_verdict_observational =
    generate_criterion_verdict_observational_cases(),
  criterion_verdict_inferential =
    generate_criterion_verdict_inferential_cases(),
  composite_verdict = generate_composite_verdict_cases(),
  baseline_object = generate_baseline_object_cases(),
  multi_criteria_scenario_consult_advice =
    generate_multi_criteria_scenario_cases()
)

for (name in names(suites)) {
  path <- file.path(output_dir, paste0(name, ".json"))
  jsonlite::write_json(suites[[name]], path, pretty = TRUE, auto_unbox = TRUE,
                       digits = NA, na = "null")
  message("Wrote: ", path)
}

# The manifest is generated from the suites just written (content
# hashes included), never hand-maintained.
description <- read.dcf("DESCRIPTION")
fixture_version <- unname(description[1, "Version"])
manifest <- generate_manifest(suites, fixture_version, case_dir = output_dir)
manifest_path <- file.path(output_dir, "manifest.json")
jsonlite::write_json(manifest, manifest_path, pretty = TRUE, auto_unbox = TRUE,
                     digits = NA, na = "null")
message("Wrote: ", manifest_path)

message("\nDone. ", length(suites), " suites generated + manifest.")
