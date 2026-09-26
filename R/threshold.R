#' Legacy: the v1.4.1 regression construction, `regression/wilson-reference` v1.
#'
#' Withdrawn as a decision rule by Statistical Companion 1.5.0, which
#' replaces it with `regression/fisher` (R/decision_rules.R). Kept, under
#' its legacy identifier, only to reproduce methodology-1.4.1 outputs and to
#' compare the two generations; no 1.5.0 fixture is computed from it. The
#' 1.4.1 fixtures themselves are the immutable release assets of v0.10.13.
#' @name legacy_wilson_reference
NULL

#' Derive threshold using the sample-size-first approach (companion §3.4 / §4.3)
#'
#' Given a baseline (successes/trials) and a *test* sample size, derives the
#' minimum pass rate the test must observe so that, if the true rate equals
#' the baseline's effective rate, the false-positive rate is at most
#' (1 - confidence). The threshold is sample-size sensitive: smaller test
#' samples carry wider sampling noise and therefore require a lower
#' threshold to maintain the same false-positive rate.
#'
#' Construction:
#'  - **General case** (k < n): the effective baseline rate is the point
#'    estimate `p_hat = k/n`, and the threshold is the one-sided Wilson
#'    lower bound at `(p_hat, test_samples, confidence)` per §3.4.
#'  - **Perfect-baseline case** (k == n): the point estimate `p_hat = 1`
#'    must not be used directly (a perfect empirical observation does not
#'    prove perfect population reliability). Per §4.3.2, the effective
#'    baseline rate is first compressed to the Wilson lower bound on the
#'    baseline itself, `p_0 = wilson_lower(k, n, confidence) = n / (n + z^2)`,
#'    and then the threshold is the Wilson lower bound at
#'    `(p_0, test_samples, confidence)`.
#'  - **Zero-baseline case** (k == 0): the effective baseline rate is the
#'    point estimate 0, and per §4.3.4 the Wilson lower bound at a zero
#'    rate is exactly 0 — so the derivation degenerates to a threshold of
#'    0 and a cutoff of 0. This is defined, not refused: a baseline that
#'    succeeded on no attempt can demand nothing of its successor.
#'    (Sizing, unlike derivation, has no answer here — see §5.4.1 and
#'    `risk_driven_sizing`.)
#'
#' @param baseline_successes Integer. Successes observed in baseline.
#' @param baseline_trials Integer. Total baseline trials.
#' @param test_samples Integer. Number of test samples to be run.
#' @param confidence Numeric. Confidence level.
#' @return Numeric. The derived threshold the test must clear.
#' @export
threshold_sample_size_first <- function(baseline_successes, baseline_trials,
                                        test_samples, confidence) {
  effective_baseline_rate <- effective_baseline_rate(
    baseline_successes, baseline_trials, confidence)
  wilson_lower_from_rate(effective_baseline_rate, test_samples, confidence)
}

#' Effective baseline rate for threshold derivation
#'
#' Returns the rate the threshold-derivation construction treats as the
#' baseline's true success probability:
#'  - the point estimate `p_hat = k/n` in the general case;
#'  - the Wilson lower bound `n / (n + z^2)` when `k == n` (companion §4.3.2,
#'    Step 1) so that a perfect empirical observation is not promoted to
#'    proof of perfect population reliability.
#'
#' At `k == 0` the general branch already returns the right answer: the
#' point estimate is 0, and §4.3.4 gives the Wilson lower bound at a zero
#' rate as exactly 0. The boundary needs no branch of its own here — it
#' needs one in `wilson_lower_from_rate`, where the cancellation is.
#'
#' @keywords internal
effective_baseline_rate <- function(baseline_successes, baseline_trials, confidence) {
  if (baseline_successes == baseline_trials) {
    wilson_lower(baseline_successes, baseline_trials, confidence)
  } else {
    baseline_successes / baseline_trials
  }
}

#' Derive implied confidence from an explicit threshold (companion §6.3)
#'
#' Given a baseline, a test sample size, and an explicit threshold, finds
#' the confidence level at which the threshold-derivation construction
#' (`threshold_sample_size_first`) would have produced this threshold.
#' Uses binary search; there is no closed-form inverse.
#'
#' @param baseline_successes Integer. Successes in baseline.
#' @param baseline_trials Integer. Trials in baseline.
#' @param test_samples Integer. Number of test samples to be run.
#' @param threshold Numeric. The explicit threshold whose implied confidence is sought.
#' @param tol Numeric. Convergence tolerance for binary search.
#' @return A list with implied_confidence and is_sound (>= 0.80).
#' @export
threshold_first_implied_confidence <- function(baseline_successes,
                                                baseline_trials,
                                                test_samples,
                                                threshold,
                                                tol = 1e-10) {
  lo <- 0.001
  hi <- 0.999

  for (i in seq_len(200)) {
    mid <- (lo + hi) / 2
    derived <- threshold_sample_size_first(
      baseline_successes, baseline_trials, test_samples, mid)
    if (abs(derived - threshold) < tol) break
    # threshold_sample_size_first is monotone-decreasing in confidence:
    # higher confidence => wider Wilson margin => lower threshold.
    if (derived > threshold) {
      lo <- mid
    } else {
      hi <- mid
    }
  }

  implied <- (lo + hi) / 2
  list(
    implied_confidence = implied,
    is_sound = implied >= 0.80
  )
}

#' Sample-size-first threshold + integer cutoff + achieved size (SC-RU-02)
#'
#' Companion v1.3 / SC-RU-02 distinguishes three artefacts of the
#' threshold-derivation construction:
#'   - `wilson_lower_real` — the real-valued Wilson lower bound.
#'     Synonym for the historical `threshold` field; preserved under
#'     both names for backward compatibility.
#'   - `cutoff_integer`    — the binding decision artefact
#'     c = ceiling(test_samples * wilson_lower_real). The test
#'     decides PASS / FAIL on K >= c, not on rounded rates.
#'   - `achieved_size`     — the lower-tail false-degradation
#'     probability at the integer cutoff under the effective baseline
#'     rate p_0: P_{p_0}(K < c). Typically less than nominal alpha
#'     because the cutoff is discretised upward.
#'
#' @keywords internal
ssf_expected_block <- function(baseline_successes, baseline_trials,
                               test_samples, confidence) {
  wlr <- threshold_sample_size_first(baseline_successes, baseline_trials,
                                     test_samples, confidence)
  c_int <- ceiling(test_samples * wlr)
  p_0 <- effective_baseline_rate(baseline_successes, baseline_trials, confidence)
  achieved <- pbinom(c_int - 1, size = test_samples, prob = p_0)
  list(
    threshold          = wlr,   # backward-compatible synonym
    wilson_lower_real  = wlr,
    cutoff_integer     = as.integer(c_int),
    achieved_size      = achieved
  )
}
