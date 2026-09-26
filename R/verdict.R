#' Evaluate a test verdict under the 1.5.0 decision rules
#'
#' The verdict of one test run under the rule its threshold's origin
#' selects: `regression/fisher` for a baseline-derived (empirical)
#' threshold, `compliance/exact-binomial` for a given (normative) one.
#'
#' Configuration errors are checked first, for every part of the
#' configuration, and every applicable code is reported, as a list in the
#' fixed order of `CONFIGURATION_ERRORS`; a refused configuration has no
#' verdict.
#'
#' A criterion carrying both bars reports both verdicts separately, each
#' with its own rule and alpha: the normative bar asks whether the
#' requirement is met, the empirical bar whether the service has degraded.
#' Its verdict combines them by the structural composite rule (PASS if
#' both pass, FAIL if either fails, INCONCLUSIVE otherwise), and a FAIL
#' names the bar or bars that failed.
#'
#' @param successes,trials The test's success count and size.
#' @param alpha One-sided level of a single-bar configuration.
#' @param baseline_successes,baseline_trials Baseline evidence (empirical
#'   bar), or NULL.
#' @param threshold p_req (normative bar), or NULL.
#' @param intent VERIFICATION or SMOKE (normative bar).
#' @param regression_alpha,compliance_alpha The two bars' levels in a
#'   configuration that carries both (default `alpha`).
#' @return A list: verdict, configuration_error (a list of codes, empty when
#'   valid), observed_rate; for a configuration with both bars also bars
#'   (one entry per bar: bar, decisionRule, alpha, verdict) and
#'   failing_bars.
#' @export
evaluate_verdict <- function(successes, trials, alpha = NULL,
                             baseline_successes = NULL, baseline_trials = NULL,
                             threshold = NULL, intent = "VERIFICATION",
                             regression_alpha = alpha, compliance_alpha = alpha) {
  empirical <- !is.null(baseline_trials)
  normative <- !is.null(threshold)
  if (!empirical && !normative) stop("a verdict needs a baseline or a threshold", call. = FALSE)
  errs <- configuration_errors(
    if (empirical) regression_configuration_error(baseline_trials, trials),
    if (normative) compliance_configuration_error(threshold, trials, compliance_alpha, intent)
  )
  out <- list(verdict = NA_character_, configuration_error = errs,
              observed_rate = successes / trials)
  joint <- empirical && normative
  if (length(errs)) {
    if (joint) {
      out$bars <- list()
      out$failing_bars <- list()
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
  if (joint) {
    bars <- list(
      list(bar = "normative", decisionRule = "compliance/exact-binomial",
           alpha = compliance_alpha, verdict = cmp),
      list(bar = "empirical", decisionRule = "regression/fisher",
           alpha = regression_alpha, verdict = reg)
    )
    j <- joint_bar_verdict(bars)
    out$verdict <- j$verdict
    out$bars <- bars
    out$failing_bars <- j$failing_bars
  } else {
    out$verdict <- if (empirical) reg else cmp
  }
  out
}

#' Combine the verdicts of a criterion's normative and empirical bars
#'
#' The structural composite rule of §1.4.6 over the bars: PASS if every
#' bar passes, FAIL if any fails, INCONCLUSIVE otherwise.
#'
#' @param bars A list of bars, each with `bar` and `verdict`.
#' @return A list: verdict and failing_bars (the bars that failed, when the
#'   verdict is FAIL; empty otherwise).
#' @export
joint_bar_verdict <- function(bars) {
  v <- vapply(bars, function(b) b$verdict, character(1))
  verdict <- if (all(v == "PASS")) "PASS" else if (any(v == "FAIL")) "FAIL" else "INCONCLUSIVE"
  failing <- if (verdict == "FAIL") vapply(bars[v == "FAIL"], function(b) b$bar, character(1)) else character(0)
  list(verdict = verdict, failing_bars = as.list(failing))
}

#' @keywords internal
verdict_case <- function(name, rule, inputs, description = NULL) {
  case <- list(name = name)
  if (!is.null(description)) case$description <- description
  if (length(rule) > 1) case$approach <- "joint"
  case$decisionRule <- if (length(rule) > 1) as.list(rule) else rule
  args <- c(list(successes = inputs$successes, trials = inputs$trials),
            inputs[intersect(names(inputs), c("alpha", "baseline_successes", "baseline_trials",
                                              "threshold", "intent", "regression_alpha",
                                              "compliance_alpha"))])
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
  joint <- function(successes, trials, threshold, baseline_successes, baseline_trials,
                    compliance_alpha = 0.01, regression_alpha = 0.05, intent = "VERIFICATION") {
    list(successes = as.integer(successes), trials = as.integer(trials), threshold = threshold,
         intent = intent, compliance_alpha = compliance_alpha,
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
    # Both bars on one configuration: every applicable code refuses the whole,
    # in the fixed order.
    verdict_case("joint_refused_empirical_part_test_larger_than_baseline", c(C, R),
      joint(190, 200, 0.90, 95, 100),
      "The normative part is valid; the empirical part is not, so nothing runs."),
    verdict_case("joint_refused_normative_part_infeasible", c(C, R),
      joint(100, 100, 0.999, 950, 1000),
      "The empirical part is valid; the normative part cannot PASS at n = 100, so nothing runs."),
    verdict_case("joint_refused_both_parts", c(C, R),
      joint(200, 200, 0.999, 95, 100),
      "Both parts are invalid: both codes are reported, TEST_LARGER_THAN_BASELINE first."),
    # A valid configuration with both bars: each bar decides with its own
    # rule and alpha; the criterion's verdict is the structural composite.
    verdict_case("joint_pass_both_bars", c(C, R), joint(945, 1000, 0.90, 951, 1000),
      "Normative bar: 945 of 1000 demonstrates 0.90 at alpha 0.01. Empirical bar: 945 meets the cutoff of 933. PASS."),
    verdict_case("joint_fail_empirical_bar", c(C, R), joint(925, 1000, 0.90, 951, 1000),
      "The requirement of 0.90 is demonstrated, but 925 falls below the cutoff of 933 derived from the baseline: FAIL, naming the empirical bar."),
    verdict_case("joint_fail_normative_bar", c(C, R), joint(945, 1000, 0.95, 930, 1000),
      "No degradation from the baseline 930 of 1000, but 945 does not demonstrate 0.95: FAIL, naming the normative bar."),
    verdict_case("joint_fail_both_bars", c(C, R), joint(900, 1000, 0.95, 951, 1000),
      "Both bars fail; both are named.")
  )

  list(
    suite = "verdict",
    description = paste(
      "Verdict evaluation under the two ruled rules: regression/fisher for a baseline-derived",
      "threshold and compliance/exact-binomial for a given one; each case names its rule in",
      "decisionRule. A configuration carrying both bars (approach joint) is refused whole when",
      "any part is invalid, reporting every applicable code. When it is valid, each bar decides",
      "with its own rule and alpha (compliance_alpha, regression_alpha) and is reported in bars;",
      "the verdict is their structural composite (PASS if both pass, FAIL if either fails,",
      "INCONCLUSIVE otherwise) and failing_bars names the bars that failed. The v1.4.1",
      "point-estimate rule (PASS iff p_hat >= threshold) and its Wald z statistic are withdrawn.",
      "Binding: verdict, configuration_error, bars, failing_bars. Informational: observed_rate."
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
