#' Risk-driven sizing: self-consistent power for baseline-derived thresholds.
#'
#' Reference computations for companion S5.4.1. The S5.3/S5.4 power forms
#' hold the threshold constant; a regression-procedure test derives its
#' acceptance floor at its own size, p*(n) = WilsonLower(p0, n, 1 - alpha),
#' so the floor falls as n shrinks. The self-consistent form puts the
#' moving floor inside the calculation: Power(n) is the probability that a
#' service whose true rate is p_min (the minimal acceptable rate — a
#' declared tolerance, not a measured estimate) fails the test.
#'
#' Defined for p_min < p0 only; the generators refuse the over-reach
#' regime rather than emitting cases for it.

#' Self-consistent power at a candidate sample size (companion S5.4.1).
#'
#' @param n Test sample size (positive integer).
#' @param baseline_rate The effective baseline rate p0 in (0, 1).
#' @param minimum_acceptable_rate The declared tolerance p_min, < p0.
#' @param confidence One-sided confidence (1 - alpha) in (0, 1).
#' @export
power_self_consistent <- function(n, baseline_rate, minimum_acceptable_rate, confidence) {
  validate_sizing_inputs(baseline_rate, minimum_acceptable_rate, confidence)
  stopifnot(n >= 1)
  floor_n <- wilson_lower_from_rate(baseline_rate, n, confidence)
  se <- sqrt(minimum_acceptable_rate * (1 - minimum_acceptable_rate) / n)
  pnorm((floor_n - minimum_acceptable_rate) / se)
}

#' Smallest n whose self-consistent power meets the target (S5.4.1).
#'
#' Power is increasing in n within the domain (the floor rises toward p0
#' and the standard error shrinks), so the minimum is well defined; found
#' by doubling then bisection.
#' @export
required_n_self_consistent <- function(baseline_rate, minimum_acceptable_rate,
                                       confidence, target_power) {
  validate_sizing_inputs(baseline_rate, minimum_acceptable_rate, confidence)
  stopifnot(target_power > 0, target_power < 1)
  power_of <- function(n) {
    power_self_consistent(n, baseline_rate, minimum_acceptable_rate, confidence)
  }
  hi <- 2
  while (power_of(hi) < target_power) {
    hi <- hi * 2
    if (hi > 1e7) stop("required n exceeds 1e7; tolerance too tight for this baseline")
  }
  lo <- max(1, hi %/% 2)
  while (lo + 1 < hi) {
    mid <- (lo + hi) %/% 2
    if (power_of(mid) >= target_power) hi <- mid else lo <- mid
  }
  as.integer(hi)
}

#' Largest tolerable rate detectable at target power with n samples (S5.4.1).
#'
#' The inversion: bisection on p_min over (0, p0) to an absolute
#' tolerance of 1e-10, per the companion's stated convention.
#' @export
detectable_rate_self_consistent <- function(n, baseline_rate, confidence, target_power) {
  stopifnot(n >= 1, target_power > 0, target_power < 1)
  stopifnot(baseline_rate > 0, baseline_rate < 1)
  lo <- 1e-9
  hi <- baseline_rate - 1e-9
  while (hi - lo > 1e-10) {
    mid <- (lo + hi) / 2
    if (power_self_consistent(n, baseline_rate, mid, confidence) >= target_power) {
      lo <- mid
    } else {
      hi <- mid
    }
  }
  lo
}

#' @keywords internal
validate_sizing_inputs <- function(baseline_rate, minimum_acceptable_rate, confidence) {
  stopifnot(
    baseline_rate > 0, baseline_rate < 1,
    minimum_acceptable_rate > 0, minimum_acceptable_rate < 1,
    confidence > 0, confidence < 1
  )
  if (minimum_acceptable_rate >= baseline_rate) {
    stop("minimum_acceptable_rate must be below baseline_rate: the construction ",
         "is defined for p_min < p0 only (companion S5.4.1 domain)")
  }
}

