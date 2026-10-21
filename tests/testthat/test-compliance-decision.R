by_name <- function(suite) setNames(suite$cases, vapply(suite$cases, `[[`, character(1), "name"))

test_that("VERIFICATION refuses an infeasible design and SMOKE decides it by its own rule", {
  cases <- by_name(generate_compliance_decision_cases())
  v <- cases[["headline_995_n477_verification_refused"]]$expected
  expect_identical(v$configuration_error, list("COMPLIANCE_INFEASIBLE"))
  expect_true(is.na(v$verdict) && is.na(v$k_min) && is.na(v$decision_rule))
  s <- cases[["headline_995_n477_smoke_pass"]]$expected
  expect_false(s$pass_possible)
  expect_identical(s$decision_rule, "compliance/smoke-exact-binomial")
  expect_identical(s$verdict, "PASS")
  expect_length(s$configuration_error, 0)
  expect_identical(cases[["headline_995_n477_smoke_fail_below_required"]]$expected$verdict, "FAIL")
})

test_that("the SMOKE rule FAILs exactly on evidence of non-compliance", {
  for (case in generate_compliance_decision_cases()$cases) {
    e <- case$expected
    if (!identical(e$decision_rule, "compliance/smoke-exact-binomial")) next
    i <- case$inputs
    req <- e$required_pass
    expect_identical(req, smoke_binomial_required_pass(i$threshold, i$test_samples, i$alpha),
                     info = case$name)
    if (req > 0) {
      expect_lte(pbinom(req - 1, i$test_samples, i$threshold), i$alpha + 1e-12)
    }
    if (req < i$test_samples) {
      expect_gt(pbinom(req, i$test_samples, i$threshold), i$alpha - 1e-12)
    }
    expect_identical(e$verdict == "PASS", i$observed_successes >= req, info = case$name)
  }
  cases <- by_name(generate_compliance_decision_cases())
  expect_identical(cases[["smoke_p99_n100_perfect_pass"]]$expected$required_pass, 97L)
  expect_identical(cases[["smoke_p99_n30_two_misses_fail"]]$expected$verdict, "FAIL")
  expect_identical(cases[["smoke_p50_n1_fail_not_possible"]]$expected$required_pass, 0L)
  expect_identical(cases[["smoke_exact_boundary_p50_n5"]]$expected$required_pass, 1L)
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
    if (identical(e$decision_rule, "compliance/exact-binomial") && isTRUE(e$pass_possible)) {
      expect_identical(e$verdict == "PASS", e$clopper_pearson_lower >= case$inputs$threshold - 1e-12,
                       info = case$name)
    }
  }
})

test_that("under SMOKE, the Clopper-Pearson upper bound coincides with the reversed test", {
  for (case in generate_compliance_decision_cases()$cases) {
    e <- case$expected
    if (!identical(e$decision_rule, "compliance/smoke-exact-binomial")) next
    i <- case$inputs
    k <- i$observed_successes
    upper <- if (k == i$test_samples) 1 else qbeta(1 - i$alpha, k + 1, i$test_samples - k)
    expect_identical(e$verdict == "FAIL", upper <= i$threshold + 1e-12, info = case$name)
  }
})
