#' Reference baseline objects (companion §1.5, §1.4.5a, schema fixtures)
#'
#' This generator emits canonical `baseline` objects at named indices — a
#' service-contract identity together with resolved covariate values. Unlike
#' the computation fixtures elsewhere in
#' `inst/cases/`, these cases carry no `expected` block: the case **is**
#' the example. Downstream frameworks load these objects, verify the
#' structural fields round-trip through their parsers, and exercise
#' covariate-match / structural-reference checks against them.
#'
#' Each baseline carries:
#'   - its index — `structural_reference` (the service-contract identity)
#'     and `covariate_profile` — alongside `factor_record` (provenance) and
#'     an optional `expiration_window`,
#'   - a list of per-criterion entries, each with `criterion_id`,
#'     `mode`, `procedure` (REGRESSION / COMPLIANCE / NA for
#'     observational), and an `observation` block carrying
#'     `n_attempted`, `n_evaluable`, `r_obs`, `n_c`, `K_c`, `p_hat_c`.
#'     `n_c = n_attempted` (§1.4.5a); `n_evaluable` and `r_obs` are the
#'     §1.5.2 diagnostics.

# -- Constructors -----------------------------------------------------

obs_block <- function(n_attempted, n_evaluable, K_c, mode) {
  n_c <- n_attempted
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

inf_crit <- function(id, procedure, n_attempted, n_evaluable, K_c) {
  list(
    criterion_id = id,
    mode = "inferential",
    procedure = procedure,
    observation = obs_block(n_attempted, n_evaluable, K_c, "inferential")
  )
}

obs_crit <- function(id, n_attempted, n_evaluable, K_c) {
  list(
    criterion_id = id,
    mode = "observational",
    procedure = NA,
    observation = obs_block(n_attempted, n_evaluable, K_c, "observational")
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

    # 1-3. The consult-advice example (§1.4.8, §1.5.6, §10.3): one
    #      baseline per contract, each over one sampling.
    baseline_case(
      name = "consult_advice_eu_weekday",
      description = paste(
        "The consult-advice@5 baseline at the EU / weekday / morning index,",
        "measured over the production sampling V_prod v5 (1000 samples). One",
        "sampling, shared by every criterion of the contract; here one",
        "REGRESSION criterion."
      ),
      factor_record        = consult_advice_factor_record,
      covariate_profile    = consult_advice_covariates_eu_weekday,
      expiration_window    = "2026-08-13",
      structural_reference = "consult-advice@5",
      criteria = list(
        inf_crit("c_well_formed",
                 procedure = "REGRESSION",
                 n_attempted = 1000, n_evaluable = 1000, K_c = 951)
      )
    ),

    baseline_case(
      name = "consult_advice_readability_eu_weekday",
      description = paste(
        "The consult-advice-readability@1 baseline at the same index, measured",
        "over V_complexity v2 (800 samples), inputs chosen to elicit clinical",
        "terminology. A different input population is a separate contract",
        "with its own sampling and baseline. The criterion's requirement is",
        "normative (SLO); the baseline observation is diagnostic context."
      ),
      factor_record        = consult_advice_factor_record,
      covariate_profile    = consult_advice_covariates_eu_weekday,
      expiration_window    = "2026-08-13",
      structural_reference = "consult-advice-readability@1",
      criteria = list(
        inf_crit("c_layperson_readable",
                 procedure = "COMPLIANCE",
                 n_attempted = 800, n_evaluable = 800, K_c = 788)
      )
    ),

    baseline_case(
      name = "consult_advice_self_harm_probe_eu_weekday",
      description = paste(
        "The consult-advice-self-harm-probe@1 baseline at the same index,",
        "measured over the adversarial sampling V_probe v3 (200 samples). One",
        "observational criterion."
      ),
      factor_record        = consult_advice_factor_record,
      covariate_profile    = consult_advice_covariates_eu_weekday,
      expiration_window    = "2026-08-13",
      structural_reference = "consult-advice-self-harm-probe@1",
      criteria = list(
        obs_crit("c_no_self_harm",
                 n_attempted = 200, n_evaluable = 200, K_c = 200)
      )
    ),

    # 4. Observational-only baseline at sentinel scale.
    baseline_case(
      name = "guardrail_sentinel_observational_only",
      description = paste(
        "A guardrail-validation baseline carrying a single observational",
        "criterion at sentinel scale (n_attempted = 10^7). A schema example of",
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
                 n_attempted = 10000000, n_evaluable = 10000000, K_c = 10000000)
      )
    ),

    # 5. Same contract as #1 but a divergent covariate profile.
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
                 n_attempted = 1000, n_evaluable = 998, K_c = 940)
      )
    ),

    # 6. Perfect-baseline edge case.
    baseline_case(
      name = "perfect_baseline_moderate_n",
      description = paste(
        "A baseline at p_hat_c = 1 over a moderate n_c (§4). Under",
        "regression/fisher the perfect count enters the Fisher test as",
        "observed, with no substitution: the cutoff is monotone in the",
        "baseline count, and a perfect baseline demands at least as much",
        "of the test as any lesser one."
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
                 n_attempted = 2000, n_evaluable = 2000, K_c = 2000)
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
      "structural checks (covariate match, structural-reference match)",
      "that §1.5.2 requires."
    ),
    method = paste(
      "Object construction. No statistical computation involved; each",
      "baseline records its index (service-contract identity and covariate",
      "profile), the factor record, an optional expiration window, and a",
      "list of per-criterion",
      "observation blocks (n_c = n_attempted, §1.4.5a; n_evaluable and",
      "r_obs the §1.5.2 diagnostics)."
    ),
    tolerance = 0,
    cases = cases
  )
}
