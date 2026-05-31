#' Wilson score confidence interval (two-sided)
#'
#' Computes the Wilson score interval for a binomial proportion.
#' This is the reference implementation against which all mavai framework
#' implementations (punit, feotest, baseltest, ...) must conform.
#'
#' @param successes Integer. Number of successes.
#' @param trials Integer. Total number of trials.
#' @param confidence Numeric. Confidence level (e.g. 0.95).
#' @return A list with lower, upper, and point estimate.
#' @export
wilson_ci <- function(successes, trials, confidence) {
  alpha <- 1 - confidence
  z <- qnorm(1 - alpha / 2)
  p_hat <- successes / trials
  n <- trials

  denom <- 1 + z^2 / n
  centre <- (p_hat + z^2 / (2 * n)) / denom
  margin <- (z / denom) * sqrt(p_hat * (1 - p_hat) / n + z^2 / (4 * n^2))

  list(
    lower = max(0, centre - margin),
    upper = min(1, centre + margin),
    point = p_hat
  )
}

#' Wilson score lower bound (one-sided), discrete inputs
#'
#' Computes the one-sided lower bound of the Wilson score interval given
#' integer (successes, trials). This is the canonical confidence statement
#' on the true rate underlying observations.
#'
#' @param successes Integer. Number of successes.
#' @param trials Integer. Total number of trials.
#' @param confidence Numeric. Confidence level (e.g. 0.95).
#' @return Numeric. The lower bound.
#' @export
wilson_lower <- function(successes, trials, confidence) {
  wilson_lower_from_rate(successes / trials, trials, confidence)
}

#' Wilson score lower bound (one-sided), continuous-rate inputs
#'
#' Computes the one-sided Wilson lower bound at a supplied rate p_hat and
#' sample size n. This is the form the threshold-derivation construction
#' uses (companion §3.4 / §4.3.2): given an effective baseline rate, what
#' threshold should an n-sample test use so that, if the true rate equals
#' p_hat, the false-positive rate is α?
#'
#' For integer (k, n), `wilson_lower_from_rate(k/n, n, conf)` matches
#' `wilson_lower(k, n, conf)` exactly. The two share an implementation —
#' the discrete form is a thin wrapper that supplies p_hat = k/n.
#'
#' @param p_hat Numeric. The proportion (in [0, 1]) used as the formula's centre.
#' @param n Integer. The sample size used in the formula.
#' @param confidence Numeric. Confidence level (e.g. 0.95).
#' @return Numeric. The lower bound.
#' @export
wilson_lower_from_rate <- function(p_hat, n, confidence) {
  alpha <- 1 - confidence
  z <- qnorm(1 - alpha)  # one-sided

  denom <- 1 + z^2 / n
  centre <- (p_hat + z^2 / (2 * n)) / denom
  margin <- (z / denom) * sqrt(p_hat * (1 - p_hat) / n + z^2 / (4 * n^2))

  max(0, centre - margin)
}

#' Generate Wilson CI reference cases
#'
#' @return A list suitable for JSON serialisation.
#' @export
generate_wilson_ci_cases <- function() {
  cases <- list(
    # Fair coin — textbook case
    list(
      name = "fair_coin_100_trials_95pct",
      inputs = list(successes = 50L, trials = 100L, confidence = 0.95),
      expected = wilson_ci(50, 100, 0.95)
    ),
    # High pass rate — typical LLM service
    list(
      name = "high_rate_95_of_100_95pct",
      inputs = list(successes = 95L, trials = 100L, confidence = 0.95),
      expected = wilson_ci(95, 100, 0.95)
    ),
    # Perfect baseline — the "perfect baseline problem"
    list(
      name = "perfect_baseline_100_of_100_95pct",
      inputs = list(successes = 100L, trials = 100L, confidence = 0.95),
      expected = wilson_ci(100, 100, 0.95)
    ),
    # Zero successes — boundary
    list(
      name = "zero_successes_0_of_100_95pct",
      inputs = list(successes = 0L, trials = 100L, confidence = 0.95),
      expected = wilson_ci(0, 100, 0.95)
    ),
    # Small sample
    list(
      name = "small_sample_3_of_5_95pct",
      inputs = list(successes = 3L, trials = 5L, confidence = 0.95),
      expected = wilson_ci(3, 5, 0.95)
    ),
    # Large sample
    list(
      name = "large_sample_950_of_1000_95pct",
      inputs = list(successes = 950L, trials = 1000L, confidence = 0.95),
      expected = wilson_ci(950, 1000, 0.95)
    ),
    # 90% confidence
    list(
      name = "fair_coin_100_trials_90pct",
      inputs = list(successes = 50L, trials = 100L, confidence = 0.90),
      expected = wilson_ci(50, 100, 0.90)
    ),
    # 99% confidence
    list(
      name = "fair_coin_100_trials_99pct",
      inputs = list(successes = 50L, trials = 100L, confidence = 0.99),
      expected = wilson_ci(50, 100, 0.99)
    ),
    # Near-boundary low rate
    list(
      name = "low_rate_2_of_100_95pct",
      inputs = list(successes = 2L, trials = 100L, confidence = 0.95),
      expected = wilson_ci(2, 100, 0.95)
    ),
    # Single trial success
    list(
      name = "single_trial_success_95pct",
      inputs = list(successes = 1L, trials = 1L, confidence = 0.95),
      expected = wilson_ci(1, 1, 0.95)
    )
  )

  list(
    suite = "wilson_ci",
    description = "Wilson score confidence intervals (two-sided)",
    method = "qnorm-based Wilson score interval",
    tolerance = 1e-10,
    cases = cases
  )
}

