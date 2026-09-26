#' Check verification feasibility under compliance/exact-binomial
#'
#' A normative design of size n against a requirement p_req can PASS iff
#' the all-success outcome clears the exact test, P_{p_req}(K >= n) =
#' p_req^n <= alpha. The minimum feasible size is
#' ceiling(log(alpha) / log(p_req)). Feasible means PASS is possible, not
#' that the test is adequately powered.
#'
#' @param target_proportion Numeric. The requirement p_req.
#' @param sample_size Integer. The configured sample size.
#' @param alpha Numeric. One-sided level.
#' @return A list with feasible, minimum_samples, and the criterion.
#' @export
check_feasibility <- function(target_proportion, sample_size, alpha) {
  n_min <- exact_binomial_min_feasible_n(target_proportion, alpha)
  list(
    feasible = sample_size >= n_min,
    minimum_samples = n_min,
    criterion = "exact_binomial_pass_possible"
  )
}

#' @keywords internal
feasibility_case <- function(name, target_proportion, sample_size, alpha) {
  list(
    name = name,
    inputs = list(target_proportion = target_proportion,
                  sample_size = as.integer(sample_size), alpha = alpha),
    expected = check_feasibility(target_proportion, sample_size, alpha)
  )
}

#' Generate feasibility reference cases
#'
#' @return A list suitable for JSON serialisation.
#' @export
generate_feasibility_cases <- function() {
  cases <- list(
    feasibility_case("fair_coin_n5_a05", 0.50, 5, 0.05),
    feasibility_case("fair_coin_n4_a05_undersized", 0.50, 4, 0.05),
    feasibility_case("high_rate_n30_a05", 0.90, 30, 0.05),
    feasibility_case("high_rate_n20_a05_undersized", 0.90, 20, 0.05),
    feasibility_case("very_high_rate_n55_a05_undersized", 0.95, 55, 0.05),
    feasibility_case("very_high_rate_n150_a05", 0.95, 150, 0.05),
    feasibility_case("high_rate_n30_a01_undersized", 0.90, 30, 0.01),
    feasibility_case("high_rate_n60_a01", 0.90, 60, 0.01),
    feasibility_case("two_nines_n793_a05", 0.99, 793, 0.05),
    # The companion's §5.5 headline: 99.5% at 477 samples cannot PASS.
    feasibility_case("headline_995_n477_a05_undersized", 0.995, 477, 0.05),
    feasibility_case("headline_995_n598_a05_at_minimum", 0.995, 598, 0.05),
    # Three nines: the zero-failure minimum and one below it.
    feasibility_case("three_nines_n2995_a05_at_minimum", 0.999, 2995, 0.05),
    feasibility_case("three_nines_n2994_a05_undersized", 0.999, 2994, 0.05),
    feasibility_case("near_perfect_n100_a05_undersized", 0.9999, 100, 0.05),
    feasibility_case("high_rate_n22_a10", 0.90, 22, 0.10),
    feasibility_case("high_rate_n66_a001", 0.90, 66, 0.001),
    # Exact boundary: 0.5^5 = 1/32 = alpha; feasible at 5 under the inclusive rule.
    feasibility_case("exact_boundary_p50_n5_a003125", 0.50, 5, 0.03125)
  )

  list(
    suite = "feasibility",
    description = paste(
      "Verification feasibility under compliance/exact-binomial: can a normative test of this",
      "size PASS at all? Feasible iff n >= ceiling(log(alpha) / log(p_req)). Under VERIFICATION",
      "intent an infeasible design is refused as COMPLIANCE_INFEASIBLE (see compliance_decision);",
      "under SMOKE it runs and reports that PASS is not possible at this size."
    ),
    method = paste(
      "PASS is possible iff P_{p_req}(K >= n) = p_req^n <= alpha;",
      "minimum_samples = ceiling(log(alpha) / log(p_req)), confirmed against that definition."
    ),
    tolerance = 0,
    cases = cases
  )
}
