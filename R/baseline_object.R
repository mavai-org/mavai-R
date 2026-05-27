#' Reference baseline objects (companion §1.5, §1.4.5a, schema fixtures)
#'
#' This generator emits canonical `baseline` objects at named indices — a
#' service-contract identity together with resolved covariate values. Unlike
#' the computation fixtures elsewhere in
#' `inst/cases/`, these cases carry no `expected` block: the case **is**
#' the example. Downstream frameworks load these objects, verify the
#' structural fields round-trip through their parsers, and exercise
#' covariate-match / structural-reference / policy-match checks against
#' them.
#'
#' Each baseline carries:
#'   - its index — `structural_reference` (the service-contract identity)
#'     and `covariate_profile` — alongside `factor_record` (provenance) and
#'     an optional `expiration_window`,
#'   - a list of per-criterion entries, each with `criterion_id`,
#'     `mode`, `procedure` (REGRESSION / COMPLIANCE / NA for
#'     observational), `denominator_policy` (one of two §1.4.5a
#'     values), optionally `availability_criterion_ref` (the
#'     structural-composition pattern), and an `observation` block
#'     carrying `n_attempted`, `n_evaluable`, `r_obs`, `n_c`, `K_c`,
#'     `p_hat_c`.

# -- Constructors -----------------------------------------------------

obs_block <- function(n_attempted, n_evaluable, K_c, policy, mode) {
  n_c <- if (policy == "CONDITIONAL_ON_EVALUABLE")
    n_evaluable else n_attempted
  r_obs <- if (n_attempted == 0) 0 else n_evaluable / n_attempted
  p_hat <- if (mode == "observational" || n_c == 0) NA_real_ else K_c / n_c

  list(
    n_attempted = as.integer(n_attempted),
    n_evaluable = as.integer(n_evaluable),
    r_obs       = r_obs,
    n_c         = as.integer(n_c),
    K_c         = as.integer(K_c),
    p_hat_c     = p_hat
  )
}

inf_crit <- function(id, procedure, policy, n_attempted, n_evaluable, K_c,
                     availability_criterion_ref = NULL) {
  c <- list(
    criterion_id = id,
    mode = "inferential",
    procedure = procedure,
    denominator_policy = policy,
    observation = obs_block(n_attempted, n_evaluable, K_c, policy, "inferential")
  )
  if (!is.null(availability_criterion_ref)) {
    c$availability_criterion_ref <- availability_criterion_ref
  }
  c
}

obs_crit <- function(id, policy, n_attempted, n_evaluable, K_c) {
  list(
    criterion_id = id,
    mode = "observational",
    procedure = NA,
    denominator_policy = policy,
    observation = obs_block(n_attempted, n_evaluable, K_c, policy, "observational")
  )
}

baseline_case <- function(name, description, factor_record, covariate_profile,
                          expiration_window, structural_reference, criteria) {
  list(
    name = name,
    description = description,
    inputs = list(
      baseline = list(
        factor_record        = factor_record,
        covariate_profile    = covariate_profile,
        expiration_window    = expiration_window,
        structural_reference = structural_reference,
        criteria             = criteria
      )
    ),
    expected = list()
  )
}

# -- Cases -----------------------------------------------------------

consult_advice_factor_record <- list(
  service      = "consult-advice-service@3.1",
  model        = "claude-sonnet-4-5-20250929",
  temperature  = 0.0,
  system_prompt = "consult-advice-prompt@5"
)

consult_advice_covariates_eu_weekday <- list(
  day_of_week   = "WEEKDAY",
  time_of_day   = "08:00-12:00",
  region        = "EU",
  serving_stack = "standard"
)

consult_advice_covariates_us_weekend <- list(
  day_of_week   = "WEEKEND",
  time_of_day   = "20:00-23:59",
  region        = "US",
  serving_stack = "standard"
)

