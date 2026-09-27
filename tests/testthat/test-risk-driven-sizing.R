by_name <- function(suite) setNames(suite$cases, vapply(suite$cases, `[[`, character(1), "name"))
suite <- generate_risk_driven_sizing_cases()
cases <- by_name(suite)

test_that("required n is where power stays at target up to n_b", {
  e <- cases[["companion_scenario_walkthrough"]]
  n <- e$expected$required_n
  i <- e$inputs
  expect_gte(e$expected$achieved_power, i$target_power)
  expect_lt(risk_sizing_power(n - 1L, i$baseline_rate, i$baseline_trials,
                              i$design_alternative_rate, i$alpha), i$target_power)
  for (m in c(n + 1L, n + 50L, i$baseline_trials)) {
    expect_gte(risk_sizing_power(m, i$baseline_rate, i$baseline_trials,
                                 i$design_alternative_rate, i$alpha), i$target_power)
  }
})

test_that("the windowed power equals the full exact sum", {
  full <- fisher_power(2000, 150, 0.05, 0.96, 0.03)
  expect_equal(risk_sizing_power(150, 0.96, 2000, 0.93, 0.05), full, tolerance = 1e-14)
})

test_that("higher power and smaller alpha cost samples", {
  base <- cases[["companion_scenario_walkthrough"]]$expected$required_n
  expect_gt(cases[["higher_power_costs_samples"]]$expected$required_n, base)
  expect_gt(cases[["smaller_alpha_costs_samples"]]$expected$required_n, base)
})

test_that("the inversion round-trips: power at the detectable rate meets the target", {
  e <- cases[["inversion_at_400"]]
  i <- e$inputs
  expect_gte(risk_sizing_power(400, i$baseline_rate, i$baseline_trials, e$expected$detectable_rate,
                               i$alpha), i$target_power)
  expect_lt(risk_sizing_power(400, i$baseline_rate, i$baseline_trials,
                              e$expected$detectable_rate + 1e-6, i$alpha), i$target_power)
})

test_that("inadmissible designs are published as refusals", {
  expect_identical(cases[["zero_baseline_required_n_refused"]]$expected$refusal_category, "ZERO_BASELINE")
  expect_identical(cases[["design_alternative_at_baseline_refused"]]$expected$refusal_category, "ALTERNATIVE_NOT_BELOW_BASELINE")
  expect_identical(cases[["test_larger_than_baseline_refused"]]$expected$refusal_category, "TEST_LARGER_THAN_BASELINE")
  r <- cases[["baseline_too_small_for_design"]]$expected
  expect_identical(r$sizing_gate, "REFUSE")
  expect_identical(r$refusal_category, "BASELINE_TOO_SMALL")
  expect_true(is.na(r$required_n))
})

test_that("resolved sizing against an observed baseline differs from design sizing", {
  cases <- setNames(generate_risk_driven_sizing_cases()$cases,
                    vapply(generate_risk_driven_sizing_cases()$cases, `[[`, character(1), "name"))
  r <- cases[["resolved_section_10_3_951_of_1000_at_0925"]]$expected
  expect_identical(r$sizing_gate, "ADMIT")
  expect_identical(r$required_n, 966L)
  expect_identical(r$first_crossing, 868L)
  expect_gte(r$resolved_power, 0.80)
  expect_lt(risk_sizing_resolved_power(965, 951, 1000, 0.925, 0.05), 0.80)
  d <- cases[["design_section_10_3_planned_1000_at_0951_vs_0925"]]$expected
  expect_identical(d$refusal_category, "BASELINE_TOO_SMALL")
  expect_equal(cases[["resolved_power_at_1000_section_10_3"]]$expected$resolved_power,
               pbinom(932, 1000, 0.925), tolerance = 1e-14)
})
