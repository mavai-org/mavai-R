#' Empirical regression under regression/score-cc: derivation and verdict.
#'
#' Two suites, two layers of the same rule (companion §3.4):
#'
#'   - `threshold_derivation` — the decision-rule layer:
#'     (K_b, n_b, n_t, alpha) -> the integer cutoff c, or the
#'     configuration error that refuses the configuration.
#'   - `regression_decision` — the end-to-end layer: the same derivation
#'     composed into a verdict on an observed test count, PASS iff
#'     K_t >= c. Frameworks run these cases through their production
#'     verdict path, not a reimplementation.
#'
#' Binding: cutoff_integer, configuration_error, verdict. Informational
#' (report obligations): threshold_real = c / n_t, displayed_rate =
#' round(c / n_t, 6), and achieved_size = the exact unconditional
#' false-degradation-signal probability A(p) at p = K_b / n_b (null when
#' K_b / n_b is 0 or 1, where A is degenerate).

#' The derivation block for one configuration.
#' @keywords internal
score_cc_expected_block <- function(baseline_successes, baseline_trials, test_samples, alpha) {
  err <- regression_configuration_error(baseline_trials, test_samples, alpha)
  if (!is.na(err)) {
    return(list(cutoff_integer = NA_integer_, configuration_error = err,
                threshold_real = NA_real_, displayed_rate = NA_real_,
                achieved_size = NA_real_))
  }
  cut <- score_cc_cutoffs(baseline_trials, test_samples, alpha)
  c_int <- cut[baseline_successes + 1L]
  stopifnot(c_int == score_cc_cutoff(baseline_successes, baseline_trials, test_samples, alpha))
  p_hat <- baseline_successes / baseline_trials
  list(
    cutoff_integer = c_int,
    configuration_error = NA_character_,
    threshold_real = c_int / test_samples,
    displayed_rate = round(c_int / test_samples, 6),
    achieved_size = if (p_hat %in% c(0, 1)) NA_real_ else
      score_cc_fail_probability(cut, baseline_trials, test_samples, p_hat, p_hat)
  )
}

#' @keywords internal
derivation_case <- function(name, baseline_successes, baseline_trials, test_samples, alpha,
                            description = NULL) {
  case <- list(name = name)
  if (!is.null(description)) case$description <- description
  c(case, list(
    inputs = list(baseline_successes = as.integer(baseline_successes),
                  baseline_trials = as.integer(baseline_trials),
                  test_samples = as.integer(test_samples), alpha = alpha),
    expected = score_cc_expected_block(baseline_successes, baseline_trials, test_samples, alpha)
  ))
}

#' One regression verdict: derived cutoff, PASS iff K_t >= c.
#' @keywords internal
regression_decision_case <- function(name, baseline_successes, baseline_trials,
                                     test_samples, alpha, observed_successes,
                                     description = NULL) {
  block <- score_cc_expected_block(baseline_successes, baseline_trials, test_samples, alpha)
  verdict <- if (!is.na(block$configuration_error)) NA_character_ else
    if (observed_successes >= block$cutoff_integer) "PASS" else "FAIL"
  case <- list(name = name)
  if (!is.null(description)) case$description <- description
  c(case, list(
    inputs = list(baseline_successes = as.integer(baseline_successes),
                  baseline_trials = as.integer(baseline_trials),
                  test_samples = as.integer(test_samples), alpha = alpha,
                  observed_successes = as.integer(observed_successes)),
    expected = c(block, list(verdict = verdict))
  ))
}

REGRESSION_METHOD <- paste0(
  "regression/score-cc v1: for k_t = 0..n_t, d = k_t/n_t - K_b/n_b, d_cc = min(0, d + ",
  "(1/n_b + 1/n_t)/2), p_bar = (K_b + k_t)/(n_b + n_t), v = p_bar (1 - p_bar) (1/n_b + 1/n_t), ",
  "z = d_cc / sqrt(v) (z = 0 when v = 0); c = the smallest k_t with z >= -qnorm(1 - alpha). ",
  "Configuration errors, checked first: TEST_LARGER_THAN_BASELINE when n_t > n_b; ",
  "OUTSIDE_CALIBRATION_TOLERANCE when the published calibration-tolerance rule ",
  "(suite calibration_tolerance_rule) refuses (n_b, n_t, alpha). Informational: ",
  "threshold_real = c/n_t; displayed_rate = round(c/n_t, 6); achieved_size = ",
  "sum_k P_p(K_b = k) P_p(K_t < c(k)) at p = K_b/n_b (null at K_b/n_b in {0, 1})."
)

