test_that("Regression verdict: clear PASS at K well above cutoff", {
  result <- regression_verdict(
    n_attempted = 1000, n_evaluable = 1000, K_c = 953, alpha = 0.05,
    denominator_policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL",
    baseline_successes = 951, baseline_trials = 1000
  )
  expect_equal(result$verdict, "PASS")
  expect_identical(result$cutoff_integer, 933L)
  expect_true(is.na(result$configuration_error))
})

test_that("Regression verdict: the §3.4 rate has cutoff 91", {
  result <- regression_verdict(
    n_attempted = 100, n_evaluable = 100, K_c = 91, alpha = 0.05,
    denominator_policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL",
    baseline_successes = 951, baseline_trials = 1000
  )
  expect_equal(result$cutoff_integer, 91L)
  expect_equal(result$displayed_rate, 0.91)
  expect_equal(result$verdict, "PASS")  # K_c = 91 = c, PASS
})

test_that("Regression verdict: K one below cutoff fails", {
  result <- regression_verdict(
    n_attempted = 100, n_evaluable = 100, K_c = 90, alpha = 0.05,
    denominator_policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL",
    baseline_successes = 951, baseline_trials = 1000
  )
  expect_equal(result$cutoff_integer, 91L)
  expect_equal(result$verdict, "FAIL")
})

test_that("Regression: a tiny test against a near-perfect baseline is admitted", {
  result <- regression_verdict(
    n_attempted = 5, n_evaluable = 5, K_c = 5, alpha = 0.001,
    denominator_policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL",
    baseline_successes = 999, baseline_trials = 1000
  )
  expect_identical(result$verdict, "PASS")
  expect_true(is.na(result$configuration_error))
})

test_that("Compliance verdict: clear PASS well above p_req", {
  result <- compliance_verdict(
    n_attempted = 10000, n_evaluable = 10000, K_c = 9990, alpha = 0.05,
    denominator_policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL", p_req = 0.99
  )
  expect_equal(result$verdict, "PASS")
  expect_true(result$clopper_pearson_lower > 0.99)
  expect_true(result$p_value <= 0.05)
  expect_equal(result$p_value_method, "exact-binomial-upper-tail")
})

test_that("Compliance FAIL with strands disagreeing (§10.3 example)", {
  result <- compliance_verdict(
    n_attempted = 800, n_evaluable = 800, K_c = 788, alpha = 0.001,
    denominator_policy = "CONDITIONAL_ON_EVALUABLE", p_req = 0.98
  )
  expect_equal(result$verdict, "FAIL")
  expect_equal(result$observed_rate_status, "ABOVE_THRESHOLD")
  expect_equal(result$operational_caution_category, "STRANDS_DISAGREE")
  # p_hat = 0.985 > p_req, but K_c = 788 < k_min = 796
  expect_true(result$p_hat_c > 0.98)
  expect_identical(result$k_min, 796L)
  expect_true(result$clopper_pearson_lower < 0.98)
})

test_that("Compliance INCONCLUSIVE at n_c = 0", {
  result <- compliance_verdict(
    n_attempted = 0, n_evaluable = 0, K_c = 0, alpha = 0.05,
    denominator_policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL", p_req = 0.95
  )
  expect_equal(result$verdict, "INCONCLUSIVE")
  expect_equal(result$feasibility_gate, "REFUSE")
})

test_that("Generator output matches the committed fixture", {
  fixture <- jsonlite::fromJSON(
    "../../inst/cases/criterion_verdict_inferential.json",
    simplifyVector = FALSE)
  generated <- generate_criterion_verdict_inferential_cases()
  expect_equal(length(fixture$cases), length(generated$cases))
  for (i in seq_along(fixture$cases)) {
    committed <- fixture$cases[[i]]$expected$verdict
    expect_equal(if (is.null(committed)) NA_character_ else committed,
                 generated$cases[[i]]$expected$verdict,
                 info = generated$cases[[i]]$name)
  }
})
