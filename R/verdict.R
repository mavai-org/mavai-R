#' Evaluate a test verdict under the 1.5.0 decision rules
#'
#' The verdict of one test run under the rule its threshold's origin
#' selects: `regression/fisher` for a baseline-derived (empirical)
#' threshold, `compliance/exact-binomial` for a given (normative) one.
#'
#' Configuration errors are checked first, for every criterion of the
#' test, and every applicable code is reported, as a list in the fixed
#' order of `CONFIGURATION_ERRORS`; a refused configuration has no verdict.
#'
#' A service judged against both a requirement and its baseline carries
#' two criteria over the same postconditions and the same observations: a
#' compliance criterion and a regression criterion, each with one rule,
#' one alpha, one threshold origin and one verdict. The test's verdict is
#' the ordinary structural composite of the two (`composite_verdict()`),
#' with the triggering criteria named and the two error envelopes split by
#' direction. An invalid part refuses the whole test.
#'
#' @param successes,trials The test's success count and size.
#' @param alpha One-sided level of a single-criterion test.
#' @param baseline_successes,baseline_trials Baseline evidence (regression
#'   criterion), or NULL.
#' @param threshold p_req (compliance criterion), or NULL.
#' @param intent VERIFICATION or SMOKE (compliance criterion).
#' @param regression_alpha,compliance_alpha The two criteria's levels in a
#'   test that carries both (default `alpha`).
#' @param compliance_criterion,regression_criterion The two criteria's ids.
#' @return A list: verdict, configuration_error (a list of codes, empty when
#'   valid), observed_rate; for a test carrying both criteria also criteria
#'   (criterion_id, procedure, decisionRule, alpha, verdict), triggering_criteria
#'   and the two envelopes.
#' @export
evaluate_verdict <- function(successes, trials, alpha = NULL,
                             baseline_successes = NULL, baseline_trials = NULL,
                             threshold = NULL, intent = "VERIFICATION",
                             regression_alpha = alpha, compliance_alpha = alpha,
                             compliance_criterion = "c_compliance",
                             regression_criterion = "c_regression") {
  empirical <- !is.null(baseline_trials)
  normative <- !is.null(threshold)
  if (!empirical && !normative) stop("a verdict needs a baseline or a threshold", call. = FALSE)
  errs <- configuration_errors(
    if (empirical) regression_configuration_error(baseline_trials, trials),
    if (normative) compliance_configuration_error(threshold, trials, compliance_alpha, intent)
  )
  out <- list(verdict = NA_character_, configuration_error = errs,
              observed_rate = successes / trials)
  both <- empirical && normative
  if (length(errs)) {
    if (both) {
      out$criteria <- list()
      out$triggering_criteria <- list()
      out$false_compliance_envelope <- NA_real_
      out$false_degradation_signal_envelope <- NA_real_
    }
    return(out)
  }
  reg <- if (empirical) {
    c_int <- fisher_cutoff(baseline_successes, baseline_trials, trials, regression_alpha)
    if (successes >= c_int) "PASS" else "FAIL"
  }
  cmp <- if (normative) {
    k <- exact_binomial_k_min(threshold, trials, compliance_alpha)
    if (!is.na(k) && successes >= k) "PASS" else "FAIL"
  }
  if (both) {
    criteria <- list(
      list(criterion_id = compliance_criterion, mode = "inferential", procedure = "COMPLIANCE",
           decisionRule = "compliance/exact-binomial", alpha = compliance_alpha, verdict = cmp),
      list(criterion_id = regression_criterion, mode = "inferential", procedure = "REGRESSION",
           decisionRule = "regression/fisher", alpha = regression_alpha, verdict = reg)
    )
    cv <- composite_verdict(criteria)
    out$verdict <- cv$composite_verdict
    out$criteria <- lapply(criteria, function(c) c[names(c) != "mode"])
    out$triggering_criteria <- cv$triggering_criteria
    out$false_compliance_envelope <- cv$false_compliance_envelope
    out$false_degradation_signal_envelope <- cv$false_degradation_signal_envelope
  } else {
    out$verdict <- if (empirical) reg else cmp
  }
  out
}

