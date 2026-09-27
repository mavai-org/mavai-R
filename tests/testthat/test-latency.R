test_that("nearest_rank_percentile computes correct index for worked example", {
  # Section 12.2.2: n=200, p50 should use index 99 (100th order statistic)
  set.seed(42)
  latencies <- sort(round(rlnorm(200, meanlog = log(200), sdlog = 0.4)))

  p50 <- nearest_rank_percentile(latencies, 0.50)
  expect_equal(p50, latencies[100])

  p90 <- nearest_rank_percentile(latencies, 0.90)
  expect_equal(p90, latencies[180])

  p95 <- nearest_rank_percentile(latencies, 0.95)
  expect_equal(p95, latencies[190])

  p99 <- nearest_rank_percentile(latencies, 0.99)
  expect_equal(p99, latencies[198])
})

test_that("nearest_rank_percentile handles single observation", {
  result <- nearest_rank_percentile(c(250), 0.99)
  expect_equal(result, 250)
})

test_that("nearest_rank_percentile handles identical values", {
  result <- nearest_rank_percentile(rep(150, 10), 0.95)
  expect_equal(result, 150)
})

test_that("nearest_rank_percentile sorts unsorted input", {
  unsorted <- c(300, 100, 200, 400, 500)
  sorted <- c(100, 200, 300, 400, 500)

  expect_equal(
    nearest_rank_percentile(unsorted, 0.50),
    nearest_rank_percentile(sorted, 0.50)
  )
})

test_that("nearest_rank_percentile: higher percentiles >= lower percentiles", {
  latencies <- c(100, 120, 140, 160, 180, 200, 250, 300, 400, 500,
                 110, 130, 150, 170, 190, 220, 260, 350, 450, 600)

  p50 <- nearest_rank_percentile(latencies, 0.50)
  p90 <- nearest_rank_percentile(latencies, 0.90)
  p95 <- nearest_rank_percentile(latencies, 0.95)
  p99 <- nearest_rank_percentile(latencies, 0.99)

  expect_true(p50 <= p90)
  expect_true(p90 <= p95)
  expect_true(p95 <= p99)
})

test_that("nearest_rank_percentile: p=1 returns maximum", {
  latencies <- c(100, 200, 300, 400, 500)
  expect_equal(nearest_rank_percentile(latencies, 1.0), 500)
})

test_that("latency_summary reports mean and max only", {
  latencies <- c(100, 200, 300, 400, 500)
  result <- latency_summary(latencies)

  expect_equal(result$mean, 300)
  expect_equal(result$max, 500)
  expect_false("sd" %in% names(result))
})

test_that("latency_threshold_derive: worked example from Section 12.4.5", {
  # Baseline: n_s=935, p=0.95, confidence=0.95
  # qbinom(0.95, 935, 0.95) = 899, so k_0.95 = 900.
  # Threshold is the 900th order statistic of the baseline.
  set.seed(42)
  baseline <- sort(round(rlnorm(935, meanlog = log(500), sdlog = 0.3)))

  result <- latency_threshold_derive(baseline, p = 0.95, confidence = 0.95)

  expect_equal(result$rank, 900L)
  expect_equal(result$threshold, baseline[900])
  expect_equal(result$n, 935L)
})

test_that("latency_threshold_derive: rank is floored at nearest-rank index", {
  # For any valid baseline, the upper-bound rank must be >= the point-estimate
  # rank ceil(p * n_s). This is the non-parametric analogue of the max(Q, ...)
  # guard in the old formula.
  baseline <- sort(round(rlnorm(100, meanlog = log(200), sdlog = 0.4)))

  result <- latency_threshold_derive(baseline, p = 0.95, confidence = 0.95)
  point_estimate_rank <- ceiling(0.95 * 100)

  expect_gte(result$rank, point_estimate_rank)
  expect_gte(result$threshold, nearest_rank_percentile(baseline, 0.95))
})

test_that("latency_threshold_derive: higher confidence yields higher threshold", {
  baseline <- sort(round(rlnorm(500, meanlog = log(300), sdlog = 0.4)))

  t_90 <- latency_threshold_derive(baseline, p = 0.95, confidence = 0.90)
  t_95 <- latency_threshold_derive(baseline, p = 0.95, confidence = 0.95)
  t_99 <- latency_threshold_derive(baseline, p = 0.95, confidence = 0.99)

  expect_lte(t_90$threshold, t_95$threshold)
  expect_lte(t_95$threshold, t_99$threshold)
})

