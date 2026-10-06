test_that("V_latency and V_test follow the structural composite rule", {
  pass <- list(constraint_id = "a", verdict = "PASS")
  fail <- list(constraint_id = "b", verdict = "FAIL")
  inc <- list(constraint_id = "c", verdict = "INCONCLUSIVE")
  crit <- function(v) list(list(criterion_id = "c1", verdict = v))
  expect_identical(test_verdict(crit("PASS"), list(fail))$test_verdict, "FAIL")
  expect_identical(test_verdict(crit("PASS"), list(inc))$test_verdict, "INCONCLUSIVE")
  expect_identical(test_verdict(crit("INCONCLUSIVE"), list(pass))$test_verdict, "INCONCLUSIVE")
  expect_identical(test_verdict(crit("INCONCLUSIVE"), list(fail))$test_verdict, "FAIL")
  expect_identical(test_verdict(crit("PASS"), list(pass, fail))$latency_verdict, "FAIL")
  lo <- test_verdict(list(), list(pass))
  expect_true(is.na(lo$rate_verdict))
  expect_true(is.na(lo$functional_mode))
  expect_identical(lo$latency_mode, "enforced")
  expect_identical(lo$test_verdict, "PASS")
  fo <- test_verdict(crit("FAIL"), list())
  expect_identical(fo$test_verdict, "FAIL")
  expect_true(is.na(fo$latency_verdict))
  expect_true(is.na(fo$latency_mode))
  expect_error(test_verdict(list(), list()))
  t <- test_verdict(crit("PASS"), list(fail))$triggering
  expect_identical(t, list(list(kind = "latency", id = "b")))
})

test_that("every dimension is enforced by default and the switch makes one advisory", {
  fail <- list(constraint_id = "b", verdict = "FAIL")
  crit <- list(list(criterion_id = "c1", verdict = "FAIL"))
  none <- test_verdict(crit, list(fail))
  expect_identical(c(none$functional_mode, none$latency_mode), c("enforced", "enforced"))
  expect_identical(none$test_verdict, "FAIL")
  expect_length(none$triggering, 2L)
  fun <- test_verdict(crit, list(fail), "functional")
  expect_identical(fun$functional_mode, "advisory")
  expect_identical(fun$rate_verdict, "FAIL")
  expect_identical(fun$triggering, list(list(kind = "latency", id = "b")))
  lat <- test_verdict(crit, list(fail), "latency")
  expect_identical(lat$latency_verdict, "FAIL")
  expect_identical(lat$triggering, list(list(kind = "criterion", id = "c1")))
  both <- test_verdict(crit, list(fail), c("functional", "latency"))
  expect_identical(both$test_verdict, "PASS")
  expect_length(both$triggering, 0L)
  expect_identical(c(both$rate_verdict, both$latency_verdict), c("FAIL", "FAIL"))
  # A dimension the test does not carry has no mode, whatever the switch.
  expect_true(is.na(test_verdict(crit, list(), "latency")$latency_mode))
  expect_error(test_verdict(crit, list(fail), "environment"))
  expect_error(test_verdict(crit, list(fail), c("latency", "latency")))
})

test_that("a latency constraint is decided by its rule and carries no mode of its own", {
  k <- latency_constraint_verdict(list(constraint_id = "p95", source = "explicit", percentile = 0.95,
                                       alpha = 0.05, threshold_ms = 500,
                                       latencies = latency_compliance_sample(100, 96, 500)))
  expect_identical(k$decisionRule, "latency/compliance-exact-binomial")
  expect_identical(k$verdict, "FAIL")
  expect_null(k$mode)
})

test_that("the verdict suite carries the mixed test-verdict cases and one case per switch setting", {
  cases <- Filter(function(c) identical(c$approach, "test_verdict"), generate_verdict_cases()$cases)
  get <- function(n) Filter(function(c) c$name == n, cases)[[1]]
  expect_identical(get("test_functional_pass_latency_fail")$expected$test_verdict, "FAIL")
  expect_identical(get("test_functional_pass_latency_inconclusive")$expected$test_verdict, "INCONCLUSIVE")
  expect_identical(get("test_functional_fail_latency_pass")$expected$test_verdict, "FAIL")
  expect_identical(get("test_latency_only")$expected$test_verdict, "PASS")
  settings <- list(none = NULL, functional = "functional", latency = "latency",
                   both = c("functional", "latency"))
  expected <- c(none = "FAIL", functional = "FAIL", latency = "FAIL", both = "PASS")
  for (s in names(settings)) {
    case <- get(paste0("test_switch_", s, "_both_fail"))
    expect_identical(unlist(case$inputs$advisory), settings[[s]], info = s)
    expect_identical(case$expected$rate_verdict, "FAIL", info = s)
    expect_identical(case$expected$latency_verdict, "FAIL", info = s)
    expect_identical(case$expected$test_verdict, expected[[s]], info = s)
  }
  a <- get("test_switch_latency_fail_does_not_fail_test")$expected
  expect_identical(c(a$latency_verdict, a$latency_mode, a$test_verdict), c("FAIL", "advisory", "PASS"))
  i <- get("test_switch_functional_latency_saturated")$expected
  expect_identical(c(i$rate_verdict, i$functional_mode, i$test_verdict), c("FAIL", "advisory", "INCONCLUSIVE"))
})
