#' Risk-driven sizing under regression/fisher (companion §5.4.1).
#'
#' Two sizing operations, named apart:
#'
#'   - design sizing, before the baseline exists: the baseline and the test
#'     are planned together, the baseline at a planned size n_b and an
#'     assumed rate p0, and the design power averages over the baseline
#'     count yet to be drawn (approaches power_at, required_n,
#'     detectable_rate below);
#'   - resolved sizing, against an existing baseline: its observed count K_b
#'     fixes the cutoff c(K_b; n_b, n_t, alpha) for every candidate n_t, and
#'     the resolved power is P_{p_design}(K_t < c(K_b; n_b, n_t, alpha))
#'     (approaches resolved_power_at, resolved_required_n). Once a baseline
#'     exists, BASELINE_TOO_SMALL is judged by this power.
#'
#' Design sizing:
#'
#' A regression test's cutoff moves with its own size, so sizing is done
#' against the operative rule itself: the exact power of regression/fisher
#' at a declared design alternative rate p_design (the true rate at which
#' the test must reach its target power; not a measured estimate, and not
#' a tolerance: the test still flags any degradation from the baseline),
#' with the baseline's n_b trials at rate p0 and the test's n_t trials at
#' p_design:
#'
#'     Power(n_t) = sum_k P_{p0}(K_b = k) P_{p_design}(K_t < c(k; n_b, n_t, alpha)).
#'
#' Three approaches: POWER_AT a candidate n_t; REQUIRED_N, the smallest
#' n_t <= n_b from which power stays at or above the target for every
#' larger n_t up to n_b (power is a sawtooth in n_t, so not the first
#' crossing); DETECTABLE_RATE, the largest p_design detectable at the target
#' power with n_t samples. Designs outside the domain are published as
#' refusals: ZERO_BASELINE (p0 = 0, §4.3.4), ALTERNATIVE_NOT_BELOW_BASELINE
#' (p_design >= p0), TEST_LARGER_THAN_BASELINE (n_t > n_b), and
#' BASELINE_TOO_SMALL (the target is not reached and held within
#' n_t <= n_b).
#'
#' The sum runs over the baseline counts carrying all but 2e-17 of the
#' binomial mass (qbinom(1e-17) .. qbinom(1 - 1e-17)); the truncation moves
#' the power by less than 2e-17.

#' @keywords internal
sizing_window <- function(n_b, p0) {
  if (p0 >= 1) return(n_b)
  qbinom(1e-17, n_b, p0):qbinom(1e-17, n_b, p0, lower.tail = FALSE)
}

#' Exact power of regression/fisher at p_design (companion §5.4.1)
#'
#' @param test_samples n_t.
#' @param baseline_rate p0.
#' @param baseline_trials n_b.
#' @param design_alternative_rate p_design, the design alternative rate.
#' @param alpha One-sided level.
#' @export
risk_sizing_power <- function(test_samples, baseline_rate, baseline_trials,
                              design_alternative_rate, alpha) {
  k <- sizing_window(baseline_trials, baseline_rate)
  cut <- fisher_cutoffs(baseline_trials, test_samples, alpha, k_b = k)
  w <- dbinom(k, baseline_trials, baseline_rate)
  lower <- c(0, pbinom(0:(test_samples - 1), test_samples, design_alternative_rate))
  sum(w * lower[cut + 1L])
}

#' Smallest n_t <= n_b from which exact power stays at target (§5.4.1)
#'
#' Scans down from n_b to the first n_t whose power falls below target;
#' the answer is the next one up. NA when power at n_b itself is short.
#' @export
risk_sizing_required_n <- function(baseline_rate, baseline_trials, design_alternative_rate,
                                   alpha, target_power) {
  for (n in seq(baseline_trials, 1L)) {
    if (risk_sizing_power(n, baseline_rate, baseline_trials, design_alternative_rate, alpha) <
        target_power) {
      return(if (n == baseline_trials) NA_integer_ else as.integer(n + 1L))
    }
  }
  1L
}

#' Largest p_design detectable at the target power with n_t samples (§5.4.1)
#'
#' Power falls as p_design rises toward p0, so bisection on p_design over
#' (0, p0) to 1e-10. NA when even p_design = 0 falls short.
#' @export
risk_sizing_detectable_rate <- function(test_samples, baseline_rate, baseline_trials,
                                        alpha, target_power) {
  pw <- function(pm) risk_sizing_power(test_samples, baseline_rate, baseline_trials, pm, alpha)
  if (pw(0) < target_power) return(NA_real_)
  lo <- 0; hi <- baseline_rate
  while (hi - lo > 1e-10) {
    mid <- (lo + hi) / 2
    if (pw(mid) >= target_power) lo <- mid else hi <- mid
  }
  lo
}

