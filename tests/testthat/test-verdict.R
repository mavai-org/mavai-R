by_name <- function(suite) setNames(suite$cases, vapply(suite$cases, `[[`, character(1), "name"))

test_that("the point-estimate rule is withdrawn: 48 of 50 does not demonstrate 90%", {
  v <- evaluate_verdict(48, 50, 0.05, threshold = 0.90)
  expect_identical(v$verdict, "FAIL")
  expect_equal(v$observed_rate, 0.96)
  expect_identical(evaluate_verdict(49, 50, 0.05, threshold = 0.90)$verdict, "PASS")
  expect_null(v$test_statistic)
})

test_that("every verdict case names its rule and each rule is exercised", {
  suite <- generate_verdict_cases()
  rules <- unlist(lapply(suite$cases, `[[`, "decisionRule"))
  expect_setequal(unique(rules), c("regression/score-cc", "compliance/exact-binomial"))
})

test_that("the verdict suite agrees with the decision suites", {
  cases <- by_name(generate_verdict_cases())
  expect_identical(cases[["regression_pass_91_of_100_baseline_951_of_1000"]]$expected$verdict, "PASS")
  expect_identical(cases[["regression_fail_95_of_100_baseline_100_of_100"]]$expected$verdict, "FAIL")
  expect_identical(cases[["regression_pass_95_of_100_baseline_99_of_100"]]$expected$verdict, "PASS")
  expect_identical(cases[["compliance_refused_50_of_50_threshold_95"]]$expected$configuration_error,
                   "COMPLIANCE_INFEASIBLE")
  expect_identical(cases[["compliance_smoke_50_of_50_threshold_95"]]$expected$verdict, "FAIL")
})

test_that("joint configurations are refused whole", {
  cases <- by_name(generate_verdict_cases())
  j <- cases[["joint_refused_empirical_part_test_larger_than_baseline"]]
  expect_identical(j$approach, "joint")
  expect_length(j$decisionRule, 2)
  expect_identical(j$expected$configuration_error, "TEST_LARGER_THAN_BASELINE")
  expect_true(is.na(j$expected$verdict))
})

test_that("a joint configuration with an invalid part is refused whole", {
  v <- evaluate_verdict(190, 200, 0.05, baseline_successes = 95, baseline_trials = 100,
                        threshold = 0.90)
  expect_identical(v$configuration_error, "TEST_LARGER_THAN_BASELINE")
  expect_true(is.na(v$verdict))
  v <- evaluate_verdict(100, 100, 0.05, baseline_successes = 950, baseline_trials = 1000,
                        threshold = 0.999)
  expect_identical(v$configuration_error, "COMPLIANCE_INFEASIBLE")
})
