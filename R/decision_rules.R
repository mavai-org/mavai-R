#' The Statistical Companion 1.5.0 decision rules.
#'
#' Three verdict-producing procedures, each with a versioned identifier
#' that travels in every fixture it governs:
#'
#'   - `regression/fisher` v1 — empirical regression: the one-sided
#'     Fisher exact test, expressed as an integer cutoff c on the test's
#'     success count (companion §3.4).
#'   - `compliance/exact-binomial` v1 — normative compliance: the exact
#'     one-sided binomial test of H0: p <= p_req, expressed as the
#'     smallest passing count k_min (companion §3.6, §5.7).
#'   - `latency/precedence` v1 — latency regression: the smallest baseline
#'     rank whose exact no-degradation breach probability for the test's
#'     nearest-rank percentile is at most alpha (companion §12.4).
#'
#' Plus the two configuration errors refused before any sample runs:
#' `TEST_LARGER_THAN_BASELINE` and `COMPLIANCE_INFEASIBLE`.
#'
#' Everything here is an exact finite sum over base-R distribution
#' functions (`phyper`, `dbinom`/`pbinom`, `qbeta`, `lchoose`/`lbeta`);
#' nothing is simulated.

METHODOLOGY_VERSION <- "1.5.0"

# Version of the fixture file shape (cases.schema.json and the manifest).
# 1 was the unversioned shape up to fixtures 0.10.13; 2 adds
# methodologyVersion, fixtureSchemaVersion and decisionRules.
FIXTURE_SCHEMA_VERSION <- 2L

DECISION_RULES <- list(
  "regression/fisher" = list(id = "regression/fisher", version = 1L),
  "compliance/exact-binomial" = list(id = "compliance/exact-binomial", version = 1L),
  "latency/precedence" = list(id = "latency/precedence", version = 1L)
)

CONFIGURATION_ERRORS <- c(
  "TEST_LARGER_THAN_BASELINE",
  "COMPLIANCE_INFEASIBLE"
)

# The alpha values at which the certification scans run.
CERTIFIED_ALPHAS <- c(0.001, 0.01, 0.05, 0.10)

# The latency percentiles the precedence rule supports (as P in p = P/100).
SUPPORTED_LATENCY_PERCENTILES <- c(50L, 90L, 95L, 99L)

#' @keywords internal
check_count <- function(x, name, min = 0) {
  if (length(x) != 1 || is.na(x) || x != round(x) || x < min) {
    stop(sprintf("%s must be a single integer >= %d", name, min), call. = FALSE)
  }
  invisible(TRUE)
}

#' @keywords internal
check_alpha <- function(alpha) {
  if (length(alpha) != 1 || is.na(alpha) || alpha <= 0 || alpha >= 1) {
    stop("alpha must be a single number in (0, 1)", call. = FALSE)
  }
  invisible(TRUE)
}

# ===========================================================================
# regression/fisher, version 1
# ===========================================================================

#' One-sided Fisher p-value of a test count
#'
#' The hypergeometric lower tail P(X <= k_t), X the number of the
#' s = k_b + k_t pooled successes that fall in the test's n_t of the
#' n_b + n_t trials. Vectorised in k_t and k_b.
#'
#' @param k_t,k_b Test and baseline success counts.
#' @param n_b,n_t Baseline and test sizes.
#' @return Numeric vector of p-values.
#' @export
fisher_pvalue <- function(k_t, k_b, n_b, n_t) {
  s <- k_b + k_t
  phyper(k_t, s, n_b + n_t - s, n_t)
}

#' Integer cutoff of regression/fisher (the binding decision artefact)
#'
#' k_t FAILs iff its one-sided Fisher p-value is <= alpha; the p-value is
#' non-decreasing in k_t, so c is the smallest k_t whose p-value exceeds
#' alpha (0 when k_t = 0 already does); PASS iff K_t >= c. Computed by the
#' literal scan the definition states. Vectorised in `baseline_successes`.
#'
#' @param baseline_successes K_b, 0..n_b (may be a vector).
#' @param baseline_trials n_b >= 1.
#' @param test_samples n_t >= 1.
#' @param alpha One-sided level.
#' @return Integer vector of cutoffs.
#' @export
fisher_cutoff <- function(baseline_successes, baseline_trials, test_samples, alpha) {
  check_count(baseline_trials, "baseline_trials", 1)
  check_count(test_samples, "test_samples", 1)
  check_alpha(alpha)
  if (any(baseline_successes < 0 | baseline_successes > baseline_trials |
          baseline_successes != round(baseline_successes))) {
    stop("baseline_successes must be integers in 0..baseline_trials", call. = FALSE)
  }
  k_t <- 0:test_samples
  vapply(baseline_successes, function(k_b) {
    above <- fisher_pvalue(k_t, k_b, baseline_trials, test_samples) > alpha
    as.integer(which(above)[1] - 1L)
  }, integer(1))
}

