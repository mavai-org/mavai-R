#' Explicit latency requirements under latency/compliance-exact-binomial:
#' verdict cases.
#'
#' An explicit requirement "the p-th percentile of successful latencies is
#' at most tau" is tested as H0: F(tau) <= p against H1: F(tau) > p
#' (companion §12.3). Y counts the successful latencies at or below tau;
#' y_min is the smallest count whose upper binomial tail under p is at
#' most alpha; PASS iff Y >= y_min. The rule is compliance/exact-binomial
#' applied to that count.
#'
#' Before the run, the planned number of samples is an upper bound on the
#' number of successful latencies: under VERIFICATION a plan below the
#' feasibility minimum is refused (COMPLIANCE_INFEASIBLE), since no count
#' could pass even if every sample succeeded. After the run the binding
#' check uses the realised count: below the feasibility minimum the
#' verdict is INCONCLUSIVE.
#'
#' Binding: test_samples, within_threshold, y_min, pass_possible,
#' verdict, configuration_error. Informational: false_compliance,
#' clopper_pearson_lower, observed_percentile_ms and
#' advisory_percentile_pass (the raw percentile comparison, which is
#' advisory and decides nothing).

#' Latencies for a case: `within` values at or below tau, the rest above
#' @keywords internal
latency_compliance_sample <- function(n_s, within, threshold_ms) {
  if (n_s == 0) return(numeric(0))
  below <- if (within > 0) threshold_ms - 150 + round(seq(0, 149, length.out = within)) else numeric(0)
  above <- if (n_s > within) threshold_ms + round(seq(1, 400, length.out = n_s - within)) else numeric(0)
  c(below, above)
}

#' One latency compliance case.
#' @keywords internal
latency_compliance_case <- function(name, percentile, threshold_ms, alpha, intent,
                                    planned_samples, latencies, description = NULL) {
  err <- compliance_configuration_error(percentile, planned_samples, alpha, intent)
  expected <- if (!is.na(err)) {
    list(test_samples = NA_integer_, within_threshold = NA_integer_, y_min = NA_integer_,
         pass_possible = NA, verdict = NA_character_, configuration_error = err,
         false_compliance = NA_real_, clopper_pearson_lower = NA_real_,
         observed_percentile_ms = NA_real_, advisory_percentile_pass = NA)
  } else {
    v <- latency_compliance_verdict(latencies, threshold_ms, percentile, alpha)
    c(v[c("test_samples", "within_threshold", "y_min", "pass_possible", "verdict")],
      list(configuration_error = NA_character_),
      v[c("false_compliance", "clopper_pearson_lower", "observed_percentile_ms",
          "advisory_percentile_pass")])
  }
  case <- list(name = name)
  if (!is.null(description)) case$description <- description
  c(case, list(
    inputs = list(percentile = percentile, threshold_ms = threshold_ms, alpha = alpha,
                  intent = intent, planned_samples = as.integer(planned_samples),
                  latencies = if (is.na(err)) latencies else list()),
    expected = expected
  ))
}

