# The Statistical Companion 1.5.0 decision rules: canonical cases and
# structural properties.

test_that("regression/score-cc reproduces every canonical cutoff", {
  canonical <- list(
    list(951, 1000, 100, 0.05, 91L),
    list(1902, 2000, 100, 0.05, 91L),
    list(951, 1000, 1000, 0.05, 933L),
    list(9510, 10000, 100, 0.05, 92L),
    list(99, 100, 100, 0.05, 94L),
    list(100, 100, 100, 0.05, 96L),
    list(1000, 1000, 100, 0.05, 99L),
    list(0, 100, 50, 0.05, 0L),
    list(27, 30, 25, 0.05, 18L),
    list(951, 1000, 1000, 0.01, 925L)
  )
  for (r in canonical) {
    info <- paste(unlist(r[1:4]), collapse = " / ")
    expect_identical(score_cc_cutoff(r[[1]], r[[2]], r[[3]], r[[4]]), r[[5]], info = info)
    expect_identical(score_cc_cutoffs(r[[2]], r[[3]], r[[4]])[r[[1]] + 1L], r[[5]], info = info)
    expect_true(is.na(regression_configuration_error(r[[2]], r[[3]], r[[4]])), info = info)
  }
})

test_that("the v1.4.1 legacy cutoffs sit beside the canonical cases", {
  legacy <- list(
    list(951, 1000, 100, 0.05, 91L), list(1902, 2000, 100, 0.05, 91L),
    list(951, 1000, 1000, 0.05, 939L), list(9510, 10000, 100, 0.05, 91L),
    list(99, 100, 100, 0.05, 96L), list(100, 100, 100, 0.05, 94L),
    list(1000, 1000, 100, 0.05, 97L), list(0, 100, 50, 0.05, 0L),
    list(27, 30, 25, 0.05, 19L), list(951, 1000, 1000, 0.01, 933L),
    list(95, 100, 200, 0.05, 184L))
  for (r in legacy) {
    expect_identical(legacy_wilson_reference_cutoff(r[[1]], r[[2]], r[[3]], r[[4]]), r[[5]],
                     info = paste(unlist(r[1:4]), collapse = " / "))
  }
})

test_that("the canonical refusals carry their configuration errors", {
  expect_identical(regression_configuration_error(100, 200, 0.05), "TEST_LARGER_THAN_BASELINE")
  expect_identical(regression_configuration_error(1000, 25, 0.01), "OUTSIDE_CALIBRATION_TOLERANCE")
  # The canonical worst case on the 110-point grid of the specification.
  ps <- seq(0.50, 0.9999, length.out = 110)
  sz <- score_cc_size(1000, 25, 0.01, ps)
  expect_equal(round(100 * max(sz), 3), 1.313)
  expect_equal(round(ps[which.max(sz)], 3), 0.977)
  expect_identical(regression_configuration_error(1000, 1000, 0.05), NA_character_)
})

test_that("the perfect-baseline discontinuity is gone: c is monotone in K_b", {
  for (cfg in list(c(100, 100, 0.05), c(30, 25, 0.05), c(1000, 100, 0.01), c(10, 10, 0.10))) {
    cut <- score_cc_cutoffs(cfg[1], cfg[2], cfg[3], verify_interval = TRUE)
    expect_true(all(diff(cut) >= 0))
    expect_identical(cut[1], 0L)
  }
  expect_true(score_cc_cutoff(99, 100, 100, 0.05) < score_cc_cutoff(100, 100, 100, 0.05))
})

test_that("the literal scan and the bisection agree on every K_b", {
  for (cfg in list(c(10, 1, 0.001), c(17, 9, 0.01), c(50, 50, 0.05), c(300, 40, 0.10),
                   c(1000, 999, 0.001))) {
    expect_identical(score_cc_cutoff(0:cfg[1], cfg[1], cfg[2], cfg[3]),
                     score_cc_cutoffs(cfg[1], cfg[2], cfg[3]))
  }
})

test_that("z is zero where the pooled variance vanishes", {
  expect_identical(score_cc_z(0, 0, 100, 50), 0)
  expect_identical(score_cc_z(50, 100, 100, 50), 0)
})

test_that("unconditional size and power are exact sums", {
  cut <- score_cc_cutoffs(30, 25, 0.05)
  brute <- 0
  for (kb in 0:30) for (kt in 0:25) {
    if (kt < cut[kb + 1]) brute <- brute + dbinom(kb, 30, 0.9) * dbinom(kt, 25, 0.85)
  }
  expect_equal(score_cc_fail_probability(cut, 30, 25, 0.9, 0.85), brute, tolerance = 1e-14)
  expect_equal(score_cc_power(30, 25, 0.05, 0.9, 0.05), brute, tolerance = 1e-14)
  # The canonical size figures of the specification.
  expect_equal(round(100 * score_cc_size(1000, 100, 0.05, 0.951), 2), 3.86)
  expect_equal(round(100 * score_cc_size(1000, 1000, 0.01, 0.951), 2), 0.74)
})

test_that("the minimum detectable degradation reaches the target power exactly", {
  d <- score_cc_minimum_detectable_degradation(1000, 100, 0.05, 0.95)
  expect_equal(score_cc_power(1000, 100, 0.05, 0.95, d), 0.80, tolerance = 1e-8)
  expect_lt(score_cc_power(1000, 100, 0.05, 0.95, d - 1e-6), 0.80)
  expect_true(is.na(score_cc_minimum_detectable_degradation(10, 1, 0.001, 0.5)))
})

