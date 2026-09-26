#' Calibration certification machinery for the 1.5.0 decision rules.
#'
#' These functions produce the certification surfaces (published as a
#' separate release asset by `scripts/certify.R`, never in inst/cases/)
#' and derive and verify the calibration-tolerance rule. They are
#' certification-time tools: nothing here is a decision rule, and the
#' one-sided Fisher test below is used only as a power benchmark.

# The p grid of the fine scan: step 0.0005 on [0.50, 0.99] and 0.00005 on
# (0.99, 0.9999].
CERTIFICATION_P_GRID <- c(seq(0.50, 0.99, by = 0.0005), seq(0.99005, 0.9999, by = 0.00005))

# The tolerance on regression/score-cc's unconditional size.
CALIBRATION_TOLERANCE_FACTOR <- 1.2

#' Worst-case unconditional size of regression/score-cc over a p grid
#'
#' @param n_b,n_t Baseline and test sizes.
#' @param alpha One-sided level.
#' @param p_grid Values of the common success probability to scan.
#' @return A list: worst_size, at_p, p_over_tolerance (count of grid
#'   points with size > 1.2 alpha), monotone (cutoff non-decreasing in K_b).
#' @export
score_cc_worst_size <- function(n_b, n_t, alpha, p_grid = CERTIFICATION_P_GRID,
                                verify_interval = FALSE) {
  cut <- score_cc_cutoffs(n_b, n_t, alpha, verify_interval = verify_interval)
  sz <- score_cc_size(n_b, n_t, alpha, p_grid, cutoffs = cut)
  j <- which.max(sz)
  list(worst_size = sz[j], at_p = p_grid[j],
       p_over_tolerance = sum(sz > CALIBRATION_TOLERANCE_FACTOR * alpha),
       monotone = all(diff(cut) >= 0L))
}

#' One-sided Fisher exact test as an integer cutoff (benchmark only)
#'
#' p-value of k_t: P(X <= k_t | margins), X hypergeometric; FAIL iff the
#' p-value <= alpha. Returns, for K_b = 0..n_b, the smallest k_t whose
#' p-value exceeds alpha (vectorised bisection; the p-value is
#' non-decreasing in k_t, checked at the boundary).
#' @keywords internal
fisher_cutoffs <- function(n_b, n_t, alpha) {
  k_b <- 0:n_b
  pval <- function(k_t, idx) {
    s <- k_b[idx] + k_t
    phyper(k_t, s, n_b + n_t - s, n_t)
  }
  lo <- rep(-1L, length(k_b)); hi <- rep(as.integer(n_t), length(k_b))
  repeat {
    open <- which(hi - lo > 1L)
    if (length(open) == 0) break
    mid <- (lo[open] + hi[open]) %/% 2L
    p <- pval(mid, open) > alpha
    hi[open[p]] <- mid[p]
    lo[open[!p]] <- mid[!p]
  }
  all_idx <- seq_along(k_b)
  low <- hi > 0L
  if (!all(pval(hi, all_idx) > alpha) ||
      any(pval(hi[low] - 1L, all_idx[low]) > alpha)) {
    stop("Fisher cutoff boundary check failed", call. = FALSE)
  }
  hi
}

#' Exact power of the one-sided Fisher benchmark
#' @keywords internal
fisher_power <- function(n_b, n_t, alpha, baseline_rate, delta,
                         cutoffs = fisher_cutoffs(n_b, n_t, alpha)) {
  score_cc_fail_probability(cutoffs, n_b, n_t, baseline_rate, baseline_rate - delta)
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

#' Derive a staircase calibration-tolerance rule from a scan
#'
#' From one alpha's scan (columns n_b, n_t, out), where `out` marks
#' configurations whose worst-case size exceeds 1.2 alpha, builds rows
#' (min_baseline_trials, max_test_ratio) such that a configuration is
#' refused iff n_b >= min_baseline_trials and n_t / n_b <= max_test_ratio
#' for some row. Conservative in both directions between grid points:
#'   - for each scanned n_b with an out-of-tolerance configuration, the
#'     ratio bound is the smallest scanned in-tolerance ratio above every
#'     out-of-tolerance ratio at that n_b (or 1 if none), so the unscanned
#'     gap between the last refused and the first accepted ratio is
#'     refused;
#'   - the row applies from just above the previous scanned n_b, so the
#'     unscanned baseline sizes below the first refused one are refused;
#'   - the bound is carried forward to every larger n_b (a staircase).
#' The ratio is published as a fraction over `den`, rounded up.
#'
#' @param scan data.frame with n_b, n_t, out (logical).
#' @param den Denominator of the published ratio.
#' @return data.frame of rows: min_baseline_trials, ratio_num, ratio_den.
#' @export
derive_tolerance_staircase <- function(scan, den = 1000L) {
  nbs <- sort(unique(scan$n_b))
  bound <- numeric(length(nbs))
  for (i in seq_along(nbs)) {
    s <- scan[scan$n_b == nbs[i], ]
    r <- s$n_t / s$n_b
    if (!any(s$out)) next
    worst <- max(r[s$out])
    above <- r[!s$out & r > worst]
    bound[i] <- if (length(above)) min(above) else 1
  }
  if (!any(bound > 0)) {
    return(data.frame(min_baseline_trials = integer(0), ratio_num = integer(0),
                      ratio_den = integer(0)))
  }
  carried <- cummax(bound)
  rows <- list()
  prev <- 0
  for (i in seq_along(nbs)) {
    if (carried[i] > prev) {
      min_nb <- if (i == 1) 1L else as.integer(nbs[i - 1] + 1)
      rows[[length(rows) + 1]] <- data.frame(
        min_baseline_trials = min_nb,
        ratio_num = as.integer(ceiling(carried[i] * den - 1e-9)),
        ratio_den = as.integer(den))
      prev <- carried[i]
    }
  }
  do.call(rbind, rows)
}
