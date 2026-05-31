#' Empirical percentile using nearest-rank method
#'
#' Computes the empirical percentile from a vector of latency observations
#' using the nearest-rank (ceiling) method. This is the reference
#' implementation against which all mavai framework implementations must
#' conform.
#'
#' @param latencies Numeric vector. Observed latencies (need not be sorted).
#' @param p Numeric. Percentile level in (0, 1].
#' @return Numeric. The percentile value.
#' @export
nearest_rank_percentile <- function(latencies, p) {
  sorted <- sort(latencies)
  n <- length(sorted)
  idx <- ceiling(p * n) - 1L
  idx <- max(0L, min(idx, n - 1L))
  sorted[idx + 1L]
}

#' Latency summary statistics
#'
#' Computes mean and maximum from a vector of successful-response latencies.
#' The sample standard deviation is deliberately omitted: the threshold
#' derivation in latency_threshold_derive() is non-parametric and does not
#' use it, and reporting s for a distribution that is not well-characterised
#' by its second moment would invite misuse.
#'
#' @param latencies Numeric vector. Observed latencies.
#' @return A list with mean and max.
#' @export
latency_summary <- function(latencies) {
  list(
    mean = mean(latencies),
    max = max(latencies)
  )
}

#' Derive latency threshold from baseline (binomial order-statistic upper bound)
#'
#' Computes a one-sided upper confidence bound on the baseline percentile
#' Q(p) using the exact binomial sampling distribution of order-statistic
#' ranks. The threshold is the k-th order statistic of the baseline, where
#' k is the smallest rank such that P(Bin(n_s, p) >= k) <= alpha.
#'
#' This construction is exact for any continuous underlying latency
#' distribution, requires no parametric assumption, and yields an integer-ms
#' threshold by construction (it is an observed latency).
#'
#' @param baseline_latencies Numeric vector. Successful-response latencies
#'   observed in the baseline experiment.
#' @param p Numeric. Percentile level (e.g. 0.95).
#' @param confidence Numeric. One-sided confidence level (e.g. 0.95).
#' @return A list with rank (k), threshold (t_{(k)}), baseline_percentile
#'   (Q(p) point estimate), and n (baseline sample count). For the
#'   unclamped binomial-derived rank and the saturation flag (companion
#'   §12.4.2), see `latency_threshold_binomial_rank()`.
#' @export
latency_threshold_derive <- function(baseline_latencies, p, confidence) {
  sorted <- sort(baseline_latencies)
  n <- length(sorted)
  alpha <- 1 - confidence

  # Exact binomial upper-bound rank.
  k <- qbinom(1 - alpha, size = n, prob = p) + 1L

  # Clamp: never below the nearest-rank point estimate, never above n.
  point_rank <- as.integer(ceiling(p * n))
  k <- max(point_rank, min(k, n))

  list(
    rank = as.integer(k),
    threshold = sorted[k],
    baseline_percentile = nearest_rank_percentile(sorted, p),
    n = as.integer(n)
  )
}

#' Unclamped binomial-derived rank, with saturation flag
#'
#' Companion §12.4.2 forbids silently clamping the binomial-derived rank
#' k_raw = qbinom(1 - alpha, n, p) + 1 to n and presenting t_{(n)} as an
#' exact upper bound on Q(p). When k_raw > n the construction's existence
#' condition is violated and the published threshold can only be an
#' advisory value at the saturation ceiling. This helper exposes both
#' k_raw and the saturation flag so the published reference data can
#' make the discipline observable to consumers.
#'
#' @param n Integer. Baseline sample count.
#' @param p Numeric. Percentile level (e.g. 0.99).
#' @param confidence Numeric. One-sided confidence level (e.g. 0.95).
#' @return A list with k_raw (integer, unclamped) and saturated (logical,
#'   TRUE iff k_raw > n).
#' @export
latency_threshold_binomial_rank <- function(n, p, confidence) {
  alpha <- 1 - confidence
  k_raw <- as.integer(qbinom(1 - alpha, size = as.integer(n), prob = p) + 1L)
  list(
    k_raw = k_raw,
    saturated = k_raw > as.integer(n)
  )
}

#' Minimum sample size for percentile reliability
#'
#' Returns the minimum number of successful samples required for a
#' percentile estimate to be non-degenerate.
#'
#' @param p Numeric. Percentile level (e.g. 0.99).
#' @return Integer. Minimum sample count.
#' @export
latency_min_samples <- function(p) {
  if (p <= 0.50) return(5L)
  if (p <= 0.90) return(10L)
  if (p <= 0.95) return(20L)
  if (p <= 0.99) return(100L)
  100L
}