#' @export
generate_baseline_object_cases <- function() {

  cases <- list(

    # 1. Consult-advice baseline (mirrors §10.3 / §1.4.8 example).
    baseline_case(
      name = "consult_advice_eu_weekday",
      description = paste(
        "The consult-advice contract baseline at the EU / weekday /",
        "morning index. Three criteria mix",
        "REGRESSION + observational + COMPLIANCE; mixed denominator",
        "policies; r_obs = 1.0 throughout."
      ),
      factor_record        = consult_advice_factor_record,
      covariate_profile    = consult_advice_covariates_eu_weekday,
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
    ),

    # 2. Observational-only baseline at sentinel scale.
    baseline_case(
      name = "guardrail_sentinel_observational_only",
      description = paste(
        "A guardrail-validation baseline carrying a single observational",
        "criterion at sentinel scale (n_attempted = 10^7) under the",
        "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL policy. A schema example of",
        "a large-n observational baseline; the observational verdict",
        "rule (§1.4.5) is unchanged at scale."
      ),
      factor_record        = list(
        service       = "moderation-guardrail@2.0",
        model         = "claude-haiku-4-5-20251001",
        temperature   = 0.0,
        system_prompt = "moderation-guard-prompt@7"
      ),
      covariate_profile    = consult_advice_covariates_eu_weekday,
      expiration_window    = "2026-11-12",
      structural_reference = "moderation-guardrail@1",
      criteria = list(
        obs_crit("c_no_self_harm_sentinel",
                 policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL",
                 n_attempted = 10000000, n_evaluable = 10000000, K_c = 10000000)
      )
    ),

    # 3. Same contract as #1 but a divergent covariate profile.
    baseline_case(
      name = "consult_advice_us_weekend_divergent",
      description = paste(
        "The same consult-advice contract under a divergent covariate",
        "profile (US / weekend / evening). Used as a covariate-match",
        "counterexample: a test at the EU / weekday index must",
        "not resolve against this baseline without explicit project-",
        "policy acknowledgement of the covariate divergence."
      ),
      factor_record        = consult_advice_factor_record,
      covariate_profile    = consult_advice_covariates_us_weekend,
      expiration_window    = "2026-08-13",
      structural_reference = "consult-advice@5",
      criteria = list(
        inf_crit("c_well_formed",
                 procedure = "REGRESSION",
                 policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL",
                 n_attempted = 1000, n_evaluable = 998, K_c = 940),
        obs_crit("c_no_self_harm",
                 policy = "CONDITIONAL_ON_EVALUABLE",
                 n_attempted = 200, n_evaluable = 199, K_c = 199),
        inf_crit("c_layperson_readable",
                 procedure = "COMPLIANCE",
                 policy = "CONDITIONAL_ON_EVALUABLE",
                 n_attempted = 800, n_evaluable = 795, K_c = 780)
      )
    ),

    # 4. Perfect-baseline edge case.
    baseline_case(
      name = "perfect_baseline_moderate_n",
      description = paste(
        "A baseline at p_hat_c = 1 over a moderate n_c. Anchors the §4",
        "perfect-baseline two-step under the per-criterion shape: a",
        "downstream threshold derivation must compress the observed 1.0",
        "to a Wilson lower bound on the baseline itself before using it",
        "as the effective baseline rate."
      ),
      factor_record        = list(
        service       = "schema-validator@1.0",
        model         = "deterministic-validator@1",
        temperature   = 0.0,
        system_prompt = "schema-prompt@1"
      ),
      covariate_profile    = consult_advice_covariates_eu_weekday,
      expiration_window    = "2026-11-12",
      structural_reference = "schema-validator@1",
      criteria = list(
        inf_crit("c_schema_valid",
                 procedure = "REGRESSION",
                 policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL",
                 n_attempted = 2000, n_evaluable = 2000, K_c = 2000)
      )
    ),

    # 5. Cross-policy counterexample. Same contract as #1 but the
    #    layperson-readable criterion's policy is flipped to MARGINAL.
    baseline_case(
      name = "consult_advice_cross_policy_counterexample",
      description = paste(
        "The same consult-advice contract at the same index as #1,",
        "except the C_layperson_readable criterion's denominator policy",
        "is MARGINAL_COUNT_UNEVALUABLE_AS_FAIL instead of",
        "CONDITIONAL_ON_EVALUABLE. Used to exercise the structural-error",
        "check that cross-policy comparison between this baseline and",
        "the #1 baseline is rejected — the two baselines look identical",
        "in every other respect but estimate different quantities under",
        "the C_layperson_readable criterion."
      ),
      factor_record        = consult_advice_factor_record,
      covariate_profile    = consult_advice_covariates_eu_weekday,
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
                 policy = "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL",
                 n_attempted = 800, n_evaluable = 800, K_c = 788)
      )
    ),

    # 6. Paired-criterion baseline (structural composition; §1.4.5a's
    #    replacement for the removed SEPARATE_AVAILABILITY_GATE policy).
    baseline_case(
      name = "paired_evaluability_content_pattern",
      description = paste(
        "Demonstrates the structural-composition pattern of the locked",
        "§1.4.5a: a downstream content criterion declared",
        "CONDITIONAL_ON_EVALUABLE references a sibling availability /",
        "evaluability criterion via availability_criterion_ref. The",
        "availability criterion itself is declared",
        "MARGINAL_COUNT_UNEVALUABLE_AS_FAIL so that unevaluable trials",
        "are counted as failures of availability. The run produced a",
        "non-1.0 r_obs on the content criterion, exercising the",
        "difference between n_attempted and n_evaluable that the",
        "conditional denominator selects."
      ),
      factor_record        = consult_advice_factor_record,
      covariate_profile    = consult_advice_covariates_eu_weekday,
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
  )

  list(
    suite = "baseline_object",
    description = paste(
      "Reference baseline objects per companion §1.5 + §1.4.5a. Cases",
      "are schema fixtures rather than computation fixtures: each case",
      "is a canonical baseline at a stated index (service-contract identity",
      "and resolved covariate values)",
      "with no expected output (the case itself is the example). Used",
      "by downstream frameworks to exercise parser conformance and the",
      "structural checks (covariate match, structural-reference match,",
      "policy match) that §§1.5.2 and 1.4.5a require."
    ),
    method = paste(
      "Object construction. No statistical computation involved; each",
      "baseline records its index (service-contract identity and covariate",
      "profile), the factor record, an optional expiration window, and a",
      "list of per-criterion",
      "observation blocks under the locked §1.4.5a two-policy enum."
    ),
    tolerance = 0,
    cases = cases
  )
}
