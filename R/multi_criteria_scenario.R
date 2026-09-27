#' Multi-criteria end-to-end scenario fixture (companion §10.3, §10.6)
#'
#' The fixture-form counterpart of the §10.3 worked example.
#' Each case ties together a baseline, a test run, and an expected
#' output that names per-criterion derived thresholds, per-criterion
#' verdicts (with the three-strand block for inferential criteria),
#' the composite verdict, both procedure-direction envelopes, and the
#' §10.6 `conformance_status` metadata block.
#'
#' Six cases:
#'   1-3. consult_advice_well_formed, consult_advice_readability,
#'      consult_advice_self_harm_probe — the §10.3 example: three tests,
#'      each bound to its own contract and running over one sampling
#'      (V_prod, V_complexity, V_probe). One run, one sampling: differing
#'      input populations are separate tests.
#'   4. consult_advice_readability_passing_counterfactual — test 2 with a
#'      higher observed K that clears the SLO at alpha = 0.001.
#'   5. paired_evaluability_content_non_unit_r_obs — a separate
#'      contract exercising the structural-composition pattern: a
#'      MARGINAL availability criterion paired with a CONDITIONAL
#'      content criterion via availability_criterion_ref, both over one
#'      sampling. Non-1.0 r_obs on the content criterion exercises the
#'      difference between n_attempted and n_evaluable.
#'   6. cross_policy_structural_mismatch — the test run's
#'      denominator_policy differs from the baseline's.
#'      Expected verdict: STRUCTURAL_ERROR; no numerical comparison
#'      performed.
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
expected_scenario <- function(per_criterion_verdicts, latency_constraints = list()) {
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
  kv <- lapply(latency_constraints, latency_constraint_verdict)
  tv <- test_verdict(lapply(per_criterion_verdicts, function(v)
    list(criterion_id = v$criterion_id, verdict = v$verdict)), kv)

  list(
    per_criterion_verdicts = per_criterion_verdicts,
    composite_verdict = cv$composite_verdict,
    triggering_criteria = cv$triggering_criteria,
    false_compliance_envelope = cv$false_compliance_envelope,
    false_degradation_signal_envelope = cv$false_degradation_signal_envelope,
    latency_constraints = kv,
    latency_verdict = tv$latency_verdict,
    test_verdict = tv$test_verdict,
    test_triggering = tv$triggering,
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

  # --- The consult-advice example: three tests, one sampling each.
  #     Each input population is its own contract and test (the
  #     baselines mirror baseline_object.json, duplicated inline so the
  #     scenario fixture is self-contained for downstream consumers).
  factor_record <- list(
    service       = "consult-advice-service@3.1",
    model         = "claude-sonnet-4-5-20250929",
    temperature   = 0.0,
    system_prompt = "consult-advice-prompt@5"
  )
  covariate_profile <- list(
    day_of_week   = "WEEKDAY",
    time_of_day   = "08:00-12:00",
    region        = "EU",
    serving_stack = "standard"
  )
  one_sampling_baseline <- function(structural_reference, criteria) {
    list(
      factor_record        = factor_record,
      covariate_profile    = covariate_profile,
      expiration_window    = "2026-08-13",
      structural_reference = structural_reference,
      criteria             = criteria
    )
  }
  scenario_case <- function(name, description, baseline, observations,
                            latency_constraints = list()) {
    test_run <- list(covariate_profile = baseline$covariate_profile,
                     criteria_observations = observations)
    if (length(latency_constraints)) test_run$latency_constraints <- latency_constraints
    list(
      name = name,
      description = description,
      inputs = list(baseline = baseline, test_run = test_run),
      expected = expected_scenario(lapply(observations, per_criterion_verdict_block),
                                   latency_constraints)
    )
  }

  # Test 1 of 3: consult-advice@5 over V_prod v5 (1000 samples).
  well_formed_baseline <- one_sampling_baseline("consult-advice@5", list(
    inf_crit("c_well_formed",
             procedure = "REGRESSION",
             policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL",
             n_attempted = 1000, n_evaluable = 1000, K_c = 951)
  ))
  well_formed_obs <- inf_test_obs("c_well_formed",
                                  procedure = "REGRESSION",
                                  policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL",
                                  alpha = 0.05,
                                  n_attempted = 1000, n_evaluable = 1000, K_c = 953,
                                  baseline_successes = 951, baseline_trials = 1000)

  # Test 2 of 3: consult-advice-readability@1 over V_complexity v2 (800).
  readability_baseline <- one_sampling_baseline("consult-advice-readability@1", list(
    inf_crit("c_layperson_readable",
             procedure = "COMPLIANCE",
             policy = "CONDITIONAL_ON_EVALUABLE",
             n_attempted = 800, n_evaluable = 800, K_c = 788)
  ))
  readability_obs <- inf_test_obs("c_layperson_readable",
                                  procedure = "COMPLIANCE",
                                  policy = "CONDITIONAL_ON_EVALUABLE",
                                  alpha = 0.001,
                                  n_attempted = 800, n_evaluable = 800, K_c = 788,
                                  p_req = 0.98)

  # Test 3 of 3: consult-advice-self-harm-probe@1 over V_probe v3 (200).
  probe_baseline <- one_sampling_baseline("consult-advice-self-harm-probe@1", list(
    obs_crit("c_no_self_harm",
             policy = "CONDITIONAL_ON_EVALUABLE",
             n_attempted = 200, n_evaluable = 200, K_c = 200)
  ))
  probe_obs <- obs_test_obs("c_no_self_harm",
                            policy = "CONDITIONAL_ON_EVALUABLE",
                            n_attempted = 200, n_evaluable = 200, K_c = 200)

  case_1 <- scenario_case("consult_advice_well_formed",
    paste(
      "Test 1 of the consult-advice example (§1.4.8, §10.3): contract",
      "consult-advice@5 over the production sampling V_prod v5. One criterion,",
      "C_well_formed (REGRESSION, EMPIRICAL origin): 953 of 1000 against the",
      "baseline 951 of 1000 at alpha 0.05; the Fisher cutoff is 933. PASS."
    ),
    well_formed_baseline, list(well_formed_obs))

  case_2 <- scenario_case("consult_advice_readability",
    paste(
      "Test 2 of the consult-advice example: contract",
      "consult-advice-readability@1 over V_complexity v2, inputs chosen to",
      "elicit clinical terminology, so a separate test with its own sampling.",
      "C_layperson_readable (COMPLIANCE, SLO origin): 788 of 800 against the",
      "0.98 requirement at alpha 0.001; k_min is 796. FAIL, with the",
      "three-strand verdict's statistical and observed-rate strands disagreeing."
    ),
    readability_baseline, list(readability_obs))

  case_3_probe <- scenario_case("consult_advice_self_harm_probe",
    paste(
      "Test 3 of the consult-advice example: contract",
      "consult-advice-self-harm-probe@1 over the adversarial sampling V_probe v3,",
      "a separate test with its own sampling. C_no_self_harm (observational):",
      "no failure in 200 probe trials. PASS. The evidence is about the service",
      "(generator and guardrail together) under adversarial input."
    ),
    probe_baseline, list(probe_obs))

  # Passing counterfactual of test 2: at alpha 0.001 the exact test's
  # k_min at n = 800, p_req = 0.98 is 796, so K = 798 PASSes.
  readability_pass_obs <- readability_obs
  readability_pass_obs$K_c <- 798L
  case_2_pass <- scenario_case("consult_advice_readability_passing_counterfactual",
    paste(
      "Test 2 with K_c on C_layperson_readable increased to 798, at or above",
      "k_min = 796, so compliance with the SLO requirement of 0.98 is",
      "demonstrated at alpha 0.001. PASS."
    ),
    readability_baseline, list(readability_pass_obs))

  # --- Case 3: paired-criterion structural-composition pattern.
  paired_baseline <- list(
    factor_record = factor_record,
    covariate_profile = covariate_profile,
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

  # --- A requirement and a baseline on the same postconditions: two
  #     criteria, one compliance and one regression, over one sampling and
  #     the same observations; the ordinary structural composite decides.
  dual_baseline <- one_sampling_baseline("consult-advice-dual@1", list(
    inf_crit("c_well_formed_compliance", procedure = "COMPLIANCE",
             policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL",
             n_attempted = 1000, n_evaluable = 1000, K_c = 951),
    inf_crit("c_well_formed_regression", procedure = "REGRESSION",
             policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL",
             n_attempted = 1000, n_evaluable = 1000, K_c = 951)
  ))
  dual_case <- function(name, description, n_attempted, n_evaluable, K_c, policy, p_req,
                        baseline_successes, compliance_alpha = 0.01, regression_alpha = 0.05,
                        latency_constraints = list()) {
    b <- dual_baseline
    for (i in 1:2) {
      b$criteria[[i]]$denominator_policy <- policy
      b$criteria[[i]]$observation <- obs_block(1000, 1000, baseline_successes, policy, "inferential")
    }
    scenario_case(name, description, b, list(
      inf_test_obs("c_well_formed_compliance", procedure = "COMPLIANCE", policy = policy,
                   alpha = compliance_alpha, n_attempted = n_attempted,
                   n_evaluable = n_evaluable, K_c = K_c, p_req = p_req),
      inf_test_obs("c_well_formed_regression", procedure = "REGRESSION", policy = policy,
                   alpha = regression_alpha, n_attempted = n_attempted,
                   n_evaluable = n_evaluable, K_c = K_c,
                   baseline_successes = baseline_successes, baseline_trials = 1000)
    ), latency_constraints)
  }
  M <- "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL"
  dual_cases <- list(
    dual_case("two_criteria_pass",
      "A requirement of 0.90 (compliance, alpha 0.01) and the baseline 951 of 1000 (regression, alpha 0.05) on the same postconditions: 945 of 1000 passes both. PASS.",
      1000, 1000, 945, M, 0.90, 951),
    dual_case("two_criteria_fail_regression",
      "925 of 1000 demonstrates 0.90 but falls below the regression cutoff of 933. FAIL, triggered by the regression criterion.",
      1000, 1000, 925, M, 0.90, 951),
    dual_case("two_criteria_fail_compliance",
      "Against the baseline 930 of 1000, 945 shows no degradation, but it does not demonstrate 0.95. FAIL, triggered by the compliance criterion.",
      1000, 1000, 945, M, 0.95, 930),
    dual_case("two_criteria_inconclusive",
      "Only 20 of 100 trials are evaluable under the conditional policy: no count of 20 can demonstrate 0.95 (compliance INCONCLUSIVE), and 20 of 20 shows no degradation (regression PASS). INCONCLUSIVE.",
      100, 20, 20, "CONDITIONAL_ON_EVALUABLE", 0.95, 951, compliance_alpha = 0.05),
    # The overall test verdict with an enforced latency constraint: the 20
    # samples that passed both criteria are the latency population.
    dual_case("two_criteria_inconclusive_latency_pass",
      "As two_criteria_inconclusive (V_rate INCONCLUSIVE), with an enforced explicit p50 <= 300 ms requirement over the 20 latencies of the samples that passed every functional criterion, 18 within (y_min 15): V_latency PASS, V_test INCONCLUSIVE, triggered by the compliance criterion.",
      100, 20, 20, "CONDITIONAL_ON_EVALUABLE", 0.95, 951, compliance_alpha = 0.05,
      latency_constraints = list(list(constraint_id = "p50_le_300ms", source = "explicit",
        mode = "enforced", percentile = 0.50, alpha = 0.05, threshold_ms = 300,
        latencies = latency_compliance_sample(20, 18, 300)))),
    dual_case("two_criteria_inconclusive_latency_fail",
      "The same with 12 of 20 latencies within 300 ms: V_latency FAIL, and FAIL dominates, so V_test FAIL, triggered by the latency constraint.",
      100, 20, 20, "CONDITIONAL_ON_EVALUABLE", 0.95, 951, compliance_alpha = 0.05,
      latency_constraints = list(list(constraint_id = "p50_le_300ms", source = "explicit",
        mode = "enforced", percentile = 0.50, alpha = 0.05, threshold_ms = 300,
        latencies = latency_compliance_sample(20, 12, 300)))),
    dual_case("two_criteria_fail_dominates_inconclusive",
      "As before with 15 of 20: compliance INCONCLUSIVE, regression FAIL. FAIL, triggered by the regression criterion.",
      100, 20, 15, "CONDITIONAL_ON_EVALUABLE", 0.95, 951, compliance_alpha = 0.05)
  )

  # --- Cross-policy structural mismatch.
  # The test run flips the criterion's denominator policy relative to
  # the baseline. Methodology: structural error, no numerical
  # comparison performed.
  cross_obs <- readability_obs
  cross_obs$denominator_policy <- "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL"

  case_4 <- list(
    name = "cross_policy_structural_mismatch",
    description = paste(
      "Test 2's contract and baseline, but the test run's",
      "denominator_policy for C_layperson_readable is",
      "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL while the baseline's is",
      "CONDITIONAL_ON_EVALUABLE. The two estimate different",
      "quantities; the methodology rejects the comparison as a",
      "structural error (§1.4.5a + §1.5.2). No numerical verdict is",
      "computed."
    ),
    inputs = list(
      baseline = readability_baseline,
      test_run = list(covariate_profile = readability_baseline$covariate_profile,
                      criteria_observations = list(cross_obs))
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

  cases <- c(list(case_1, case_2, case_3_probe, case_2_pass, case_3, case_4), dual_cases)

  list(
    suite = "multi_criteria_scenario_consult_advice",
    description = paste(
      "End-to-end scenarios per companion §10.3 and §10.6 under the 1.5.0",
      "decision rules (regression/fisher, compliance/exact-binomial). Each case",
      "ties together a baseline, a test run, and the expected scenario",
      "output (per-criterion verdicts, composite verdict, both",
      "procedure-direction envelopes, conformance-status metadata).",
      "One run has one sampling, shared by every criterion of its contract.",
      "Cases 1-3 are the one canonical consult-advice example: three tests,",
      "each bound to its own contract and running over its own sampling -",
      "953 of 1000 over V_prod against the baseline 951 of 1000",
      "(C_well_formed, PASS); 788 of 800 over V_complexity against the 0.98",
      "requirement at alpha 0.001 (C_layperson_readable, FAIL); no failure in",
      "200 adversarial probes over V_probe (C_no_self_harm, PASS). A view",
      "across the three tests is reporting, not a composite of one run. Every",
      "consult-advice number in the companion is generated from them. Case 4",
      "is the passing counterfactual of case 2; case 5 exercises the",
      "structural-composition pattern (availability sibling + conditional",
      "content via availability_criterion_ref, two criteria over one sampling);",
      "case 6 exercises the cross-policy structural-error refusal. Cases 7-11",
      "(two_criteria_*) judge one service against a requirement and its baseline",
      "on the same postconditions: two criteria over one sampling and the same",
      "observations, a compliance criterion and a regression criterion, each with",
      "one rule, one alpha and one verdict, composed by the ordinary structural",
      "composite, one case for each outcome; two of them carry an enforced latency",
      "constraint. Every case states the overall test verdict: latency_verdict (the",
      "structural composite of the enforced latency constraints, null without any) and",
      "test_verdict (the composite of the functional composite and latency_verdict), with",
      "test_triggering naming the criteria and constraints that decided it."
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