#' Generate latency percentile reference cases
#'
#' @return A list suitable for JSON serialisation.
#' @export
generate_latency_percentile_cases <- function() {
  typical_latencies <- c(
    120, 125, 130, 132, 135, 138, 140, 142, 145, 148,
    150, 152, 155, 158, 160, 162, 165, 170, 175, 180,
    185, 190, 195, 200, 210, 220, 240, 260, 300, 450
  )

  uniform_latencies <- c(
    100, 110, 120, 130, 140, 150, 160, 170, 180, 190,
    200, 210, 220, 230, 240, 250, 260, 270, 280, 290
  )

  heavy_tail_latencies <- c(
    100, 105, 108, 110, 112, 115, 118, 120, 122, 125,
    128, 130, 132, 135, 138, 140, 145, 150, 155, 160,
    165, 170, 180, 200, 250, 300, 500, 800, 1500, 3000
  )

  minimal_latencies <- c(100, 200, 300, 400, 500)
  single_latency <- c(250)
  identical_latencies <- rep(150, 10)

  set.seed(42)
  large_sample <- sort(round(rlnorm(200, meanlog = log(200), sdlog = 0.4)))

  cases <- list(
    list(name = "typical_skewed_p50",
         inputs = list(latencies = typical_latencies, percentile = 0.50),
         expected = list(value = nearest_rank_percentile(typical_latencies, 0.50))),
    list(name = "typical_skewed_p90",
         inputs = list(latencies = typical_latencies, percentile = 0.90),
         expected = list(value = nearest_rank_percentile(typical_latencies, 0.90))),
    list(name = "typical_skewed_p95",
         inputs = list(latencies = typical_latencies, percentile = 0.95),
         expected = list(value = nearest_rank_percentile(typical_latencies, 0.95))),
    list(name = "typical_skewed_p99",
         inputs = list(latencies = typical_latencies, percentile = 0.99),
         expected = list(value = nearest_rank_percentile(typical_latencies, 0.99))),
    list(name = "uniform_p50",
         inputs = list(latencies = uniform_latencies, percentile = 0.50),
         expected = list(value = nearest_rank_percentile(uniform_latencies, 0.50))),
    list(name = "uniform_p95",
         inputs = list(latencies = uniform_latencies, percentile = 0.95),
         expected = list(value = nearest_rank_percentile(uniform_latencies, 0.95))),
    list(name = "heavy_tail_p90",
         inputs = list(latencies = heavy_tail_latencies, percentile = 0.90),
         expected = list(value = nearest_rank_percentile(heavy_tail_latencies, 0.90))),
    list(name = "heavy_tail_p95",
         inputs = list(latencies = heavy_tail_latencies, percentile = 0.95),
         expected = list(value = nearest_rank_percentile(heavy_tail_latencies, 0.95))),
    list(name = "heavy_tail_p99",
         inputs = list(latencies = heavy_tail_latencies, percentile = 0.99),
         expected = list(value = nearest_rank_percentile(heavy_tail_latencies, 0.99))),
    list(name = "minimal_sample_p50",
         inputs = list(latencies = minimal_latencies, percentile = 0.50),
         expected = list(value = nearest_rank_percentile(minimal_latencies, 0.50))),
    list(name = "single_observation_p50",
         inputs = list(latencies = single_latency, percentile = 0.50),
         expected = list(value = nearest_rank_percentile(single_latency, 0.50))),
    list(name = "single_observation_p99",
         inputs = list(latencies = single_latency, percentile = 0.99),
         expected = list(value = nearest_rank_percentile(single_latency, 0.99))),
    list(name = "identical_values_p95",
         inputs = list(latencies = identical_latencies, percentile = 0.95),
         expected = list(value = nearest_rank_percentile(identical_latencies, 0.95))),
    list(name = "large_sample_p50",
         inputs = list(latencies = large_sample, percentile = 0.50),
         expected = list(value = nearest_rank_percentile(large_sample, 0.50))),
    list(name = "large_sample_p90",
         inputs = list(latencies = large_sample, percentile = 0.90),
         expected = list(value = nearest_rank_percentile(large_sample, 0.90))),
    list(name = "large_sample_p95",
         inputs = list(latencies = large_sample, percentile = 0.95),
         expected = list(value = nearest_rank_percentile(large_sample, 0.95))),
    list(name = "large_sample_p99",
         inputs = list(latencies = large_sample, percentile = 0.99),
         expected = list(value = nearest_rank_percentile(large_sample, 0.99)))
  )

  summary_cases <- list(
    list(name = "typical_skewed_summary",
         inputs = list(latencies = typical_latencies),
         expected = latency_summary(typical_latencies)),
    list(name = "heavy_tail_summary",
         inputs = list(latencies = heavy_tail_latencies),
         expected = latency_summary(heavy_tail_latencies)),
    list(name = "large_sample_summary",
         inputs = list(latencies = large_sample),
         expected = latency_summary(large_sample)),
    list(name = "single_observation_summary",
         inputs = list(latencies = single_latency),
         expected = latency_summary(single_latency)),
    list(name = "identical_values_summary",
         inputs = list(latencies = identical_latencies),
         expected = latency_summary(identical_latencies))
  )

  list(
    suite = "latency_percentile",
    description = "Empirical percentile estimation using nearest-rank method, with summary statistics (mean, max)",
    method = "Nearest-rank (ceiling) percentile; sample mean and max",
    tolerance = 1e-10,
    cases = c(cases, summary_cases)
  )
}

