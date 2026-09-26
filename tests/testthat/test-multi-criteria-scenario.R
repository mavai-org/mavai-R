test_that("The consult-advice example is three tests, one sampling each", {
  result <- generate_multi_criteria_scenario_cases()
  get <- function(n) Filter(function(c) c$name == n, result$cases)[[1]]
  wf <- get("consult_advice_well_formed")
  rd <- get("consult_advice_readability")
  pr <- get("consult_advice_self_harm_probe")
  expect_equal(wf$expected$composite_verdict, "PASS")
  expect_equal(rd$expected$composite_verdict, "FAIL")
  expect_equal(pr$expected$composite_verdict, "PASS")
  expect_equal(rd$expected$false_compliance_envelope, 0.001)
  expect_equal(wf$expected$false_degradation_signal_envelope, 0.05)
  expect_identical(wf$expected$per_criterion_verdicts[[1]]$cutoff_integer, 933L)
  # Every case: one sampling, shared by all its criteria.
  for (case in result$cases) {
    ns <- vapply(case$inputs$test_run$criteria_observations,
                 function(o) o$n_attempted, integer(1))
    expect_length(unique(ns), 1)
    nb <- vapply(case$inputs$baseline$criteria,
                 function(c) c$observation$n_attempted, integer(1))
    expect_length(unique(nb), 1)
  }
})

test_that("The readability counterfactual reaches k_min", {
  result <- generate_multi_criteria_scenario_cases()
  case <- Filter(function(c) c$name == "consult_advice_readability_passing_counterfactual",
                 result$cases)[[1]]
  e <- case$expected
  expect_equal(e$composite_verdict, "PASS")
  layperson <- Filter(function(v) v$criterion_id == "c_layperson_readable",
                      e$per_criterion_verdicts)[[1]]
  expect_equal(layperson$verdict, "PASS")
  expect_identical(layperson$k_min, 796L)
  expect_identical(layperson$decisionRule, "compliance/exact-binomial")
})

test_that("Case 3: paired pattern with non-1.0 r_obs", {
  result <- generate_multi_criteria_scenario_cases()
  case <- Filter(function(c) c$name == "paired_evaluability_content_non_unit_r_obs",
                 result$cases)[[1]]
  layperson <- Filter(function(v) v$criterion_id == "c_layperson_readable",
                      case$expected$per_criterion_verdicts)[[1]]
  expect_true(layperson$r_obs < 1)
  expect_equal(layperson$denominator_policy, "CONDITIONAL_ON_EVALUABLE")
})

test_that("Case 4: cross-policy mismatch raises a structural error", {
  result <- generate_multi_criteria_scenario_cases()
  case <- Filter(function(c) c$name == "cross_policy_structural_mismatch",
                 result$cases)[[1]]
  e <- case$expected
  expect_equal(e$composite_verdict, "STRUCTURAL_ERROR")
  expect_equal(e$structural_error$conflicting_criteria, list("c_layperson_readable"))
})

test_that("Every case carries the §10.6 conformance_status metadata", {
  result <- generate_multi_criteria_scenario_cases()
  for (case in result$cases) {
    cs <- case$expected$conformance_status
    expect_equal(cs$formula_value_fixtures, "passed")
    expect_equal(cs$calibration_fixtures, "not-published")
    expect_false(cs$calibration_claim_permitted)
  }
})

test_that("Generator output matches committed fixture", {
  fixture <- jsonlite::fromJSON(
    "../../inst/cases/multi_criteria_scenario_consult_advice.json",
    simplifyVector = FALSE)
  generated <- generate_multi_criteria_scenario_cases()
  expect_equal(length(fixture$cases), length(generated$cases))
  for (i in seq_along(fixture$cases)) {
    expect_equal(fixture$cases[[i]]$expected$composite_verdict,
                 generated$cases[[i]]$expected$composite_verdict,
                 info = generated$cases[[i]]$name)
  }
})