#' Cutoffs of regression/fisher for a range of K_b, fast
#'
#' Vectorised bisection over k_t for every K_b at once, relying on the
#' p-value being non-decreasing in k_t (P(X <= k_t) with s = K_b + k_t);
#' the boundary it returns (p-value above alpha at c, at most alpha at
#' c - 1) is checked for every K_b. Agrees with `fisher_cutoff()`.
#'
#' @param n_b,n_t Baseline and test sizes.
#' @param alpha One-sided level.
#' @param k_b Baseline counts (default 0..n_b).
#' @return Integer vector of cutoffs, one per k_b.
#' @export
fisher_cutoffs <- function(n_b, n_t, alpha, k_b = 0:n_b) {
  check_count(n_b, "n_b", 1)
  check_count(n_t, "n_t", 1)
  check_alpha(alpha)
  lo <- rep(-1L, length(k_b))             # virtual failing point
  hi <- rep(as.integer(n_t), length(k_b))  # P(X <= n_t) = 1 > alpha
  repeat {
    open <- which(hi - lo > 1L)
    if (length(open) == 0) break
    mid <- (lo[open] + hi[open]) %/% 2L
    above <- fisher_pvalue(mid, k_b[open], n_b, n_t) > alpha
    hi[open[above]] <- mid[above]
    lo[open[!above]] <- mid[!above]
  }
  low <- hi > 0L
  if (!all(fisher_pvalue(hi, k_b, n_b, n_t) > alpha) ||
      any(fisher_pvalue(hi[low] - 1L, k_b[low], n_b, n_t) > alpha)) {
    stop("Fisher cutoff boundary check failed", call. = FALSE)
  }
  hi
}

#' Unconditional probability that the test FAILs, K_t < c(K_b)
#'
#' With K_b ~ Bin(n_b, p_b) and K_t ~ Bin(n_t, p_t) independent:
#' sum over k_b of P(K_b = k_b) P(K_t < c(k_b)). With p_b = p_t this is
#' the false-degradation-signal probability A(p); with p_t < p_b it is
#' the power. Exact finite sum.
#'
#' @param cutoffs Cutoff vector for K_b = 0..n_b.
#' @param n_b,n_t Baseline and test sizes.
#' @param p_b,p_t Baseline and test success probabilities.
#' @return Numeric scalar.
#' @export
regression_fail_probability <- function(cutoffs, n_b, n_t, p_b, p_t) {
  w <- dbinom(0:n_b, n_b, p_b)
  lower <- c(0, pbinom(0:(n_t - 1), n_t, p_t))  # P(K_t < c) at c = 0..n_t
  sum(w * lower[cutoffs + 1L])
}

#' Exact unconditional size A(p) of regression/fisher
#'
#' @param n_b,n_t Baseline and test sizes.
#' @param alpha One-sided level.
#' @param p Common success probability (vector allowed).
#' @param cutoffs Optional precomputed cutoff vector.
#' @return Numeric vector, one size per p.
#' @export
fisher_size <- function(n_b, n_t, alpha, p, cutoffs = fisher_cutoffs(n_b, n_t, alpha)) {
  vapply(p, function(pp) regression_fail_probability(cutoffs, n_b, n_t, pp, pp), numeric(1))
}