#' Generate latency threshold derivation reference cases
#'
#' Each case provides the full baseline vector plus (p, confidence). The
#' expected output is the exact binomial order-statistic upper bound.
#'
#' @return A list suitable for JSON serialisation.
#' @export
generate_latency_threshold_cases <- function() {
  set.seed(42)
  baseline_935 <- sort(round(rlnorm(935, meanlog = log(500), sdlog = 0.3)))

  set.seed(7)
  baseline_50 <- sort(round(rlnorm(50, meanlog = log(400), sdlog = 0.35)))

  set.seed(11)
  baseline_5000 <- sort(round(rlnorm(5000, meanlog = log(200), sdlog = 0.3)))

  set.seed(13)
  baseline_500 <- sort(round(rlnorm(500, meanlog = log(300), sdlog = 0.35)))

  identical_100 <- rep(200L, 100)

  set.seed(17)
  heavy_baseline_100 <- sort(round(rlnorm(100, meanlog = log(300), sdlog = 0.8)))

  cases <- list(
    list(name = "worked_example_p95_935_samples",
         inputs = list(baseline_latencies = baseline_935, p = 0.95, confidence = 0.95),
         expected = latency_threshold_derive(baseline_935, 0.95, 0.95)),
    list(name = "small_baseline_p95_50_samples",
         inputs = list(baseline_latencies = baseline_50, p = 0.95, confidence = 0.95),
         expected = latency_threshold_derive(baseline_50, 0.95, 0.95)),
    list(name = "large_baseline_p95_5000_samples",
         inputs = list(baseline_latencies = baseline_5000, p = 0.95, confidence = 0.95),
         expected = latency_threshold_derive(baseline_5000, 0.95, 0.95)),
    list(name = "high_confidence_p95_500_samples",
         inputs = list(baseline_latencies = baseline_500, p = 0.95, confidence = 0.99),
         expected = latency_threshold_derive(baseline_500, 0.95, 0.99)),
    list(name = "identical_values_p95",
         inputs = list(baseline_latencies = identical_100, p = 0.95, confidence = 0.95),
         expected = latency_threshold_derive(identical_100, 0.95, 0.95)),
    list(name = "heavy_tailed_p99_100_samples",
         inputs = list(baseline_latencies = heavy_baseline_100, p = 0.99, confidence = 0.95),
         expected = latency_threshold_derive(heavy_baseline_100, 0.99, 0.95))
  )

  list(
    suite = "latency_threshold",
    description = "Latency threshold derivation via exact binomial order-statistic upper bound",
    method = "tau = t_{(k)} where k = qbinom(1 - alpha, n_s, p) + 1, clamped to [ceil(p*n), n]",
    tolerance = 0,
    cases = cases
  )
}

#' Bootstrap upper confidence bound on the baseline percentile
#'
#' Computes a one-sided upper bound on Q(p) by 10,000-replicate
#' percentile bootstrap (type-1 quantile). Informational only — used to
#' compare against the exact binomial order-statistic construction.
#' This is NOT the production threshold method.
#'
#' @param baseline Numeric vector. Successful-response latencies.
#' @param p Numeric. Percentile level.
#' @param confidence Numeric. One-sided confidence level.
#' @param B Integer. Number of bootstrap replicates (default 10000).
#' @param seed Integer. Bootstrap RNG seed (default 1). Determinism is
#'   load-bearing: the published bootstrap_upper values in the
#'   conformance fixture depend on this seed.
#' @return Numeric. The bootstrap upper bound at the requested
#'   confidence level.
#' @export
bootstrap_upper <- function(baseline, p, confidence, B = 10000L, seed = 1L) {
  set.seed(seed)
  n <- length(baseline)
  reps <- replicate(B, {
    nearest_rank_percentile(sample(baseline, n, replace = TRUE), p)
  })
  unname(quantile(reps, probs = confidence, type = 1))
}

