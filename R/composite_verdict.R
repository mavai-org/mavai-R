# Rules that decide a criterion under SMOKE intent; their criteria enter
# neither envelope (companion §1.4.6).
SMOKE_DECISION_RULES <- c("compliance/smoke-exact-binomial",
                          "latency/smoke-compliance-exact-binomial")

#' Composite-verdict aggregation (companion §1.4.6, SC-RU-05)
#'
#' Aggregates a contract's per-criterion verdicts into the structural
#' composite verdict and the two procedure-direction envelopes.
#'
#' Composite-verdict rule (§1.4.6):
#'   - PASS         if every per-criterion verdict is PASS
#'   - FAIL         if any per-criterion verdict is FAIL
#'   - INCONCLUSIVE otherwise (i.e. some PASS, the rest INCONCLUSIVE, or
#'                  all INCONCLUSIVE; no FAILs present)
#'
#' Triggering criteria:
#'   - When composite is FAIL: the criteria whose verdict is FAIL.
#'   - When composite is INCONCLUSIVE: the criteria whose verdict is
#'                  INCONCLUSIVE.
#'   - When composite is PASS: none.
#'
#' Envelopes (SC-RU-05):
#'   - `false_compliance_envelope`         = sum of alpha_c over inferential
#'                                           criteria with procedure
#'                                           COMPLIANCE.
#'   - `false_degradation_signal_envelope` = sum of alpha_c over inferential
#'                                           criteria with procedure
#'                                           REGRESSION.
#'   - Observational criteria contribute to neither (they carry no alpha).
#'   - A criterion decided by a SMOKE rule (`compliance/smoke-exact-binomial`,
#'     `latency/smoke-compliance-exact-binomial`) contributes to neither: its
#'     alpha bounds a false FAIL of a service that meets its requirement, and
#'     its PASS claims no compliance (companion §1.4.6, §5.7.3).
#'   - An envelope is `NA` (omitted from output) when no inferential
#'     criterion of that procedure direction is present on the contract.
#'
#' @param criteria List of per-criterion entries. Each entry is a list with
#'   keys: `criterion_id` (character), `mode` (`"inferential"` or
#'   `"observational"`), `procedure` (`"REGRESSION"` or `"COMPLIANCE"` for
#'   inferential criteria; `NA` or absent for observational), `alpha`
#'   (numeric in (0,1) for inferential criteria; `NA` or absent for
#'   observational), `verdict` (`"PASS"`, `"FAIL"`, or `"INCONCLUSIVE"`),
#'   and optionally `decision_rule` (the rule that decided the criterion;
#'   absent means the procedure's VERIFICATION rule).
#' @return A list with `composite_verdict`, `triggering_criteria`,
#'   `false_compliance_envelope`, `false_degradation_signal_envelope`.
#' @export
composite_verdict <- function(criteria) {
  verdicts <- vapply(criteria, function(c) c$verdict, character(1))

  composite <- if (all(verdicts == "PASS")) {
    "PASS"
  } else if (any(verdicts == "FAIL")) {
    "FAIL"
  } else {
    "INCONCLUSIVE"
  }

  triggering <- if (composite == "FAIL") {
    vapply(criteria[verdicts == "FAIL"], function(c) c$criterion_id, character(1))
  } else if (composite == "INCONCLUSIVE") {
    vapply(criteria[verdicts == "INCONCLUSIVE"], function(c) c$criterion_id, character(1))
  } else {
    character(0)
  }

  envelope_sum <- function(procedure_label) {
    contributing <- vapply(criteria, function(c) {
      isTRUE(c$mode == "inferential") &&
        !is.null(c$procedure) && !is.na(c$procedure) &&
        c$procedure == procedure_label &&
        !(isTRUE(c$decision_rule %in% SMOKE_DECISION_RULES))
    }, logical(1))
    if (!any(contributing)) return(NA_real_)
    sum(vapply(criteria[contributing], function(c) c$alpha, numeric(1)))
  }

  list(
    composite_verdict = composite,
    triggering_criteria = as.list(triggering),
    false_compliance_envelope = envelope_sum("COMPLIANCE"),
    false_degradation_signal_envelope = envelope_sum("REGRESSION")
  )
}

