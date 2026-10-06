#' The overall test verdict: the enforced dimensions composed by one
#' structural rule (companion §1.4.6, §12.3.2, §12.6).
#'
#' A test's functional dimension has the verdict V_rate, the structural
#' composite of its criteria. Its latency dimension has the verdict
#' V_latency, the same composite over its latency constraints, each decided
#' by its rule: PASS if every constraint passes, FAIL if any fails,
#' INCONCLUSIVE otherwise.
#'
#' Every assertion is enforced by default. A run-time switch makes the
#' functional dimension, the latency dimension or both advisory for a run;
#' it acts on a whole dimension, never on one criterion or constraint. An
#' advisory dimension is decided exactly as an enforced one and its verdict
#' reported, but it does not enter V_test. The test's verdict V_test is the
#' structural composite of the enforced dimensions the test carries; with
#' none enforced it is the composite over no verdict, PASS, and the test
#' cannot fail on its assertions. Configuration refusals come before any
#' verdict, whatever the modes, and are unchanged.

#' The dimensions the run-time switch can make advisory
#' @keywords internal
DIMENSIONS <- c("functional", "latency")

#' The structural composite of a vector of verdicts (PASS over none)
#' @keywords internal
structural_composite <- function(verdicts) {
  if (all(verdicts == "PASS")) "PASS" else if (any(verdicts == "FAIL")) "FAIL" else "INCONCLUSIVE"
}

#' The verdict of one latency constraint
#'
#' Every constraint is decided by the rule for its threshold source,
#' whatever the latency dimension's mode: an explicit requirement by
#' latency/compliance-exact-binomial; a baseline-derived constraint by the
#' non-degeneracy gate and latency/precedence (the test's nearest-rank
#' percentile at or below the baseline threshold passes).
#'
#' @param constraint A list: constraint_id, source ("explicit" or
#'   "baseline-derived"), percentile, alpha, latencies (the test's
#'   successful latencies), threshold_ms (explicit) or baseline_latencies
#'   (baseline-derived).
#' @param intent VERIFICATION or SMOKE.
#' @return A list: constraint_id, source, decisionRule, verdict.
#' @export
latency_constraint_verdict <- function(constraint, intent = "VERIFICATION") {
  p <- constraint$percentile
  lat <- constraint$latencies
  out <- list(constraint_id = constraint$constraint_id, source = constraint$source)
  if (constraint$source == "explicit") {
    out$decisionRule <- "latency/compliance-exact-binomial"
    out$verdict <- latency_compliance_verdict(lat, constraint$threshold_ms, p, constraint$alpha)$verdict
  } else {
    base <- sort(constraint$baseline_latencies)
    nd <- latency_nondegeneracy_decision(p, length(lat), intent, "baseline-derived")
    k <- if (length(lat) > 0) latency_precedence_rank(length(base), length(lat), p, constraint$alpha) else NA
    out$decisionRule <- "latency/precedence"
    out$verdict <- if (nd$outcome == "INCONCLUSIVE" || is.na(k)) "INCONCLUSIVE" else
      if (sort(lat)[latency_test_rank(length(lat), p)] <= base[k]) "PASS" else "FAIL"
  }
  out
}

#' Compose the overall test verdict V_test
#'
#' @param criteria Functional criteria, each a list with criterion_id and
#'   verdict (may be empty).
#' @param constraints Latency constraint verdicts from
#'   `latency_constraint_verdict()` (may be empty).
#' @param advisory The dimensions the run-time switch makes advisory: none
#'   (the default), "functional", "latency" or both.
#' @return A list: rate_verdict (V_rate, NA without functional criteria),
#'   latency_verdict (V_latency, NA without latency constraints),
#'   functional_mode and latency_mode ("enforced" or "advisory", NA for a
#'   dimension the test does not carry), test_verdict (V_test, over the
#'   enforced dimensions), triggering (the criteria and constraints of the
#'   enforced dimensions that decided a FAIL or an INCONCLUSIVE: kind and id).
#' @export
test_verdict <- function(criteria = list(), constraints = list(), advisory = character()) {
  advisory <- as.character(unlist(advisory))
  if (!all(advisory %in% DIMENSIONS) || anyDuplicated(advisory)) {
    stop("advisory names each of functional and latency at most once", call. = FALSE)
  }
  if (length(criteria) == 0 && length(constraints) == 0) {
    stop("a test verdict needs a functional criterion or a latency constraint", call. = FALSE)
  }
  cv <- vapply(criteria, function(c) c$verdict, character(1))
  lv <- vapply(constraints, function(k) k$verdict, character(1))
  v_rate <- if (length(cv)) structural_composite(cv) else NA_character_
  v_lat <- if (length(lv)) structural_composite(lv) else NA_character_
  mode <- function(dim, carried) {
    if (!carried) NA_character_ else if (dim %in% advisory) "advisory" else "enforced"
  }
  f_mode <- mode("functional", length(cv) > 0)
  l_mode <- mode("latency", length(lv) > 0)
  bound <- c(if (identical(f_mode, "enforced")) v_rate, if (identical(l_mode, "enforced")) v_lat)
  v_test <- structural_composite(bound)
  trig <- list()
  if (v_test != "PASS") {
    if (identical(f_mode, "enforced")) for (c in criteria) {
      if (c$verdict == v_test) trig[[length(trig) + 1]] <- list(kind = "criterion", id = c$criterion_id)
    }
    if (identical(l_mode, "enforced")) for (k in constraints) {
      if (k$verdict == v_test) trig[[length(trig) + 1]] <- list(kind = "latency", id = k$constraint_id)
    }
  }
  list(rate_verdict = v_rate, latency_verdict = v_lat,
       functional_mode = f_mode, latency_mode = l_mode,
       test_verdict = v_test, triggering = trig)
}