#' The refusal category of a sizing design, or NA.
#' @keywords internal
sizing_refusal <- function(baseline_rate, design_alternative_rate = NULL, baseline_trials,
                           test_samples = NULL) {
  if (baseline_rate == 0) return("ZERO_BASELINE")
  if (!is.null(design_alternative_rate) && design_alternative_rate >= baseline_rate) {
    return("ALTERNATIVE_NOT_BELOW_BASELINE")
  }
  if (!is.null(test_samples) && test_samples > baseline_trials) return("TEST_LARGER_THAN_BASELINE")
  NA_character_
}

#' Resolved power of regression/fisher against an observed baseline
#'
#' @param test_samples n_t.
#' @param baseline_successes K_b, observed.
#' @param baseline_trials n_b.
#' @param design_alternative_rate p_design.
#' @param alpha One-sided level.
#' @export
risk_sizing_resolved_power <- function(test_samples, baseline_successes, baseline_trials,
                                       design_alternative_rate, alpha) {
  c_int <- fisher_cutoff(baseline_successes, baseline_trials, test_samples, alpha)
  pbinom(c_int - 1, test_samples, design_alternative_rate)
}

#' Smallest n_t <= n_b from which resolved power stays at target (§5.4.1)
#'
#' NA when resolved power at n_b itself is short (BASELINE_TOO_SMALL).
#' @export
risk_sizing_resolved_required_n <- function(baseline_successes, baseline_trials,
                                            design_alternative_rate, alpha, target_power) {
  pw <- vapply(seq_len(baseline_trials), function(n)
    risk_sizing_resolved_power(n, baseline_successes, baseline_trials,
                               design_alternative_rate, alpha), numeric(1))
  below <- which(pw < target_power)
  if (length(below) == 0) return(1L)
  if (max(below) == baseline_trials) return(NA_integer_)
  as.integer(max(below) + 1L)
}

#' @keywords internal
refused <- function(category, fields) {
  e <- list(sizing_gate = "REFUSE", refusal_category = category)
  for (f in fields) e[[f]] <- NA
  e
}

#' @keywords internal
required_n_case <- function(name, baseline_rate, baseline_trials, design_alternative_rate,
                            alpha, target_power) {
  inputs <- list(baseline_rate = baseline_rate, baseline_trials = as.integer(baseline_trials),
                 design_alternative_rate = design_alternative_rate, alpha = alpha,
                 target_power = target_power)
  cat <- sizing_refusal(baseline_rate, design_alternative_rate, baseline_trials)
  expected <- if (!is.na(cat)) refused(cat, c("required_n", "achieved_power")) else {
    n <- risk_sizing_required_n(baseline_rate, baseline_trials, design_alternative_rate,
                                alpha, target_power)
    if (is.na(n)) refused("BASELINE_TOO_SMALL", c("required_n", "achieved_power")) else
      list(sizing_gate = "ADMIT", required_n = n,
           achieved_power = risk_sizing_power(n, baseline_rate, baseline_trials,
                                              design_alternative_rate, alpha))
  }
  list(name = name, approach = "required_n", inputs = inputs, expected = expected)
}

#' @keywords internal
power_at_case <- function(name, baseline_rate, baseline_trials, design_alternative_rate,
                          alpha, test_samples) {
  inputs <- list(baseline_rate = baseline_rate, baseline_trials = as.integer(baseline_trials),
                 design_alternative_rate = design_alternative_rate, alpha = alpha,
                 test_samples = as.integer(test_samples))
  cat <- sizing_refusal(baseline_rate, design_alternative_rate, baseline_trials, test_samples)
  expected <- if (!is.na(cat)) refused(cat, "power") else
    list(sizing_gate = "ADMIT",
         power = risk_sizing_power(test_samples, baseline_rate, baseline_trials,
                                   design_alternative_rate, alpha))
  list(name = name, approach = "power_at", inputs = inputs, expected = expected)
}

