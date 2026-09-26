by_name <- function(suite) setNames(suite$cases, vapply(suite$cases, `[[`, character(1), "name"))

test_that("VERIFICATION refuses an infeasible design and SMOKE says PASS is not possible", {
  cases <- by_name(generate_compliance_decision_cases())
  v <- cases[["headline_995_n477_verification_refused"]]$expected
  expect_identical(v$configuration_error, "COMPLIANCE_INFEASIBLE")
  expect_true(is.na(v$verdict) && is.na(v$k_min))
  s <- cases[["headline_995_n477_smoke_pass_not_possible"]]$expected
  expect_false(s$pass_possible)
  expect_identical(s$verdict, "FAIL")
  expect_true(is.na(s$configuration_error))
})

test_that("the verdict flips exactly at k_min", {
  cases <- by_name(generate_compliance_decision_cases())
  for (stem in c("p95_n150", "p99_n793", "alpha001_p90_n60")) {
    pass <- cases[[paste0(stem, "_pass_at_k_min")]]
    fail <- cases[[paste0(stem, "_fail_below_k_min")]]
    expect_identical(pass$expected$verdict, "PASS", info = stem)
    expect_identical(fail$expected$verdict, "FAIL", info = stem)
    expect_identical(pass$inputs$observed_successes, pass$expected$k_min, info = stem)
  }
  expect_identical(cases[["p999_n2995_zero_failures_pass"]]$expected$k_min, 2995L)
})

test_that("false compliance never exceeds alpha", {
  for (case in generate_compliance_decision_cases()$cases) {
    fc <- case$expected$false_compliance
    # At an exact boundary the double may sit a few ulps above alpha (§10.6 convention).
    if (!is.na(fc)) expect_lte(fc, case$inputs$alpha * (1 + 1e-9))
  }
})

test_that("Clopper-Pearson coincides with the exact test", {
  for (case in generate_compliance_decision_cases()$cases) {
    e <- case$expected
    if (!is.na(e$verdict) && isTRUE(e$pass_possible)) {
      expect_identical(e$verdict == "PASS", e$clopper_pearson_lower >= case$inputs$threshold - 1e-12,
                       info = case$name)
    }
  }
})