#' Generate the regression/score-cc derivation cases
#'
#' @return A list suitable for JSON serialisation.
#' @export
generate_threshold_derivation_cases <- function() {
  cases <- list(
    # The companion's canonical cases (§3.4 rate, larger baselines, equal sizes).
    derivation_case("ordinary_951_of_1000_test100_a05", 951, 1000, 100, 0.05),
    derivation_case("ordinary_larger_baseline_1902_of_2000_test100_a05", 1902, 2000, 100, 0.05),
    derivation_case("boundary_equal_sizes_951_of_1000_test1000_a05", 951, 1000, 1000, 0.05,
                    "n_t = n_b: the largest test the design rule admits."),
    derivation_case("large_baseline_small_test_9510_of_10000_test100_a05", 9510, 10000, 100, 0.05),
    # The perfect-baseline discontinuity is gone: 99/100 -> 94, 100/100 -> 96.
    derivation_case("near_perfect_99_of_100_test100_a05", 99, 100, 100, 0.05),
    derivation_case("perfect_100_of_100_test100_a05", 100, 100, 100, 0.05,
                    "No special case at K_b = n_b; the cutoff is monotone in K_b."),
    derivation_case("perfect_large_1000_of_1000_test100_a05", 1000, 1000, 100, 0.05),
    derivation_case("zero_baseline_0_of_100_test50_a05", 0, 100, 50, 0.05,
                    "c = 0 at K_b = 0: a baseline that succeeded on nothing demands nothing."),
    derivation_case("small_baseline_27_of_30_test25_a05", 27, 30, 25, 0.05),
    derivation_case("alpha001_inside_tolerance_951_of_1000_test1000", 951, 1000, 1000, 0.01),
    # Further sizes and levels.
    derivation_case("baseline_95_of_100_test50_a05", 95, 100, 50, 0.05),
    derivation_case("baseline_95_of_100_test50_a01", 95, 100, 50, 0.01),
    derivation_case("baseline_950_of_1000_test50_a05", 950, 1000, 50, 0.05),
    derivation_case("baseline_950_of_1000_test200_a05", 950, 1000, 200, 0.05),
    derivation_case("baseline_950_of_1000_test200_a10", 950, 1000, 200, 0.10),
    derivation_case("baseline_9_of_10_test10_a05", 9, 10, 10, 0.05),
    derivation_case("zero_baseline_0_of_1000_test200_a05", 0, 1000, 200, 0.05),
    derivation_case("zero_baseline_0_of_100_test85_a01", 0, 100, 85, 0.01),
    # Refusals.
    derivation_case("refused_test_larger_than_baseline_95_of_100_test200", 95, 100, 200, 0.05,
                    "n_t > n_b: refused whatever the counts."),
    derivation_case("refused_test_larger_than_baseline_zero_0_of_10_test50", 0, 10, 50, 0.05,
                    "n_t > n_b is refused even at a zero baseline."),
    derivation_case("refused_outside_tolerance_951_of_1000_test25_a01", 951, 1000, 25, 0.01,
                    "Worst-case size 1.313% at p near 0.977 against a tolerance of 1.2%."),
    derivation_case("refused_outside_tolerance_9500_of_10000_test100_a001", 9500, 10000, 100, 0.001)
  )

  list(
    suite = "threshold_derivation",
    description = paste(
      "The decision-rule layer of empirical regression (companion §3.4): from baseline evidence",
      "(K_b, n_b), a test size n_t and alpha, the integer cutoff c of regression/score-cc, or the",
      "configuration error that refuses the configuration before any sample runs. The cutoff",
      "is the binding artefact; configuration_error is binding (null when the configuration is",
      "valid); threshold_real, displayed_rate and achieved_size are informational report values."
    ),
    method = REGRESSION_METHOD,
    tolerance = 1e-10,
    cases = cases
  )
}

