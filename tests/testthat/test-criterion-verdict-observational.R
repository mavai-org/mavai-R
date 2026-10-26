test_that("Observational PASS at zero failures, full evaluability", {
  result <- observational_verdict(200, 200, 200)
  expect_equal(result$n_c, 200L)
  expect_equal(result$r_obs, 1)
  expect_equal(result$verdict, "PASS")
})

test_that("Observational FAIL on a single observed failure", {
  result <- observational_verdict(1000, 1000, 999)
  expect_equal(result$verdict, "FAIL")
})

test_that("Observational INCONCLUSIVE at zero trials", {
  result <- observational_verdict(0, 0, 0)
  expect_equal(result$verdict, "INCONCLUSIVE")
})

test_that("Trials with no testable value count as FAILs (§1.4.5a)", {
  # 1000 attempted, 950 produced a testable value, all 950 PASSed
  result <- observational_verdict(1000, 950, 950)
  expect_equal(result$n_c, 1000L)
  expect_equal(result$verdict, "FAIL")
  expect_equal(result$r_obs, 0.95)
})

test_that("Generator emits the expected suite shape", {
  result <- generate_criterion_verdict_observational_cases()
  expect_equal(result$suite, "criterion_verdict_observational")
  expect_equal(result$tolerance, 0)
  expect_true(length(result$cases) >= 5)
})

test_that("Generator output matches the committed fixture", {
  fixture <- jsonlite::fromJSON(
    "../../inst/cases/criterion_verdict_observational.json",
    simplifyVector = FALSE)
  generated <- generate_criterion_verdict_observational_cases()
  expect_equal(length(fixture$cases), length(generated$cases))
  for (i in seq_along(fixture$cases)) {
    expect_equal(fixture$cases[[i]]$expected$verdict,
                 generated$cases[[i]]$expected$verdict,
                 info = generated$cases[[i]]$name)
    expect_equal(fixture$cases[[i]]$expected$n_c,
                 generated$cases[[i]]$expected$n_c,
                 info = generated$cases[[i]]$name)
  }
})