test_that("compliance/exact-binomial reproduces every canonical case", {
  expect_identical(exact_binomial_k_min(0.995, 477, 0.05), NA_integer_)
  expect_identical(exact_binomial_min_feasible_n(0.995, 0.05), 598L)
  expect_identical(compliance_configuration_error(0.995, 477, 0.05, "VERIFICATION"), "COMPLIANCE_INFEASIBLE")
  expect_identical(compliance_configuration_error(0.995, 477, 0.05, "SMOKE"), NA_character_)
  rows <- list(list(0.95, 150, 148L, 1.815, 59L), list(0.99, 793, 790L, 4.369, 299L),
               list(0.999, 2995, 2995L, 4.996, 2995L))
  for (r in rows) {
    k <- exact_binomial_k_min(r[[1]], r[[2]], 0.05)
    expect_identical(k, r[[3]])
    expect_equal(round(100 * pbinom(k - 1, r[[2]], r[[1]], lower.tail = FALSE), 3), r[[4]])
    expect_identical(exact_binomial_min_feasible_n(r[[1]], 0.05), r[[5]])
  }
  expect_identical(exact_binomial_k_min(0.999, 2994, 0.05), NA_integer_)
  expect_identical(compliance_configuration_error(0.999, 2994, 0.05, "VERIFICATION"), "COMPLIANCE_INFEASIBLE")
})

test_that("k_min is the definition, at every n and in the vectorised search", {
  for (pr in c(0.5, 0.9, 0.99)) for (a in c(0.001, 0.05)) {
    ns <- c(1:60, 100, 377, 1000)
    lit <- vapply(ns, function(n) exact_binomial_k_min(pr, n, a), integer(1))
    expect_identical(exact_binomial_k_min_vec(ns, pr, a), lit)
    n_min <- exact_binomial_min_feasible_n(pr, a)
    expect_identical(n_min, as.integer(which(!is.na(exact_binomial_k_min_vec(1:5000, pr, a)))[1]))
  }
})

test_that("exact sizing is the n from which power stays at target", {
  s <- compliance_exact_sizing(0.95, 0.02, 0.05)
  expect_identical(s$required_samples, 694L)
  expect_identical(compliance_exact_sizing(0.95, 0.01, 0.05)$required_samples, 2869L)
  pw <- vapply(s$required_samples:(s$required_samples + 300), function(n)
    exact_binomial_pass_probability(0.95, n, 0.05, 0.97), numeric(1))
  expect_true(all(pw >= 0.80))
  expect_lt(exact_binomial_pass_probability(0.95, s$required_samples - 1L, 0.05, 0.97), 0.80)
  expect_true(s$first_crossing <= s$required_samples)
  expect_identical(compliance_sizing_alternative(0.99, 0.02),
                   list(rate = 0.995, kind = "MIDWAY"))
})

test_that("latency/precedence reproduces every canonical case", {
  rows <- list(list(935, 192, 0.95, 911L, 4.95), list(935, 935, 0.95, 904L, 4.11),
               list(200, 200, 0.90, 189L, 4.79), list(1000, 15, 0.95, 998L, 4.37))
  for (r in rows) {
    k <- latency_precedence_rank(r[[1]], r[[2]], r[[3]], 0.05)
    expect_identical(k, r[[4]])
    expect_equal(round(100 * latency_breach_probability(r[[1]], k, r[[2]], r[[3]]), 2), r[[5]])
    expect_identical(latency_precedence_rank_fast(r[[1]], r[[2]], r[[3]], 0.05), k)
  }
  expect_identical(latency_precedence_rank(100, 15, 0.95, 0.05), NA_integer_)
  expect_identical(latency_precedence_rank(300, 100, 0.99, 0.05), NA_integer_)
  # v1.4.1 beside it: ranks 900, 900, 188, 962, 99 (saturation unflagged), 300.
  expect_identical(legacy_order_statistic_rank(935, 0.95, 0.05)$rank, 900L)
  expect_identical(legacy_order_statistic_rank(1000, 0.95, 0.05)$rank, 962L)
  expect_identical(legacy_order_statistic_rank(100, 0.95, 0.05)$rank, 99L)
})

test_that("the breach sum agrees with a numerical integration", {
  for (cfg in list(c(935, 911, 192, 0.95), c(200, 150, 50, 0.5), c(50, 49, 10, 0.9))) {
    r <- latency_test_rank(cfg[3], cfg[4])
    f <- function(u) pbinom(r - 1, cfg[3], u) * dbeta(u, cfg[2], cfg[1] - cfg[2] + 1)
    integ <- integrate(f, 0, 1, rel.tol = 1e-12, subdivisions = 2000L)$value
    expect_equal(latency_breach_probability(cfg[1], cfg[2], cfg[3], cfg[4]), integ, tolerance = 1e-8)
  }
})

test_that("the test rank is the nearest rank in integer arithmetic", {
  expect_identical(latency_test_rank(192, 0.95), 183L)
  expect_identical(latency_test_rank(100, 0.99), 99L)
  expect_identical(latency_test_rank(20, 0.95), 19L)
  expect_identical(latency_test_rank(1, 0.5), 1L)
  expect_error(latency_test_rank(10, 0.75), "p50, p90, p95, p99")
})

test_that("the calibration-tolerance rule is defined at the certified alphas only", {
  expect_false(outside_calibration_tolerance(10000, 100, 0.05))
  expect_false(outside_calibration_tolerance(10000, 100, 0.10))
  expect_true(outside_calibration_tolerance(1000, 80, 0.01))
  expect_false(outside_calibration_tolerance(1000, 81, 0.01))
  expect_error(outside_calibration_tolerance(1000, 80, 0.02), "not certified")
})