#' Exact power of regression/fisher against the operative cutoff
#'
#' P(FAIL) with the baseline at p_b and the test at p_b - delta.
#'
#' @param n_b,n_t Baseline and test sizes.
#' @param alpha One-sided level.
#' @param baseline_rate p_b.
#' @param delta Degradation margin (p_t = p_b - delta, delta <= p_b).
#' @param cutoffs Optional precomputed cutoff vector.
#' @return Numeric scalar.
#' @export
fisher_power <- function(n_b, n_t, alpha, baseline_rate, delta,
                         cutoffs = fisher_cutoffs(n_b, n_t, alpha)) {
  if (delta < 0 || delta > baseline_rate) stop("need 0 <= delta <= baseline_rate", call. = FALSE)
  regression_fail_probability(cutoffs, n_b, n_t, baseline_rate, baseline_rate - delta)
}

#' Minimum detectable degradation of regression/fisher
#'
#' The smallest delta at which the exact power under the operative rule
#' reaches `power` (default 0.80), with the baseline at `baseline_rate`.
#' Power is increasing in delta, so the answer is found by bisection to
#' 1e-12. NA when even delta = baseline_rate (a test rate of 0) does not
#' reach the target: no degradation is detectable at that power.
#'
#' @param n_b,n_t Baseline and test sizes.
#' @param alpha One-sided level.
#' @param baseline_rate p_b.
#' @param power Target power.
#' @return Numeric scalar or NA.
#' @export
fisher_minimum_detectable_degradation <- function(n_b, n_t, alpha, baseline_rate,
                                                  power = 0.80) {
  cutoffs <- fisher_cutoffs(n_b, n_t, alpha)
  pw <- function(delta) regression_fail_probability(cutoffs, n_b, n_t, baseline_rate,
                                                    baseline_rate - delta)
  if (pw(baseline_rate) < power) return(NA_real_)
  lo <- 0; hi <- baseline_rate
  while (hi - lo > 1e-12) {
    mid <- (lo + hi) / 2
    if (pw(mid) >= power) hi <- mid else lo <- mid
  }
  hi
}

#' Implied alpha of a declared cutoff under regression/fisher
#'
#' The threshold-first inversion (companion §6.3): the smallest alpha at
#' which the Fisher rule yields the declared cutoff c. The rule gives c
#' exactly when P(X <= c - 1) <= alpha < P(X <= c), so the implied alpha
#' is the p-value at c - 1 (0 for c = 0, the infimum). NA when no alpha
#' yields c (the p-values at c - 1 and c coincide, so the rule skips c).
#'
#' @param baseline_successes,baseline_trials Baseline evidence.
#' @param test_samples n_t.
#' @param cutoff The declared cutoff, 0..n_t.
#' @return Numeric or NA.
#' @export
fisher_implied_alpha <- function(baseline_successes, baseline_trials, test_samples, cutoff) {
  check_count(cutoff, "cutoff", 0)
  if (cutoff > test_samples) stop("cutoff must be at most test_samples", call. = FALSE)
  if (cutoff == 0) return(0)
  below <- fisher_pvalue(cutoff - 1, baseline_successes, baseline_trials, test_samples)
  at <- fisher_pvalue(cutoff, baseline_successes, baseline_trials, test_samples)
  if (!(below < at)) return(NA_real_)
  below
}

#' Configuration error of an empirical (regression) configuration
#'
#' `TEST_LARGER_THAN_BASELINE` when n_t > n_b (a design rule); NA
#' otherwise. regression/fisher never exceeds alpha, so no configuration
#' is refused on calibration grounds.
#'
#' @param baseline_trials n_b.
#' @param test_samples n_t.
#' @return A configuration-error code or NA_character_.
#' @export
regression_configuration_error <- function(baseline_trials, test_samples) {
  check_count(baseline_trials, "baseline_trials", 1)
  check_count(test_samples, "test_samples", 1)
  if (test_samples > baseline_trials) return("TEST_LARGER_THAN_BASELINE")
  NA_character_
}

# ===========================================================================
# compliance/exact-binomial, version 1
# ===========================================================================

#' Smallest passing count of compliance/exact-binomial
#'
#' k_min = min{k : P_{p_req}(K >= k) <= alpha}, K ~ Bin(n, p_req); PASS
#' iff K >= k_min. NA when no count can pass (the design is infeasible).
#'
#' @param threshold p_req.
#' @param n Test size.
#' @param alpha One-sided level.
#' @return Integer or NA.
#' @export
exact_binomial_k_min <- function(threshold, n, alpha) {
  check_count(n, "n", 1)
  check_alpha(alpha)
  upper <- pbinom(0:n - 1, n, threshold, lower.tail = FALSE)  # P(K >= k), k = 0..n
  ok <- which(upper <= alpha)
  if (length(ok) == 0) NA_integer_ else as.integer(ok[1] - 1L)
}

