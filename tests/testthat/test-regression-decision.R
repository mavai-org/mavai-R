by_name <- function(suite) setNames(suite$cases, vapply(suite$cases, `[[`, character(1), "name"))

test_that("the §3.4 rate is reproduced exactly under regression/fisher", {
  worked <- by_name(generate_regression_decision_cases())[["worked_example_pass_at_cutoff"]]
  expect_identical(worked$expected$cutoff_integer, 91L)
  expect_equal(worked$expected$threshold_real, 0.91)
  expect_equal(worked$expected$displayed_rate, 0.91)
  expect_lte(worked$expected$achieved_size, 0.05)
  expect_identical(worked$expected$verdict, "PASS")
  expect_true(is.na(worked$expected$configuration_error))
})

test_that("the regression verdict flips exactly at the cutoff", {
  cases <- by_name(generate_regression_decision_cases())
  for (stem in c("worked_example", "small_test", "near_perfect_baseline", "perfect_baseline",
                 "boundary_equal_sizes", "alpha001")) {
    pass <- cases[[paste0(stem, "_pass_at_cutoff")]]
    fail <- cases[[paste0(stem, "_fail_below_cutoff")]]
    expect_identical(pass$expected$verdict, "PASS", info = stem)
    expect_identical(fail$expected$verdict, "FAIL", info = stem)
    expect_identical(pass$inputs$observed_successes, pass$expected$cutoff_integer, info = stem)
    expect_identical(fail$inputs$observed_successes, fail$expected$cutoff_integer - 1L, info = stem)
  }
})

test_that("refused configurations carry a code and no verdict", {
  cases <- by_name(generate_regression_decision_cases())
  r1 <- cases[["refused_test_larger_than_baseline"]]$expected
  expect_identical(r1$configuration_error, "TEST_LARGER_THAN_BASELINE")
  expect_true(is.na(r1$verdict) && is.na(r1$cutoff_integer))
  r2 <- cases[["small_test_large_baseline_pass_at_cutoff"]]$expected
  expect_true(is.na(r2$configuration_error))
  expect_identical(r2$verdict, "PASS")
})

test_that("no published case has a test larger than its baseline without refusing it", {
  for (suite in list(generate_regression_decision_cases(), generate_threshold_derivation_cases())) {
    for (case in suite$cases) {
      i <- case$inputs
      if (i$test_samples > i$baseline_trials) {
        expect_identical(case$expected$configuration_error, "TEST_LARGER_THAN_BASELINE", info = case$name)
      }
    }
  }
})

test_that("the derivation suite carries every canonical cutoff", {
  cases <- by_name(generate_threshold_derivation_cases())
  expect_identical(cases[["boundary_equal_sizes_951_of_1000_test1000_a05"]]$expected$cutoff_integer, 933L)
  expect_identical(cases[["near_perfect_99_of_100_test100_a05"]]$expected$cutoff_integer, 94L)
  expect_identical(cases[["perfect_100_of_100_test100_a05"]]$expected$cutoff_integer, 96L)
  expect_identical(cases[["perfect_large_1000_of_1000_test100_a05"]]$expected$cutoff_integer, 99L)
  expect_identical(cases[["zero_baseline_0_of_100_test50_a05"]]$expected$cutoff_integer, 0L)
  expect_identical(cases[["small_baseline_27_of_30_test25_a05"]]$expected$cutoff_integer, 18L)
  expect_identical(cases[["alpha001_951_of_1000_test1000"]]$expected$cutoff_integer, 925L)
  expect_identical(cases[["large_baseline_small_test_9510_of_10000_test100_a05"]]$expected$cutoff_integer, 91L)
  expect_identical(cases[["ordinary_951_of_1000_test100_a05"]]$expected$cutoff_integer, 91L)
  expect_identical(cases[["ordinary_larger_baseline_1902_of_2000_test100_a05"]]$expected$cutoff_integer, 91L)
  expect_identical(cases[["refused_test_larger_than_baseline_95_of_100_test200"]]$expected$configuration_error,
                   "TEST_LARGER_THAN_BASELINE")
  tf <- cases[["tf_951_of_1000_test100_cutoff91"]]$expected
  expect_lte(tf$implied_alpha, 0.05)
  expect_true(tf$is_sound)
  expect_false(cases[["tf_951_of_1000_test100_cutoff94"]]$expected$is_sound)
  expect_true(is.na(cases[["perfect_100_of_100_test100_a05"]]$expected$achieved_size))
})

test_that("the conflation detector pair carries opposite verdicts across the two rules", {
  regression <- by_name(generate_regression_decision_cases())[["conflation_detector_regression_pass"]]
  compliance <- by_name(generate_compliance_decision_cases())[["conflation_detector_compliance_fail"]]
  expect_identical(regression$expected$verdict, "PASS")
  expect_identical(compliance$expected$verdict, "FAIL")
  expect_identical(regression$inputs$observed_successes, compliance$inputs$observed_successes)
  expect_identical(regression$inputs$test_samples, compliance$inputs$test_samples)
  expect_equal(compliance$inputs$threshold, regression$expected$displayed_rate)
})