#' @keywords internal
verdict_case <- function(name, rule, inputs, description = NULL) {
  case <- list(name = name)
  if (!is.null(description)) case$description <- description
  if (length(rule) > 1) case$approach <- "two_criteria"
  case$decisionRule <- if (length(rule) > 1) as.list(rule) else rule
  args <- c(list(successes = inputs$successes, trials = inputs$trials),
            inputs[intersect(names(inputs), c("alpha", "baseline_successes", "baseline_trials",
                                              "threshold", "intent", "regression_alpha",
                                              "compliance_alpha", "compliance_criterion",
                                              "regression_criterion"))])
  c(case, list(inputs = inputs, expected = do.call(evaluate_verdict, args)))
}

#' Generate verdict evaluation reference cases
#'
#' @return A list suitable for JSON serialisation.
#' @export
generate_verdict_cases <- function() {
  R <- "regression/fisher"
  C <- "compliance/exact-binomial"
  cmp <- function(successes, trials, threshold, alpha = 0.05, intent = "VERIFICATION") {
    list(successes = as.integer(successes), trials = as.integer(trials), threshold = threshold,
         alpha = alpha, intent = intent)
  }
  reg <- function(successes, trials, baseline_successes, baseline_trials, alpha = 0.05) {
    list(successes = as.integer(successes), trials = as.integer(trials),
         baseline_successes = as.integer(baseline_successes),
         baseline_trials = as.integer(baseline_trials), alpha = alpha)
  }
  two <- function(successes, trials, threshold, baseline_successes, baseline_trials,
                  compliance_alpha = 0.01, regression_alpha = 0.05, intent = "VERIFICATION") {
    list(successes = as.integer(successes), trials = as.integer(trials),
         compliance_criterion = "c_well_formed_compliance", threshold = threshold,
         intent = intent, compliance_alpha = compliance_alpha,
         regression_criterion = "c_well_formed_regression",
         baseline_successes = as.integer(baseline_successes),
         baseline_trials = as.integer(baseline_trials), regression_alpha = regression_alpha)
  }
  cases <- list(
    # Normative bar: the exact test, not a comparison of the observed rate.
    verdict_case("compliance_fail_48_of_50_threshold_90", C, cmp(48, 50, 0.90),
      "96% observed against a 90% requirement does not demonstrate compliance at n = 50."),
    verdict_case("compliance_pass_49_of_50_threshold_90", C, cmp(49, 50, 0.90)),
    verdict_case("compliance_fail_40_of_50_threshold_90", C, cmp(40, 50, 0.90)),
    verdict_case("compliance_fail_45_of_50_threshold_90", C, cmp(45, 50, 0.90)),
    verdict_case("compliance_fail_0_of_50_threshold_90", C, cmp(0, 50, 0.90)),
    verdict_case("compliance_pass_920_of_1000_threshold_90", C, cmp(920, 1000, 0.90)),
    verdict_case("compliance_refused_50_of_50_threshold_95", C, cmp(50, 50, 0.95),
      "n = 50 is below the feasibility minimum of 59: refused under VERIFICATION."),
    verdict_case("compliance_smoke_50_of_50_threshold_95", C, cmp(50, 50, 0.95, intent = "SMOKE"),
      "SMOKE runs the undersized design; it cannot PASS."),
    # Empirical bar: the one-sided Fisher cutoff.
    verdict_case("regression_pass_91_of_100_baseline_951_of_1000", R, reg(91, 100, 951, 1000)),
    verdict_case("regression_fail_90_of_100_baseline_951_of_1000", R, reg(90, 100, 951, 1000)),
    verdict_case("regression_pass_95_of_100_baseline_99_of_100", R, reg(95, 100, 99, 100)),
    verdict_case("regression_fail_95_of_100_baseline_100_of_100", R, reg(95, 100, 100, 100),
      "The cutoff is monotone in the baseline count: a perfect baseline demands more than 99 of 100."),
    verdict_case("regression_refused_test_larger_than_baseline", R, reg(190, 200, 95, 100)),
    verdict_case("regression_pass_25_of_25_baseline_951_of_1000_alpha001", R,
      reg(25, 25, 951, 1000, alpha = 0.01),
      "A small test against a large baseline at alpha 0.01 is admitted: the rule never exceeds alpha."),
    # A requirement and a baseline on the same postconditions: two criteria,
    # a compliance criterion and a regression criterion, over the same
    # observations. Every applicable code refuses the whole test, in the
    # fixed order.
    verdict_case("two_criteria_refused_regression_part_test_larger_than_baseline", c(C, R),
      two(190, 200, 0.90, 95, 100),
      "The compliance criterion is valid; the regression criterion's test is larger than its baseline, so nothing runs."),
    verdict_case("two_criteria_refused_compliance_part_infeasible", c(C, R),
      two(100, 100, 0.999, 950, 1000),
      "The regression criterion is valid; the compliance criterion cannot PASS at n = 100, so nothing runs."),
    verdict_case("two_criteria_refused_both_parts", c(C, R),
      two(200, 200, 0.999, 95, 100),
      "Both parts are invalid: both codes are reported, TEST_LARGER_THAN_BASELINE first."),
    # A valid test: each criterion decides with its own rule and alpha; the
    # test's verdict is the ordinary structural composite.
    verdict_case("two_criteria_pass", c(C, R), two(945, 1000, 0.90, 951, 1000),
      "Compliance: 945 of 1000 demonstrates 0.90 at alpha 0.01. Regression: 945 meets the cutoff of 933. PASS."),
    verdict_case("two_criteria_fail_regression", c(C, R), two(925, 1000, 0.90, 951, 1000),
      "The requirement of 0.90 is demonstrated, but 925 falls below the cutoff of 933: FAIL, triggered by the regression criterion."),
    verdict_case("two_criteria_fail_compliance", c(C, R), two(945, 1000, 0.95, 930, 1000),
      "No degradation from the baseline 930 of 1000, but 945 does not demonstrate 0.95: FAIL, triggered by the compliance criterion."),
    verdict_case("two_criteria_fail_both", c(C, R), two(900, 1000, 0.95, 951, 1000),
      "Both criteria fail; both are named.")
  )

  list(
    suite = "verdict",
    description = paste(
      "Verdict evaluation under the two ruled rules: regression/fisher for a baseline-derived",
      "threshold and compliance/exact-binomial for a given one; each case names its rule in",
      "decisionRule. A test carrying a requirement and a baseline on the same postconditions",
      "(approach two_criteria) carries two criteria over the same observations, a compliance",
      "criterion and a regression criterion, each with one rule and one alpha",
      "(compliance_alpha, regression_alpha) and one verdict, reported in criteria; the test's",
      "verdict is their structural composite (PASS if both pass, FAIL if either fails,",
      "INCONCLUSIVE otherwise), triggering_criteria names the criteria that decided it, and the",
      "error envelopes are split by direction. The test is refused whole when any part is",
      "invalid, reporting every applicable code. The v1.4.1 point-estimate rule (PASS iff",
      "p_hat >= threshold) and its Wald z statistic are withdrawn. Binding: verdict,",
      "configuration_error, criteria, triggering_criteria. Informational: observed_rate,",
      "false_compliance_envelope, false_degradation_signal_envelope."
    ),
    method = paste(
      "regression/fisher: PASS iff K_t >= c(K_b, n_b, n_t, alpha) (see regression_decision).",
      "compliance/exact-binomial: PASS iff K >= k_min(p_req, n, alpha) (see compliance_decision).",
      "Configuration errors are checked first, for every part of the configuration;",
      "configuration_error is the list of every applicable code in the fixed order",
      "TEST_LARGER_THAN_BASELINE, COMPLIANCE_INFEASIBLE (empty when valid)."
    ),
    tolerance = 1e-10,
    cases = cases
  )
}