#' @keywords internal
detectable_rate_case <- function(name, baseline_rate, baseline_trials, alpha, target_power,
                                 test_samples) {
  inputs <- list(baseline_rate = baseline_rate, baseline_trials = as.integer(baseline_trials),
                 alpha = alpha, target_power = target_power,
                 test_samples = as.integer(test_samples))
  cat <- sizing_refusal(baseline_rate, NULL, baseline_trials, test_samples)
  expected <- if (!is.na(cat)) refused(cat, "detectable_rate") else
    list(sizing_gate = "ADMIT",
         detectable_rate = risk_sizing_detectable_rate(test_samples, baseline_rate,
                                                       baseline_trials, alpha, target_power))
  list(name = name, approach = "detectable_rate", inputs = inputs, expected = expected)
}

#' @keywords internal
resolved_required_n_case <- function(name, baseline_successes, baseline_trials,
                                     design_alternative_rate, alpha, target_power,
                                     description = NULL) {
  inputs <- list(baseline_successes = as.integer(baseline_successes),
                 baseline_trials = as.integer(baseline_trials),
                 design_alternative_rate = design_alternative_rate, alpha = alpha,
                 target_power = target_power)
  cat <- sizing_refusal(baseline_successes / baseline_trials, design_alternative_rate, baseline_trials)
  expected <- if (!is.na(cat)) refused(cat, c("required_n", "resolved_power", "first_crossing")) else {
    pw <- vapply(seq_len(baseline_trials), function(n)
      risk_sizing_resolved_power(n, baseline_successes, baseline_trials,
                                 design_alternative_rate, alpha), numeric(1))
    n <- risk_sizing_resolved_required_n(baseline_successes, baseline_trials,
                                         design_alternative_rate, alpha, target_power)
    if (is.na(n)) refused("BASELINE_TOO_SMALL", c("required_n", "resolved_power", "first_crossing")) else
      list(sizing_gate = "ADMIT", required_n = n, resolved_power = pw[n],
           first_crossing = as.integer(which(pw >= target_power)[1]))
  }
  case <- list(name = name, approach = "resolved_required_n")
  if (!is.null(description)) case$description <- description
  c(case, list(inputs = inputs, expected = expected))
}

#' @keywords internal
resolved_power_at_case <- function(name, baseline_successes, baseline_trials,
                                   design_alternative_rate, alpha, test_samples) {
  inputs <- list(baseline_successes = as.integer(baseline_successes),
                 baseline_trials = as.integer(baseline_trials),
                 design_alternative_rate = design_alternative_rate, alpha = alpha,
                 test_samples = as.integer(test_samples))
  cat <- sizing_refusal(baseline_successes / baseline_trials, design_alternative_rate,
                        baseline_trials, test_samples)
  expected <- if (!is.na(cat)) refused(cat, c("cutoff_integer", "resolved_power")) else
    list(sizing_gate = "ADMIT",
         cutoff_integer = fisher_cutoff(baseline_successes, baseline_trials, test_samples, alpha),
         resolved_power = risk_sizing_resolved_power(test_samples, baseline_successes,
                                                     baseline_trials, design_alternative_rate, alpha))
  list(name = name, approach = "resolved_power_at", inputs = inputs, expected = expected)
}

