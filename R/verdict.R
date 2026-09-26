#' Evaluate a test verdict under the 1.5.0 decision rules
#'
#' The verdict of one test run under the rule its threshold's origin
#' selects: `regression/score-cc` for a baseline-derived (empirical)
#' threshold, `compliance/exact-binomial` for a given (normative) one.
#' A configuration that carries both bars is evaluated as one: if either
#' part is invalid the whole configuration is refused and no verdict is
#' produced.
#'
#' @param successes,trials The test's success count and size.
#' @param alpha One-sided level.
#' @param baseline_successes,baseline_trials Baseline evidence (empirical
#'   bar), or NULL.
#' @param threshold p_req (normative bar), or NULL.
#' @param intent VERIFICATION or SMOKE (normative bar).
#' @return A list: verdict, configuration_error, observed_rate. For a
#'   joint configuration that is valid, verdict is NA and the two parts'
#'   verdicts are returned as regression_verdict and compliance_verdict.
#' @export
evaluate_verdict <- function(successes, trials, alpha,
                             baseline_successes = NULL, baseline_trials = NULL,
                             threshold = NULL, intent = "VERIFICATION") {
  empirical <- !is.null(baseline_trials)
  normative <- !is.null(threshold)
  if (!empirical && !normative) stop("a verdict needs a baseline or a threshold", call. = FALSE)
  errs <- c(
    if (empirical) regression_configuration_error(baseline_trials, trials, alpha),
    if (normative) compliance_configuration_error(threshold, trials, alpha, intent)
  )
  errs <- errs[!is.na(errs)]
  if (length(errs) > 1) stop("more than one configuration error: ", paste(errs, collapse = ", "),
                             call. = FALSE)
  out <- list(verdict = NA_character_,
              configuration_error = if (length(errs)) errs else NA_character_,
              observed_rate = successes / trials)
  if (length(errs)) return(out)
  reg <- if (empirical) {
    c_int <- score_cc_cutoff(baseline_successes, baseline_trials, trials, alpha)
    if (successes >= c_int) "PASS" else "FAIL"
  }
  cmp <- if (normative) {
    k <- exact_binomial_k_min(threshold, trials, alpha)
    if (!is.na(k) && successes >= k) "PASS" else "FAIL"
  }
  if (empirical && normative) {
    out$regression_verdict <- reg
    out$compliance_verdict <- cmp
  } else {
    out$verdict <- if (empirical) reg else cmp
  }
  out
}

#' @keywords internal
verdict_case <- function(name, rule, inputs, description = NULL) {
  case <- list(name = name)
  if (!is.null(description)) case$description <- description
  if (length(rule) > 1) case$approach <- "joint"
  case$decisionRule <- if (length(rule) > 1) as.list(rule) else rule
  args <- c(list(successes = inputs$successes, trials = inputs$trials, alpha = inputs$alpha),
            inputs[intersect(names(inputs), c("baseline_successes", "baseline_trials",
                                              "threshold", "intent"))])
  c(case, list(inputs = inputs, expected = do.call(evaluate_verdict, args)))
}

#' Generate verdict evaluation reference cases
#'
#' @return A list suitable for JSON serialisation.
#' @export
generate_verdict_cases <- function() {
  R <- "regression/score-cc"
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
    # Empirical bar: the continuity-corrected pooled score cutoff.
    verdict_case("regression_pass_91_of_100_baseline_951_of_1000", R, reg(91, 100, 951, 1000)),
    verdict_case("regression_fail_90_of_100_baseline_951_of_1000", R, reg(90, 100, 951, 1000)),
    verdict_case("regression_pass_95_of_100_baseline_99_of_100", R, reg(95, 100, 99, 100)),
    verdict_case("regression_fail_95_of_100_baseline_100_of_100", R, reg(95, 100, 100, 100),
      "The cutoff is monotone in the baseline count: a perfect baseline demands more than 99 of 100."),
    verdict_case("regression_refused_test_larger_than_baseline", R, reg(190, 200, 95, 100)),
    verdict_case("regression_refused_outside_calibration_tolerance", R,
      reg(25, 25, 951, 1000, alpha = 0.01)),
    # Both bars on one configuration: an invalid part refuses the whole.
    verdict_case("joint_refused_empirical_part_test_larger_than_baseline", c(C, R),
      c(cmp(190, 200, 0.90), list(baseline_successes = 95L, baseline_trials = 100L)),
      "The normative part is valid; the empirical part is not, so nothing runs."),
    verdict_case("joint_refused_normative_part_infeasible", c(C, R),
      c(cmp(100, 100, 0.999), list(baseline_successes = 950L, baseline_trials = 1000L)),
      "The empirical part is valid; the normative part cannot PASS at n = 100, so nothing runs.")
  )

  list(
    suite = "verdict",
    description = paste(
      "Verdict evaluation under the two ruled rules: regression/score-cc for a baseline-derived",
      "threshold and compliance/exact-binomial for a given one; each case names its rule in",
      "decisionRule. A configuration carrying both bars (approach joint) is refused whole when",
      "either part is invalid. The v1.4.1 point-estimate rule (PASS iff p_hat >= threshold) and",
      "its Wald z statistic are withdrawn. Binding: verdict, configuration_error. Informational:",
      "observed_rate."
    ),
    method = paste(
      "regression/score-cc: PASS iff K_t >= c(K_b, n_b, n_t, alpha) (see regression_decision).",
      "compliance/exact-binomial: PASS iff K >= k_min(p_req, n, alpha) (see compliance_decision).",
      "Configuration errors are checked first, for every part of the configuration."
    ),
    tolerance = 1e-10,
    cases = cases
  )
}
