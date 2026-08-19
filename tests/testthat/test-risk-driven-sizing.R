test_that("power is increasing in n within the domain", {
  powers <- vapply(c(50, 150, 405, 1000), function(n) {
    power_self_consistent(n, 0.96, 0.93, 0.95)
  }, numeric(1))
  expect_true(all(diff(powers) > 0))
})

test_that("required n is minimal: the target holds at n and fails at n - 1", {
  n <- required_n_self_consistent(0.87, 0.84, 0.95, 0.80)
  expect_gte(power_self_consistent(n, 0.87, 0.84, 0.95), 0.80)
  expect_lt(power_self_consistent(n - 1, 0.87, 0.84, 0.95), 0.80)
})

test_that("the companion's computed examples are pinned", {
  expect_identical(required_n_self_consistent(0.87, 0.84, 0.95, 0.80), 891L)
  expect_identical(required_n_self_consistent(0.96, 0.93, 0.95, 0.80), 405L)
  expect_equal(wilson_lower_from_rate(0.87, 891, 0.95), 0.8503, tolerance = 1e-4)
})

test_that("the closed-form seed underpowers the worked example", {
  expect_lt(power_self_consistent(826, 0.87, 0.84, 0.95), 0.80)
})

test_that("the inversion round-trips: power at the detectable rate meets the target", {
  detectable <- detectable_rate_self_consistent(100, 0.87, 0.95, 0.80)
  expect_gte(power_self_consistent(100, 0.87, detectable, 0.95), 0.80)
  # And a nudge above the detectable rate falls below the target.
  expect_lt(power_self_consistent(100, 0.87, detectable + 1e-6, 0.95), 0.80)
})

test_that("inverting at the required n recovers the declared tolerance", {
  expect_equal(detectable_rate_self_consistent(891, 0.87, 0.95, 0.80), 0.84,
               tolerance = 1e-3)
  expect_equal(detectable_rate_self_consistent(405, 0.96, 0.95, 0.80), 0.93,
               tolerance = 1e-3)
})

test_that("the over-reach regime is refused, not computed", {
  expect_error(
    power_self_consistent(100, 0.90, 0.90, 0.95),
    "p_min < p0"
  )
  expect_error(
    required_n_self_consistent(0.90, 0.95, 0.95, 0.80),
    "p_min < p0"
  )
})

test_that("the generated suite is well formed", {
  suite <- generate_risk_driven_sizing_cases()
  expect_identical(suite$suite, "risk_driven_sizing")
  expect_identical(suite$tolerance, 1e-6)
  names_ <- vapply(suite$cases, function(c) c$name, character(1))
  expect_identical(anyDuplicated(names_), 0L)
  approaches <- vapply(suite$cases, function(c) c$approach, character(1))
  expect_setequal(unique(approaches), c("required_n", "power_at", "detectable_rate"))
  for (case in suite$cases) {
    expect_true(length(case$expected) >= 1, info = case$name)
    expect_true(all(!vapply(case$expected, is.null, logical(1))), info = case$name)
  }
})

test_that("inadmissible sizing designs are published as refusals, not omitted", {
  # The suite used to express the §5.4.1 domain restriction by declining
  # to emit cases outside it, which left "correctly refuses" a convention
  # rather than an assertable outcome. Both routes out of the domain are
  # now published, and they are distinguishable by cause.
  suite <- generate_risk_driven_sizing_cases()
  by_name <- setNames(suite$cases, vapply(suite$cases, `[[`, "", "name"))

  refused <- Filter(function(c) c$expected$sizing_gate == "REFUSE", suite$cases)
  expect_length(refused, 4)

  for (case in refused) {
    # Every numeric expectation is absent, because none exists.
    numerics <- setdiff(names(case$expected), c("sizing_gate", "refusal_category"))
    expect_gt(length(numerics), 0)
    for (f in numerics) expect_true(is.na(case$expected[[f]]))
  }

  # A zero baseline reaches the refusal through an effective rate of
  # exactly 0 (§4.3.4); all three approaches refuse, since the emptiness
  # is in the domain rather than in any one inversion.
  zero <- Filter(function(c) c$expected$refusal_category == "ZERO_BASELINE", refused)
  expect_setequal(vapply(zero, `[[`, "", "approach"),
                  c("required_n", "power_at", "detectable_rate"))
  for (case in zero) expect_identical(case$inputs$baseline_rate, 0)

  # The other route out is a tolerance that is not below the baseline —
  # same gate, different cause. A framework collapsing the two into one
  # message loses the distinction the operator acts on.
  expect_identical(
    by_name[["tolerance_at_baseline_refused"]]$expected$refusal_category,
    "EMPTY_TOLERANCE_INTERVAL")

  # Admissible cases carry the gate too, so its absence is never how a
  # consumer infers admissibility.
  admitted <- Filter(function(c) c$expected$sizing_gate == "ADMIT", suite$cases)
  expect_length(admitted, length(suite$cases) - 4)
})
