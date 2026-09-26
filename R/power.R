#' Exact power and sizing under the 1.5.0 decision rules.
#'
#' Three approaches, each an exact finite computation against the
#' operative decision rule (no normal approximation):
#'
#'   - `compliance_sizing` (compliance/exact-binomial): the smallest n from
#'     which P(PASS | alternative) stays at or above the target power —
#'     not the first crossing, since power is a sawtooth in n — searched
#'     to n = 20000 with the feasibility gate inside the search. The
#'     alternative is p_req + delta, or the midway rate (p_req + 1)/2
#'     where p_req + delta >= 1.
#'   - `regression_power` (regression/fisher): the exact power at a
#'     declared margin, sum_k P_{p_b}(K_b = k) P_{p_b - delta}(K_t < c(k)).
#'   - `regression_mdd` (regression/fisher): where no margin is declared,
#'     the minimum detectable degradation at the target power (default
#'     0.80), null when no degradation reaches it.

#' @keywords internal
compliance_sizing_case <- function(name, threshold, delta, alpha, power = 0.80) {
  s <- compliance_exact_sizing(threshold, delta, alpha, power)
  list(
    name = name, approach = "compliance_sizing", decisionRule = "compliance/exact-binomial",
    inputs = list(threshold = threshold, min_detectable_effect = delta, alpha = alpha,
                  power = power),
    expected = list(required_samples = s$required_samples, achieved_power = s$achieved_power,
                    alternative_rate = s$alternative_rate, alternative_kind = s$alternative_kind,
                    first_crossing = s$first_crossing)
  )
}

#' @keywords internal
regression_power_case <- function(name, n_b, n_t, alpha, baseline_rate, delta) {
  list(
    name = name, approach = "regression_power", decisionRule = "regression/fisher",
    inputs = list(baseline_trials = as.integer(n_b), test_samples = as.integer(n_t),
                  alpha = alpha, baseline_rate = baseline_rate, min_detectable_effect = delta),
    expected = list(achieved_power = fisher_power(n_b, n_t, alpha, baseline_rate, delta))
  )
}

#' @keywords internal
regression_mdd_case <- function(name, n_b, n_t, alpha, baseline_rate, power = 0.80) {
  list(
    name = name, approach = "regression_mdd", decisionRule = "regression/fisher",
    inputs = list(baseline_trials = as.integer(n_b), test_samples = as.integer(n_t),
                  alpha = alpha, baseline_rate = baseline_rate, power = power),
    expected = list(minimum_detectable_degradation =
                      fisher_minimum_detectable_degradation(n_b, n_t, alpha, baseline_rate, power))
  )
}

#' Generate power analysis reference cases
#'
#' @return A list suitable for JSON serialisation.
#' @export
generate_power_analysis_cases <- function() {
  cases <- list(
    compliance_sizing_case("compliance_p95_delta002_a05", 0.95, 0.02, 0.05),
    compliance_sizing_case("compliance_p95_delta001_a05", 0.95, 0.01, 0.05),
    compliance_sizing_case("compliance_p90_delta005_a05", 0.90, 0.05, 0.05),
    compliance_sizing_case("compliance_p80_delta010_a01", 0.80, 0.10, 0.01),
    compliance_sizing_case("compliance_p50_delta010_a10", 0.50, 0.10, 0.10),
    compliance_sizing_case("compliance_p95_delta005_a05_midway", 0.95, 0.05, 0.05),
    compliance_sizing_case("compliance_p99_delta002_a05_midway", 0.99, 0.02, 0.05),
    compliance_sizing_case("compliance_p95_delta002_a05_power95", 0.95, 0.02, 0.05, power = 0.95),
    regression_power_case("regression_nb1000_nt100_p95_delta005_a05", 1000, 100, 0.05, 0.95, 0.05),
    regression_power_case("regression_nb1000_nt1000_p95_delta002_a05", 1000, 1000, 0.05, 0.95, 0.02),
    regression_power_case("regression_nb2000_nt1000_p951_delta0026_a05", 2000, 1000, 0.05, 0.951, 0.026),
    regression_power_case("regression_nb100_nt100_p99_delta005_a01", 100, 100, 0.01, 0.99, 0.05),
    regression_power_case("regression_nb30_nt25_p90_delta010_a05", 30, 25, 0.05, 0.90, 0.10),
    regression_mdd_case("regression_mdd_nb1000_nt100_p95_a05", 1000, 100, 0.05, 0.95),
    regression_mdd_case("regression_mdd_nb1000_nt1000_p95_a05", 1000, 1000, 0.05, 0.95),
    regression_mdd_case("regression_mdd_nb30_nt25_p90_a05", 30, 25, 0.05, 0.90),
    regression_mdd_case("regression_mdd_nb100_nt100_p100_a05", 100, 100, 0.05, 1.00),
    regression_mdd_case("regression_mdd_nb10_nt1_p50_a001_none", 10, 1, 0.001, 0.50)
  )

  list(
    suite = "power_analysis",
    description = paste(
      "Exact power and sizing against the operative decision rules. compliance_sizing: the",
      "smallest n from which exact power at the alternative stays at or above target",
      "(compliance/exact-binomial). regression_power: exact power of regression/fisher at a",
      "declared margin. regression_mdd: the minimum detectable degradation at the target power",
      "when no margin is declared. Each case names its rule in decisionRule."
    ),
    method = paste(
      "compliance_sizing: power(n) = P_{p1}(K >= k_min(p_req, n, alpha)), 0 where infeasible;",
      "p1 = p_req + delta, or (p_req + 1)/2 when p_req + delta >= 1 (alternative_kind MIDWAY);",
      "required_samples = 1 + the largest n <= 20000 with power(n) < target (null if that is",
      "20000); first_crossing = the smallest n with power(n) >= target.",
      "regression_power: sum_k dbinom(k, n_b, p_b) P_{p_b - delta}(K_t < c(k)), c the",
      "regression/fisher cutoff. regression_mdd: the smallest delta in (0, p_b] with that power",
      ">= target (bisection to 1e-12), null when delta = p_b falls short."
    ),
    tolerance = 1e-9,
    cases = cases
  )
}
