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

#' Minimum sample size for a non-saturated distribution-free upper bound
#' (legacy)
#'
#' The Wilks minimum n_s >= ceiling(log(alpha) / log(p)): the existence
#' condition of the withdrawn order-statistic confidence bound (legacy
#' `latency/order-statistic-bound`). It is neither necessary nor sufficient
#' for the latency/precedence rank, whose existence is decided by
#' `latency_precedence_exists()`; kept only for reproducing 1.4.1 outputs.
#'
#' @param p Numeric. Percentile level (e.g. 0.95).
#' @param confidence Numeric. One-sided confidence level (e.g. 0.95).
#' @return Integer. Minimum sample count.
#' @export
latency_bound_existence_min_samples <- function(p, confidence) {
  alpha <- 1 - confidence
  as.integer(ceiling(log(alpha) / log(p)))
}

#' Existence of a latency/precedence threshold for a test of n_t latencies
#'
#' A rank exists iff the top rank achieves it, breach(n_b) <= alpha,
#' because breach(k) decreases in k. Run on the actual number of
#' successful latencies after the test, this is the binding saturation
#' decision: saturated means INCONCLUSIVE.
#'
#' @return A list: saturated (TRUE when no rank achieves alpha) and rank
#'   (the precedence rank, or NA when saturated).
#' @export
latency_precedence_exists <- function(baseline_trials, test_samples, p, alpha) {
  k <- latency_precedence_rank(baseline_trials, test_samples, p, alpha)
  list(saturated = is.na(k), rank = k)
}

#' Pre-run planning check for a latency/precedence assertion
#'
#' Before the run the number of successful latencies is not known; the
#' expected count floor(planned_samples * baseline_success_rate) is an
#' expectation, not a lower bound. The rank search on it gives a warning
#' (no rank at the expected count) and planning figures: the rank at the
#' expected count, and the smallest baseline, at least as large as the
#' expected count, that supports a rank for it. Nothing here is binding:
#' saturation is decided after the run from the actual count
#' (`latency_precedence_exists()`).
#'
#' @return A list: expected_test_samples, warning, planning_rank,
#'   minimum_baseline_trials.
#' @export
latency_precedence_planning <- function(baseline_trials, planned_samples, baseline_success_rate,
                                        p, alpha) {
  n_exp <- as.integer(floor(planned_samples * baseline_success_rate + 1e-9))
  e <- latency_precedence_exists(baseline_trials, n_exp, p, alpha)
  n_b <- n_exp
  while (is.na(latency_precedence_rank(n_b, n_exp, p, alpha))) n_b <- n_b + 1L
  list(expected_test_samples = n_exp, warning = e$saturated, planning_rank = e$rank,
       minimum_baseline_trials = as.integer(n_b))
}

