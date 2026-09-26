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
#'   - `regression_power` (regression/fisher): the exact design power at a
#'     declared margin, with the baseline and the test both yet to be
#'     drawn: sum_k P_{p_b}(K_b = k) P_{p_b - delta}(K_t < c(k)).
#'   - `regression_resolved_power` (regression/fisher): once a baseline has
#'     been observed its cutoff c(K_b) is fixed, and the power of that
#'     resolved test at a design alternative rate p_design is
#'     P_{p_design}(K_t < c(K_b)). It answers a different question from the
#'     design power and is reported beside it, named apart.
#'   - `regression_mdd` (regression/fisher): where no margin is declared,
#'     the minimum detectable degradation at the target power (default
#'     0.80), null when no degradation reaches it.

#' @keywords internal
compliance_sizing_case <- function(name, threshold, delta, alpha, power = 0.80,
                                   alternative_rate = NULL) {
  s <- compliance_exact_sizing(threshold, delta, alpha, power, alternative_rate = alternative_rate)
  inputs <- list(threshold = threshold, min_detectable_effect = delta, alpha = alpha,
                 power = power)
  if (!is.null(alternative_rate)) inputs$alternative_rate <- alternative_rate
  list(
    name = name, approach = "compliance_sizing", decisionRule = "compliance/exact-binomial",
    inputs = inputs,
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
    expected = list(design_power = fisher_power(n_b, n_t, alpha, baseline_rate, delta))
  )
}

#' @keywords internal
regression_resolved_power_case <- function(name, k_b, n_b, n_t, alpha, design_alternative_rate) {
  c_int <- fisher_cutoff(k_b, n_b, n_t, alpha)
  list(
    name = name, approach = "regression_resolved_power", decisionRule = "regression/fisher",
    inputs = list(baseline_successes = as.integer(k_b), baseline_trials = as.integer(n_b),
                  test_samples = as.integer(n_t), alpha = alpha,
                  design_alternative_rate = design_alternative_rate),
    expected = list(cutoff_integer = c_int,
                    resolved_test_power = pbinom(c_int - 1, n_t, design_alternative_rate))
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
    compliance_sizing_case("compliance_p95_declared_alternative_098_a05", 0.95, 0.02, 0.05,
                           alternative_rate = 0.98),
    compliance_sizing_case("compliance_p98_declared_alternative_0985_a0001", 0.98, 0.005, 0.001,
                           alternative_rate = 0.985),
    regression_power_case("regression_nb1000_nt100_p95_delta005_a05", 1000, 100, 0.05, 0.95, 0.05),
    regression_power_case("regression_nb1000_nt1000_p95_delta002_a05", 1000, 1000, 0.05, 0.95, 0.02),
    regression_power_case("regression_nb2000_nt1000_p951_delta0026_a05", 2000, 1000, 0.05, 0.951, 0.026),
    regression_power_case("regression_nb100_nt100_p99_delta005_a01", 100, 100, 0.01, 0.99, 0.05),
    regression_power_case("regression_nb30_nt25_p90_delta010_a05", 30, 25, 0.05, 0.90, 0.10),
    regression_resolved_power_case("resolved_kb951_nb1000_nt1000_at0925_a05", 951, 1000, 1000, 0.05, 0.925),
    regression_resolved_power_case("resolved_kb951_nb1000_nt100_at090_a05", 951, 1000, 100, 0.05, 0.90),
    regression_resolved_power_case("resolved_kb100_nb100_nt100_at090_a05", 100, 100, 100, 0.05, 0.90),
    regression_resolved_power_case("resolved_kb1920_nb2000_nt463_at093_a05", 1920, 2000, 463, 0.05, 0.93),
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
      "(compliance/exact-binomial), at the declared alternative rate where one is declared",
      "(alternative_kind DECLARED), else at p_req + delta (MARGIN) or the midway rate (MIDWAY).",
      "regression_power: the design power of regression/fisher at a declared margin, baseline and",
      "test both yet to be drawn. regression_resolved_power: the power of the test resolved",
      "against an observed baseline, whose cutoff is fixed, at a design alternative rate; it is",
      "reported beside the design power and named apart. regression_mdd: the minimum",
      "detectable degradation at the target design power when no margin is declared. Each case",
      "names its rule in decisionRule."
    ),
    method = paste(
      "compliance_sizing: power(n) = P_{p1}(K >= k_min(p_req, n, alpha)), 0 where infeasible;",
      "p1 = the declared alternative_rate (DECLARED), else p_req + delta (MARGIN), or",
      "(p_req + 1)/2 when p_req + delta >= 1 (MIDWAY);",
      "required_samples = 1 + the largest n <= 20000 with power(n) < target (null if that is",
      "20000); first_crossing = the smallest n with power(n) >= target.",
      "regression_power: design_power = sum_k dbinom(k, n_b, p_b) P_{p_b - delta}(K_t < c(k)),",
      "c the regression/fisher cutoff. regression_resolved_power: resolved_test_power =",
      "pbinom(c(K_b) - 1, n_t, design_alternative_rate), c(K_b) the cutoff at the observed",
      "baseline count. regression_mdd: the smallest delta in (0, p_b] with that power",
      ">= target (bisection to 1e-12), null when delta = p_b falls short."
    ),
    tolerance = 1e-9,
    cases = cases
  )
}
