#' Calibration certification machinery for the 2.0.0 decision rules.
#'
#' These functions produce the certification surfaces (published as a
#' separate release asset by `scripts/certify.R`, never in inst/cases/).
#' They are certification-time tools: nothing here is a decision rule.
#' The beta-binomial predictive rule below is used only as a power
#' comparison disclosing how conservative regression/fisher is.

# The p grid of the fine scan: step 0.0005 on [0.50, 0.99], 0.00005 on
# (0.99, 0.9999] and 0.000005 on (0.9999, 0.99999].
CERTIFICATION_P_GRID <- c(seq(0.50, 0.99, by = 0.0005), seq(0.99005, 0.9999, by = 0.00005),
                          seq(0.999905, 0.99999, by = 0.000005))

#' Worst-case unconditional size of regression/fisher over a p grid
#'
#' @param n_b,n_t Baseline and test sizes.
#' @param alpha One-sided level.
#' @param p_grid Values of the common success probability to scan.
#' @return A list: worst_size, at_p, p_over_alpha (count of grid points
#'   with size > alpha), monotone (cutoff non-decreasing in K_b).
#' @export
fisher_worst_size <- function(n_b, n_t, alpha, p_grid = CERTIFICATION_P_GRID) {
  cut <- fisher_cutoffs(n_b, n_t, alpha)
  sz <- fisher_size(n_b, n_t, alpha, p_grid, cutoffs = cut)
  j <- which.max(sz)
  list(worst_size = sz[j], at_p = p_grid[j], p_over_alpha = sum(sz > alpha),
       monotone = all(diff(cut) >= 0L))
}

#' Beta-binomial predictive cutoffs (comparison only, never a rule)
#'
#' Jeffreys prior a = b = 1/2: K_t | K_b ~ BetaBinomial(n_t, a + K_b,
#' b + n_b - K_b); c = the largest integer with P_pred(K_t < c) <= alpha.
#' @keywords internal
bbpred_cutoffs <- function(n_b, n_t, alpha, a = 0.5, b = 0.5) {
  x <- 0:n_t
  vapply(0:n_b, function(k) {
    d <- exp(lchoose(n_t, x) + lbeta(x + a + k, n_t - x + b + n_b - k) - lbeta(a + k, b + n_b - k))
    as.integer(sum(cumsum(d)[seq_len(n_t)] <= alpha))
  }, integer(1))
}

#' Precedence rank by bisection (certification speed)
#'
#' breach(k) is decreasing in k, so the smallest k with breach <= alpha
#' is found by bisection; equals `latency_precedence_rank()`.
#' @keywords internal
latency_precedence_rank_fast <- function(n_b, test_samples, p, alpha) {
  br <- function(k) latency_breach_probability(n_b, k, test_samples, p)
  if (br(n_b) > alpha) return(NA_integer_)
  if (br(1L) <= alpha) return(1L)
  lo <- 1L; hi <- as.integer(n_b)  # br(lo) > alpha >= br(hi)
  while (hi - lo > 1L) {
    mid <- (lo + hi) %/% 2L
    if (br(mid) <= alpha) hi <- mid else lo <- mid
  }
  hi
}
