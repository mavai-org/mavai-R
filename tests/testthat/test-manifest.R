suites_for_test <- function() {
  list(
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
    criterion_verdict_observational = generate_criterion_verdict_observational_cases(),
    criterion_verdict_inferential = generate_criterion_verdict_inferential_cases(),
    composite_verdict = generate_composite_verdict_cases(),
    baseline_object = generate_baseline_object_cases(),
    multi_criteria_scenario_consult_advice = generate_multi_criteria_scenario_cases()
  )
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
  }
})

test_that("informational classification applies only where authored", {
  manifest <- generate_manifest(suites_for_test(), "0.0.0-test")
  bootstrap <- manifest$suites$latency_threshold_bootstrap
  expect_setequal(bootstrap$informationalFields,
                  c("bootstrap_upper", "point_estimate", "diff"))
  expect_false(any(bootstrap$informationalFields %in% bootstrap$bindingFields))
  # The decision suite's binding fields include the cutoff artefacts.
  decision <- manifest$suites$regression_decision
  expect_true(all(c("cutoff_integer", "achieved_size", "verdict")
                  %in% decision$bindingFields))
  expect_length(decision$informationalFields, 0)
  # threshold_derivation's cutoff fields are binding — the arc's point.
  derivation <- manifest$suites$threshold_derivation
  expect_true(all(c("cutoff_integer", "achieved_size")
                  %in% derivation$bindingFields))
})

test_that("every family-mandatory suite exists, and absence fails loudly", {
  suites <- suites_for_test()
  expect_true(all(FAMILY_MANDATORY_SUITES %in% names(suites)))
  reduced <- suites[setdiff(names(suites), "wilson_lower")]
  expect_error(generate_manifest(reduced, "0.0.0-test"), "wilson_lower")
})