#' Generate risk-driven sizing reference cases (companion §5.4.1)
#'
#' @return A list suitable for JSON serialisation.
#' @export
generate_risk_driven_sizing_cases <- function() {
  cases <- list(
    # The companion's two scenarios (p0 0.87 / p_design 0.84 and 0.96 / 0.93),
    # now priced exactly against the Fisher rule with a stated baseline.
    required_n_case("companion_worked_example", 0.87, 3000, 0.84, 0.05, 0.80),
    required_n_case("companion_scenario_walkthrough", 0.96, 2000, 0.93, 0.05, 0.80),
    required_n_case("higher_power_costs_samples", 0.96, 2000, 0.93, 0.05, 0.90),
    required_n_case("smaller_alpha_costs_samples", 0.96, 2000, 0.93, 0.01, 0.80),
    required_n_case("large_design_drop_is_cheap", 0.90, 1000, 0.80, 0.05, 0.80),
    required_n_case("baseline_too_small_for_design", 0.96, 300, 0.93, 0.05, 0.80),
    power_at_case("walkthrough_candidate_50", 0.96, 2000, 0.93, 0.05, 50),
    power_at_case("walkthrough_candidate_150", 0.96, 2000, 0.93, 0.05, 150),
    power_at_case("worked_example_at_891", 0.87, 3000, 0.84, 0.05, 891),
    detectable_rate_case("inversion_at_100", 0.87, 3000, 0.05, 0.80, 100),
    detectable_rate_case("inversion_at_400", 0.96, 2000, 0.05, 0.80, 400),
    # Refusals.
    required_n_case("zero_baseline_required_n_refused", 0, 1000, 0.90, 0.05, 0.80),
    power_at_case("zero_baseline_power_at_refused", 0, 1000, 0.90, 0.05, 100),
    detectable_rate_case("zero_baseline_detectable_rate_refused", 0, 1000, 0.05, 0.80, 100),
    required_n_case("design_alternative_at_baseline_refused", 0.90, 1000, 0.90, 0.05, 0.80),
    power_at_case("test_larger_than_baseline_refused", 0.90, 100, 0.80, 0.05, 200),
    # Resolved sizing against an existing baseline: the observed count fixes
    # the cutoff, and resolved power decides. The companion's §10.3
    # configuration: design power never reaches 0.80 at n_t <= 1000 (0.753 at
    # 1000), resolved power reaches and holds it from 966.
    resolved_required_n_case("resolved_section_10_3_951_of_1000_at_0925", 951, 1000, 0.925, 0.05, 0.80,
      "Admissible under resolved sizing (stays at 0.80 from 966, first reaching it at 868), where design sizing for the same planned baseline refuses."),
    required_n_case("design_section_10_3_planned_1000_at_0951_vs_0925", 0.951, 1000, 0.925, 0.05, 0.80),
    resolved_required_n_case("resolved_walkthrough_1920_of_2000_at_093", 1920, 2000, 0.93, 0.05, 0.80),
    resolved_required_n_case("resolved_baseline_too_small_288_of_300_at_093", 288, 300, 0.93, 0.05, 0.80),
    resolved_required_n_case("resolved_alternative_at_baseline_refused", 900, 1000, 0.90, 0.05, 0.80),
    resolved_required_n_case("resolved_zero_baseline_refused", 0, 1000, 0.90, 0.05, 0.80),
    resolved_power_at_case("resolved_power_at_1000_section_10_3", 951, 1000, 0.925, 0.05, 1000),
    resolved_power_at_case("resolved_power_at_463_walkthrough", 1920, 2000, 0.93, 0.05, 463),
    resolved_power_at_case("resolved_test_larger_than_baseline_refused", 95, 100, 0.85, 0.05, 200)
  )

  list(
    suite = "risk_driven_sizing",
    description = paste(
      "Risk-driven sizing (companion §5.4.1) against the operative regression rule, in two",
      "operations. Design sizing, before the baseline exists (approaches power_at, required_n,",
      "detectable_rate), plans baseline and test together and uses the design power. Resolved",
      "sizing, against an existing baseline (approaches resolved_power_at, resolved_required_n),",
      "uses the resolved power at the observed baseline count, whose cutoff is fixed; once a",
      "baseline exists BASELINE_TOO_SMALL is judged by it. Design sizing:",
      "regression/fisher: the exact power of the rule at a declared design alternative rate",
      "p_design - the true rate at which the test must reach its target power; the test still",
      "flags any degradation from the baseline - with the baseline's n_b trials at rate p0.",
      "POWER_AT gives the power at a",
      "candidate n_t; REQUIRED_N the smallest n_t <= n_b from which power stays at or above the",
      "target up to n_b; DETECTABLE_RATE the largest p_design detectable at the target with n_t",
      "samples. Designs outside the domain are published as refusals: sizing_gate REFUSE, every",
      "numeric expectation null, refusal_category ZERO_BASELINE, ALTERNATIVE_NOT_BELOW_BASELINE,",
      "TEST_LARGER_THAN_BASELINE or BASELINE_TOO_SMALL (the target is not reached and held",
      "within n_t <= n_b)."
    ),
    method = paste(
      "Power(n_t) = sum_k dbinom(k, n_b, p0) pbinom(c(k) - 1, n_t, p_design), c the",
      "regression/fisher cutoff at (k, n_b, n_t, alpha), over the baseline counts from",
      "qbinom(1e-17, n_b, p0) to qbinom(1 - 1e-17, n_b, p0); required_n = 1 + the largest",
      "n_t <= n_b with Power < target (refused when that is n_b); detectable_rate by bisection",
      "on p_design over (0, p0) to 1e-10. Resolved: resolved_power(n_t) = pbinom(c(K_b; n_b, n_t,",
      "alpha) - 1, n_t, p_design); resolved_required_n = 1 + the largest n_t <= n_b with resolved",
      "power < target (refused BASELINE_TOO_SMALL when that is n_b); first_crossing = the smallest",
      "n_t with resolved power >= target; refusals as for design with p0 = K_b / n_b."
    ),
    tolerance = 1e-6,
    cases = cases
  )
}
