#' Empirical regression under regression/fisher: derivation and verdict.
#'
#' Two suites, two layers of the same rule (companion §3.4):
#'
#'   - `threshold_derivation` — the decision-rule layer:
#'     (K_b, n_b, n_t, alpha) -> the integer cutoff c, or the
#'     configuration error that refuses the configuration; and the
#'     threshold-first inversion, a declared cutoff -> its implied alpha.
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
fisher_expected_block <- function(baseline_successes, baseline_trials, test_samples, alpha) {
  err <- regression_configuration_error(baseline_trials, test_samples)
  if (!is.na(err)) {
    return(list(cutoff_integer = NA_integer_, configuration_error = err,
                threshold_real = NA_real_, displayed_rate = NA_real_,
                achieved_size = NA_real_))
  }
  cut <- fisher_cutoffs(baseline_trials, test_samples, alpha)
  c_int <- cut[baseline_successes + 1L]
  stopifnot(c_int == fisher_cutoff(baseline_successes, baseline_trials, test_samples, alpha))
  p_hat <- baseline_successes / baseline_trials
  list(
    cutoff_integer = c_int,
    configuration_error = NA_character_,
    threshold_real = c_int / test_samples,
    displayed_rate = round(c_int / test_samples, 6),
    achieved_size = if (p_hat %in% c(0, 1)) NA_real_ else
      regression_fail_probability(cut, baseline_trials, test_samples, p_hat, p_hat)
  )
}

#' @keywords internal
derivation_case <- function(name, baseline_successes, baseline_trials, test_samples, alpha,
                            description = NULL) {
  case <- list(name = name, approach = "sample_size_first")
  if (!is.null(description)) case$description <- description
  c(case, list(
    inputs = list(baseline_successes = as.integer(baseline_successes),
                  baseline_trials = as.integer(baseline_trials),
                  test_samples = as.integer(test_samples), alpha = alpha),
    expected = fisher_expected_block(baseline_successes, baseline_trials, test_samples, alpha)
  ))
}

#' One regression verdict: derived cutoff, PASS iff K_t >= c.
#' @keywords internal
regression_decision_case <- function(name, baseline_successes, baseline_trials,
                                     test_samples, alpha, observed_successes,
                                     description = NULL) {
  block <- fisher_expected_block(baseline_successes, baseline_trials, test_samples, alpha)
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
  "regression/fisher v1: for k_t = 0..n_t, the one-sided Fisher p-value is the hypergeometric ",
  "lower tail P(X <= k_t) = phyper(k_t, s, n_b + n_t - s, n_t) with s = K_b + k_t pooled ",
  "successes; k_t FAILs iff the p-value <= alpha; c = the smallest k_t whose p-value exceeds ",
  "alpha. Configuration error, checked first: TEST_LARGER_THAN_BASELINE when n_t > n_b. ",
  "Informational: threshold_real = c/n_t; displayed_rate = round(c/n_t, 6); achieved_size = ",
  "sum_k P_p(K_b = k) P_p(K_t < c(k)) at p = K_b/n_b (null at K_b/n_b in {0, 1})."
)

#' One threshold-first case: a declared cutoff and its implied alpha.
#' @keywords internal
threshold_first_case <- function(name, baseline_successes, baseline_trials, test_samples,
                                 declared_cutoff, description = NULL) {
  a <- fisher_implied_alpha(baseline_successes, baseline_trials, test_samples, declared_cutoff)
  case <- list(name = name, approach = "threshold_first")
  if (!is.null(description)) case$description <- description
  c(case, list(
    inputs = list(baseline_successes = as.integer(baseline_successes),
                  baseline_trials = as.integer(baseline_trials),
                  test_samples = as.integer(test_samples),
                  declared_cutoff = as.integer(declared_cutoff)),
    expected = list(implied_alpha = a, is_sound = if (is.na(a)) NA else a <= 0.20)
  ))
}

