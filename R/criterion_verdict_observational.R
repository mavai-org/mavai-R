#' Observational-criterion verdict (companion §1.4.5)
#'
#' Determines the per-criterion verdict for an observational criterion.
#' The verdict is deterministic on the observed counts; no Wilson
#' construction is involved (observational criteria make no
#' inferential claim by construction).
#'
#' The denominator `n_c` is the number of trials, `n_attempted`
#' (§1.4.5a): every trial counts, and a trial that produced no testable
#' value is a FAIL carrying its reason, so it counts toward `n_c` and
#' never toward `K_c`.
#'
#' The verdict rule (§1.4.5):
#'   - PASS         if `K_c == n_c` and `n_c > 0`
#'   - FAIL         if `K_c <  n_c`
#'   - INCONCLUSIVE if `n_c == 0`
#'
#' `r_obs = n_evaluable / n_attempted` is the §1.5.2 diagnostic (the
#' share of trials that produced a testable value); it decides nothing.
#'
#' @param n_attempted Integer. Total trials attempted.
#' @param n_evaluable Integer. Trials that produced a testable value.
#' @param K_c Integer. Trials that PASSed.
#' @return A list with `n_c`, `r_obs`, `verdict`, `statement`.
#' @export
observational_verdict <- function(n_attempted, n_evaluable, K_c) {
  stopifnot(
    is.numeric(n_attempted), n_attempted >= 0,
    is.numeric(n_evaluable), n_evaluable >= 0, n_evaluable <= n_attempted,
    is.numeric(K_c), K_c >= 0, K_c <= n_evaluable
  )

  n_c <- n_attempted

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
      "No failure observed across %d trials drawn from the criterion's validation set.",
      n_c
    ),
    FAIL = sprintf(
      "%d failure(s) of the criterion were observed across %d trials.",
      n_c - K_c, n_c
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
  case <- function(name, n_attempted, n_evaluable, K_c, description = NULL) {
    out <- list(
      name = name,
      inputs = list(
        n_attempted = as.integer(n_attempted),
        n_evaluable = as.integer(n_evaluable),
        K_c = as.integer(K_c)
      ),
      expected = observational_verdict(n_attempted, n_evaluable, K_c)
    )
    if (!is.null(description)) out$description <- description
    out
  }

  cases <- list(
    # PASS at small n_c — analogue of §10.3 self-harm probe.
    case("pass_200_probes_zero_failures",
         n_attempted = 200, n_evaluable = 200, K_c = 200),

    # PASS at large scale (observational verdict rule, §1.4.5).
    case("pass_sentinel_scale_10_million",
         n_attempted = 10000000, n_evaluable = 10000000, K_c = 10000000),

    # FAIL on a single observed failure.
    case("fail_one_failure_in_1000",
         n_attempted = 1000, n_evaluable = 1000, K_c = 999),

    # INCONCLUSIVE at n_c = 0 — no trials attempted.
    case("inconclusive_zero_attempts",
         n_attempted = 0, n_evaluable = 0, K_c = 0),

    # Trials with no testable value are FAILs (§1.4.5a): 50 of 1000
    # produced none, so n_c = 1000, K_c = 950 → FAIL; r_obs = 0.95.
    case("fail_no_value_trials_count_as_fail",
         n_attempted = 1000, n_evaluable = 950, K_c = 950,
         description = "50 of 1000 trials produced no testable value: each is a FAIL with its reason, so n_c = 1000 and K_c = 950 → FAIL (§1.4.5a); r_obs = 0.95 is the diagnostic (§1.5.2).")
  )

  list(
    suite = "criterion_verdict_observational",
    description = paste(
      "Per-observational-criterion verdict cases per the statistical companion",
      "§1.4.5 (observational verdict rule) and §1.4.5a (the denominator).",
      "The denominator n_c is the number of trials; a trial that produced",
      "no testable value is a FAIL. r_obs is the §1.5.2 diagnostic. The verdict is deterministic on",
      "(n_c, K_c): PASS if K_c == n_c and n_c > 0; FAIL if K_c < n_c;",
      "INCONCLUSIVE if n_c == 0. Observational criteria carry no Wilson",
      "construction and no alpha."
    ),
    method = paste(
      "Deterministic application of §1.4.5's three-outcome rule at the",
      "denominator n_c = n_attempted."
    ),
    tolerance = 0,
    cases = cases
  )
}