#' Generate Wilson lower bound reference cases
#'
#' @return A list suitable for JSON serialisation.
#' @export
generate_wilson_lower_cases <- function() {
  cases <- list(
    list(
      name = "baseline_95_of_100_95pct",
      inputs = list(successes = 95L, trials = 100L, confidence = 0.95),
      expected = list(lower_bound = wilson_lower(95, 100, 0.95))
    ),
    list(
      name = "perfect_baseline_100_of_100_95pct",
      inputs = list(successes = 100L, trials = 100L, confidence = 0.95),
      expected = list(lower_bound = wilson_lower(100, 100, 0.95))
    ),
    list(
      name = "baseline_950_of_1000_95pct",
      inputs = list(successes = 950L, trials = 1000L, confidence = 0.95),
      expected = list(lower_bound = wilson_lower(950, 1000, 0.95))
    ),
    list(
      name = "baseline_95_of_100_99pct",
      inputs = list(successes = 95L, trials = 100L, confidence = 0.99),
      expected = list(lower_bound = wilson_lower(95, 100, 0.99))
    ),
    list(
      name = "baseline_95_of_100_90pct",
      inputs = list(successes = 95L, trials = 100L, confidence = 0.90),
      expected = list(lower_bound = wilson_lower(95, 100, 0.90))
    ),
    list(
      name = "fair_coin_50_of_100_95pct",
      inputs = list(successes = 50L, trials = 100L, confidence = 0.95),
      expected = list(lower_bound = wilson_lower(50, 100, 0.95))
    ),
    list(
      name = "small_sample_5_of_5_95pct",
      inputs = list(successes = 5L, trials = 5L, confidence = 0.95),
      expected = list(lower_bound = wilson_lower(5, 5, 0.95))
    ),
    # Pathological: zero successes — complete failure
    list(
      name = "zero_successes_0_of_100_95pct",
      inputs = list(successes = 0L, trials = 100L, confidence = 0.95),
      expected = list(lower_bound = wilson_lower(0, 100, 0.95))
    ),
    # Pathological: zero successes, small sample
    list(
      name = "zero_successes_0_of_5_95pct",
      inputs = list(successes = 0L, trials = 5L, confidence = 0.95),
      expected = list(lower_bound = wilson_lower(0, 5, 0.95))
    ),
    # Pathological: zero successes at 99% confidence
    list(
      name = "zero_successes_0_of_100_99pct",
      inputs = list(successes = 0L, trials = 100L, confidence = 0.99),
      expected = list(lower_bound = wilson_lower(0, 100, 0.99))
    ),
    # Pathological: single trial failure
    list(
      name = "single_trial_failure_0_of_1_95pct",
      inputs = list(successes = 0L, trials = 1L, confidence = 0.95),
      expected = list(lower_bound = wilson_lower(0, 1, 0.95))
    ),
    # Pathological: single trial success
    list(
      name = "single_trial_success_1_of_1_95pct",
      inputs = list(successes = 1L, trials = 1L, confidence = 0.95),
      expected = list(lower_bound = wilson_lower(1, 1, 0.95))
    )
  )

  list(
    suite = "wilson_lower",
    description = "Wilson score one-sided lower bound",
    method = "qnorm-based Wilson score lower bound (one-sided z)",
    tolerance = 1e-10,
    cases = cases
  )
}
