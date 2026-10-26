test_that("Generator emits the expected six baseline cases", {
  result <- generate_baseline_object_cases()
  expect_equal(result$suite, "baseline_object")
  expect_equal(length(result$cases), 6)
  names <- vapply(result$cases, function(c) c$name, character(1))
  expect_true("consult_advice_eu_weekday" %in% names)
  expect_true("consult_advice_readability_eu_weekday" %in% names)
  expect_true("consult_advice_self_harm_probe_eu_weekday" %in% names)
})

test_that("Every baseline is one sampling: all its criteria share one n", {
  result <- generate_baseline_object_cases()
  for (case in result$cases) {
    n <- vapply(case$inputs$baseline$criteria,
                function(c) c$observation$n_attempted, integer(1))
    expect_length(unique(n), 1)
  }
  get <- function(n) Filter(function(c) c$name == n, result$cases)[[1]]
  ids <- function(case) vapply(case$inputs$baseline$criteria,
                               function(c) c$criterion_id, character(1))
  expect_identical(ids(get("consult_advice_eu_weekday")), "c_well_formed")
  expect_identical(ids(get("consult_advice_readability_eu_weekday")), "c_layperson_readable")
  expect_identical(ids(get("consult_advice_self_harm_probe_eu_weekday")), "c_no_self_harm")
})

test_that("No criterion carries a denominator policy or an availability reference", {
  result <- generate_baseline_object_cases()
  for (case in result$cases) {
    for (crit in case$inputs$baseline$criteria) {
      expect_null(crit$denominator_policy, info = paste(case$name, crit$criterion_id))
      expect_null(crit$availability_criterion_ref, info = paste(case$name, crit$criterion_id))
    }
  }
})

test_that("Every observation block's n_c is the number of trials (§1.4.5a)", {
  result <- generate_baseline_object_cases()
  for (case in result$cases) {
    for (crit in case$inputs$baseline$criteria) {
      o <- crit$observation
      expect_equal(o$n_c, o$n_attempted, info = paste(case$name, crit$criterion_id))
    }
  }
})

test_that("Generator output matches committed fixture", {
  fixture <- jsonlite::fromJSON("../../inst/cases/baseline_object.json",
                                simplifyVector = FALSE)
  generated <- generate_baseline_object_cases()
  expect_equal(length(fixture$cases), length(generated$cases))
  for (i in seq_along(fixture$cases)) {
    expect_equal(fixture$cases[[i]]$name, generated$cases[[i]]$name)
  }
})
