#' The conformance manifest: what the fixtures oblige, machine-readably.
#'
#' Generated from the suites at generation time, never hand-maintained.
#' The manifest is the denominator that makes a framework's conformance
#' standing countable: per suite it carries the case names, the expected
#' fields classified binding vs informational, and a content hash of the
#' fixture file (so a consumer can assert its vendored snapshot matches
#' the manifest it claims coverage against). A family-mandatory tier
#' names the suites every mavai implementation must support; per-repo
#' scope declarations may extend that tier, never subtract from it.
#'
#' A conforming implementation's conformance test MUST, for every suite
#' in (family-mandatory UNION its declared scope): evaluate every case,
#' assert every binding expected field, fail its build on any gap or
#' mismatch, and report its standing (covered / in-manifest counts and
#' the named not-yet-addressed suites).

# Suites every mavai implementation must support: the methodological
# spine. Roster confirmed by the owner at the 2026-07-10 design session
# (seed examples named: the Wilson lower bound and the binomial
# order-statistic construction).
FAMILY_MANDATORY_SUITES <- c(
  "wilson_ci",
  "wilson_lower",
  "threshold_derivation",
  "verdict",
  "latency_percentile",
  "latency_threshold",
  "regression_decision"
)

# Why the roster is not extended for the effective-baseline step
# (DIR-R-SIZING-boundary-cases, 2026-08). Published in the manifest
# because a tier decision that lives only in a directive is a decision
# consumers cannot see.
TIER_RATIONALE <- paste0(
  "The effective-baseline substitution of companion S4.3.2 and its zero-baseline mirror ",
  "S4.3.4 are obligations of the existing mandatory tier; the roster is unchanged. ",
  "threshold_derivation carries the perfect baseline at two baseline sizes and the zero ",
  "baseline at three test sizes, and regression_decision carries both boundaries composed ",
  "into a verdict. Each of those cases binds: an implementation using the raw point ",
  "estimate at k = n differs from the published threshold by 5e-3 to 8e-2, far above the ",
  "1e-6 tolerance, and one carrying a cancellation residue at k = 0 returns cutoff_integer ",
  "1 where the fixtures say 0. Promoting baseline_object or criterion_verdict_inferential ",
  "was therefore not needed to make the substitution binding. ",
  "One obligation is deliberately NOT in the mandatory tier: the sizing refusal at an ",
  "empty domain (S5.4.1), published in risk_driven_sizing, which is optional. A framework ",
  "that implements no risk-driven sizing has nothing to refuse; one that does must consume ",
  "the suite to be conformant with the feature it claims. Whether risk_driven_sizing should ",
  "join the roster is a question about the roster, not about this boundary, and is left to ",
  "the owner."
)

# Expected fields documented as informational (not conformance targets).
# Everything not listed here is binding. Authored here, beside the
# generators, so classification travels with the release.
INFORMATIONAL_FIELDS <- list(
  latency_threshold_bootstrap = c("bootstrap_upper", "point_estimate", "diff")
)

#' Collect one suite's expected-field inventory across its cases.
#' @keywords internal
expected_fields_of <- function(suite) {
  fields <- character(0)
  for (case in suite$cases) {
    fields <- union(fields, names(case$expected))
  }
  sort(fields)
}

#' Generate the conformance manifest from generated suite objects.
#'
#' @param suites Named list of suite objects (name -> generator output).
#' @param fixture_version The package version the manifest describes.
#' @param case_dir Directory holding the written suite JSON files, for
#'   content hashing; hashes are omitted when files are absent (unit
#'   tests over in-memory suites).
#' @return A list suitable for JSON serialisation.
#' @export
generate_manifest <- function(suites, fixture_version, case_dir = NULL) {
  suite_entries <- list()
  for (name in sort(names(suites))) {
    suite <- suites[[name]]
    fields <- expected_fields_of(suite)
    informational <- intersect(fields, INFORMATIONAL_FIELDS[[name]])
    entry <- list(
      file = paste0(name, ".json"),
      tolerance = suite$tolerance,
      caseCount = length(suite$cases),
      cases = vapply(suite$cases, function(case) case$name, character(1)),
      bindingFields = setdiff(fields, informational),
      informationalFields = informational
    )
    if (!is.null(case_dir)) {
      path <- file.path(case_dir, entry$file)
      if (file.exists(path)) {
        entry$md5 <- unname(tools::md5sum(path))
      }
    }
    suite_entries[[name]] <- entry
  }
  missing <- setdiff(FAMILY_MANDATORY_SUITES, names(suites))
  if (length(missing) > 0) {
    stop("family-mandatory suites missing from generation: ",
         paste(missing, collapse = ", "))
  }
  list(
    manifestVersion = 1L,
    fixtureVersion = fixture_version,
    familyMandatory = FAMILY_MANDATORY_SUITES,
    familyMandatoryRationale = TIER_RATIONALE,
    suites = suite_entries
  )
}
