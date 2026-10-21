#' Normative compliance verdict cases: compliance/exact-binomial under
#' VERIFICATION, compliance/smoke-exact-binomial under SMOKE.
#'
#' VERIFICATION (companion §3.6): H0: p <= p_req against H1: p > p_req.
#' k_min = min{k : P_{p_req}(K >= k) <= alpha}; PASS iff K >= k_min. PASS
#' means the evidence supports compliance at the configured level; FAIL
#' means compliance was not demonstrated, not that the rate is below the
#' requirement. A design too small to PASS is refused before any sample
#' runs (COMPLIANCE_INFEASIBLE).
#'
#' SMOKE (companion §5.7.3): the burden reversed, H0: p >= p_req against
#' H1: p < p_req, at every size. FAIL iff P_{p_req}(K <= k) <= alpha;
#' required_pass is the largest failing count plus one (0 when no count
#' can FAIL); PASS iff K >= required_pass. PASS means no evidence of
#' non-compliance at this size, never evidence of compliance.
#'
#' k_min and pass_possible are the compliance/exact-binomial facts of the
#' design whatever the intent (a SMOKE report states whether PASS would
#' have been evidential, §5.7.4); required_pass is the deciding rule's
#' binding count.
#'
#' Binding: decision_rule, k_min, pass_possible, required_pass, verdict,
#' configuration_error. Informational: p_value (the deciding rule's own
#' one-sided p-value at p_req), false_compliance = P_{p_req}(K >= k_min)
#' (VERIFICATION; 0 when no count can pass), false_non_compliance =
#' P_{p_req}(K < required_pass) (SMOKE), and clopper_pearson_lower, the
#' one-sided Clopper-Pearson lower bound at level 1 - alpha that may be
#' reported beside the verdict.

#' One compliance verdict.
#' @keywords internal
compliance_decision_case <- function(name, threshold, test_samples, alpha, intent,
                                     observed_successes, description = NULL) {
  err <- compliance_configuration_error(threshold, test_samples, alpha, intent)
  expected <- if (!is.na(err)) {
    list(decision_rule = NA_character_, k_min = NA_integer_, pass_possible = NA,
         required_pass = NA_integer_, verdict = NA_character_,
         configuration_error = configuration_errors(err), p_value = NA_real_,
         false_compliance = NA_real_, false_non_compliance = NA_real_,
         clopper_pearson_lower = NA_real_)
  } else {
    k <- exact_binomial_k_min(threshold, test_samples, alpha)
    d <- compliance_decide(observed_successes, threshold, test_samples, alpha, intent)
    list(
      decision_rule = d$decision_rule,
      k_min = k,
      pass_possible = !is.na(k),
      required_pass = d$required_pass,
      verdict = d$verdict,
      configuration_error = configuration_errors(),
      p_value = d$p_value,
      false_compliance = d$false_compliance,
      false_non_compliance = d$false_non_compliance,
      clopper_pearson_lower = clopper_pearson_lower(observed_successes, test_samples, alpha)
    )
  }
  case <- list(name = name)
  if (!is.null(description)) case$description <- description
  if (is.na(err)) case$decisionRule <- compliance_rule(intent)
  c(case, list(
    inputs = list(threshold = threshold, test_samples = as.integer(test_samples),
                  alpha = alpha, intent = intent,
                  observed_successes = as.integer(observed_successes)),
    expected = expected
  ))
}