#' Generate the regression/score-cc verdict cases
#'
#' @return A list suitable for JSON serialisation.
#' @export
generate_regression_decision_cases <- function() {
  worked_c <- score_cc_cutoff(951, 1000, 100, 0.05)
  small_c <- score_cc_cutoff(27, 30, 25, 0.05)
  near_c <- score_cc_cutoff(99, 100, 100, 0.05)
  perfect_c <- score_cc_cutoff(100, 100, 100, 0.05)
  equal_c <- score_cc_cutoff(951, 1000, 1000, 0.05)
  a01_c <- score_cc_cutoff(951, 1000, 1000, 0.01)

  cases <- list(
    # The §3.4 rate: baseline 951/1000, n_t = 100, c = 91.
    regression_decision_case("worked_example_pass_at_cutoff", 951, 1000, 100, 0.05, worked_c),
    regression_decision_case("worked_example_fail_below_cutoff", 951, 1000, 100, 0.05, worked_c - 1L),
    regression_decision_case("worked_example_pass_above_cutoff", 951, 1000, 100, 0.05, 97L),
    regression_decision_case("worked_example_fail_deep_degradation", 951, 1000, 100, 0.05, 80L),
    # Small baseline and test.
    regression_decision_case("small_test_pass_at_cutoff", 27, 30, 25, 0.05, small_c),
    regression_decision_case("small_test_fail_below_cutoff", 27, 30, 25, 0.05, small_c - 1L),
    # Near-perfect and perfect baselines: the cutoff rises with K_b.
    regression_decision_case("near_perfect_baseline_pass_at_cutoff", 99, 100, 100, 0.05, near_c),
    regression_decision_case("near_perfect_baseline_fail_below_cutoff", 99, 100, 100, 0.05, near_c - 1L),
    regression_decision_case("perfect_baseline_pass_at_cutoff", 100, 100, 100, 0.05, perfect_c),
    regression_decision_case("perfect_baseline_fail_below_cutoff", 100, 100, 100, 0.05, perfect_c - 1L,
      "95 of 100 FAILs against a perfect baseline and PASSes against 99 of 100."),
    # Zero baseline: c = 0, so a test that observed nothing PASSes.
    regression_decision_case("zero_baseline_pass_on_nothing_observed", 0, 100, 50, 0.05, 0L),
    regression_decision_case("zero_baseline_pass_at_test_200", 0, 1000, 200, 0.05, 0L),
    # n_t = n_b, the boundary of the design rule.
    regression_decision_case("boundary_equal_sizes_pass_at_cutoff", 951, 1000, 1000, 0.05, equal_c),
    regression_decision_case("boundary_equal_sizes_fail_below_cutoff", 951, 1000, 1000, 0.05, equal_c - 1L),
    # alpha 0.01 inside the calibration tolerance.
    regression_decision_case("alpha001_pass_at_cutoff", 951, 1000, 1000, 0.01, a01_c),
    regression_decision_case("alpha001_fail_below_cutoff", 951, 1000, 1000, 0.01, a01_c - 1L),
    # Refusals: no verdict is produced.
    regression_decision_case("refused_test_larger_than_baseline", 95, 100, 200, 0.05, 190L),
    regression_decision_case("refused_outside_calibration_tolerance", 951, 1000, 25, 0.01, 25L),
    # The conflation detector: this observation PASSes the regression rule;
    # compliance_decision's conflation_detector_compliance_fail FAILs the
    # same observation against c / n_t taken as a given requirement.
    regression_decision_case("conflation_detector_regression_pass", 951, 1000, 100, 0.05, worked_c)
  )

  list(
    suite = "regression_decision",
    description = paste(
      "End-to-end verdicts of empirical regression under regression/score-cc (companion §3.4):",
      "the cutoff c derived from (K_b, n_b, n_t, alpha) and PASS iff the observed test count",
      "K_t >= c. Refused configurations carry their configuration_error and no verdict.",
      "Binding: cutoff_integer, configuration_error, verdict. Informational: threshold_real,",
      "displayed_rate, achieved_size. Frameworks MUST evaluate these cases through their",
      "production verdict path. The conflation_detector case pairs with compliance_decision's",
      "conflation_detector_compliance_fail: one observation, opposite verdicts under the two rules."
    ),
    method = paste(REGRESSION_METHOD, "PASS iff K_t >= c."),
    tolerance = 1e-10,
    cases = cases
  )
}
