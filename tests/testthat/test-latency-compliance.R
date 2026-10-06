test_that("an explicit latency requirement is the compliance rule on the within-threshold count", {
  lat <- c(rep(400, 99), 700)
  v <- latency_compliance_verdict(lat, 500, 0.95, 0.05)
  expect_equal(v$within_threshold, 99L)
  expect_equal(v$y_min, exact_binomial_k_min(0.95, 100, 0.05))
  expect_equal(v$y_min, 99L)
  expect_equal(v$verdict, "PASS")
  expect_lte(v$false_compliance, 0.05)
})

test_that("the raw percentile comparison decides nothing and can pass where compliance is not shown", {
  lat <- c(rep(400, 95), rep(700, 5))
  v <- latency_compliance_verdict(lat, 500, 0.95, 0.05)
  expect_true(v$raw_percentile_pass)
  expect_equal(v$verdict, "FAIL")
  # At the null boundary F(tau) = 0.95 the raw comparison passes about 62% of the time.
  expect_equal(pbinom(94, 100, 0.95, lower.tail = FALSE), 0.616, tolerance = 1e-3)
})

test_that("ties at the threshold count as within it", {
  v <- latency_compliance_verdict(c(rep(500, 99), 900), 500, 0.95, 0.05)
  expect_equal(v$within_threshold, 99L)
})

test_that("too few successful latencies is INCONCLUSIVE, not FAIL", {
  v <- latency_compliance_verdict(rep(100, 58), 500, 0.95, 0.05)
  expect_false(v$pass_possible)
  expect_equal(v$verdict, "INCONCLUSIVE")
  expect_equal(exact_binomial_min_feasible_n(0.95, 0.05), 59L)
})

test_that("the exact boundary is admitted", {
  v <- latency_compliance_verdict(rep(100, 5), 300, 0.50, 0.03125)
  expect_equal(v$y_min, 5L)
  expect_equal(v$verdict, "PASS")
})

test_that("a VERIFICATION plan below the feasibility minimum is refused", {
  cases <- generate_latency_compliance_decision_cases()$cases
  refused <- Filter(function(c) c$name == "p95_plan_58_verification_refused", cases)[[1]]
  expect_equal(refused$expected$configuration_error, list("COMPLIANCE_INFEASIBLE"))
})

test_that("an explicit p50 requirement at alpha 0.10 is decidable from 4 latencies", {
  v <- latency_compliance_verdict(rep(100, 4), 300, 0.50, 0.10)
  expect_identical(v$y_min, 4L)
  expect_true(v$pass_possible)
  expect_identical(v$verdict, "PASS")
  expect_lt(4, latency_min_samples(0.50))
})