#' Generate the compliance/exact-binomial verdict cases
#'
#' @return A list suitable for JSON serialisation.
#' @export
generate_compliance_decision_cases <- function() {
  cases <- list(
    # The companion's §5.5 headline: 99.5% at 477 samples cannot PASS.
    compliance_decision_case("headline_995_n477_verification_refused", 0.995, 477, 0.05,
      "VERIFICATION", 477L, "Below the feasibility minimum of 598: refused before any sample runs."),
    compliance_decision_case("headline_995_n477_smoke_pass", 0.995, 477, 0.05,
      "SMOKE", 477L, "SMOKE runs the undersized design under its own rule: 477 of 477 shows no evidence of non-compliance."),
    compliance_decision_case("headline_995_n477_smoke_fail_below_required", 0.995, 477, 0.05,
      "SMOKE", smoke_binomial_required_pass(0.995, 477, 0.05) - 1L,
      "One below the SMOKE rule's required_pass: evidence that the rate falls short of 99.5%."),
    # Canonical feasible designs, each at k_min and one below.
    compliance_decision_case("p95_n150_pass_at_k_min", 0.95, 150, 0.05, "VERIFICATION", 148L),
    compliance_decision_case("p95_n150_fail_below_k_min", 0.95, 150, 0.05, "VERIFICATION", 147L),
    compliance_decision_case("p95_n150_smoke_pass_at_k_min", 0.95, 150, 0.05, "SMOKE", 148L,
      "Above the feasibility minimum SMOKE still decides by its own rule; 148 PASSes under both."),
    compliance_decision_case("p95_n150_smoke_pass_below_k_min", 0.95, 150, 0.05, "SMOKE", 147L,
      "147 FAILs under VERIFICATION (not demonstrated) but PASSes under SMOKE (no evidence of non-compliance)."),
    compliance_decision_case("p95_n150_smoke_fail_below_required", 0.95, 150, 0.05, "SMOKE",
      smoke_binomial_required_pass(0.95, 150, 0.05) - 1L),
    compliance_decision_case("p99_n793_pass_at_k_min", 0.99, 793, 0.05, "VERIFICATION", 790L),
    compliance_decision_case("p99_n793_fail_below_k_min", 0.99, 793, 0.05, "VERIFICATION", 789L),
    compliance_decision_case("p999_n2995_zero_failures_pass", 0.999, 2995, 0.05, "VERIFICATION", 2995L,
      "The zero-failure minimum: k_min = n."),
    compliance_decision_case("p999_n2995_one_failure_fail", 0.999, 2995, 0.05, "VERIFICATION", 2994L),
    compliance_decision_case("p999_n2994_verification_refused", 0.999, 2994, 0.05, "VERIFICATION", 2994L,
      "One below the zero-failure minimum."),
    # Ordinary margins.
    compliance_decision_case("compliance_pass_clear_margin", 0.80, 100, 0.05, "VERIFICATION", 95L),
    compliance_decision_case("compliance_fail_not_demonstrated", 0.90, 100, 0.05, "VERIFICATION", 92L,
      "The observed rate exceeds the requirement, yet compliance is not demonstrated."),
    compliance_decision_case("alpha001_p90_n60_pass_at_k_min", 0.90, 60, 0.01, "VERIFICATION",
      exact_binomial_k_min(0.90, 60, 0.01)),
    compliance_decision_case("alpha001_p90_n60_fail_below_k_min", 0.90, 60, 0.01, "VERIFICATION",
      exact_binomial_k_min(0.90, 60, 0.01) - 1L),
    compliance_decision_case("alpha0001_p98_n800_fail", 0.98, 800, 0.001, "VERIFICATION", 788L),
    # Exact boundaries: the upper tail at k_min equals alpha exactly, with
    # alpha declared as that decimal. The inclusive rule admits k_min;
    # double precision alone does not (§10.6).
    compliance_decision_case("exact_boundary_p50_n5", 0.5, 5, 0.03125, "VERIFICATION", 5L,
      "P(K >= 5) = 1/32 = alpha exactly: the design is feasible and 5 of 5 PASSes."),
    compliance_decision_case("exact_boundary_p60_n10", 0.6, 10, 0.0463574016, "VERIFICATION", 9L,
      "P(K >= 9) = 0.0463574016 = alpha exactly: k_min = 9."),
    # The conflation detector: the observation regression_decision's
    # conflation_detector_regression_pass PASSes (K = c = 91 of 100) FAILs
    # when c / n_t = 0.91 is taken as a given requirement.
    compliance_decision_case("conflation_detector_compliance_fail", 0.91, 100, 0.05, "VERIFICATION", 91L),
    # compliance/smoke-exact-binomial at sizes VERIFICATION refuses.
    compliance_decision_case("smoke_p99_n100_perfect_pass", 0.99, 100, 0.05, "SMOKE", 100L,
      "100 of 100 against a 99% requirement: VERIFICATION would refuse the design (299 needed); SMOKE PASSes."),
    compliance_decision_case("smoke_p99_n100_pass_at_required", 0.99, 100, 0.05, "SMOKE", 97L),
    compliance_decision_case("smoke_p99_n100_fail_below_required", 0.99, 100, 0.05, "SMOKE", 96L,
      "Four misses in 100 are evidence that the rate falls short of 99%."),
    compliance_decision_case("smoke_p99_n30_two_misses_fail", 0.99, 30, 0.05, "SMOKE", 28L,
      "P(K <= 28) = 0.036 at 99%: two misses in 30 are evidence of non-compliance."),
    compliance_decision_case("smoke_p99_n30_one_miss_pass", 0.99, 30, 0.05, "SMOKE", 29L),
    compliance_decision_case("smoke_p99_n5_one_miss_fail", 0.99, 5, 0.05, "SMOKE", 4L,
      "At the five-sample SMOKE default against 99%, any miss FAILs: P(K <= 4) = 0.049."),
    compliance_decision_case("smoke_p90_n5_pass_at_required", 0.90, 5, 0.05, "SMOKE", 3L),
    compliance_decision_case("smoke_p90_n5_fail_below_required", 0.90, 5, 0.05, "SMOKE", 2L),
    compliance_decision_case("smoke_p50_n1_fail_not_possible", 0.50, 1, 0.05, "SMOKE", 0L,
      "No count can FAIL at this size (P(K <= 0) = 0.5): required_pass is 0 and the run PASSes, carrying no evidence."),
    compliance_decision_case("smoke_exact_boundary_p50_n5", 0.5, 5, 0.03125, "SMOKE", 0L,
      "P(K <= 0) = 1/32 = alpha exactly: the inclusive rule FAILs 0 of 5, so required_pass = 1.")
  )

  list(
    suite = "compliance_decision",
    description = paste(
      "Verdicts of normative compliance (companion §3.6, §5.7). Under VERIFICATION by",
      "compliance/exact-binomial: H0: p <= p_req against H1: p > p_req; PASS iff K >= k_min; a design",
      "too small to PASS is refused as COMPLIANCE_INFEASIBLE. Under SMOKE by",
      "compliance/smoke-exact-binomial at every size: H0: p >= p_req against H1: p < p_req; FAIL iff",
      "P(K <= k) <= alpha; PASS iff K >= required_pass, meaning no evidence of non-compliance, never",
      "evidence of compliance. Binding: decision_rule, k_min, pass_possible, required_pass, verdict,",
      "configuration_error. Informational: p_value, false_compliance, false_non_compliance,",
      "clopper_pearson_lower. Frameworks MUST evaluate these cases through their production verdict path."
    ),
    method = paste(
      "compliance/exact-binomial v1: k_min = min{k : P_{p_req}(K >= k) <= alpha}, K ~ Bin(n, p_req)",
      "(null when no k <= n qualifies); PASS iff K >= k_min; p_value = P_{p_req}(K >= K_obs).",
      "COMPLIANCE_INFEASIBLE iff intent is VERIFICATION and n < ceiling(log(alpha) / log(p_req)).",
      "compliance/smoke-exact-binomial v1: required_pass = 1 + max{k : P_{p_req}(K <= k) <= alpha}",
      "(0 when none); PASS iff K >= required_pass; p_value = P_{p_req}(K <= K_obs). required_pass is",
      "k_min under VERIFICATION. false_compliance = P_{p_req}(K >= k_min); false_non_compliance =",
      "P_{p_req}(K < required_pass); clopper_pearson_lower = qbeta(alpha, K, n - K + 1) (0 at K = 0).",
      "Exact boundaries are decided in rational arithmetic (R/exact_boundary.R)."
    ),
    tolerance = 1e-10,
    cases = cases
  )
}