#' Generate the latency/compliance-exact-binomial verdict cases
#'
#' @return A list suitable for JSON serialisation.
#' @export
generate_latency_compliance_decision_cases <- function() {
  s <- latency_compliance_sample
  cases <- list(
    # The companion's §12.3 example: p95 <= 500 ms at alpha 0.05 over 100
    # successful latencies. y_min = 99; the raw percentile passes from 95.
    latency_compliance_case("p95_n100_pass_at_y_min", 0.95, 500, 0.05, "VERIFICATION", 100L,
      s(100, 99, 500)),
    latency_compliance_case("p95_n100_fail_below_y_min", 0.95, 500, 0.05, "VERIFICATION", 100L,
      s(100, 98, 500)),
    latency_compliance_case("p95_n100_advisory_pass_not_demonstrated", 0.95, 500, 0.05,
      "VERIFICATION", 100L, s(100, 95, 500),
      "The observed p95 is within 500 ms (95 of 100 at or below), so the advisory comparison passes; compliance is not demonstrated."),
    latency_compliance_case("p95_n100_advisory_fail", 0.95, 500, 0.05, "VERIFICATION", 100L,
      s(100, 94, 500), "94 of 100 within: the observed p95 exceeds 500 ms and the verdict is FAIL."),
    latency_compliance_case("tie_at_threshold_counts_within", 0.95, 500, 0.05, "VERIFICATION", 100L,
      c(rep(500, 99), 900),
      "Latencies equal to the threshold count as within it."),
    # Feasibility: at p95, alpha 0.05, no count can pass below 59 latencies.
    latency_compliance_case("p95_plan_58_verification_refused", 0.95, 500, 0.05, "VERIFICATION", 58L,
      numeric(0), "The plan of 58 is below the feasibility minimum of 59 even if every sample succeeds."),
    latency_compliance_case("p95_plan_58_smoke_inconclusive", 0.95, 500, 0.05, "SMOKE", 58L,
      s(58, 58, 500), "SMOKE runs the undersized plan; 58 of 58 within the threshold cannot PASS."),
    latency_compliance_case("p95_plan_60_realised_58_inconclusive", 0.95, 500, 0.05, "VERIFICATION", 60L,
      s(58, 58, 500),
      "The plan is feasible, but two samples fail and 58 successful latencies remain: too few to decide."),
    latency_compliance_case("p95_n59_zero_exceedances_pass", 0.95, 500, 0.05, "VERIFICATION", 59L,
      s(59, 59, 500), "The feasibility minimum: y_min = n_s."),
    latency_compliance_case("p99_n500_pass_at_y_min", 0.99, 1200, 0.05, "VERIFICATION", 500L,
      s(500, exact_binomial_k_min(0.99, 500, 0.05), 1200)),
    latency_compliance_case("p99_n500_fail_below_y_min", 0.99, 1200, 0.05, "VERIFICATION", 500L,
      s(500, exact_binomial_k_min(0.99, 500, 0.05) - 1L, 1200)),
    latency_compliance_case("p90_n200_alpha001_pass_at_y_min", 0.90, 800, 0.01, "VERIFICATION", 200L,
      s(200, exact_binomial_k_min(0.90, 200, 0.01), 800)),
    latency_compliance_case("p90_n200_alpha001_fail_below_y_min", 0.90, 800, 0.01, "VERIFICATION", 200L,
      s(200, exact_binomial_k_min(0.90, 200, 0.01) - 1L, 800)),
    latency_compliance_case("p50_n40_pass_at_y_min", 0.50, 300, 0.05, "VERIFICATION", 40L,
      s(40, exact_binomial_k_min(0.50, 40, 0.05), 300)),
    # Exact boundary: P(Y >= 5) = 1/32 = alpha at p50, n_s = 5.
    latency_compliance_case("exact_boundary_p50_n5", 0.50, 300, 0.03125, "VERIFICATION", 5L,
      s(5, 5, 300), "P(Y >= 5) = 1/32 = alpha exactly: the inclusive rule admits 5 of 5.")
  )

  list(
    suite = "latency_compliance_decision",
    description = paste(
      "Verdicts of explicit latency requirements under latency/compliance-exact-binomial",
      "(companion §12.3): a requirement that the p-th percentile of successful latencies is at",
      "most tau is tested as H0: F(tau) <= p against H1: F(tau) > p. Y counts the successful",
      "latencies at or below tau; PASS iff Y >= y_min, the compliance/exact-binomial k_min at",
      "p_req = p over the realised number of successful latencies. A VERIFICATION plan whose",
      "planned samples are below the feasibility minimum is refused as COMPLIANCE_INFEASIBLE; a",
      "run whose realised successful count is below it is INCONCLUSIVE. The raw comparison of",
      "the observed percentile with tau is advisory and reported only. Binding: test_samples,",
      "within_threshold, y_min, pass_possible, verdict, configuration_error. Informational:",
      "false_compliance, clopper_pearson_lower, observed_percentile_ms, advisory_percentile_pass.",
      "Frameworks MUST evaluate these cases through their production verdict path."
    ),
    method = paste(
      "latency/compliance-exact-binomial v1: Y = #{latencies <= tau}; y_min = min{y :",
      "P_p(Y >= y) <= alpha}, Y ~ Bin(n_s, p) (null when no y <= n_s qualifies); PASS iff",
      "Y >= y_min; INCONCLUSIVE when y_min is null. COMPLIANCE_INFEASIBLE iff intent is",
      "VERIFICATION and planned_samples < ceiling(log(alpha) / log(p)). false_compliance =",
      "P_p(Y >= y_min); clopper_pearson_lower = qbeta(alpha, Y, n_s - Y + 1) (0 at Y = 0);",
      "observed_percentile_ms is the nearest-rank percentile, rank ceiling(p n_s);",
      "advisory_percentile_pass = observed_percentile_ms <= tau."
    ),
    tolerance = 1e-10,
    cases = cases
  )
}
