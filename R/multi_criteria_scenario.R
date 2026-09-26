#' Multi-criteria end-to-end scenario fixture (companion §10.3, §10.6)
#'
#' The fixture-form counterpart of the locked §10.3 worked example.
#' Each case ties together a baseline, a test run, and an expected
#' output that names per-criterion derived thresholds, per-criterion
#' verdicts (with the three-strand block for inferential criteria),
#' the composite verdict, both procedure-direction envelopes, and the
#' §10.6 `conformance_status` metadata block.
#'
#' Four cases:
#'   1. consult_advice_locked_section_10_3 — the §10.3 contract.
#'      Composite FAIL triggered by C_layperson_readable.
#'   2. consult_advice_passing_counterfactual — the same contract,
#'      same baseline, but a higher observed K on C_layperson_readable
#'      that clears the SLO at α = 0.001. Composite PASS.
#'   3. paired_evaluability_content_non_unit_r_obs — a separate
#'      contract exercising the structural-composition pattern: a
#'      MARGINAL availability criterion paired with a CONDITIONAL
#'      content criterion via availability_criterion_ref. Non-1.0
#'      r_obs on the content criterion exercises the difference
#'      between n_attempted and n_evaluable.
#'   4. cross_policy_structural_mismatch — the test run's
#'      denominator_policy differs from the baseline's for at least
#'      one criterion. Expected verdict: STRUCTURAL_ERROR; no
#'      numerical comparison performed.
#'
#' Numerics: verified by R recomputation against the locked companion.

# -- Helpers --------------------------------------------------------

inf_test_obs <- function(criterion_id, procedure, policy, alpha,
                        n_attempted, n_evaluable, K_c,
                        baseline_successes = NA, baseline_trials = NA,
                        p_req = NA,
                        availability_criterion_ref = NULL) {
  list(
    criterion_id        = criterion_id,
    mode                = "inferential",
    procedure           = procedure,
    denominator_policy  = policy,
    alpha               = alpha,
    n_attempted         = as.integer(n_attempted),
    n_evaluable         = as.integer(n_evaluable),
    K_c                 = as.integer(K_c),
    baseline_successes  = if (!is.na(baseline_successes)) as.integer(baseline_successes) else NA_integer_,
    baseline_trials     = if (!is.na(baseline_trials)) as.integer(baseline_trials) else NA_integer_,
    p_req               = p_req,
    availability_criterion_ref = if (is.null(availability_criterion_ref)) NA_character_ else availability_criterion_ref
  )
}

obs_test_obs <- function(criterion_id, policy,
                         n_attempted, n_evaluable, K_c) {
  list(
    criterion_id        = criterion_id,
    mode                = "observational",
    procedure           = NA_character_,
    denominator_policy  = policy,
    alpha               = NA_real_,
    n_attempted         = as.integer(n_attempted),
    n_evaluable         = as.integer(n_evaluable),
    K_c                 = as.integer(K_c)
  )
}