test_that("latency_threshold_derive: higher percentile yields higher threshold", {
  baseline <- sort(round(rlnorm(500, meanlog = log(300), sdlog = 0.4)))

  t_50 <- latency_threshold_derive(baseline, p = 0.50, confidence = 0.95)
  t_95 <- latency_threshold_derive(baseline, p = 0.95, confidence = 0.95)
  t_99 <- latency_threshold_derive(baseline, p = 0.99, confidence = 0.95)

  expect_lte(t_50$threshold, t_95$threshold)
  expect_lte(t_95$threshold, t_99$threshold)
})

test_that("latency_threshold_derive: rank saturates at n_s when infeasible", {
  # Small n_s relative to p: bound cannot be resolved, rank saturates at n_s
  # and threshold = max. The feasibility gate should catch this upstream but
  # the function must not crash.
  baseline <- sort(c(100, 120, 140, 160, 180, 200, 250, 300, 400, 500))

  result <- latency_threshold_derive(baseline, p = 0.99, confidence = 0.95)

  expect_equal(result$rank, 10L)
  expect_equal(result$threshold, 500)
})

test_that("latency_threshold_binomial_rank: flags saturation when k_raw > n", {
  # n_s = 10, p = 0.99, confidence = 0.95: the binomial-derived rank
  # exceeds 10, so the construction's existence condition is violated.
  result <- latency_threshold_binomial_rank(n = 10L, p = 0.99, confidence = 0.95)
  expect_true(result$saturated)
  expect_gt(result$k_raw, 10L)
})

test_that("latency_threshold_binomial_rank: does not flag saturation when k_raw <= n", {
  # n_s = 935, p = 0.99: well within the existence regime.
  result <- latency_threshold_binomial_rank(n = 935L, p = 0.99, confidence = 0.95)
  expect_false(result$saturated)
  expect_lte(result$k_raw, 935L)
})

test_that("latency_threshold_derive: identical values collapse to common value", {
  baseline <- rep(150, 100)

  result <- latency_threshold_derive(baseline, p = 0.95, confidence = 0.95)

  expect_equal(result$threshold, 150)
})

test_that("latency_min_samples returns correct minimums", {
  expect_equal(latency_min_samples(0.50), 5L)
  expect_equal(latency_min_samples(0.90), 10L)
  expect_equal(latency_min_samples(0.95), 20L)
  expect_equal(latency_min_samples(0.99), 100L)
})

test_that("the Wilks minimum is the legacy existence condition, not the precedence one", {
  expect_equal(latency_bound_existence_min_samples(0.95, 0.95), 59L)
  # Not sufficient: 100 latencies meet the p95 Wilks minimum, yet no rank exists for a test of 15.
  expect_true(latency_precedence_exists(100, 15, 0.95, 0.05)$saturated)
  # Not necessary: 200 latencies fall short of the p99 Wilks minimum (299), yet a rank exists for a test of 10.
  expect_lt(200L, latency_bound_existence_min_samples(0.99, 0.95))
  expect_false(latency_precedence_exists(200, 10, 0.99, 0.05)$saturated)
})

test_that("precedence existence is decided by the top rank", {
  for (cfg in list(c(85, 25, 0.95), c(86, 25, 0.95), c(949, 50, 0.99), c(33, 10, 0.90))) {
    top <- latency_breach_probability(cfg[1], cfg[1], cfg[2], cfg[3]) <= 0.05
    expect_identical(!latency_precedence_exists(cfg[1], cfg[2], cfg[3], 0.05)$saturated, top)
  }
})

