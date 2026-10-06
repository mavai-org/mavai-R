#' The conformance manifest: what the fixtures oblige, machine-readably.
#'
#' Generated from the suites at generation time, never hand-maintained.
#' The manifest is the denominator that makes a framework's conformance
#' standing countable: per suite it carries the case names, the decision
#' rules the suite's expectations depend on, the expected fields
#' classified binding vs informational, and a content hash of the
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

MANIFEST_VERSION <- 2L

# Suites every mavai implementation must support under methodology 1.6.0.
FAMILY_MANDATORY_SUITES <- c(
  "wilson_ci",
  "wilson_lower",
  "regression_decision",
  "compliance_decision",
  "latency_threshold",
  "feasibility",
  "power_analysis",
  "verdict"
)

# Why the roster is what it is. Published in the manifest because a tier
# decision that lives only in a design document is a decision consumers
# cannot see.
TIER_RATIONALE <- paste0(
  "Methodology 1.5.0 replaced the three decision rules and the mandatory roster with them; 1.6.0 keeps ",
  "both and changes only which verdicts bind (every assertion enforced by default). ",
  "The roster is the methodological spine of the three rules: the Wilson interval and lower ",
  "bound (kept as descriptive primitives; no rule decides with them), the empirical-regression ",
  "verdict (regression/fisher), the normative-compliance verdict (compliance/exact-binomial), ",
  "the latency threshold (latency/precedence), the feasibility gate and exact sizing of the ",
  "compliance rule, the exact power of the regression rule, and the verdict suite encoding ",
  "both ruled rules. Every mandatory decision suite carries its refusal cases, so both ",
  "configuration errors are binding through them. threshold_derivation (the regression cutoff ",
  "without a verdict, and the threshold-first inversion), risk_driven_sizing (exact sizing of ",
  "the regression rule against a declared tolerance, with its refusals), latency_percentile ",
  "(the nearest-rank primitive), latency_percentile_minimums and latency_compliance_decision ",
  "(explicit latency requirements enforced under latency/compliance-exact-binomial) remain ",
  "published and optional: ",
  "a framework that implements the feature must consume the suite. ",
  "criterion_verdict_inferential, criterion_verdict_observational, composite_verdict, ",
  "baseline_object and multi_criteria_scenario_consult_advice are informational. Withdrawn with ",
  "the 1.4.1 rules: latency_threshold_bootstrap (a comparison of the withdrawn order-statistic ",
  "bound); the 1.4.1 fixtures remain reproducible from the v0.10.13 release assets."
)

# Expected fields documented as informational (report obligations, not
# conformance targets). Everything not listed here is binding. Authored
# here, beside the generators, so classification travels with the release.
INFORMATIONAL_FIELDS <- list(
  threshold_derivation = c("threshold_real", "displayed_rate", "size_at_assumed_common_rate"),
  regression_decision = c("threshold_real", "displayed_rate", "size_at_assumed_common_rate"),
  compliance_decision = c("false_compliance", "clopper_pearson_lower"),
  latency_threshold = c("breach_probability", "test_rank", "n", "baseline_percentile"),
  latency_compliance_decision = c("false_compliance", "clopper_pearson_lower",
                                  "observed_percentile_ms", "raw_percentile_pass"),
  verdict = c("observed_rate"),
  power_analysis = c("first_crossing")
)

# The decision rules each suite's expectations depend on (none for the
# descriptive and structural suites).
SUITE_DECISION_RULES <- list(
  threshold_derivation = "regression/fisher",
  regression_decision = "regression/fisher",
  risk_driven_sizing = "regression/fisher",
  compliance_decision = "compliance/exact-binomial",
  feasibility = "compliance/exact-binomial",
  latency_threshold = "latency/precedence",
  latency_percentile_minimums = "latency/precedence",
  latency_compliance_decision = "latency/compliance-exact-binomial",
  power_analysis = c("compliance/exact-binomial", "regression/fisher"),
  verdict = c("compliance/exact-binomial", "regression/fisher", "latency/precedence",
              "latency/compliance-exact-binomial"),
  criterion_verdict_inferential = c("compliance/exact-binomial", "regression/fisher"),
  multi_criteria_scenario_consult_advice = c("compliance/exact-binomial", "regression/fisher",
                                             "latency/compliance-exact-binomial")
)

#' The decisionRules entry of a suite: a list of {id, version}.
#' @keywords internal
suite_decision_rules <- function(name) {
  ids <- SUITE_DECISION_RULES[[name]]
  if (is.null(ids)) return(list())
  lapply(ids, function(id) DECISION_RULES[[id]])
}

#' Stamp a generated suite with the methodology and fixture-schema
#' versions and its decision rules, in a fixed key order.
#'
#' @param name Suite name.
#' @param suite Generator output.
#' @return The suite with methodologyVersion, fixtureSchemaVersion and
#'   decisionRules inserted after `suite`.
#' @export
finalise_suite <- function(name, suite) {
  stopifnot(identical(suite$suite, name))
  c(list(suite = suite$suite,
         methodologyVersion = METHODOLOGY_VERSION,
         fixtureSchemaVersion = FIXTURE_SCHEMA_VERSION,
         decisionRules = suite_decision_rules(name)),
    suite[setdiff(names(suite), "suite")])
}

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
      decisionRules = suite_decision_rules(name),
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
    manifestVersion = MANIFEST_VERSION,
    fixtureVersion = fixture_version,
    methodologyVersion = METHODOLOGY_VERSION,
    fixtureSchemaVersion = FIXTURE_SCHEMA_VERSION,
    decisionRules = unname(DECISION_RULES),
    configurationErrors = CONFIGURATION_ERRORS,
    familyMandatory = FAMILY_MANDATORY_SUITES,
    familyMandatoryRationale = TIER_RATIONALE,
    suites = suite_entries
  )
}