per_criterion_verdict_block <- function(test_obs) {
  if (test_obs$mode == "observational") {
    ov <- observational_verdict(test_obs$n_attempted, test_obs$n_evaluable,
                                test_obs$K_c, test_obs$denominator_policy)
    list(
      criterion_id = test_obs$criterion_id,
      mode = "observational",
      procedure = NA_character_,
      denominator_policy = test_obs$denominator_policy,
      n_c = ov$n_c, r_obs = ov$r_obs,
      verdict = ov$verdict,
      statement = ov$statement
    )
  } else if (test_obs$procedure == "REGRESSION") {
    rv <- regression_verdict(test_obs$n_attempted, test_obs$n_evaluable,
                             test_obs$K_c, test_obs$alpha,
                             test_obs$denominator_policy,
                             test_obs$baseline_successes,
                             test_obs$baseline_trials)
    list(
      criterion_id = test_obs$criterion_id,
      mode = "inferential",
      procedure = "REGRESSION",
      denominator_policy = test_obs$denominator_policy,
      alpha = test_obs$alpha,
      decisionRule = "regression/fisher",
      n_c = rv$n_c, r_obs = rv$r_obs,
      p_hat_c = rv$p_hat_c,
      cutoff_integer = rv$cutoff_integer,
      displayed_rate = rv$displayed_rate,
      configuration_error = rv$configuration_error,
      verdict = rv$verdict,
      statistical_verdict = rv$statistical_verdict,
      observed_rate_status = rv$observed_rate_status,
      operational_caution_category = rv$operational_caution_category
    )
  } else if (test_obs$procedure == "COMPLIANCE") {
    cv <- compliance_verdict(test_obs$n_attempted, test_obs$n_evaluable,
                             test_obs$K_c, test_obs$alpha,
                             test_obs$denominator_policy,
                             test_obs$p_req)
    list(
      criterion_id = test_obs$criterion_id,
      mode = "inferential",
      procedure = "COMPLIANCE",
      denominator_policy = test_obs$denominator_policy,
      alpha = test_obs$alpha,
      p_req = test_obs$p_req,
      decisionRule = "compliance/exact-binomial",
      n_c = cv$n_c, r_obs = cv$r_obs,
      p_hat_c = cv$p_hat_c,
      k_min = cv$k_min,
      clopper_pearson_lower = cv$clopper_pearson_lower,
      p_value = cv$p_value,
      p_value_method = cv$p_value_method,
      p_value_tail = cv$p_value_tail,
      feasibility_gate = cv$feasibility_gate,
      verdict = cv$verdict,
      statistical_verdict = cv$statistical_verdict,
      observed_rate_status = cv$observed_rate_status,
      operational_caution_category = cv$operational_caution_category
    )
  }
}

#' Expected scenario output (composite + envelopes + per-criterion
#' verdicts + §10.6 conformance status).
#' @keywords internal
expected_scenario <- function(per_criterion_verdicts) {
  # Compose criteria entries for composite_verdict()
  for_composite <- lapply(per_criterion_verdicts, function(v) {
    list(
      criterion_id = v$criterion_id,
      mode = v$mode,
      procedure = if (v$mode == "inferential") v$procedure else NA,
      alpha = if (v$mode == "inferential") v$alpha else NA,
      verdict = v$verdict
    )
  })
  cv <- composite_verdict(for_composite)

  list(
    per_criterion_verdicts = per_criterion_verdicts,
    composite_verdict = cv$composite_verdict,
    triggering_criteria = cv$triggering_criteria,
    false_compliance_envelope = cv$false_compliance_envelope,
    false_degradation_signal_envelope = cv$false_degradation_signal_envelope,
    conformance_status = list(
      formula_value_fixtures = "passed",
      calibration_fixtures = "not-published",
      calibration_claim_permitted = FALSE
    )
  )
}

#' Structural-error expected output for cross-policy mismatch cases.
#' The methodology rejects the comparison; no numerical verdict is
#' computed.
#' @keywords internal
expected_structural_error <- function(reason, conflicting_criteria) {
  list(
    composite_verdict = "STRUCTURAL_ERROR",
    structural_error = list(
      reason = reason,
      conflicting_criteria = as.list(conflicting_criteria)
    ),
    conformance_status = list(
      formula_value_fixtures = "passed",
      calibration_fixtures = "not-published",
      calibration_claim_permitted = FALSE
    )
  )
}

# -- Cases ----------------------------------------------------------

