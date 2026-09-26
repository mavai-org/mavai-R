#' Legacy decision rules of methodology 1.4.1, under their own identifiers.
#'
#' Statistical Companion 2.0.0 withdraws these three constructions as
#' decision rules. They survive in mavai-R only — never in a framework —
#' to reproduce methodology-1.4.1 outputs and to compare the two
#' generations. No 2.0.0 fixture is computed from them; the 1.4.1
#' fixtures are the immutable release assets of v0.10.13. None of these
#' identifiers claims 2.0.0 calibration.
#'
#'   - `regression/wilson-reference` v1 — the Wilson lower bound of the
#'     baseline rate evaluated at the test size, with the perfect-baseline
#'     substitution (R/threshold.R); c = ceiling(n_t * p*).
#'   - `latency/order-statistic-bound` v1 — the exact binomial upper
#'     confidence bound on the baseline quantile, k = qbinom(1 - alpha,
#'     n, p) + 1 clamped to [ceiling(p n), n] (R/latency.R).
#'   - `compliance/wilson-clearance` v1 — PASS iff the Wilson lower bound
#'     of the test clears p_req, with the Wilson feasibility gate
#'     n >= ceiling(p_req z^2 / (1 - p_req)).
#' @name legacy_decision_rules
NULL

LEGACY_DECISION_RULES <- list(
  "regression/wilson-reference" = list(id = "regression/wilson-reference", version = 1L),
  "latency/order-statistic-bound" = list(id = "latency/order-statistic-bound", version = 1L),
  "compliance/wilson-clearance" = list(id = "compliance/wilson-clearance", version = 1L)
)

#' Legacy regression cutoff, `regression/wilson-reference` v1
#' @export
legacy_wilson_reference_cutoff <- function(baseline_successes, baseline_trials, test_samples, alpha) {
  vapply(baseline_successes, function(k) {
    ssf_expected_block(k, baseline_trials, test_samples, 1 - alpha)$cutoff_integer
  }, integer(1))
}

#' Legacy conditional size of the Wilson cutoff, P_{p0}(K_t < c)
#' @export
legacy_wilson_reference_achieved_size <- function(baseline_successes, baseline_trials,
                                                  test_samples, alpha) {
  ssf_expected_block(baseline_successes, baseline_trials, test_samples, 1 - alpha)$achieved_size
}

#' Legacy latency rank, `latency/order-statistic-bound` v1
#'
#' @return A list: rank (clamped to n when saturated, as the 1.4.1
#'   fixtures published it), k_raw, saturated.
#' @export
legacy_order_statistic_rank <- function(n, p, alpha) {
  b <- latency_threshold_binomial_rank(n, p, 1 - alpha)
  point <- as.integer(ceiling(p * n))
  list(rank = as.integer(max(point, min(b$k_raw, n))), k_raw = b$k_raw, saturated = b$saturated)
}

#' Legacy compliance verdict, `compliance/wilson-clearance` v1
#'
#' PASS iff WilsonLower(K, n, 1 - alpha) >= p_req, as the 1.4.1
#' regression_decision fixtures stated it (criterion_verdict_inferential
#' used >; the two differ only on exact ties).
#' @export
legacy_wilson_clearance_pass <- function(successes, n, threshold, alpha) {
  wilson_lower(successes, n, 1 - alpha) >= threshold
}

#' Smallest passing count under `compliance/wilson-clearance` v1 (NA if none)
#' @export
legacy_wilson_clearance_min_k <- function(n, threshold, alpha) {
  ok <- which(vapply(0:n, function(k) legacy_wilson_clearance_pass(k, n, threshold, alpha), logical(1)))
  if (length(ok) == 0) NA_integer_ else as.integer(ok[1] - 1L)
}

#' Legacy Wilson feasibility minimum, ceiling(p_req z^2 / (1 - p_req))
#' @export
legacy_wilson_feasibility_min_n <- function(threshold, alpha) {
  z <- qnorm(1 - alpha)
  as.integer(ceiling(threshold * z^2 / (1 - threshold)))
}
