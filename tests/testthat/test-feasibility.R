test_that("feasibility is the exact test's all-success condition", {
  for (pr in c(0.5, 0.9, 0.95, 0.99, 0.995, 0.999)) for (a in c(0.001, 0.01, 0.05, 0.10)) {
    r <- check_feasibility(pr, 10, a)
    n <- r$minimum_samples
    expect_lte(pr^n, a + 1e-15)
    expect_gt(pr^(n - 1), a)
    expect_identical(n, as.integer(ceiling(log(a) / log(pr))))
    expect_identical(r$criterion, "exact_binomial_pass_possible")
  }
})

test_that("the canonical feasibility minimums are reproduced", {
  expect_identical(check_feasibility(0.995, 477, 0.05)$minimum_samples, 598L)
  expect_false(check_feasibility(0.995, 477, 0.05)$feasible)
  expect_identical(check_feasibility(0.999, 2995, 0.05)$minimum_samples, 2995L)
  expect_true(check_feasibility(0.999, 2995, 0.05)$feasible)
  expect_false(check_feasibility(0.999, 2994, 0.05)$feasible)
  expect_identical(check_feasibility(0.95, 150, 0.05)$minimum_samples, 59L)
  expect_identical(check_feasibility(0.99, 793, 0.05)$minimum_samples, 299L)
})

test_that("zero samples are never feasible", {
  expect_false(check_feasibility(0.90, 0, 0.05)$feasible)
})

test_that("a higher requirement or a smaller alpha requires more samples", {
  expect_gt(check_feasibility(0.99, 1, 0.05)$minimum_samples, check_feasibility(0.95, 1, 0.05)$minimum_samples)
  expect_gt(check_feasibility(0.95, 1, 0.01)$minimum_samples, check_feasibility(0.95, 1, 0.05)$minimum_samples)
})