#' Generate latency-threshold bootstrap-comparison reference cases
#'
#' This suite serves two coupled roles:
#'
#' (1) **Conformance contract** for the exact binomial order-statistic
#'     upper bound. Every consuming framework (punit, feotest, ...) must
#'     reproduce the rank, threshold, baseline_percentile, and n fields
#'     exactly from the published baseline_latencies. Because every
#'     conformance value is an integer or an element of the integer
#'     baseline_latencies array, conformance is exact equality and the
#'     suite carries tolerance: 0.
#'
#' (2) **Bootstrap-vs-binomial comparison** documented in §12.4.4 of the
#'     Statistical Companion. The informational fields bootstrap_upper,
#'     point_estimate, and diff preserve the published comparison so a
#'     reader can see how the conservative binomial bound relates to the
#'     bootstrap upper bound on each lognormal baseline.
#'
#' Determinism is load-bearing: the baselines are seeded so that
#' consumers can verify the rank/threshold against the same array, and
#' the bootstrap seed is fixed so the informational fields are stable
#' across regenerations.
#'
#' @return A list suitable for JSON serialisation.
#' @export
generate_latency_threshold_bootstrap_cases <- function() {
  # Reuses the same DGP and seeds as the n=200 percentile-suite sample
  # and the n=935 threshold-suite sample — by construction these
  # baselines are byte-identical across suites.
  set.seed(42)
  baseline_200 <- sort(round(rlnorm(200, meanlog = log(200), sdlog = 0.4)))

  set.seed(42)
  baseline_935 <- sort(round(rlnorm(935, meanlog = log(500), sdlog = 0.3)))

  build_case <- function(label, baseline, p, confidence = 0.95) {
    derived <- latency_threshold_derive(baseline, p, confidence)
    binomial <- latency_threshold_binomial_rank(derived$n, p, confidence)
    point_est <- nearest_rank_percentile(baseline, p)
    boot <- bootstrap_upper(baseline, p, confidence)
    list(
      name = sprintf("%s_p%g", label, p * 100),
      inputs = list(
        baseline_latencies = baseline,
        p = p,
        confidence = confidence
      ),
      expected = list(
        # Conformance fields — exact equality required.
        rank = derived$rank,
        threshold = derived$threshold,
        baseline_percentile = derived$baseline_percentile,
        n = derived$n,
        k_raw = binomial$k_raw,
        saturated = binomial$saturated,
        # Informational comparison fields — not conformance targets.
        bootstrap_upper = boot,
        point_estimate = point_est,
        diff = derived$threshold - boot
      )
    )
  }

  cases <- list(
    build_case("lognormal_n200", baseline_200, 0.95),
    build_case("lognormal_n200", baseline_200, 0.99),
    build_case("lognormal_n935", baseline_935, 0.95),
    build_case("lognormal_n935", baseline_935, 0.99)
  )

  list(
    suite = "latency_threshold_bootstrap",
    description = paste0(
      "Conformance suite for the exact binomial order-statistic upper bound on the baseline percentile. ",
      "Each case publishes the (ascending-sorted) baseline sample, the derivation parameters, ",
      "and the expected conformance fields (rank, threshold, baseline_percentile, n, k_raw, saturated). ",
      "Conformance is exact equality per field: every conformance value is an integer, a boolean, ",
      "or a specific element of baseline_latencies, so floating-point tolerance does not apply ",
      "(suite tolerance: 0). The k_raw field is the unclamped binomial-derived rank ",
      "(qbinom(1 - alpha, n, p) + 1); saturated is TRUE iff k_raw > n. Per Statistical Companion ",
      "§12.4.2, when saturated is TRUE the published rank and threshold are advisory at the ",
      "saturation ceiling (rank = n, threshold = t_{(n)}) and MUST NOT be presented as exact bounds ",
      "on Q(p) — consumers must branch on saturated before treating threshold as inferential. ",
      "The fields bootstrap_upper, point_estimate, and diff are preserved as informational comparison ",
      "content (10,000-replicate percentile bootstrap upper bound, raw sample quantile, and the ",
      "difference from the binomial threshold) and are not conformance targets."
    ),
    method = paste0(
      "Exact binomial order-statistic upper bound (k = qbinom(1 - alpha, n_s, p) + 1, clamped to ",
      "[ceil(p*n), n]); bootstrap upper bound at type-1 quantile preserved alongside as informational ",
      "comparison."
    ),
    tolerance = 0,
    cases = cases
  )
}
