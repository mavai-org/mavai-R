#' Normative compliance under compliance/exact-binomial: verdict cases.
#'
#' H0: p <= p_req against H1: p > p_req (companion §3.6). k_min =
#' min{k : P_{p_req}(K >= k) <= alpha}; PASS iff K >= k_min. PASS means the
#' evidence supports compliance at the configured level; FAIL means
#' compliance was not demonstrated, not that the rate is below the
#' requirement.
#'
#' Intent matters only below the feasibility minimum: under VERIFICATION
#' the design is refused before any sample runs (COMPLIANCE_INFEASIBLE);
#' under SMOKE it runs, cannot PASS, and says so (pass_possible = false)
#' rather than implying a directional FAIL.
#'
#' Binding: k_min, pass_possible, verdict, configuration_error.
#' Informational: false_compliance = P_{p_req}(K >= k_min) (0 when no count
#' can pass), and clopper_pearson_lower, the one-sided Clopper-Pearson
#' lower bound at level 1 - alpha that may be reported beside the verdict.

#' One compliance verdict.
#' @keywords internal
compliance_decision_case <- function(name, threshold, test_samples, alpha, intent,
                                     observed_successes, description = NULL) {
  err <- compliance_configuration_error(threshold, test_samples, alpha, intent)
  expected <- if (!is.na(err)) {
    list(k_min = NA_integer_, pass_possible = NA, verdict = NA_character_,
         configuration_error = configuration_errors(err), false_compliance = NA_real_,
         clopper_pearson_lower = NA_real_)
  } else {
    k <- exact_binomial_k_min(threshold, test_samples, alpha)
    possible <- !is.na(k)
    list(
      k_min = k,
      pass_possible = possible,
      verdict = if (possible && observed_successes >= k) "PASS" else "FAIL",
      configuration_error = configuration_errors(),
      false_compliance = if (possible) pbinom(k - 1, test_samples, threshold, lower.tail = FALSE) else 0,
      clopper_pearson_lower = clopper_pearson_lower(observed_successes, test_samples, alpha)
    )
  }
  case <- list(name = name)
  if (!is.null(description)) case$description <- description
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
    compliance_decision_case("headline_995_n477_smoke_pass_not_possible", 0.995, 477, 0.05,
      "SMOKE", 477L, "SMOKE runs the undersized design; even 477 of 477 cannot PASS."),
    # Canonical feasible designs, each at k_min and one below.
    compliance_decision_case("p95_n150_pass_at_k_min", 0.95, 150, 0.05, "VERIFICATION", 148L),
    compliance_decision_case("p95_n150_fail_below_k_min", 0.95, 150, 0.05, "VERIFICATION", 147L),
    compliance_decision_case("p95_n150_smoke_pass_at_k_min", 0.95, 150, 0.05, "SMOKE", 148L,
      "Above the feasibility minimum SMOKE and VERIFICATION decide alike."),
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
    compliance_decision_case("conflation_detector_compliance_fail", 0.91, 100, 0.05, "VERIFICATION", 91L)
  )

  list(
    suite = "compliance_decision",
    description = paste(
      "Verdicts of normative compliance under compliance/exact-binomial (companion §3.6, §5.7):",
      "H0: p <= p_req against H1: p > p_req; PASS iff K >= k_min. PASS means the evidence supports",
      "compliance at the configured level; FAIL means compliance was not demonstrated. Under",
      "VERIFICATION intent a design too small to PASS is refused as COMPLIANCE_INFEASIBLE; under",
      "SMOKE it runs and reports pass_possible = false. Binding: k_min, pass_possible, verdict,",
      "configuration_error. Informational: false_compliance, clopper_pearson_lower. Frameworks",
      "MUST evaluate these cases through their production verdict path."
    ),
    method = paste(
      "compliance/exact-binomial v1: k_min = min{k : P_{p_req}(K >= k) <= alpha}, K ~ Bin(n, p_req)",
      "(null when no k <= n qualifies); PASS iff K >= k_min. COMPLIANCE_INFEASIBLE iff intent is",
      "VERIFICATION and n < ceiling(log(alpha) / log(p_req)). false_compliance =",
      "P_{p_req}(K >= k_min); clopper_pearson_lower = qbeta(alpha, K, n - K + 1) (0 at K = 0)."
    ),
    tolerance = 1e-10,
    cases = cases
  )
}
