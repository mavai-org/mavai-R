#' Generate all reference case files
#'
#' Writes JSON files to inst/cases/ for each statistical computation suite.
#' This is the primary entry point for regenerating the conformance dataset.
#'
#' @param output_dir Character. Directory to write JSON files to.
#'   Defaults to inst/cases/ relative to the package root.
#' @export
generate_all <- function(output_dir = NULL) {
  if (is.null(output_dir)) {
    output_dir <- system.file("cases", package = "mavair")
    if (output_dir == "") {
      # Not installed — use local path
      output_dir <- file.path("inst", "cases")
    }
  }

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  suites <- list(
    wilson_ci = generate_wilson_ci_cases(),
    wilson_lower = generate_wilson_lower_cases(),
    threshold_derivation = generate_threshold_derivation_cases(),
    power_analysis = generate_power_analysis_cases(),
    feasibility = generate_feasibility_cases(),
    verdict = generate_verdict_cases(),
    latency_percentile = generate_latency_percentile_cases(),
    latency_threshold = generate_latency_threshold_cases()
  )

  for (name in names(suites)) {
    path <- file.path(output_dir, paste0(name, ".json"))
    jsonlite::write_json(suites[[name]], path, pretty = TRUE, auto_unbox = TRUE,
                         digits = NA)
    message("Wrote: ", path)
  }

  invisible(suites)
}
