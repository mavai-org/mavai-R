make_criteria <- function(...) list(...)
inf <- function(id, procedure, alpha, verdict) {
  list(criterion_id = id, mode = "inferential",
       procedure = procedure, alpha = alpha, verdict = verdict)
}
obs <- function(id, verdict) {
  list(criterion_id = id, mode = "observational",
       procedure = NA, alpha = NA, verdict = verdict)
}

test_that("All PASS yields composite PASS", {
  result <- composite_verdict(make_criteria(
    inf("a", "REGRESSION", 0.05, "PASS"),
    inf("b", "COMPLIANCE", 0.001, "PASS")
  ))
  expect_equal(result$composite_verdict, "PASS")
  expect_length(result$triggering_criteria, 0)
})

test_that("Any FAIL yields composite FAIL", {
  result <- composite_verdict(make_criteria(
    inf("a", "REGRESSION", 0.05, "PASS"),
    inf("b", "COMPLIANCE", 0.001, "FAIL")
  ))
  expect_equal(result$composite_verdict, "FAIL")
  expect_equal(result$triggering_criteria, list("b"))
})

test_that("Mix of PASS and INCONCLUSIVE yields INCONCLUSIVE", {
  result <- composite_verdict(make_criteria(
    inf("a", "REGRESSION", 0.05, "PASS"),
    inf("b", "COMPLIANCE", 0.001, "INCONCLUSIVE")
  ))
  expect_equal(result$composite_verdict, "INCONCLUSIVE")
  expect_equal(result$triggering_criteria, list("b"))
})

test_that("Envelope sums separately by procedure direction", {
  result <- composite_verdict(make_criteria(
    inf("r1", "REGRESSION", 0.05, "PASS"),
    inf("r2", "REGRESSION", 0.05, "PASS"),
    inf("c1", "COMPLIANCE", 0.001, "PASS"),
    inf("c2", "COMPLIANCE", 0.01,  "PASS")
  ))
  expect_equal(result$false_degradation_signal_envelope, 0.10)
  expect_equal(result$false_compliance_envelope, 0.011)
})

test_that("Observational criteria contribute to neither envelope", {
  result <- composite_verdict(make_criteria(
    inf("r1", "REGRESSION", 0.05, "PASS"),
    obs("o1",                     "PASS"),
    obs("o2",                     "PASS")
  ))
  expect_equal(result$false_degradation_signal_envelope, 0.05)
  expect_true(is.na(result$false_compliance_envelope))
})

test_that("Missing procedure direction emits NA for that envelope", {
  result <- composite_verdict(make_criteria(
    inf("r1", "REGRESSION", 0.05, "PASS")
  ))
  expect_equal(result$false_degradation_signal_envelope, 0.05)
  expect_true(is.na(result$false_compliance_envelope))
})

test_that("Observational-only contract emits neither envelope", {
  result <- composite_verdict(make_criteria(
    obs("o1", "PASS"),
    obs("o2", "PASS")
  ))
  expect_true(is.na(result$false_compliance_envelope))
  expect_true(is.na(result$false_degradation_signal_envelope))
})

test_that("Generator output matches committed fixture", {
  fixture <- jsonlite::fromJSON("../../inst/cases/composite_verdict.json",
                                simplifyVector = FALSE)
  generated <- generate_composite_verdict_cases()
  expect_equal(length(fixture$cases), length(generated$cases))
  for (i in seq_along(fixture$cases)) {
    expect_equal(fixture$cases[[i]]$expected$composite_verdict,
                 generated$cases[[i]]$expected$composite_verdict,
                 info = generated$cases[[i]]$name)
  }
})

test_that("A criterion decided by a SMOKE rule enters neither envelope", {
  smoke <- function(id, rule, alpha, verdict) {
    c(inf(id, "COMPLIANCE", alpha, verdict), list(decision_rule = rule))
  }
  result <- composite_verdict(make_criteria(
    inf("verified", "COMPLIANCE", 0.01, "PASS"),
    smoke("rate", "compliance/smoke-exact-binomial", 0.05, "PASS"),
    smoke("p95", "latency/smoke-compliance-exact-binomial", 0.05, "PASS"),
    smoke("named", "compliance/exact-binomial", 0.001, "PASS")
  ))
  expect_equal(result$false_compliance_envelope, 0.011)
  expect_true(is.na(result$false_degradation_signal_envelope))

  only_smoke <- composite_verdict(make_criteria(
    smoke("rate", "compliance/smoke-exact-binomial", 0.05, "FAIL")
  ))
  expect_equal(only_smoke$composite_verdict, "FAIL")
  expect_true(is.na(only_smoke$false_compliance_envelope))
})