required_n_case <- function(name, baseline_rate, minimum_acceptable_rate,
                            confidence, target_power) {
  n <- required_n_self_consistent(baseline_rate, minimum_acceptable_rate,
                                  confidence, target_power)
  list(
    name = name,
    approach = "required_n",
    inputs = list(
      baseline_rate = baseline_rate,
      minimum_acceptable_rate = minimum_acceptable_rate,
      confidence = confidence,
      target_power = target_power
    ),
    expected = list(
      sizing_gate = "ADMIT",
      required_n = n,
      floor = wilson_lower_from_rate(baseline_rate, n, confidence),
      achieved_power = power_self_consistent(n, baseline_rate,
                                             minimum_acceptable_rate, confidence)
    )
  )
}

power_at_case <- function(name, baseline_rate, minimum_acceptable_rate,
                          confidence, test_samples) {
  list(
    name = name,
    approach = "power_at",
    inputs = list(
      baseline_rate = baseline_rate,
      minimum_acceptable_rate = minimum_acceptable_rate,
      confidence = confidence,
      test_samples = test_samples
    ),
    expected = list(
      sizing_gate = "ADMIT",
      floor = wilson_lower_from_rate(baseline_rate, test_samples, confidence),
      power = power_self_consistent(test_samples, baseline_rate,
                                    minimum_acceptable_rate, confidence)
    )
  )
}

detectable_rate_case <- function(name, baseline_rate, confidence,
                                 target_power, test_samples) {
  list(
    name = name,
    approach = "detectable_rate",
    inputs = list(
      baseline_rate = baseline_rate,
      confidence = confidence,
      target_power = target_power,
      test_samples = test_samples
    ),
    expected = list(
      sizing_gate = "ADMIT",
      detectable_rate = detectable_rate_self_consistent(test_samples, baseline_rate,
                                                        confidence, target_power)
    )
  )
}

#' One inadmissible sizing design: the refusal, published (companion S4.3.4).
#'
#' Until now this suite expressed the S5.4.1 domain restriction by
#' declining to emit cases outside it — the generator's `stopifnot` fired
#' and the regime went unpublished. That makes "correctly refuses" a
#' convention each framework invents rather than an outcome any of them
#' can be held to. These cases publish the refusal in the form the family
#' already uses for an inadmissible input (`criterion_verdict_inferential`
#' expresses one as a gate plus nulled numerics): `sizing_gate` is REFUSE,
#' every numeric expectation is null because none exists, and a category
#' names the cause.
#'
#' A zero baseline is the case that matters here and the reason it is
#' reachable at all: at k = 0 the effective baseline rate is exactly 0
#' (S4.3.4), so `baseline_rate = 0` is the faithful input rather than a
#' contrived one, and p_min < p0 is empty for every p_min in (0, 1).
#' The constructor computes nothing — there is nothing to compute — so it
#' does not route through `validate_sizing_inputs`, which would stop.
#'
#' @keywords internal
sizing_refusal_case <- function(name, approach, inputs, category) {
  fields <- list(
    required_n = c("required_n", "floor", "achieved_power"),
    power_at = c("floor", "power"),
    detectable_rate = c("detectable_rate")
  )[[approach]]
  expected <- list(sizing_gate = "REFUSE", refusal_category = category)
  for (f in fields) expected[[f]] <- NA
  list(name = name, approach = approach, inputs = inputs, expected = expected)
}