test_that("percentile minimums suite publishes the emission minimums and the existence gate", {
  suite <- generate_latency_percentile_minimums_cases()
  expect_equal(suite$suite, "latency_percentile_minimums")
  expect_equal(suite$tolerance, 0)
  emission <- Filter(function(c) c$approach == "emission_non_degeneracy", suite$cases)
  expect_equal(
    vapply(emission, function(c) c$expected$minimum_contributing_samples, integer(1)),
    c(5L, 10L, 20L, 100L)
  )
  existence <- Filter(function(c) c$approach == "precedence_existence", suite$cases)
  by_name <- setNames(existence, vapply(existence, `[[`, character(1), "name"))
  expect_true(by_name[["p95_100_test15_saturated"]]$expected$saturated)
  expect_identical(by_name[["p95_1000_test15"]]$expected$rank, 998L)
  expect_identical(by_name[["p95_935_test192"]]$expected$rank, 911L)
  for (stem in c("p90_%d_test10", "p95_%d_test25", "p99_%d_test50", "p99_%d_test160", "p95_%d_test10", "p99_%d_test25")) {
    sat <- Filter(function(c) grepl(sub("%d", "[0-9]+", stem), c$name) && grepl("saturated", c$name), existence)
    first <- Filter(function(c) grepl(sub("%d", "[0-9]+", stem), c$name) && grepl("first_rank", c$name), existence)
    expect_true(sat[[1]]$expected$saturated)
    expect_false(first[[1]]$expected$saturated)
    expect_identical(first[[1]]$inputs$baseline_trials, sat[[1]]$inputs$baseline_trials + 1L)
  }
  expect_false(any(vapply(existence, function(c) c$inputs$test_samples > c$inputs$baseline_trials, logical(1))))
})


test_that("the pre-run check warns and plans; saturation is decided on the actual count", {
  pl <- latency_precedence_planning(400, 200, 0.80, 0.99, 0.05)
  expect_identical(pl$expected_test_samples, 160L)
  expect_true(pl$warning)
  expect_identical(pl$minimum_baseline_trials, 554L)
  ok <- latency_precedence_planning(554, 200, 0.80, 0.99, 0.05)
  expect_false(ok$warning)
  # The expectation is not a lower bound: 161 successful latencies saturate.
  expect_true(latency_precedence_exists(554, 161, 0.99, 0.05)$saturated)
})

test_that("TEST_LARGER_THAN_BASELINE is judged on the sampling for latency, never on latency counts", {
  cases <- generate_latency_threshold_cases()$cases
  get <- function(n) Filter(function(c) c$name == n, cases)[[1]]
  r <- get("refused_planned_test_larger_than_baseline")
  expect_identical(r$expected$configuration_error, list("TEST_LARGER_THAN_BASELINE"))
  expect_true(is.na(r$expected$rank))
  a <- get("latency_counts_not_compared_p50")
  expect_length(a$expected$configuration_error, 0)
  expect_gt(a$inputs$test_samples, length(a$inputs$baseline_latencies))
  for (case in cases) {
    refused <- length(case$expected$configuration_error) > 0
    expect_identical(refused, case$inputs$planned_samples > case$inputs$baseline_samples, info = case$name)
  }
})

test_that("non-degeneracy warns before the run and decides after it", {
  pl <- latency_nondegeneracy_planning(0.99, 110, 0.80)
  expect_identical(pl$expected_test_samples, 88L)
  expect_true(pl$warning)
  expect_identical(pl$planned_samples_needed, 125L)
  expect_false(latency_nondegeneracy_planning(0.99, 125, 0.80)$warning)
  expect_identical(latency_nondegeneracy_decision(0.99, 99, "VERIFICATION", TRUE)$outcome, "INCONCLUSIVE")
  expect_identical(latency_nondegeneracy_decision(0.99, 100, "VERIFICATION", TRUE)$outcome, "DECIDED")
  expect_identical(latency_nondegeneracy_decision(0.99, 40, "SMOKE", TRUE)$outcome, "INDICATIVE")
  expect_identical(latency_nondegeneracy_decision(0.95, 19, "VERIFICATION", FALSE)$outcome, "INDICATIVE")
})

test_that("the non-degeneracy gate branches by threshold source", {
  e <- latency_nondegeneracy_decision(0.50, 4, "VERIFICATION", TRUE, "explicit")
  expect_false(e$applies)
  expect_true(e$degenerate)
  expect_identical(e$outcome, "DECIDED")
  expect_identical(latency_nondegeneracy_decision(0.50, 4, "VERIFICATION", FALSE, "explicit")$outcome, "INDICATIVE")
  expect_identical(latency_nondegeneracy_decision(0.50, 4, "VERIFICATION", TRUE, "baseline-derived")$outcome, "INCONCLUSIVE")
})
