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

#' Generate threshold derivation reference cases
#'
#' @return A list suitable for JSON serialisation.
#' @export
generate_threshold_derivation_cases <- function() {
  cases <- list(
    # Sample-size-first cases — general (k < n)
    list(
      name = "ssf_95_of_100_test50_95pct",
      approach = "sample_size_first",
      inputs = list(
        baseline_successes = 95L, baseline_trials = 100L,
        test_samples = 50L, confidence = 0.95
      ),
      expected = ssf_expected_block(95, 100, 50, 0.95)
    ),
    list(
      name = "ssf_950_of_1000_test100_95pct",
      approach = "sample_size_first",
      inputs = list(
        baseline_successes = 950L, baseline_trials = 1000L,
        test_samples = 100L, confidence = 0.95
      ),
      expected = ssf_expected_block(950, 1000, 100, 0.95)
    ),
    # Sample-size-first case — perfect-baseline two-step (companion §4.3.2)
    list(
      name = "ssf_perfect_baseline_test50_95pct",
      approach = "sample_size_first",
      inputs = list(
        baseline_successes = 100L, baseline_trials = 100L,
        test_samples = 50L, confidence = 0.95
      ),
      expected = ssf_expected_block(100, 100, 50, 0.95)
    ),
    list(
      name = "ssf_perfect_baseline_n1000_test100_95pct",
      approach = "sample_size_first",
      inputs = list(
        baseline_successes = 1000L, baseline_trials = 1000L,
        test_samples = 100L, confidence = 0.95
      ),
      # Companion §4.3.2 worked example: real-valued ≈ 0.9686, cutoff ≈ 97
      expected = ssf_expected_block(1000, 1000, 100, 0.95)
    ),
    # Sample-size-first case — zero baseline (companion §4.3.4)
    #
    # The mirror of the perfect-baseline cases above. At k = 0 the
    # effective baseline rate is exactly 0 at every n, so the derivation
    # degenerates: threshold 0, cutoff 0, and an achieved size of 0
    # because a cutoff of 0 excludes no outcome. A baseline that
    # succeeded on no attempt can demand nothing of its successor, and
    # these cases publish that rather than leaving each framework to
    # infer it.
    #
    # The two test sizes are chosen, not arbitrary. n_test = 50 and
    # n_test = 200 are where the one-sided 95% arithmetic failed to
    # cancel to zero and left a residue near 1e-18 — invisible against
    # the suite's 1e-6 tolerance on `threshold`, and decisive on
    # `cutoff_integer`, which ceiling() lifts from 0 to 1. These are the
    # cases that hold the fix in place.
    list(
      name = "ssf_zero_baseline_n10_test50_95pct",
      approach = "sample_size_first",
      inputs = list(
        baseline_successes = 0L, baseline_trials = 10L,
        test_samples = 50L, confidence = 0.95
      ),
      expected = ssf_expected_block(0, 10, 50, 0.95)
    ),
    list(
      name = "ssf_zero_baseline_n1000_test200_95pct",
      approach = "sample_size_first",
      inputs = list(
        baseline_successes = 0L, baseline_trials = 1000L,
        test_samples = 200L, confidence = 0.95
      ),
      expected = ssf_expected_block(0, 1000, 200, 0.95)
    ),
    # Same zero baseline at a different confidence: p_0 = 0 does not
    # move with z any more than it moves with n. n_test = 85 rather than
    # a round number because the round ones mostly cancel cleanly — 85 is
    # a residue site at 99%, so this case discriminates as the other two
    # do instead of merely agreeing with everyone.
    list(
      name = "ssf_zero_baseline_n100_test85_99pct",
      approach = "sample_size_first",
      inputs = list(
        baseline_successes = 0L, baseline_trials = 100L,
        test_samples = 85L, confidence = 0.99
      ),
      expected = ssf_expected_block(0, 100, 85, 0.99)
    ),
    # Sample-size-first sensitivity to test sample size — companion §3.5
    list(
      name = "ssf_950_of_1000_test50_95pct",
      approach = "sample_size_first",
      inputs = list(
        baseline_successes = 950L, baseline_trials = 1000L,
        test_samples = 50L, confidence = 0.95
      ),
      expected = ssf_expected_block(950, 1000, 50, 0.95)
    ),
    list(
      name = "ssf_950_of_1000_test200_95pct",
      approach = "sample_size_first",
      inputs = list(
        baseline_successes = 950L, baseline_trials = 1000L,
        test_samples = 200L, confidence = 0.95
      ),
      expected = ssf_expected_block(950, 1000, 200, 0.95)
    ),
    # Sample-size-first at higher confidence
    list(
      name = "ssf_95_of_100_test50_99pct",
      approach = "sample_size_first",
      inputs = list(
        baseline_successes = 95L, baseline_trials = 100L,
        test_samples = 50L, confidence = 0.99
      ),
      expected = ssf_expected_block(95, 100, 50, 0.99)
    ),
    # SC-RU-02 worked example: baseline 0.951, test n = 100, alpha = 0.05
    # Companion §3.4 reports wilson_lower_real ≈ 0.902124,
    # cutoff = 91, achieved_size ≈ 0.024986.
    list(
      name = "ssf_sc_ru_02_worked_example",
      approach = "sample_size_first",
      inputs = list(
        baseline_successes = 951L, baseline_trials = 1000L,
        test_samples = 100L, confidence = 0.95
      ),
      expected = ssf_expected_block(951, 1000, 100, 0.95)
    ),
    # Threshold-first cases (now require test_samples per companion §6.3)
    list(
      name = "tf_baseline_95pct_test100_threshold_90",
      approach = "threshold_first",
      inputs = list(
        baseline_successes = 95L, baseline_trials = 100L,
        test_samples = 100L, threshold = 0.90
      ),
      expected = threshold_first_implied_confidence(95, 100, 100, 0.90)
    ),
    list(
      name = "tf_baseline_95pct_test100_threshold_85",
      approach = "threshold_first",
      inputs = list(
        baseline_successes = 95L, baseline_trials = 100L,
        test_samples = 100L, threshold = 0.85
      ),
      expected = threshold_first_implied_confidence(95, 100, 100, 0.85)
    ),
    list(
      name = "tf_baseline_95pct_test100_threshold_94",
      approach = "threshold_first",
      inputs = list(
        baseline_successes = 95L, baseline_trials = 100L,
        test_samples = 100L, threshold = 0.94
      ),
      expected = threshold_first_implied_confidence(95, 100, 100, 0.94)
    )
  )

  list(
    suite = "threshold_derivation",
    description = paste(
      "Threshold derivation per the statistical companion: §3.4 for the",
      "general case, §4.3.2 for the perfect-baseline two-step, §4.3.4 for",
      "the zero-baseline degeneration, §6.3 for",
      "threshold-first inversion. The threshold is the one-sided Wilson",
      "lower bound at the *test* sample size; smaller test samples lower",
      "the threshold (§3.5)."
    ),
    method = "Wilson lower bound at test sample size (§3.4 / §4.3.2 / §4.3.4); binary search for implied confidence (§6.3)",
    tolerance = 1e-6,
    cases = cases
  )
}
