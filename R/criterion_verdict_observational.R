#' Observational-criterion verdict (companion §1.4.5)
#'
#' Determines the per-criterion verdict for an observational criterion.
#' The verdict is deterministic on the observed counts and the declared
#' denominator policy of §1.4.5a; no Wilson construction is involved
#' (observational criteria make no inferential claim by construction).
#'
#' The effective denominator `n_c` is derived from the policy:
#'   - `CONDITIONAL_ON_EVALUABLE`:           `n_c = n_evaluable`
#'   - `MARGINAL_COUNT_UNEVALUABLE_AS_FAIL`: `n_c = n_attempted`
#'
#' The verdict rule (§1.4.5):
#'   - PASS         if `K_c == n_c` and `n_c > 0`
#'   - FAIL         if `K_c <  n_c`
#'   - INCONCLUSIVE if `n_c == 0`
#'
#' Under `MARGINAL_COUNT_UNEVALUABLE_AS_FAIL`, any unevaluable trial
#' contributes to the denominator without contributing to `K_c`, so the
#' criterion FAILs whenever a trial was attempted but did not produce
#' an evaluable observation. This is the methodology's expression of
#' "failure to produce an evaluable observation is itself a failure of
#' the criterion or of the end-to-end service contract".
#'
#' @param n_attempted Integer. Total trials attempted under the validation set.
#' @param n_evaluable Integer. Trials on which the postcondition could be evaluated.
#' @param K_c Integer. Successes among the evaluable trials.
#' @param policy Character. One of `"CONDITIONAL_ON_EVALUABLE"`,
#'   `"MARGINAL_COUNT_UNEVALUABLE_AS_FAIL"`.
#' @return A list with `n_c`, `r_obs`, `verdict`, `statement`.
#' @export
observational_verdict <- function(n_attempted, n_evaluable, K_c, policy) {
  stopifnot(
    is.numeric(n_attempted), n_attempted >= 0,
    is.numeric(n_evaluable), n_evaluable >= 0, n_evaluable <= n_attempted,
    is.numeric(K_c), K_c >= 0, K_c <= n_evaluable,
    policy %in% c("CONDITIONAL_ON_EVALUABLE", "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL")
  )

  n_c <- if (policy == "CONDITIONAL_ON_EVALUABLE") n_evaluable else n_attempted

  r_obs <- if (n_attempted == 0) 0 else n_evaluable / n_attempted

  verdict <- if (n_c == 0) {
    "INCONCLUSIVE"
  } else if (K_c == n_c) {
    "PASS"
  } else {
    "FAIL"
  }

  statement <- switch(
    verdict,
    PASS = sprintf(
      "No failure observed across %d trials drawn from the criterion's validation set (policy: %s).",
      n_c, policy
    ),
    FAIL = sprintf(
      "%d failure(s) of the criterion were observed across %d trials (policy: %s).",
      n_c - K_c, n_c, policy
    ),
    INCONCLUSIVE = "No conclusive observation of the criterion was available in the run."
  )

  list(
    n_c = as.integer(n_c),
    r_obs = r_obs,
    verdict = verdict,
    statement = statement
  )
}

#' Generate observational verdict reference cases
#'
#' @return A list suitable for JSON serialisation.
#' @export
generate_criterion_verdict_observational_cases <- function() {
  case <- function(name, n_attempted, n_evaluable, K_c, policy) {
    list(
      name = name,
      inputs = list(
        n_attempted = as.integer(n_attempted),
        n_evaluable = as.integer(n_evaluable),
        K_c = as.integer(K_c),
        denominator_policy = policy
      ),
      expected = observational_verdict(n_attempted, n_evaluable, K_c, policy)
    )
  }

  cases <- list(
    # PASS at small n_c — analogue of §10.3 self-harm probe.
    case("pass_200_probes_zero_failures_conditional",
         n_attempted = 200, n_evaluable = 200, K_c = 200,
         policy = "CONDITIONAL_ON_EVALUABLE"),

    case("pass_200_probes_zero_failures_marginal",
         n_attempted = 200, n_evaluable = 200, K_c = 200,
         policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL"),

    # PASS at large scale (observational verdict rule, §1.4.5).
    case("pass_sentinel_scale_10_million_marginal",
         n_attempted = 10000000, n_evaluable = 10000000, K_c = 10000000,
         policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL"),

    # FAIL on a single observed failure.
    case("fail_one_failure_in_1000_conditional",
         n_attempted = 1000, n_evaluable = 1000, K_c = 999,
         policy = "CONDITIONAL_ON_EVALUABLE"),

    case("fail_one_failure_in_1000_marginal",
         n_attempted = 1000, n_evaluable = 1000, K_c = 999,
         policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL"),

    # INCONCLUSIVE at n_c = 0 — no trials attempted.
    case("inconclusive_zero_attempts_conditional",
         n_attempted = 0, n_evaluable = 0, K_c = 0,
         policy = "CONDITIONAL_ON_EVALUABLE"),

    case("inconclusive_zero_attempts_marginal",
         n_attempted = 0, n_evaluable = 0, K_c = 0,
         policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL"),

    # Policy-derived denominator difference: same raw counts under the
    # two policies produce different verdicts when n_evaluable < n_attempted.
    # Under CONDITIONAL_ON_EVALUABLE the 50 unevaluable trials are excluded
    # so n_c = 950 and K_c = 950 → PASS.
    # Under MARGINAL_COUNT_UNEVALUABLE_AS_FAIL the unevaluables count as
    # failures so n_c = 1000 and K_c = 950 → FAIL.
    case("policy_diff_950_evaluable_conditional_passes",
         n_attempted = 1000, n_evaluable = 950, K_c = 950,
         policy = "CONDITIONAL_ON_EVALUABLE"),

    case("policy_diff_950_evaluable_marginal_fails",
         n_attempted = 1000, n_evaluable = 950, K_c = 950,
         policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL")
  )

  list(
    suite = "criterion_verdict_observational",
    description = paste(
      "Per-observational-criterion verdict cases per the statistical companion",
      "§1.4.5 (observational verdict rule) and §1.4.5a (denominator policy).",
      "The effective denominator n_c is derived from the declared policy:",
      "n_evaluable under CONDITIONAL_ON_EVALUABLE, n_attempted under",
      "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL. The verdict is deterministic on",
      "(n_c, K_c): PASS if K_c == n_c and n_c > 0; FAIL if K_c < n_c;",
      "INCONCLUSIVE if n_c == 0. Observational criteria carry no Wilson",
      "construction and no alpha."
    ),
    method = paste(
      "Deterministic application of §1.4.5's three-outcome rule at the",
      "policy-derived effective denominator n_c."
    ),
    tolerance = 0,
    cases = cases
  )
}
