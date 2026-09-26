#' Inferential-criterion verdict (companion §1.4.5, §1.4.6, §3.4, §3.6)
#'
#' Per-inferential-criterion verdict generation, separated by procedure
#' direction (REGRESSION vs COMPLIANCE), each decided by its 1.5.0
#' decision rule. An informational suite: no framework is obliged to
#' consume it.
#'
#' Shared mechanics:
#'   - Effective denominator n_c derived from policy (§1.4.5a):
#'       CONDITIONAL_ON_EVALUABLE:           n_c = n_evaluable
#'       MARGINAL_COUNT_UNEVALUABLE_AS_FAIL: n_c = n_attempted
#'     K_c is the count of postcondition successes among the evaluable
#'     trials in either case; unevaluable trials never contribute to
#'     K_c (the postcondition could not be checked on them).
#'   - p_hat_c = K_c / n_c (the policy-aware point estimate).
#'   - Inconclusive outcomes: n_c == 0; for COMPLIANCE also an n_c too
#'     small for any count to pass (feasibility gate REFUSE).
#'
#' REGRESSION (regression/score-cc):
#'   H_0: p_c >= p_b (no degradation); H_1: p_c < p_b
#'   c = the score-cc cutoff from (K_b, n_b, n_c, alpha); PASS iff K_c >= c.
#'   The configured test (n_attempted trials) is first checked for the
#'   configuration errors TEST_LARGER_THAN_BASELINE and
#'   OUTSIDE_CALIBRATION_TOLERANCE; a refused configuration has no verdict.
#'   The observed-rate strand compares p_hat_c with c / n_c.
#'
#' COMPLIANCE (compliance/exact-binomial):
#'   H_0: p_c <= p_req; H_1: p_c > p_req
#'   k_min = min{k : P_{p_req}(K >= k) <= alpha} at n_c; PASS iff K_c >= k_min.
#'   p_value: P_{p_req}(K >= K_c), the exact test's own p-value
#'   (PASS iff p_value <= alpha). clopper_pearson_lower is the one-sided
#'   Clopper-Pearson bound reported beside the verdict.
#'
#' Three-strand verdict fields:
#'   - statistical:           PASS, FAIL, or INCONCLUSIVE.
#'   - observed_rate_status:  ABOVE_THRESHOLD / BELOW_THRESHOLD /
#'                            AT_THRESHOLD / NOT_APPLICABLE.
#'                            For REGRESSION the threshold is c / n_c; for
#'                            COMPLIANCE it is p_req.
#'   - operational_caution_category: ADEQUATE_POWER /
#'                            STRANDS_DISAGREE / FEASIBILITY_REFUSED /
#'                            ZERO_EVALUABLE / FAIL_CLEAR /
#'                            CONFIGURATION_REFUSED.

regression_verdict <- function(n_attempted, n_evaluable, K_c, alpha,
                               denominator_policy,
                               baseline_successes, baseline_trials) {
  n_c <- if (denominator_policy == "CONDITIONAL_ON_EVALUABLE")
    n_evaluable else n_attempted
  r_obs <- if (n_attempted == 0) 0 else n_evaluable / n_attempted
  empty <- list(
    n_c = as.integer(n_c), r_obs = r_obs, p_hat_c = NA_real_,
    cutoff_integer = NA_integer_, displayed_rate = NA_real_,
    configuration_error = NA_character_,
    verdict = "INCONCLUSIVE", statistical_verdict = "INCONCLUSIVE",
    observed_rate_status = "NOT_APPLICABLE",
    operational_caution_category = "ZERO_EVALUABLE"
  )

  if (n_attempted > 0) {
    err <- regression_configuration_error(baseline_trials, n_attempted, alpha)
    if (!is.na(err)) {
      empty$configuration_error <- err
      empty$verdict <- NA_character_
      empty$statistical_verdict <- NA_character_
      empty$operational_caution_category <- "CONFIGURATION_REFUSED"
      return(empty)
    }
  }
  if (n_c == 0) return(empty)

  cutoff <- score_cc_cutoff(baseline_successes, baseline_trials, n_c, alpha)
  verdict <- if (K_c >= cutoff) "PASS" else "FAIL"
  p_hat_c <- K_c / n_c
  displayed <- cutoff / n_c
  observed_rate_status <- if (p_hat_c > displayed) "ABOVE_THRESHOLD"
                          else if (p_hat_c < displayed) "BELOW_THRESHOLD"
                          else "AT_THRESHOLD"
  caution <- if (verdict == "PASS" && observed_rate_status == "ABOVE_THRESHOLD") {
    "ADEQUATE_POWER"
  } else if (verdict == "FAIL" && observed_rate_status == "BELOW_THRESHOLD") {
    "FAIL_CLEAR"
  } else {
    "STRANDS_DISAGREE"
  }

  list(
    n_c = as.integer(n_c), r_obs = r_obs,
    p_hat_c = p_hat_c,
    cutoff_integer = cutoff,
    displayed_rate = round(displayed, 6),
    configuration_error = NA_character_,
    verdict = verdict,
    statistical_verdict = verdict,
    observed_rate_status = observed_rate_status,
    operational_caution_category = caution
  )
}