#' Generate latency percentile minimum-sample-size and existence cases
#'
#' Two case groups, distinguished by the `approach` field:
#'
#' (1) **emission_non_degeneracy** — the companion §12.5.2 minimums
#'     governing whether a percentile may be emitted in experiment
#'     artefacts and verdicts at all (below the minimum the key is
#'     omitted, renderers show a dash). One case per supported level.
#'
#' (2) **precedence_existence** — the companion §12.5.2.1 existence
#'     condition: whether a latency/precedence rank exists for a baseline
#'     of n_b latencies, a test of n_t successful latencies, a percentile
#'     and alpha, and the rank. On the actual count after the run it is the
#'     binding saturation decision; saturated means INCONCLUSIVE.
#'
#' (3) **precedence_planning** — the §12.5.3 pre-run check: the same
#'     search on the expected successful count, giving a warning and
#'     planning figures, never a verdict.
#'
#' @return A list suitable for JSON serialisation.
#' @export
generate_latency_percentile_minimums_cases <- function() {
  levels <- c(0.50, 0.90, 0.95, 0.99)

  emission_cases <- lapply(levels, function(p) {
    list(
      name = sprintf("emission_minimum_p%g", p * 100),
      approach = "emission_non_degeneracy",
      inputs = list(percentile = p),
      expected = list(minimum_contributing_samples = latency_min_samples(p))
    )
  })

  existence_case <- function(name, n_b, n_t, p, alpha) {
    e <- latency_precedence_exists(n_b, n_t, p, alpha)
    list(
      name = name,
      approach = "precedence_existence",
      decisionRule = "latency/precedence",
      inputs = list(baseline_trials = as.integer(n_b), test_samples = as.integer(n_t),
                    percentile = p, alpha = alpha),
      expected = list(saturated = e$saturated, rank = e$rank)
    )
  }
  existence_cases <- list(
    existence_case("p95_100_test15_saturated", 100, 15, 0.95, 0.05),
    existence_case("p95_1000_test15", 1000, 15, 0.95, 0.05),
    existence_case("p99_300_test100_saturated", 300, 100, 0.99, 0.05),
    existence_case("p95_935_test192", 935, 192, 0.95, 0.05),
    existence_case("p90_32_test10_saturated", 32, 10, 0.90, 0.05),
    existence_case("p90_33_test10_first_rank", 33, 10, 0.90, 0.05),
    existence_case("p95_85_test25_saturated", 85, 25, 0.95, 0.05),
    existence_case("p95_86_test25_first_rank", 86, 25, 0.95, 0.05),
    existence_case("p99_949_test50_saturated", 949, 50, 0.99, 0.05),
    existence_case("p99_950_test50_first_rank_exact_boundary", 950, 50, 0.99, 0.05),
    existence_case("p95_189_test10_saturated", 189, 10, 0.95, 0.05),
    existence_case("p95_190_test10_first_rank_exact_boundary", 190, 10, 0.95, 0.05),
    existence_case("p99_474_test25_saturated", 474, 25, 0.99, 0.05),
    existence_case("p99_475_test25_first_rank_exact_boundary", 475, 25, 0.99, 0.05),
    existence_case("p99_553_test160_saturated", 553, 160, 0.99, 0.05),
    existence_case("p99_554_test160_first_rank", 554, 160, 0.99, 0.05),
    existence_case("p50_20_test10", 20, 10, 0.50, 0.05),
    existence_case("p95_500_test100_alpha001", 500, 100, 0.95, 0.01),
    existence_case("p99_554_test161_saturated", 554, 161, 0.99, 0.05)
  )

  planning_case <- function(name, n_b, planned, rate, p, alpha, description = NULL) {
    e <- latency_precedence_planning(n_b, planned, rate, p, alpha)
    case <- list(name = name, approach = "precedence_planning", decisionRule = "latency/precedence")
    if (!is.null(description)) case$description <- description
    c(case, list(
      inputs = list(baseline_trials = as.integer(n_b), planned_samples = as.integer(planned),
                    baseline_success_rate = rate, percentile = p, alpha = alpha),
      expected = e
    ))
  }
  planning_cases <- list(
    planning_case("p99_400_planned200_rate080_warning", 400, 200, 0.80, 0.99, 0.05,
      "The §12.5.3 example: 160 expected successful latencies, no rank at a baseline of 400; a warning and the planning figure 554, not a verdict."),
    planning_case("p99_554_planned200_rate080_no_warning", 554, 200, 0.80, 0.99, 0.05,
      "A rank exists at the expected 160; if the run returns 161 or more successful latencies the post-run decision is saturated (p99_554_test161_saturated)."),
    planning_case("p95_1000_planned20_rate075", 1000, 20, 0.75, 0.95, 0.05),
    planning_case("p90_30_planned12_rate090_warning", 30, 12, 0.90, 0.90, 0.05)
  )

  list(
    suite = "latency_percentile_minimums",
    description = paste0(
      "Minimum sample sizes and the existence gate for empirical latency percentiles (p50/p90/p95/p99). ",
      "Cases with approach 'emission_non_degeneracy' carry the Statistical Companion §12.5.2 ",
      "minimums for emitting a percentile in experiment artefacts (baseline, exploration, ",
      "optimization) and verdicts: below the minimum the percentile key is omitted entirely ",
      "and renderers display a placeholder. Cases with approach 'precedence_existence' carry the ",
      "§12.5.2.1 existence condition of latency/precedence from the baseline size, the test's ",
      "number of successful latencies, the percentile and alpha: saturated (no rank achieves ",
      "alpha) and otherwise the rank; on the actual count after the run it is the binding ",
      "saturation decision, and saturated is INCONCLUSIVE. Cases with approach ",
      "'precedence_planning' carry the §12.5.3 pre-run check: the same search on the expected ",
      "successful count floor(planned_samples * baseline_success_rate), an expectation and not a ",
      "lower bound, giving a warning (no rank at the expected count), the planning rank and the ",
      "smallest baseline at least as large as the expected count that supports a rank; it ",
      "decides nothing. The withdrawn Wilks minimums are no longer ",
      "published. Cases named exact_boundary have breach(n_b) = n_t / (n_b + n_t) = alpha exactly ",
      "(the test percentile is the test maximum); the inclusive rule admits the rank, and double ",
      "precision alone does not: implementations follow the exact-boundary convention (companion ",
      "§10.6). Conformance is exact equality (tolerance: 0)."
    ),
    method = paste0(
      "Emission minimums per companion §12.5.2 (non-degeneracy: 5/10/20/100 for ",
      "p50/p90/p95/p99); existence per §12.5.2.1: a rank exists iff breach(n_b) <= alpha, with ",
      "breach(k) = sum_{j=0}^{r-1} C(n_t, j) B(k + j, n_b - k + 1 + n_t - j) / B(k, n_b - k + 1) and ",
      "r = ceiling(P n_t / 100); rank = the smallest k with breach(k) <= alpha (latency/precedence v1). ",
      "Planning: expected_test_samples = floor(planned_samples * baseline_success_rate); warning = ",
      "no rank at that count; planning_rank = the rank at it (null under a warning); ",
      "minimum_baseline_trials = the smallest n_b >= expected_test_samples with a rank."
    ),
    tolerance = 0,
    cases = c(emission_cases, existence_cases, planning_cases)
  )
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

#' Generate latency threshold reference cases (latency/precedence v1)
#'
#' Each case provides the full baseline vector plus the test size n_t,
#' the percentile p and alpha. The expected output is the precedence rank
#' — the smallest baseline rank k whose exact no-degradation breach
#' probability for the test's nearest-rank percentile is at most alpha —
#' and its order statistic, or `saturated: true` (INCONCLUSIVE) when no
#' rank achieves alpha.
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

  set.seed(42)
  baseline_200 <- sort(round(rlnorm(200, meanlog = log(200), sdlog = 0.4)))

  set.seed(19)
  baseline_1000 <- sort(round(rlnorm(1000, meanlog = log(250), sdlog = 0.35)))

  set.seed(23)
  baseline_300 <- sort(round(rlnorm(300, meanlog = log(350), sdlog = 0.4)))

  lat_case <- function(name, baseline, test_samples, p, alpha, description = NULL) {
    case <- list(name = name)
    if (!is.null(description)) case$description <- description
    c(case, list(
      inputs = list(baseline_latencies = baseline, test_samples = as.integer(test_samples),
                    p = p, alpha = alpha),
      expected = latency_precedence_threshold(baseline, test_samples, p, alpha)
    ))
  }

  cases <- list(
    lat_case("worked_example_p95_935_samples_test192", baseline_935, 192, 0.95, 0.05,
             "The companion's §12.4.1 configuration."),
    lat_case("boundary_equal_sizes_p95_935_test935", baseline_935, 935, 0.95, 0.05),
    lat_case("p90_200_samples_test200", baseline_200, 200, 0.90, 0.05),
    lat_case("p50_200_samples_test50", baseline_200, 50, 0.50, 0.05),
    lat_case("large_baseline_small_test_p95_1000_test15", baseline_1000, 15, 0.95, 0.05),
    lat_case("saturated_p95_100_test15", heavy_baseline_100, 15, 0.95, 0.05,
             "No rank achieves alpha: INCONCLUSIVE, no threshold."),
    lat_case("saturated_p99_300_test100", baseline_300, 100, 0.99, 0.05,
             "No rank achieves alpha: INCONCLUSIVE, no threshold."),
    lat_case("small_baseline_p95_50_test50", baseline_50, 50, 0.95, 0.05),
    lat_case("large_baseline_p95_5000_test500", baseline_5000, 500, 0.95, 0.05),
    lat_case("alpha001_p95_500_test100", baseline_500, 100, 0.95, 0.01),
    lat_case("identical_values_p95_100_test50", identical_100, 50, 0.95, 0.05,
             "Heavy ties: the threshold is the common value; ties make the bound conservative, not invalid."),
    lat_case("heavy_tailed_p99_100_test100", heavy_baseline_100, 100, 0.99, 0.05)
  )

  list(
    suite = "latency_threshold",
    description = paste(
      "Latency threshold under latency/precedence (companion §12.4): the smallest baseline rank",
      "whose exact, distribution-free no-degradation breach probability for the test's",
      "nearest-rank percentile is at most alpha, and the observed baseline latency at that rank.",
      "When no rank achieves alpha the result is INCONCLUSIVE with saturated = true and no rank or",
      "threshold. A test percentile equal to the threshold is not a breach. Binding: rank,",
      "threshold, saturated. Informational: breach_probability, test_rank, n, baseline_percentile."
    ),
    method = paste(
      "latency/precedence v1: r = ceiling(P n_t / 100) in integer arithmetic (P in 50, 90, 95, 99);",
      "breach(k) = sum_{j=0}^{r-1} C(n_t, j) B(k + j, n_b - k + 1 + n_t - j) / B(k, n_b - k + 1);",
      "rank = the smallest k in 1..n_b with breach(k) <= alpha; threshold = the rank-th order",
      "statistic of the baseline latencies; saturated iff no such k (rank and threshold null).",
      "baseline_percentile is the baseline's own nearest-rank percentile."
    ),
    tolerance = 1e-10,
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

#' Latency-threshold bootstrap comparison (legacy, not published)
#'
#' The comparison behind companion §12.4.4 between the v1.4.1 order-
#' statistic bound (legacy `latency/order-statistic-bound`) and a
#' percentile bootstrap. Since methodology 1.5.0 it is no longer published
#' as a fixture suite — the bound it compares is not the 1.5.0 latency
#' decision rule — and survives only for scripts/bootstrap_compare.R.
#' Its former roles:
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
