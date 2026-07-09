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

test_that("latency_bound_existence_min_samples matches companion 12.5.2.1", {
  # At alpha = 0.05 (companion's published table).
  expect_equal(latency_bound_existence_min_samples(0.50, 0.95), 5L)
  expect_equal(latency_bound_existence_min_samples(0.90, 0.95), 29L)
  expect_equal(latency_bound_existence_min_samples(0.95, 0.95), 59L)
  expect_equal(latency_bound_existence_min_samples(0.99, 0.95), 299L)
  # Existence condition: p^n <= alpha holds at the minimum, fails below it.
  for (p in c(0.50, 0.90, 0.95, 0.99)) {
    n_min <- latency_bound_existence_min_samples(p, 0.95)
    expect_lte(p^n_min, 0.05)
    expect_gt(p^(n_min - 1L), 0.05)
  }
})

test_that("percentile minimums suite publishes both gates exactly", {
  suite <- generate_latency_percentile_minimums_cases()
  expect_equal(suite$suite, "latency_percentile_minimums")
  expect_equal(suite$tolerance, 0)
  emission <- Filter(function(c) c$approach == "emission_non_degeneracy", suite$cases)
  expect_equal(
    vapply(emission, function(c) c$expected$minimum_contributing_samples, integer(1)),
    c(5L, 10L, 20L, 100L)
  )
  existence <- Filter(function(c) c$approach == "bound_existence", suite$cases)
  expect_length(existence, 8L)  # four levels at two confidence levels
  c95 <- Filter(function(c) c$inputs$confidence == 0.95, existence)
  expect_equal(
    vapply(c95, function(c) c$expected$minimum_baseline_samples, integer(1)),
    c(5L, 29L, 59L, 299L)
  )
})
