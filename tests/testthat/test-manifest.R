suites_for_test <- function() {
  s <- list(
    wilson_ci = generate_wilson_ci_cases(),
    wilson_lower = generate_wilson_lower_cases(),
    threshold_derivation = generate_threshold_derivation_cases(),
    regression_decision = generate_regression_decision_cases(),
    compliance_decision = generate_compliance_decision_cases(),
    feasibility = generate_feasibility_cases(),
    power_analysis = generate_power_analysis_cases(),
    risk_driven_sizing = generate_risk_driven_sizing_cases(),
    verdict = generate_verdict_cases(),
    latency_percentile = generate_latency_percentile_cases(),
    latency_threshold = generate_latency_threshold_cases(),
    latency_percentile_minimums = generate_latency_percentile_minimums_cases(),
    criterion_verdict_observational = generate_criterion_verdict_observational_cases(),
    criterion_verdict_inferential = generate_criterion_verdict_inferential_cases(),
    composite_verdict = generate_composite_verdict_cases(),
    baseline_object = generate_baseline_object_cases(),
    multi_criteria_scenario_consult_advice = generate_multi_criteria_scenario_cases()
  )
  Map(finalise_suite, names(s), s)
}

test_that("the manifest reflects the suites exactly", {
  suites <- suites_for_test()
  manifest <- generate_manifest(suites, "0.0.0-test")
  expect_setequal(names(manifest$suites), names(suites))
  for (name in names(suites)) {
    entry <- manifest$suites[[name]]
    expect_equal(entry$caseCount, length(suites[[name]]$cases))
    expect_setequal(entry$cases,
                    vapply(suites[[name]]$cases, `[[`, character(1), "name"))
    expect_identical(entry$decisionRules, suites[[name]]$decisionRules)
  }
})

test_that("the manifest and every suite carry the methodology and fixture-schema versions", {
  suites <- suites_for_test()
  manifest <- generate_manifest(suites, "0.0.0-test")
  expect_identical(manifest$methodologyVersion, "1.5.0")
  expect_identical(manifest$fixtureSchemaVersion, 2L)
  expect_identical(manifest$manifestVersion, 2L)
  expect_setequal(manifest$configurationErrors,
                  c("TEST_LARGER_THAN_BASELINE", "COMPLIANCE_INFEASIBLE"))
  expect_setequal(vapply(manifest$decisionRules, `[[`, character(1), "id"),
                  c("regression/fisher", "compliance/exact-binomial", "latency/precedence",
                      "latency/compliance-exact-binomial"))
  for (s in suites) {
    expect_identical(names(s)[1:4], c("suite", "methodologyVersion", "fixtureSchemaVersion", "decisionRules"))
    expect_identical(s$methodologyVersion, "1.5.0")
  }
})

test_that("report values are informational and decision artefacts binding", {
  manifest <- generate_manifest(suites_for_test(), "0.0.0-test")
  for (name in c("threshold_derivation", "regression_decision")) {
    e <- manifest$suites[[name]]
    expect_setequal(e$informationalFields, c("threshold_real", "displayed_rate", "size_at_assumed_common_rate"))
    expect_true(all(c("cutoff_integer", "configuration_error") %in% e$bindingFields))
  }
  expect_true("verdict" %in% manifest$suites$regression_decision$bindingFields)
  expect_true(all(c("k_min", "verdict", "configuration_error", "pass_possible") %in%
                    manifest$suites$compliance_decision$bindingFields))
  expect_true(all(c("rank", "threshold", "saturated") %in% manifest$suites$latency_threshold$bindingFields))
  expect_true("breach_probability" %in% manifest$suites$latency_threshold$informationalFields)
  for (e in manifest$suites) expect_false(any(e$informationalFields %in% e$bindingFields))
})

test_that("every family-mandatory suite exists, and absence fails loudly", {
  suites <- suites_for_test()
  expect_setequal(FAMILY_MANDATORY_SUITES,
                  c("wilson_ci", "wilson_lower", "regression_decision", "compliance_decision",
                    "latency_threshold", "feasibility", "power_analysis", "verdict"))
  expect_true(all(FAMILY_MANDATORY_SUITES %in% names(suites)))
  reduced <- suites[setdiff(names(suites), "compliance_decision")]
  expect_error(generate_manifest(reduced, "0.0.0-test"), "compliance_decision")
})