compliance_verdict <- function(n_attempted, n_evaluable, K_c, alpha,
                               denominator_policy, p_req) {
  n_c <- if (denominator_policy == "CONDITIONAL_ON_EVALUABLE")
    n_evaluable else n_attempted
  r_obs <- if (n_attempted == 0) 0 else n_evaluable / n_attempted
  inconclusive <- function(p_hat_c, cp, caution) list(
    n_c = as.integer(n_c), r_obs = r_obs,
    p_hat_c = p_hat_c,
    k_min = NA_integer_,
    clopper_pearson_lower = cp,
    feasibility_gate = "REFUSE",
    verdict = "INCONCLUSIVE",
    p_value = NA_real_,
    p_value_method = "exact-binomial-upper-tail",
    p_value_tail = "P_{p=p_req}(K >= K_c)",
    statistical_verdict = "INCONCLUSIVE",
    observed_rate_status = "NOT_APPLICABLE",
    operational_caution_category = caution
  )

  if (n_c == 0) return(inconclusive(NA_real_, NA_real_, "ZERO_EVALUABLE"))

  p_hat_c <- K_c / n_c
  cp <- clopper_pearson_lower(K_c, n_c, alpha)
  k_min <- exact_binomial_k_min(p_req, n_c, alpha)
  if (is.na(k_min)) return(inconclusive(p_hat_c, cp, "FEASIBILITY_REFUSED"))

  verdict <- if (K_c >= k_min) "PASS" else "FAIL"
  p_value <- pbinom(K_c - 1, size = n_c, prob = p_req, lower.tail = FALSE)

  observed_rate_status <- if (p_hat_c > p_req) "ABOVE_THRESHOLD"
                          else if (p_hat_c < p_req) "BELOW_THRESHOLD"
                          else "AT_THRESHOLD"

  # STRANDS_DISAGREE arises classically in COMPLIANCE: observed rate
  # above the requirement, but compliance not demonstrated. The §10.3
  # layperson-readable case is the canonical example.
  caution <- if (verdict == "PASS" && observed_rate_status == "ABOVE_THRESHOLD") {
    "ADEQUATE_POWER"
  } else if (verdict == "FAIL" && observed_rate_status == "BELOW_THRESHOLD") {
    "FAIL_CLEAR"
  } else {
    "STRANDS_DISAGREE"
  }

  list(
    n_c = as.integer(n_c), r_obs = r_obs,
    p_hat_c = p_hat_c,
    k_min = k_min,
    clopper_pearson_lower = cp,
    feasibility_gate = "ADMIT",
    verdict = verdict,
    p_value = p_value,
    p_value_method = "exact-binomial-upper-tail",
    p_value_tail = "P_{p=p_req}(K >= K_c)",
    statistical_verdict = verdict,
    observed_rate_status = observed_rate_status,
    operational_caution_category = caution
  )
}

