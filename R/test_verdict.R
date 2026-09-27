#' The overall test verdict: functional criteria and enforced latency
#' constraints composed by one structural rule (companion §1.4.6, §12.3.2).
#'
#' A test's functional dimension has the verdict V_rate, the structural
#' composite of its criteria. Its latency dimension has the verdict
#' V_latency, the same composite over its enforced latency constraints:
#' PASS if every enforced constraint passes, FAIL if any fails,
#' INCONCLUSIVE otherwise. Advisory constraints never participate. The
#' test's verdict V_test composes the two dimensions by the same rule. A
#' test with no functional criteria has V_test = V_latency; a test with no
#' enforced latency constraints has V_test = V_rate. Configuration
#' refusals come before any verdict and are unchanged.

#' The structural composite of a vector of verdicts
#' @keywords internal
structural_composite <- function(verdicts) {
  if (all(verdicts == "PASS")) "PASS" else if (any(verdicts == "FAIL")) "FAIL" else "INCONCLUSIVE"
}

#' The verdict of one latency constraint
#'
#' An enforced explicit requirement is decided by
#' latency/compliance-exact-binomial; an enforced baseline-derived
#' constraint by the non-degeneracy gate and latency/precedence (the test's
#' nearest-rank percentile at or below the baseline threshold passes). An
#' advisory constraint compares the observed percentile with its threshold
#' and reports ADVISORY_PASS or ADVISORY_WARN; it never participates.
#'
#' @param constraint A list: constraint_id, source ("explicit" or
#'   "baseline-derived"), mode ("enforced" or "advisory"), percentile,
#'   alpha, latencies (the test's successful latencies), threshold_ms
#'   (explicit) or baseline_latencies (baseline-derived).
#' @param intent VERIFICATION or SMOKE.
#' @return A list: constraint_id, source, mode, decisionRule, verdict,
#'   participates.
#' @export
latency_constraint_verdict <- function(constraint, intent = "VERIFICATION") {
  p <- constraint$percentile
  lat <- constraint$latencies
  enforced <- constraint$mode == "enforced"
  out <- list(constraint_id = constraint$constraint_id, source = constraint$source,
              mode = constraint$mode, participates = enforced)
  if (constraint$source == "explicit") {
    tau <- constraint$threshold_ms
    if (enforced) {
      out$decisionRule <- "latency/compliance-exact-binomial"
      out$verdict <- latency_compliance_verdict(lat, tau, p, constraint$alpha)$verdict
    }
  } else {
    base <- sort(constraint$baseline_latencies)
    nd <- latency_nondegeneracy_decision(p, length(lat), intent, enforced, "baseline-derived")
    k <- if (length(lat) > 0) latency_precedence_rank(length(base), length(lat), p, constraint$alpha) else NA
    tau <- if (is.na(k)) NA_real_ else base[k]
    if (enforced) {
      out$decisionRule <- "latency/precedence"
      out$verdict <- if (nd$outcome == "INCONCLUSIVE" || is.na(k)) "INCONCLUSIVE" else
        if (sort(lat)[latency_test_rank(length(lat), p)] <= tau) "PASS" else "FAIL"
    }
  }
  if (!enforced) {
    observed <- sort(lat)[latency_test_rank(length(lat), p)]
    out$decisionRule <- NA_character_
    out$verdict <- if (!is.na(tau) && observed <= tau) "ADVISORY_PASS" else "ADVISORY_WARN"
  }
  out
}

#' Compose the overall test verdict V_test
#'
#' @param criteria Functional criteria, each a list with criterion_id and
#'   verdict (may be empty).
#' @param constraints Latency constraint verdicts from
#'   `latency_constraint_verdict()` (may be empty).
#' @return A list: rate_verdict (V_rate, NA without functional criteria),
#'   latency_verdict (V_latency, NA without enforced constraints),
#'   test_verdict (V_test), triggering (the criteria and enforced
#'   constraints that decided a FAIL or an INCONCLUSIVE: kind and id).
#' @export
test_verdict <- function(criteria = list(), constraints = list()) {
  enforced <- Filter(function(k) isTRUE(k$participates), constraints)
  if (length(criteria) == 0 && length(enforced) == 0) {
    stop("a test verdict needs a functional criterion or an enforced latency constraint", call. = FALSE)
  }
  cv <- vapply(criteria, function(c) c$verdict, character(1))
  lv <- vapply(enforced, function(k) k$verdict, character(1))
  v_rate <- if (length(cv)) structural_composite(cv) else NA_character_
  v_lat <- if (length(lv)) structural_composite(lv) else NA_character_
  v_test <- structural_composite(c(v_rate, v_lat)[!is.na(c(v_rate, v_lat))])
  trig <- list()
  if (v_test != "PASS") {
    for (c in criteria) if (c$verdict == v_test) trig[[length(trig) + 1]] <- list(kind = "criterion", id = c$criterion_id)
    for (k in enforced) if (k$verdict == v_test) trig[[length(trig) + 1]] <- list(kind = "latency", id = k$constraint_id)
  }
  list(rate_verdict = v_rate, latency_verdict = v_lat, test_verdict = v_test, triggering = trig)
}
