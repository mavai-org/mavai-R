#' The composed decision rule, as end-to-end scenario cases.
#'
#' The formula-value suites validate each computation in isolation; this
#' suite validates the *decision* they compose into, per companion §3.4:
#' for a baseline-derived (regression) test the binding artefact is the
#' integer cutoff c = ceiling(n_test * p*), p* the sample-size-first
#' Wilson lower bound, and the verdict is PASS iff the raw observed
#' success count K >= c. A compliance sibling group (threshold given,
#' not derived; verdict via the test sample's own Wilson lower bound
#' clearing it, §3.2/§3.6) is included so the two procedures' difference
#' is itself fixture-visible: a framework that conflates them fails the
#' suite even when every component computation is arithmetically
#' conformant.
#'
#' Consuming frameworks must run these cases through their production
#' verdict path, not a reimplementation.

#' One regression-procedure scenario: derived cutoff, verdict on K >= c.
#' @keywords internal
regression_decision_case <- function(name, baseline_successes, baseline_trials,
                                     test_samples, confidence,
                                     observed_successes) {
  block <- ssf_expected_block(baseline_successes, baseline_trials,
                              test_samples, confidence)
  c_int <- block$cutoff_integer
  list(
    name = name,
    procedure = "REGRESSION",
    inputs = list(
      baseline_successes = baseline_successes,
      baseline_trials = baseline_trials,
      test_samples = test_samples,
      confidence = confidence,
      observed_successes = observed_successes
    ),
    expected = list(
      threshold_real = block$wilson_lower_real,
      cutoff_integer = c_int,
      displayed_rate = round(c_int / test_samples, 6),
      achieved_size = block$achieved_size,
      verdict = if (observed_successes >= c_int) "PASS" else "FAIL"
    )
  )
}

#' One compliance-procedure scenario: threshold given, Wilson clearance.
#' @keywords internal
compliance_decision_case <- function(name, threshold, test_samples,
                                     confidence, observed_successes) {
  bound <- wilson_lower(observed_successes, test_samples, confidence)
  list(
    name = name,
    procedure = "COMPLIANCE",
    inputs = list(
      threshold = threshold,
      test_samples = test_samples,
      confidence = confidence,
      observed_successes = observed_successes
    ),
    expected = list(
      wilson_lower = bound,
      verdict = if (bound >= threshold) "PASS" else "FAIL"
    )
  )
}

#' Generate the decision-rule scenario cases
#'
#' @return A list suitable for JSON serialisation.
#' @export
generate_regression_decision_cases <- function() {
  worked <- ssf_expected_block(951, 1000, 100, 0.95)
  worked_c <- worked$cutoff_integer

  small <- ssf_expected_block(9, 10, 10, 0.95)
  small_c <- small$cutoff_integer

  perfect <- ssf_expected_block(50, 50, 50, 0.95)
  perfect_c <- perfect$cutoff_integer

  cases <- list(
    # The companion's own worked example (S3.4): p-hat = 0.951,
    # n_test = 100 -> p* ~= 0.902124, c = 91, achieved size ~= 0.024986.
    regression_decision_case("worked_example_pass_at_cutoff",
                             951, 1000, 100, 0.95, worked_c),
    regression_decision_case("worked_example_fail_below_cutoff",
                             951, 1000, 100, 0.95, worked_c - 1L),
    regression_decision_case("worked_example_pass_above_cutoff",
                             951, 1000, 100, 0.95, 97L),
    regression_decision_case("worked_example_fail_deep_degradation",
                             951, 1000, 100, 0.95, 80L),

    # Small-n discretisation: the real-valued bound and the integer
    # cutoff disagree materially; only K >= c is the decision.
    regression_decision_case("small_test_pass_at_cutoff",
                             9, 10, 10, 0.95, small_c),
    regression_decision_case("small_test_fail_below_cutoff",
                             9, 10, 10, 0.95, small_c - 1L),

    # Perfect baseline (k = n): the effective-rate guard (S4.3.2)
    # feeds the derivation; the decision stays K >= c.
    regression_decision_case("perfect_baseline_pass_at_cutoff",
                             50, 50, 50, 0.95, perfect_c),
    regression_decision_case("perfect_baseline_fail_below_cutoff",
                             50, 50, 50, 0.95, perfect_c - 1L),

    # Zero baseline (k = 0): the §4.3.4 degeneration carried all the way
    # to a verdict. The cutoff is 0, so K >= 0 holds for every outcome
    # and the test passes on nothing observed. That reads oddly and is
    # correct — the baseline supports no lower bound above zero, so it
    # can demand nothing — but it is exactly the shape a framework is
    # likely to get wrong, by refusing, by erroring, or by carrying a
    # floating-point residue into ceiling() and demanding one success.
    # n_test = 50 is the residue site; the pair pins both the arithmetic
    # and the verdict it composes into.
    regression_decision_case("zero_baseline_pass_on_nothing_observed",
                             0, 10, 50, 0.95, 0L),
    regression_decision_case("zero_baseline_pass_at_test_200",
                             0, 1000, 200, 0.95, 0L),

    # High confidence variant.
    regression_decision_case("worked_example_high_confidence_at_95_of_100",
                             951, 1000, 100, 0.99, 95L),

    # Compliance siblings (threshold GIVEN; verdict via the test
    # sample's own Wilson lower bound clearing it).
    compliance_decision_case("compliance_pass_clear_margin",
                             0.80, 100, 0.95, 95L),
    compliance_decision_case("compliance_fail_bound_below_threshold",
                             0.90, 100, 0.95, 92L),

    # The conflation detector: the same observation that PASSES the
    # regression procedure (K = c = 91 >= c) FAILS under a compliance
    # reading against the same derived value used as a given threshold
    # (WilsonLower(91, 100, 0.95) < 0.902124). A framework applying the
    # compliance rule on the regression path gets this pair inverted.
    regression_decision_case("conflation_detector_regression_pass",
                             951, 1000, 100, 0.95, worked_c),
    compliance_decision_case("conflation_detector_compliance_fail",
                             round(worked$wilson_lower_real, 6), 100, 0.95,
                             worked_c)
  )

  list(
    suite = "regression_decision",
    description = paste0(
      "End-to-end scenario cases for the composed decision rules. REGRESSION cases derive the ",
      "threshold from a baseline per the sample-size-first construction (companion S3.4) and ",
      "decide PASS iff the raw observed success count K >= cutoff_integer -- the integer cutoff ",
      "is the binding artefact; threshold_real, displayed_rate, and achieved_size are report ",
      "obligations. COMPLIANCE cases take the threshold as given and decide via the test ",
      "sample's own Wilson lower bound clearing it (S3.2/S3.6). The conflation_detector pair ",
      "shares one observation across both procedures with opposite verdicts, so a framework ",
      "that applies the compliance rule on the regression path fails the suite even though ",
      "every component computation is arithmetically conformant. Frameworks MUST evaluate ",
      "these cases through their production verdict path."
    ),
    method = paste0(
      "REGRESSION: p* = sample-size-first Wilson lower bound (with the S4.3.2 perfect-baseline ",
      "guard, and the S4.3.4 zero-baseline degeneration), c = ceiling(n_test * p*), PASS iff ",
      "K >= c; achieved size = P_p0(K < c). ",
      "COMPLIANCE: PASS iff WilsonLower(K, n_test, C) >= given threshold."
    ),
    tolerance = 1e-10,
    cases = cases
  )
}
