by_name <- function(suite) setNames(suite$cases, vapply(suite$cases, `[[`, character(1), "name"))

test_that("compliance sizing reproduces the published stays-at figures", {
  cases <- by_name(generate_power_analysis_cases())
  expect_identical(cases[["compliance_p95_delta002_a05"]]$expected$required_samples, 694L)
  expect_identical(cases[["compliance_p95_delta001_a05"]]$expected$required_samples, 2869L)
  expect_identical(cases[["compliance_p99_delta002_a05_midway"]]$expected$alternative_kind, "MIDWAY")
  expect_equal(cases[["compliance_p99_delta002_a05_midway"]]$expected$alternative_rate, 0.995)
})

test_that("achieved power at the required size meets the target", {
  for (case in generate_power_analysis_cases()$cases) {
    if (case$approach == "compliance_sizing") {
      expect_gte(case$expected$achieved_power, case$inputs$power)
      expect_lte(case$expected$first_crossing, case$expected$required_samples)
    }
  }
})

test_that("smaller margins and higher targets need more samples", {
  a <- compliance_exact_sizing(0.95, 0.02, 0.05)$required_samples
  expect_gt(compliance_exact_sizing(0.95, 0.01, 0.05)$required_samples, a)
  expect_gt(compliance_exact_sizing(0.95, 0.02, 0.05, power = 0.95)$required_samples, a)
})

test_that("regression power and the minimum detectable degradation are consistent", {
  for (case in generate_power_analysis_cases()$cases) {
    i <- case$inputs
    if (case$approach == "regression_mdd" && !is.na(case$expected$minimum_detectable_degradation)) {
      pw <- fisher_power(i$baseline_trials, i$test_samples, i$alpha, i$baseline_rate,
                           case$expected$minimum_detectable_degradation)
      expect_equal(pw, i$power, tolerance = 1e-8, info = case$name)
    }
    if (case$approach == "regression_power") {
      expect_gt(case$expected$achieved_power, i$alpha)
    }
  }
})
