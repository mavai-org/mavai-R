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
  expect_setequal(unique(rules), c("regression/fisher", "compliance/exact-binomial"))
})

test_that("the verdict suite agrees with the decision suites", {
  cases <- by_name(generate_verdict_cases())
  expect_identical(cases[["regression_pass_91_of_100_baseline_951_of_1000"]]$expected$verdict, "PASS")
  expect_identical(cases[["regression_fail_95_of_100_baseline_100_of_100"]]$expected$verdict, "FAIL")
  expect_identical(cases[["regression_pass_95_of_100_baseline_99_of_100"]]$expected$verdict, "PASS")
  expect_identical(cases[["compliance_refused_50_of_50_threshold_95"]]$expected$configuration_error,
                   list("COMPLIANCE_INFEASIBLE"))
  expect_identical(cases[["compliance_smoke_50_of_50_threshold_95"]]$expected$verdict, "FAIL")
})

test_that("a test carrying a compliance and a regression criterion is refused whole", {
  cases <- by_name(generate_verdict_cases())
  j <- cases[["two_criteria_refused_regression_part_test_larger_than_baseline"]]
  expect_identical(j$approach, "two_criteria")
  expect_length(j$decisionRule, 2)
  expect_identical(j$expected$configuration_error, list("TEST_LARGER_THAN_BASELINE"))
  expect_true(is.na(j$expected$verdict))
  both <- cases[["two_criteria_refused_both_parts"]]$expected$configuration_error
  expect_identical(both, list("TEST_LARGER_THAN_BASELINE", "COMPLIANCE_INFEASIBLE"))
})

test_that("codes are reported in the fixed order whatever the order found", {
  expect_identical(configuration_errors("COMPLIANCE_INFEASIBLE", NA, "TEST_LARGER_THAN_BASELINE"),
                   list("TEST_LARGER_THAN_BASELINE", "COMPLIANCE_INFEASIBLE"))
  expect_identical(configuration_errors(NA, NA), list())
  expect_error(configuration_errors("NOT_A_CODE"))
})

test_that("two criteria on the same observations compose by the structural composite", {
  cases <- by_name(generate_verdict_cases())
  get <- function(n) cases[[n]]$expected
  expect_identical(get("two_criteria_pass")$verdict, "PASS")
  e <- get("two_criteria_fail_regression")
  expect_identical(e$verdict, "FAIL")
  expect_identical(e$triggering_criteria, list("c_well_formed_regression"))
  expect_identical(vapply(e$criteria, `[[`, character(1), "decisionRule"),
                   c("compliance/exact-binomial", "regression/fisher"))
  expect_identical(vapply(e$criteria, `[[`, numeric(1), "alpha"), c(0.01, 0.05))
  expect_equal(e$false_compliance_envelope, 0.01)
  expect_equal(e$false_degradation_signal_envelope, 0.05)
  expect_identical(get("two_criteria_fail_compliance")$triggering_criteria, list("c_well_formed_compliance"))
  expect_length(get("two_criteria_fail_both")$triggering_criteria, 2)
  expect_false(exists("joint_bar_verdict"))
})

test_that("a test with two criteria and an invalid part is refused whole", {
  v <- evaluate_verdict(190, 200, 0.05, baseline_successes = 95, baseline_trials = 100,
                        threshold = 0.90)
  expect_identical(v$configuration_error, list("TEST_LARGER_THAN_BASELINE"))
  expect_true(is.na(v$verdict))
  v <- evaluate_verdict(100, 100, 0.05, baseline_successes = 950, baseline_trials = 1000,
                        threshold = 0.999)
  expect_identical(v$configuration_error, list("COMPLIANCE_INFEASIBLE"))
})