#' k_min for every n in `ns` at once (sizing searches)
#'
#' A qbinom candidate repaired against the definition until stable, so
#' it equals `exact_binomial_k_min()` at every n.
#' @keywords internal
exact_binomial_k_min_vec <- function(ns, threshold, alpha) {
  k <- qbinom(1 - alpha, ns, threshold) + 1
  repeat {
    up <- pbinom(k - 1, ns, threshold, lower.tail = FALSE) > alpha  # k too small
    dn <- k > 0 & pbinom(k - 2, ns, threshold, lower.tail = FALSE) <= alpha  # k - 1 passes
    if (!any(up) && !any(dn)) break
    k[up] <- k[up] + 1
    k[dn] <- k[dn] - 1
  }
  ifelse(k > ns, NA_integer_, as.integer(k))
}

#' Feasibility of compliance/exact-binomial
#'
#' PASS is possible at n iff P_{p_req}(K >= n) = p_req^n <= alpha; the
#' minimum is ceiling(log(alpha) / log(p_req)), confirmed against the
#' definition so floating point cannot move it by one.
#'
#' @param threshold p_req.
#' @param alpha One-sided level.
#' @return Integer, the smallest feasible n.
#' @export
exact_binomial_min_feasible_n <- function(threshold, alpha) {
  check_alpha(alpha)
  if (threshold <= 0 || threshold >= 1) stop("threshold must be in (0, 1)", call. = FALSE)
  n <- as.integer(ceiling(log(alpha) / log(threshold)))
  top <- function(m) pbinom(m - 1, m, threshold, lower.tail = FALSE)  # P(K >= m)
  while (n > 1L && top(n - 1L) <= alpha) n <- n - 1L
  while (top(n) > alpha) n <- n + 1L
  max(n, 1L)
}

#' Exact P(PASS) of compliance/exact-binomial at a true rate p
#' @export
exact_binomial_pass_probability <- function(threshold, n, alpha, p) {
  k <- exact_binomial_k_min(threshold, n, alpha)
  if (is.na(k)) 0 else pbinom(k - 1, n, p, lower.tail = FALSE)
}

#' Clopper-Pearson one-sided lower bound at level 1 - alpha (0 at k = 0)
#' @export
clopper_pearson_lower <- function(successes, n, alpha) {
  if (successes == 0) 0 else qbeta(alpha, successes, n - successes + 1)
}

#' The sizing alternative for compliance/exact-binomial
#'
#' p_req + delta, or the midway rate (p_req + 1)/2 where p_req + delta >= 1
#' and the contract declares no alternative.
#' @export
compliance_sizing_alternative <- function(threshold, delta) {
  if (threshold + delta < 1) {
    list(rate = threshold + delta, kind = "MARGIN")
  } else {
    list(rate = (threshold + 1) / 2, kind = "MIDWAY")
  }
}

#' Exact sizing of compliance/exact-binomial
#'
#' The smallest n from which P(PASS | alternative) stays at or above the
#' target power for every larger n up to `n_max` (not the first crossing:
#' power is a sawtooth in n). Infeasible n have P(PASS) = 0, so the
#' feasibility gate sits inside the search. NA (unsettled) when power is
#' still below target at `n_max`.
#'
#' @param threshold p_req.
#' @param delta Declared margin.
#' @param alpha One-sided level.
#' @param power Target power.
#' @param n_max Search horizon.
#' @return A list: required_samples, first_crossing, achieved_power,
#'   alternative_rate, alternative_kind.
#' @export
compliance_exact_sizing <- function(threshold, delta, alpha, power = 0.80, n_max = 20000L) {
  alt <- compliance_sizing_alternative(threshold, delta)
  ns <- seq_len(n_max)
  k <- exact_binomial_k_min_vec(ns, threshold, alpha)
  pw <- ifelse(is.na(k), 0, pbinom(k - 1, ns, alt$rate, lower.tail = FALSE))
  below <- which(pw < power)
  stays <- if (length(below) == 0) 1L else if (max(below) == n_max) NA_integer_ else
    as.integer(max(below) + 1L)
  list(
    required_samples = stays,
    first_crossing = as.integer(which(pw >= power)[1]),
    achieved_power = if (is.na(stays)) NA_real_ else pw[stays],
    alternative_rate = alt$rate,
    alternative_kind = alt$kind
  )
}