#' Generate composite-verdict reference cases
#'
#' @return A list suitable for JSON serialisation.
#' @export
generate_composite_verdict_cases <- function() {

  crit_inf <- function(id, procedure, alpha, verdict) {
    list(criterion_id = id, mode = "inferential",
         procedure = procedure, alpha = alpha, verdict = verdict)
  }

  crit_smoke <- function(id, procedure, rule, alpha, verdict) {
    list(criterion_id = id, mode = "inferential",
         procedure = procedure, alpha = alpha, verdict = verdict,
         decision_rule = rule)
  }

  crit_obs <- function(id, verdict) {
    list(criterion_id = id, mode = "observational",
         procedure = NA, alpha = NA, verdict = verdict)
  }

  case <- function(name, description, criteria) {
    list(
      name = name,
      description = description,
      inputs = list(criteria = criteria),
      expected = composite_verdict(criteria)
    )
  }

  cases <- list(
    case(
      "all_pass_regression_only",
      "Three REGRESSION criteria all pass; only the degradation envelope is emitted.",
      list(
        crit_inf("c_well_formed",    "REGRESSION", 0.05, "PASS"),
        crit_inf("c_latency_within", "REGRESSION", 0.05, "PASS"),
        crit_inf("c_schema_valid",   "REGRESSION", 0.01, "PASS")
      )
    ),
    case(
      "all_pass_compliance_only",
      "Three COMPLIANCE criteria all pass; only the false-compliance envelope is emitted.",
      list(
        crit_inf("c_sla_uptime",       "COMPLIANCE", 0.001, "PASS"),
        crit_inf("c_sla_correctness",  "COMPLIANCE", 0.001, "PASS"),
        crit_inf("c_policy_pii",       "COMPLIANCE", 0.01,  "PASS")
      )
    ),
    case(
      "consult_advice_fail_single_trigger",
      "The §10.3 consult-advice contract: one REGRESSION, one observational, one COMPLIANCE. The COMPLIANCE criterion fails. Both envelopes are emitted with their distinct sums; the observational criterion contributes to neither.",
      list(
        crit_inf("c_well_formed",        "REGRESSION", 0.05,  "PASS"),
        crit_obs("c_no_self_harm",                            "PASS"),
        crit_inf("c_layperson_readable", "COMPLIANCE", 0.001, "FAIL")
      )
    ),
    case(
      "fail_multi_trigger_mixed_procedures",
      "Two failing criteria across both procedure directions. Each envelope sums only over its own family.",
      list(
        crit_inf("c_regression_a", "REGRESSION", 0.05,  "FAIL"),
        crit_inf("c_regression_b", "REGRESSION", 0.05,  "PASS"),
        crit_inf("c_compliance_a", "COMPLIANCE", 0.001, "FAIL"),
        crit_inf("c_compliance_b", "COMPLIANCE", 0.01,  "PASS")
      )
    ),
    case(
      "inconclusive_some_pass_some_inconclusive",
      "No FAIL verdicts but at least one INCONCLUSIVE: composite is INCONCLUSIVE.",
      list(
        crit_inf("c_regression_pass",         "REGRESSION", 0.05,  "PASS"),
        crit_inf("c_compliance_inconclusive", "COMPLIANCE", 0.001, "INCONCLUSIVE")
      )
    ),
    case(
      "inconclusive_all_inconclusive",
      "Pathological case: every criterion INCONCLUSIVE (e.g. the run produced no evaluable trials anywhere). Composite is INCONCLUSIVE.",
      list(
        crit_inf("c_a", "REGRESSION", 0.05, "INCONCLUSIVE"),
        crit_inf("c_b", "COMPLIANCE", 0.001, "INCONCLUSIVE"),
        crit_obs("c_c",                      "INCONCLUSIVE")
      )
    ),
    case(
      "mixed_observational_excluded_from_envelopes",
      "Mixed inferential + observational criteria. Both envelopes exclude the observational alpha (it has none). Composite is PASS.",
      list(
        crit_inf("c_regression", "REGRESSION", 0.05,  "PASS"),
        crit_inf("c_compliance", "COMPLIANCE", 0.001, "PASS"),
        crit_obs("c_observation_a",                   "PASS"),
        crit_obs("c_observation_b",                   "PASS")
      )
    ),
    case(
      "observational_only_pass",
      "Contract with only observational criteria. Composite is PASS; neither envelope is emitted (no inferential criterion of either direction).",
      list(
        crit_obs("c_guardrail_a", "PASS"),
        crit_obs("c_guardrail_b", "PASS")
      )
    ),
    case(
      "observational_only_fail",
      "Contract with only observational criteria, one fails. Composite is FAIL; neither envelope is emitted.",
      list(
        crit_obs("c_guardrail_a", "PASS"),
        crit_obs("c_guardrail_b", "FAIL")
      )
    ),
    case(
      "smoke_only_excluded_from_envelopes",
      "A SMOKE run of two requirements, pass rate and latency, each decided by its SMOKE rule. Their alpha bounds a false FAIL and their PASS claims no compliance, so neither envelope is emitted (§1.4.6). The latency criterion FAILs, so the composite FAILs.",
      list(
        crit_smoke("c_policy_rate", "COMPLIANCE", "compliance/smoke-exact-binomial", 0.05, "PASS"),
        crit_smoke("c_p95_latency", "COMPLIANCE", "latency/smoke-compliance-exact-binomial", 0.05, "FAIL")
      )
    ),
    case(
      "smoke_beside_verification_and_regression",
      "A SMOKE requirement beside a VERIFICATION requirement and a regression criterion. Only the VERIFICATION requirement enters the false-compliance envelope and only the regression criterion the false-degradation-signal envelope; the SMOKE criterion enters neither.",
      list(
        crit_inf("c_verified_rate", "COMPLIANCE", 0.01, "PASS"),
        crit_smoke("c_smoke_rate", "COMPLIANCE", "compliance/smoke-exact-binomial", 0.05, "PASS"),
        crit_inf("c_regression", "REGRESSION", 0.05, "PASS")
      )
    ),
    case(
      "verification_rule_named_enters_envelope",
      "A requirement whose decision_rule names compliance/exact-binomial, the VERIFICATION rule, enters the false-compliance envelope exactly as one with no decision_rule.",
      list(
        crit_smoke("c_named_rule", "COMPLIANCE", "compliance/exact-binomial", 0.001, "PASS"),
        crit_inf("c_unnamed_rule", "COMPLIANCE", 0.01, "PASS")
      )
    )
  )

  list(
    suite = "composite_verdict",
    description = paste(
      "Composite-verdict aggregation per companion §1.4.6 (composite",
      "rule) and SC-RU-05 (envelopes split by procedure direction). The",
      "composite rule is: PASS if every per-criterion verdict is PASS;",
      "FAIL if any is FAIL; INCONCLUSIVE otherwise. The two envelopes",
      "are sums of alpha_c over their own family of inferential criteria:",
      "the false-compliance envelope over COMPLIANCE criteria, the",
      "false-degradation-signal envelope over REGRESSION criteria.",
      "Observational criteria carry no alpha and contribute to neither.",
      "A criterion decided by a SMOKE rule (its optional decision_rule is",
      "compliance/smoke-exact-binomial or",
      "latency/smoke-compliance-exact-binomial) contributes to neither:",
      "its alpha bounds a false FAIL and its PASS claims no compliance."
    ),
    method = paste(
      "Three-way aggregation (PASS/FAIL/INCONCLUSIVE) plus per-family",
      "alpha summation. An envelope is omitted (encoded as null) when",
      "no inferential criterion of that procedure direction is present."
    ),
    tolerance = 1e-12,
    cases = cases
  )
}