#' Generate the regression/fisher derivation cases
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
    derivation_case("alpha001_951_of_1000_test1000", 951, 1000, 1000, 0.01),
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
    # Exact boundaries: the Fisher p-value of a test count equals alpha
    # exactly (12 of 12 against a test of 4: P(X <= 2) = 1/20). The
    # inclusive rule FAILs that count; double precision alone puts the
    # p-value above alpha. See the exact-boundary convention (§10.6).
    derivation_case("exact_boundary_12_of_12_test4_a05", 12, 12, 4, 0.05,
                    "P(X <= 2) = 1/20 = alpha exactly: k_t = 2 FAILs, so c = 3."),
    derivation_case("exact_boundary_19_of_23_test2_a05", 19, 23, 2, 0.05,
                    "P(X <= 0) = 1/20 = alpha exactly: k_t = 0 FAILs, so c = 1."),
    # Small tests against large baselines at small alpha: no calibration
    # refusal, since the rule never exceeds alpha.
    derivation_case("small_test_large_baseline_951_of_1000_test25_a01", 951, 1000, 25, 0.01),
    derivation_case("small_test_large_baseline_9500_of_10000_test100_a001", 9500, 10000, 100, 0.001),
    # Threshold-first (§6.3): the implied alpha of a declared cutoff, the
    # smallest alpha at which the rule yields it.
    threshold_first_case("tf_951_of_1000_test100_cutoff91", 951, 1000, 100, 91L,
      "The cutoff the rule yields at alpha 0.05; its implied alpha is at most 0.05."),
    threshold_first_case("tf_951_of_1000_test100_cutoff90", 951, 1000, 100, 90L),
    threshold_first_case("tf_951_of_1000_test100_cutoff94", 951, 1000, 100, 94L,
      "A cutoff close to the baseline rate: implied alpha above 0.20, unsound."),
    threshold_first_case("tf_95_of_100_test100_cutoff85", 95, 100, 100, 85L),
    threshold_first_case("tf_zero_cutoff", 95, 100, 100, 0L,
      "Cutoff 0 results at every alpha below the p-value of k_t = 0; the infimum is 0.")
  )

  list(
    suite = "threshold_derivation",
    description = paste(
      "The decision-rule layer of empirical regression (companion §3.4). approach",
      "sample_size_first: from baseline evidence (K_b, n_b), a test size n_t and alpha, the integer",
      "cutoff c of regression/fisher, or the configuration error that refuses the configuration",
      "before any sample runs; the cutoff and configuration_error are binding, threshold_real,",
      "displayed_rate and achieved_size informational. approach threshold_first (§6.3): the implied",
      "alpha of a declared cutoff, the smallest alpha at which the rule yields it (null when no",
      "alpha does), and is_sound = implied_alpha <= 0.20."
    ),
    method = paste(REGRESSION_METHOD, "threshold_first: implied_alpha = P(X <= c - 1) with",
                   "s = K_b + c - 1 (0 at c = 0), null when P(X <= c - 1) = P(X <= c)."),
    tolerance = 1e-10,
    cases = cases
  )
}

#' Generate the regression/fisher verdict cases
#'
#' @return A list suitable for JSON serialisation.
#' @export
generate_regression_decision_cases <- function() {
  worked_c <- fisher_cutoff(951, 1000, 100, 0.05)
  small_c <- fisher_cutoff(27, 30, 25, 0.05)
  near_c <- fisher_cutoff(99, 100, 100, 0.05)
  perfect_c <- fisher_cutoff(100, 100, 100, 0.05)
  equal_c <- fisher_cutoff(951, 1000, 1000, 0.05)
  a01_c <- fisher_cutoff(951, 1000, 1000, 0.01)

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
    # alpha 0.01.
    regression_decision_case("alpha001_pass_at_cutoff", 951, 1000, 1000, 0.01, a01_c),
    regression_decision_case("alpha001_fail_below_cutoff", 951, 1000, 1000, 0.01, a01_c - 1L),
    # Refusals: no verdict is produced.
    regression_decision_case("refused_test_larger_than_baseline", 95, 100, 200, 0.05, 190L),
    # Exact boundary: 2 of 4 against 12 of 12 has Fisher p-value 1/20 = alpha.
    regression_decision_case("exact_boundary_fail_at_alpha", 12, 12, 4, 0.05, 2L,
      "The p-value of the observed count equals alpha exactly; the inclusive rule FAILs it."),
    regression_decision_case("exact_boundary_pass_at_cutoff", 12, 12, 4, 0.05, 3L),
    # A small test against a large baseline at alpha 0.01: admitted.
    regression_decision_case("small_test_large_baseline_pass_at_cutoff", 951, 1000, 25, 0.01,
                             fisher_cutoff(951, 1000, 25, 0.01)),
    regression_decision_case("small_test_large_baseline_fail_below_cutoff", 951, 1000, 25, 0.01,
                             fisher_cutoff(951, 1000, 25, 0.01) - 1L),
    # The conflation detector: this observation PASSes the regression rule;
    # compliance_decision's conflation_detector_compliance_fail FAILs the
    # same observation against c / n_t taken as a given requirement.
    regression_decision_case("conflation_detector_regression_pass", 951, 1000, 100, 0.05, worked_c)
  )

  list(
    suite = "regression_decision",
    description = paste(
      "End-to-end verdicts of empirical regression under regression/fisher (companion §3.4):",
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