#' Generate risk-driven sizing reference cases (companion S5.4.1).
#' @export
generate_risk_driven_sizing_cases <- function() {
  cases <- list(
    # The companion's two computed examples, reproduced exactly.
    required_n_case("companion_worked_example", 0.87, 0.84, 0.95, 0.80),
    required_n_case("companion_scenario_walkthrough", 0.96, 0.93, 0.95, 0.80),

    # Parameter sensitivity around the walkthrough tuple.
    required_n_case("higher_confidence_costs_samples", 0.96, 0.93, 0.99, 0.80),
    required_n_case("higher_power_costs_samples", 0.96, 0.93, 0.95, 0.90),
    required_n_case("wide_tolerance_is_cheap", 0.90, 0.80, 0.95, 0.80),
    required_n_case("high_baseline_tight_tolerance", 0.99, 0.97, 0.95, 0.80),

    # The moving floor at candidate sizes (the companion's walkthrough table).
    power_at_case("walkthrough_candidate_50", 0.96, 0.93, 0.95, 50),
    power_at_case("walkthrough_candidate_150", 0.96, 0.93, 0.95, 150),
    # The S5.4 closed-form seed for the worked example (n = 826) falls
    # short of the target — the fixture pins the seed/self-consistent gap.
    power_at_case("closed_form_seed_underpowers", 0.87, 0.84, 0.95, 826),
    power_at_case("beyond_required_n", 0.87, 0.84, 0.95, 1200),

    # Inversions, including round-trips at the required-n cases' sizes.
    detectable_rate_case("companion_inversion_at_100", 0.87, 0.95, 0.80, 100),
    detectable_rate_case("roundtrip_worked_example", 0.87, 0.95, 0.80, 891),
    detectable_rate_case("roundtrip_walkthrough", 0.96, 0.95, 0.80, 405),

    # The refused regime, at the boundary that reaches it in practice:
    # a baseline that observed no successes. All three approaches refuse,
    # because the emptiness is in the domain and not in any one
    # inversion. Published so a framework's refusal is assertable rather
    # than assumed — see `sizing_refusal_case`.
    sizing_refusal_case(
      "zero_baseline_required_n_refused", "required_n",
      list(baseline_rate = 0, minimum_acceptable_rate = 0.90,
           confidence = 0.95, target_power = 0.80),
      "ZERO_BASELINE"),
    sizing_refusal_case(
      "zero_baseline_power_at_refused", "power_at",
      list(baseline_rate = 0, minimum_acceptable_rate = 0.90,
           confidence = 0.95, test_samples = 100L),
      "ZERO_BASELINE"),
    sizing_refusal_case(
      "zero_baseline_detectable_rate_refused", "detectable_rate",
      list(baseline_rate = 0, confidence = 0.95,
           target_power = 0.80, test_samples = 100L),
      "ZERO_BASELINE"),

    # The other way out of the domain, for contrast: the baseline is
    # admissible but the declared tolerance is not below it, so there is
    # nothing to detect. Same gate, different cause — a framework that
    # collapses the two into one message loses the distinction the
    # operator needs to act on.
    sizing_refusal_case(
      "tolerance_at_baseline_refused", "required_n",
      list(baseline_rate = 0.90, minimum_acceptable_rate = 0.90,
           confidence = 0.95, target_power = 0.80),
      "EMPTY_TOLERANCE_INTERVAL")
  )

  list(
    suite = "risk_driven_sizing",
    description = paste0(
      "Self-consistent power for baseline-derived thresholds (companion S5.4.1). ",
      "The acceptance floor p*(n) moves with the test's own sample size, so sizing ",
      "is computed against the moving floor rather than a fixed threshold: POWER_AT ",
      "cases give the floor and power at a candidate n; REQUIRED_N cases give the ",
      "smallest n meeting a target power for a declared minimal acceptable rate; ",
      "DETECTABLE_RATE cases invert to the largest tolerable rate detectable at a ",
      "fixed n. Defined for minimum_acceptable_rate < baseline_rate only; designs outside ",
      "that domain are published as refusals rather than omitted -- sizing_gate is REFUSE, ",
      "every numeric expectation is null, and refusal_category names the cause. A zero ",
      "baseline (S4.3.4) reaches the refusal by way of an effective baseline rate of exactly ",
      "0, at which the domain is empty for every tolerance."
    ),
    method = paste0(
      "floor = WilsonLower(baseline_rate, n, confidence) (from-rate form, shared z); ",
      "Power(n) = pnorm((floor - p_min) / sqrt(p_min (1 - p_min) / n)); ",
      "required_n = min{ n : Power(n) >= target_power } by doubling + bisection; ",
      "detectable_rate by bisection on p_min over (0, p0) to 1e-10."
    ),
    tolerance = 1e-6,
    cases = cases
  )
}