#' @export
generate_multi_criteria_scenario_cases <- function() {

  # --- Shared consult-advice baseline (mirrors baseline_object.json
  #     case 1; duplicated inline so the scenario fixture is
  #     self-contained for downstream consumers).
  consult_advice_baseline <- list(
    factor_record = list(
      service       = "consult-advice-service@3.1",
      model         = "claude-sonnet-4-5-20250929",
      temperature   = 0.0,
      system_prompt = "consult-advice-prompt@5"
    ),
    covariate_profile = list(
      day_of_week   = "WEEKDAY",
      time_of_day   = "08:00-12:00",
      region        = "EU",
      serving_stack = "standard"
    ),
    expiration_window    = "2026-08-13",
    structural_reference = "consult-advice@5",
    criteria = list(
      inf_crit("c_well_formed",
               procedure = "REGRESSION",
               policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL",
               n_attempted = 1000, n_evaluable = 1000, K_c = 951),
      obs_crit("c_no_self_harm",
               policy = "CONDITIONAL_ON_EVALUABLE",
               n_attempted = 200, n_evaluable = 200, K_c = 200),
      inf_crit("c_layperson_readable",
               procedure = "COMPLIANCE",
               policy = "CONDITIONAL_ON_EVALUABLE",
               n_attempted = 800, n_evaluable = 800, K_c = 788)
    )
  )

  # --- Case 1: locked §10.3 contract, composite FAIL.
  case_1_test_run <- list(
    covariate_profile = consult_advice_baseline$covariate_profile,
    criteria_observations = list(
      inf_test_obs("c_well_formed",
                   procedure = "REGRESSION",
                   policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL",
                   alpha = 0.05,
                   n_attempted = 1000, n_evaluable = 1000, K_c = 953,
                   baseline_successes = 951, baseline_trials = 1000),
      obs_test_obs("c_no_self_harm",
                   policy = "CONDITIONAL_ON_EVALUABLE",
                   n_attempted = 200, n_evaluable = 200, K_c = 200),
      inf_test_obs("c_layperson_readable",
                   procedure = "COMPLIANCE",
                   policy = "CONDITIONAL_ON_EVALUABLE",
                   alpha = 0.001,
                   n_attempted = 800, n_evaluable = 800, K_c = 788,
                   p_req = 0.98)
    )
  )
  case_1_per_crit <- lapply(case_1_test_run$criteria_observations,
                            per_criterion_verdict_block)

  case_1 <- list(
    name = "consult_advice_locked_section_10_3",
    description = paste(
      "The locked §10.3 worked example. Three criteria: C_well_formed",
      "(REGRESSION, EMPIRICAL origin) passes; C_no_self_harm",
      "(observational) passes; C_layperson_readable (COMPLIANCE, SLO",
      "origin) fails with the three-strand verdict's statistical and",
      "observed-rate strands disagreeing. Composite FAIL."
    ),
    inputs = list(
      baseline = consult_advice_baseline,
      test_run = case_1_test_run
    ),
    expected = expected_scenario(case_1_per_crit)
  )

  # --- Case 2: passing counterfactual.
  # Bump K_c on layperson-readable enough to demonstrate compliance at
  # α = 0.001: the exact test's k_min at n = 800, p_req = 0.98 is 796,
  # so K = 798 (p_hat = 0.9975) PASSes.
  case_2_test_run <- case_1_test_run
  case_2_test_run$criteria_observations[[3]]$K_c <- 798L
  case_2_per_crit <- lapply(case_2_test_run$criteria_observations,
                            per_criterion_verdict_block)

  case_2 <- list(
    name = "consult_advice_passing_counterfactual",
    description = paste(
      "Same contract and baseline as case 1, with K_c on",
      "C_layperson_readable increased to 798, at or above k_min = 796, so",
      "compliance with the SLO requirement of 0.98 is demonstrated at",
      "α = 0.001. Composite PASS."
    ),
    inputs = list(
      baseline = consult_advice_baseline,
      test_run = case_2_test_run
    ),
    expected = expected_scenario(case_2_per_crit)
  )

  # --- Case 3: paired-criterion structural-composition pattern.
  paired_baseline <- list(
    factor_record = consult_advice_baseline$factor_record,
    covariate_profile = consult_advice_baseline$covariate_profile,
    expiration_window    = "2026-08-13",
    structural_reference = "consult-advice-paired@1",
    criteria = list(
      inf_crit("c_evaluable_response",
               procedure = "COMPLIANCE",
               policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL",
               n_attempted = 1000, n_evaluable = 970, K_c = 970),
      inf_crit("c_layperson_readable",
               procedure = "COMPLIANCE",
               policy = "CONDITIONAL_ON_EVALUABLE",
               n_attempted = 1000, n_evaluable = 970, K_c = 950,
               availability_criterion_ref = "c_evaluable_response")
    )
  )

  case_3_test_run <- list(
    covariate_profile = paired_baseline$covariate_profile,
    criteria_observations = list(
      inf_test_obs("c_evaluable_response",
                   procedure = "COMPLIANCE",
                   policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL",
                   alpha = 0.05,
                   n_attempted = 1000, n_evaluable = 965, K_c = 965,
                   p_req = 0.95),
      inf_test_obs("c_layperson_readable",
                   procedure = "COMPLIANCE",
                   policy = "CONDITIONAL_ON_EVALUABLE",
                   alpha = 0.05,
                   n_attempted = 1000, n_evaluable = 965, K_c = 945,
                   p_req = 0.95,
                   availability_criterion_ref = "c_evaluable_response")
    )
  )
  case_3_per_crit <- lapply(case_3_test_run$criteria_observations,
                            per_criterion_verdict_block)

  case_3 <- list(
    name = "paired_evaluability_content_non_unit_r_obs",
    description = paste(
      "Structural-composition pattern: a MARGINAL availability",
      "criterion (c_evaluable_response) paired with a CONDITIONAL",
      "content criterion (c_layperson_readable) via",
      "availability_criterion_ref. Test run produces n_evaluable < ",
      "n_attempted, exercising the difference between attempted and",
      "evaluable that the conditional denominator selects. The",
      "composite verdict surfaces both the availability claim and",
      "the content claim independently."
    ),
    inputs = list(
      baseline = paired_baseline,
      test_run = case_3_test_run
    ),
    expected = expected_scenario(case_3_per_crit)
  )

  # --- Case 4: cross-policy structural mismatch.
  # The test run flips one criterion's denominator policy relative to
  # the baseline. Methodology: structural error, no numerical
  # comparison performed.
  case_4_test_run <- case_1_test_run
  case_4_test_run$criteria_observations[[3]]$denominator_policy <-
    "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL"

  case_4 <- list(
    name = "cross_policy_structural_mismatch",
    description = paste(
      "Same contract and baseline as case 1, but the test run's",
      "denominator_policy for C_layperson_readable is",
      "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL while the baseline's is",
      "CONDITIONAL_ON_EVALUABLE. The two estimate different",
      "quantities; the methodology rejects the comparison as a",
      "structural error (§1.4.5a + §1.5.2). No numerical verdict is",
      "computed."
    ),
    inputs = list(
      baseline = consult_advice_baseline,
      test_run = case_4_test_run
    ),
    expected = expected_structural_error(
      reason = paste(
        "Cross-policy comparison rejected: C_layperson_readable carries",
        "denominator_policy CONDITIONAL_ON_EVALUABLE on the baseline but",
        "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL on the test run."
      ),
      conflicting_criteria = "c_layperson_readable"
    )
  )

  cases <- list(case_1, case_2, case_3, case_4)

  list(
    suite = "multi_criteria_scenario_consult_advice",
    description = paste(
      "End-to-end scenarios per companion §10.3 and §10.6 under the 2.0.0",
      "decision rules (regression/fisher, compliance/exact-binomial). Each case",
      "ties together a baseline, a test run, and the expected scenario",
      "output (per-criterion verdicts, composite verdict, both",
      "procedure-direction envelopes, conformance-status metadata).",
      "Case 1 is the one canonical consult-advice example: the run 953 of",
      "1000 against the baseline 951 of 1000 (C_well_formed) and 788 of 800",
      "against the 0.98 requirement at alpha 0.001 (C_layperson_readable);",
      "composite FAIL. Every consult-advice number in the companion is",
      "generated from it. Case 2 is the passing counterfactual; case 3 exercises the structural-",
      "composition pattern (availability sibling + conditional content",
      "via availability_criterion_ref); case 4 exercises the cross-",
      "policy structural-error refusal."
    ),
    method = paste(
      "Per-criterion verdicts computed by regression_verdict /",
      "compliance_verdict / observational_verdict and composed by",
      "composite_verdict. The §10.6 conformance_status block names",
      "formula_value_fixtures: passed and calibration_fixtures:",
      "not-published, anchoring the conformance contract a downstream",
      "framework is expected to replicate."
    ),
    tolerance = 1e-9,
    cases = cases
  )
}
