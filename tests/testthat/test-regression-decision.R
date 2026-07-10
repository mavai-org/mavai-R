test_that("the S3.4 worked example is reproduced exactly", {
  suite <- generate_regression_decision_cases()
  worked <- Filter(function(c) c$name == "worked_example_pass_at_cutoff", suite$cases)[[1]]
  expect_equal(worked$expected$cutoff_integer, 91L)
  # The companion's S3.4 prose prints both to six decimal places.
  expect_equal(round(worked$expected$threshold_real, 6), 0.902124)
  expect_equal(round(worked$expected$achieved_size, 6), 0.024986)
  expect_equal(worked$expected$displayed_rate, 0.91)
  expect_equal(worked$expected$verdict, "PASS")
})

test_that("the regression verdict flips exactly at the cutoff", {
  suite <- generate_regression_decision_cases()
  by_name <- setNames(suite$cases, vapply(suite$cases, `[[`, character(1), "name"))
  expect_equal(by_name[["worked_example_pass_at_cutoff"]]$expected$verdict, "PASS")
  expect_equal(by_name[["worked_example_fail_below_cutoff"]]$expected$verdict, "FAIL")
  expect_equal(by_name[["small_test_pass_at_cutoff"]]$expected$verdict, "PASS")
  expect_equal(by_name[["small_test_fail_below_cutoff"]]$expected$verdict, "FAIL")
  expect_equal(by_name[["perfect_baseline_pass_at_cutoff"]]$expected$verdict, "PASS")
  expect_equal(by_name[["perfect_baseline_fail_below_cutoff"]]$expected$verdict, "FAIL")
})

test_that("the conflation detector pair carries opposite verdicts", {
  suite <- generate_regression_decision_cases()
  by_name <- setNames(suite$cases, vapply(suite$cases, `[[`, character(1), "name"))
  regression <- by_name[["conflation_detector_regression_pass"]]
  compliance <- by_name[["conflation_detector_compliance_fail"]]
  expect_equal(regression$expected$verdict, "PASS")
  expect_equal(compliance$expected$verdict, "FAIL")
  # Same observation, same n, same confidence — the procedures differ.
  expect_equal(regression$inputs$observed_successes,
               compliance$inputs$observed_successes)
  expect_equal(regression$inputs$test_samples, compliance$inputs$test_samples)
})

test_that("every case names its procedure", {
  suite <- generate_regression_decision_cases()
  procedures <- vapply(suite$cases, `[[`, character(1), "procedure")
  expect_true(all(procedures %in% c("REGRESSION", "COMPLIANCE")))
  expect_true("COMPLIANCE" %in% procedures)
})