#' Generate inferential-criterion verdict reference cases
#'
#' @return A list suitable for JSON serialisation.
#' @export
generate_criterion_verdict_inferential_cases <- function() {

  reg_case <- function(name, n_attempted, n_evaluable, K_c, alpha, policy,
                       baseline_successes, baseline_trials, description = NULL) {
    case <- list(
      name = name,
      procedure = "REGRESSION",
      decisionRule = "regression/score-cc",
      inputs = list(
        procedure = "REGRESSION",
        n_attempted = as.integer(n_attempted),
        n_evaluable = as.integer(n_evaluable),
        K_c = as.integer(K_c),
        alpha = alpha,
        denominator_policy = policy,
        baseline_successes = as.integer(baseline_successes),
        baseline_trials = as.integer(baseline_trials)
      ),
      expected = regression_verdict(n_attempted, n_evaluable, K_c, alpha,
                                    policy, baseline_successes, baseline_trials)
    )
    if (!is.null(description)) case$description <- description
    case
  }

  com_case <- function(name, n_attempted, n_evaluable, K_c, alpha, policy,
                       p_req, description = NULL) {
    case <- list(
      name = name,
      procedure = "COMPLIANCE",
      decisionRule = "compliance/exact-binomial",
      inputs = list(
        procedure = "COMPLIANCE",
        n_attempted = as.integer(n_attempted),
        n_evaluable = as.integer(n_evaluable),
        K_c = as.integer(K_c),
        alpha = alpha,
        denominator_policy = policy,
        p_req = p_req
      ),
      expected = compliance_verdict(n_attempted, n_evaluable, K_c, alpha,
                                    policy, p_req)
    )
    if (!is.null(description)) case$description <- description
    case
  }

  cases <- list(
    # REGRESSION — clear PASS: K well above cutoff.
    reg_case("regression_clear_pass_consult_advice_well_formed",
             n_attempted = 1000, n_evaluable = 1000, K_c = 953, alpha = 0.05,
             policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL",
             baseline_successes = 951, baseline_trials = 1000,
             description = "§10.3 C_well_formed: K = 953 well above the derived cutoff."),

    # REGRESSION — clear FAIL: K well below cutoff.
    reg_case("regression_clear_fail_K_far_below_cutoff",
             n_attempted = 1000, n_evaluable = 1000, K_c = 850, alpha = 0.05,
             policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL",
             baseline_successes = 951, baseline_trials = 1000),

    # REGRESSION — borderline: K right at cutoff boundary.
    # The §3.4 rate has cutoff = 91 for n = 100; K = 91 PASSes,
    # K = 90 FAILs.
    reg_case("regression_borderline_pass_K_equals_cutoff",
             n_attempted = 100, n_evaluable = 100, K_c = 91, alpha = 0.05,
             policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL",
             baseline_successes = 951, baseline_trials = 1000,
             description = "The §3.4 rate: cutoff = 91; K = 91 → PASS (boundary)."),

    reg_case("regression_borderline_fail_K_one_below_cutoff",
             n_attempted = 100, n_evaluable = 100, K_c = 90, alpha = 0.05,
             policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL",
             baseline_successes = 951, baseline_trials = 1000,
             description = "The §3.4 rate: cutoff = 91; K = 90 → FAIL."),

    # REGRESSION — INCONCLUSIVE via n_c = 0.
    reg_case("regression_inconclusive_zero_evaluable",
             n_attempted = 0, n_evaluable = 0, K_c = 0, alpha = 0.05,
             policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL",
             baseline_successes = 951, baseline_trials = 1000),

    # REGRESSION — refused configuration: a 5-trial test against a
    # 1000-trial baseline at alpha 0.001 is outside the calibration
    # tolerance, so no verdict is produced.
    reg_case("regression_refused_outside_calibration_tolerance",
             n_attempted = 5, n_evaluable = 5, K_c = 5, alpha = 0.001,
             policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL",
             baseline_successes = 999, baseline_trials = 1000),

    # REGRESSION — policy difference. Same raw counts under two policies.
    # n_attempted=1000, n_evaluable=950, K_c=950. Under CONDITIONAL the
    # effective n_c=950 and the test compares K_c=950 to the cutoff at
    # n=950 against baseline 951/1000. Under MARGINAL the effective
    # n_c=1000 and K_c=950 is compared with the cutoff at n=1000.
    reg_case("regression_policy_diff_conditional",
             n_attempted = 1000, n_evaluable = 950, K_c = 950, alpha = 0.05,
             policy = "CONDITIONAL_ON_EVALUABLE",
             baseline_successes = 951, baseline_trials = 1000,
             description = "Same data as the next case under different policy. CONDITIONAL: only the 950 evaluable trials count; observed rate is 1.0."),

    reg_case("regression_policy_diff_marginal",
             n_attempted = 1000, n_evaluable = 950, K_c = 950, alpha = 0.05,
             policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL",
             baseline_successes = 951, baseline_trials = 1000,
             description = "Same data as the previous case under MARGINAL: unevaluable trials count toward n_c but not K_c, so K_c/n_c = 0.95."),

    # COMPLIANCE — clear PASS: observed well above requirement, sample large.
    com_case("compliance_clear_pass",
             n_attempted = 10000, n_evaluable = 10000, K_c = 9990,
             alpha = 0.05, policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL",
             p_req = 0.99),

    # COMPLIANCE — clear FAIL: observed rate well below requirement.
    com_case("compliance_clear_fail",
             n_attempted = 1000, n_evaluable = 1000, K_c = 800,
             alpha = 0.05, policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL",
             p_req = 0.95),

    # COMPLIANCE — the canonical §10.3 layperson-readable disagreement:
    # p_hat = 0.985, p_req = 0.98, but compliance not demonstrated at α = 0.001.
    com_case("compliance_strands_disagree_consult_advice_layperson",
             n_attempted = 800, n_evaluable = 800, K_c = 788,
             alpha = 0.001, policy = "CONDITIONAL_ON_EVALUABLE",
             p_req = 0.98,
             description = "§10.3 C_layperson_readable: p_hat = 0.985 > p_req = 0.98, but K = 788 is below k_min at α = 0.001 → FAIL with strands disagreeing."),

    # COMPLIANCE — INCONCLUSIVE via n_c = 0.
    com_case("compliance_inconclusive_zero_evaluable",
             n_attempted = 0, n_evaluable = 0, K_c = 0,
             alpha = 0.05, policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL",
             p_req = 0.95),

    # COMPLIANCE — INCONCLUSIVE via feasibility gate: no count of 5 can pass.
    com_case("compliance_inconclusive_feasibility_refused",
             n_attempted = 5, n_evaluable = 5, K_c = 5,
             alpha = 0.05, policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL",
             p_req = 0.999)
  )

  list(
    suite = "criterion_verdict_inferential",
    description = paste(
      "Per-inferential-criterion verdict cases (informational), partitioned",
      "by procedure direction. REGRESSION tests for degradation from a",
      "baseline (H_1: p_c < p_b) under regression/score-cc and decides",
      "K_c >= c; a configuration the design rule or the calibration-tolerance",
      "rule refuses has no verdict. COMPLIANCE tests whether the rate clears",
      "a requirement (H_1: p_c > p_req) under compliance/exact-binomial and",
      "decides K_c >= k_min. The effective denominator n_c is derived from",
      "the §1.4.5a policy. Each case carries the three-strand verdict."
    ),
    method = paste(
      "REGRESSION: regression/score-cc cutoff c from (K_b, n_b, n_c,",
      "alpha), decision K_c >= c; configuration errors checked on",
      "(n_b, n_attempted, alpha). COMPLIANCE: compliance/exact-binomial",
      "k_min at n_c, decision K_c >= k_min, p-value = P_{p=p_req}(K >= K_c),",
      "INCONCLUSIVE when no count of n_c can pass."
    ),
    tolerance = 1e-9,
    cases = cases
  )
}