#' Configuration error of a normative (compliance) configuration
#'
#' `COMPLIANCE_INFEASIBLE` when n is below the feasibility minimum under
#' VERIFICATION intent; SMOKE is exempt (it runs and reports that PASS is
#' not possible at this size). NA otherwise.
#' @export
compliance_configuration_error <- function(threshold, n, alpha, intent) {
  if (!intent %in% c("VERIFICATION", "SMOKE")) stop("intent must be VERIFICATION or SMOKE", call. = FALSE)
  if (intent == "VERIFICATION" && n < exact_binomial_min_feasible_n(threshold, alpha)) {
    return("COMPLIANCE_INFEASIBLE")
  }
  NA_character_
}

# ===========================================================================
# latency/precedence, version 1
# ===========================================================================

#' @keywords internal
latency_percentile_P <- function(p) {
  P <- as.integer(round(100 * p))
  if (!P %in% SUPPORTED_LATENCY_PERCENTILES || abs(100 * p - P) > 1e-9) {
    stop("latency percentile must be one of p50, p90, p95, p99", call. = FALSE)
  }
  P
}

#' Nearest-rank index of the test percentile, in integer arithmetic
#'
#' r = ceiling(P * n_t / 100) with P in {50, 90, 95, 99}.
#' @export
latency_test_rank <- function(test_samples, p) {
  check_count(test_samples, "test_samples", 1)
  P <- latency_percentile_P(p)
  as.integer((P * test_samples + 99L) %/% 100L)
}

#' No-degradation breach probability of baseline rank k
#'
#' breach(k) = sum_{j=0}^{r-1} C(n_t, j) B(k + j, n_b - k + 1 + n_t - j)
#'             / B(k, n_b - k + 1),
#' the probability, for continuous i.i.d. latencies, that fewer than r of
#' the n_t test latencies fall at or below the baseline's k-th order
#' statistic (so the test's nearest-rank percentile exceeds it).
#' Vectorised in k.
#' @export
latency_breach_probability <- function(n_b, k, test_samples, p) {
  r <- latency_test_rank(test_samples, p)
  j <- 0:(r - 1L)
  vapply(k, function(kk) {
    sum(exp(lchoose(test_samples, j) + lbeta(kk + j, n_b - kk + 1 + test_samples - j) -
              lbeta(kk, n_b - kk + 1)))
  }, numeric(1))
}

#' Precedence rank of latency/precedence
#'
#' The smallest k in 1..n_b with breach(k) <= alpha; NA when none
#' achieves alpha (the result is INCONCLUSIVE, saturated).
#' @export
latency_precedence_rank <- function(n_b, test_samples, p, alpha) {
  check_count(n_b, "n_b", 1)
  check_alpha(alpha)
  for (k in seq_len(n_b)) {
    if (latency_breach_probability(n_b, k, test_samples, p) <= alpha) return(as.integer(k))
  }
  NA_integer_
}

#' Latency threshold under latency/precedence
#'
#' @param baseline_latencies Successful-sample latencies (integer ms).
#' @param test_samples n_t.
#' @param p Percentile level (0.50, 0.90, 0.95, 0.99).
#' @param alpha One-sided level.
#' @return A list: rank, threshold, saturated, breach_probability,
#'   test_rank, n, baseline_percentile.
#' @export
latency_precedence_threshold <- function(baseline_latencies, test_samples, p, alpha) {
  sorted <- sort(baseline_latencies)
  n_b <- length(sorted)
  k <- latency_precedence_rank(n_b, test_samples, p, alpha)
  saturated <- is.na(k)
  list(
    rank = k,
    threshold = if (saturated) NA_real_ else sorted[k],
    saturated = saturated,
    breach_probability = if (saturated) NA_real_ else
      latency_breach_probability(n_b, k, test_samples, p),
    test_rank = latency_test_rank(test_samples, p),
    n = as.integer(n_b),
    baseline_percentile = nearest_rank_percentile(sorted, p)
  )
}
