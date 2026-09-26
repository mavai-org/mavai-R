test_that("the staircase refuses every out-of-tolerance configuration and the gaps beside them", {
  scan <- data.frame(n_b = c(100, 100, 100, 100, 200, 200, 200, 200),
                     n_t = c(5, 10, 20, 50, 10, 20, 40, 100),
                     out = c(TRUE, TRUE, FALSE, FALSE, TRUE, TRUE, TRUE, FALSE))
  rule <- derive_tolerance_staircase(scan)
  expect_identical(rule$min_baseline_trials, c(1L, 101L))
  expect_identical(rule$ratio_num, c(200L, 500L))
  refused <- function(nb, nt) any(nb >= rule$min_baseline_trials & nt * rule$ratio_den <= rule$ratio_num * nb)
  for (i in which(scan$out)) expect_true(refused(scan$n_b[i], scan$n_t[i]))
  expect_true(refused(150, 29))   # between scanned sizes: carried conservatively
  expect_false(refused(200, 101))
  expect_identical(nrow(derive_tolerance_staircase(transform(scan, out = FALSE))), 0L)
})

test_that("the Fisher benchmark cutoff is the definition", {
  for (cfg in list(c(30, 25, 0.05), c(100, 10, 0.01))) {
    nb <- cfg[1]; nt <- cfg[2]; a <- cfg[3]
    lit <- vapply(0:nb, function(k) {
      p <- vapply(0:nt, function(kt) phyper(kt, k + kt, nb + nt - k - kt, nt), numeric(1))
      as.integer(which(p > a)[1] - 1L)
    }, integer(1))
    expect_identical(fisher_cutoffs(nb, nt, a), lit)
  }
})

test_that("the worst-case scan finds the canonical excess", {
  w <- score_cc_worst_size(1000, 25, 0.01, p_grid = seq(0.95, 0.99, by = 0.0005))
  expect_gt(w$worst_size, 1.2 * 0.01)
  expect_true(w$monotone)
  expect_lt(score_cc_worst_size(100, 100, 0.05, p_grid = seq(0.5, 0.999, by = 0.01))$worst_size,
            1.2 * 0.05)
})

test_that("the committed tolerance rule refuses the scanned excess it was derived from", {
  # A spot check of the certification; scripts/certify.R verifies the full grids.
  expect_true(outside_calibration_tolerance(100, 1, 0.01))      # 1.94 alpha
  expect_true(outside_calibration_tolerance(1000, 12, 0.001))   # 10.07 alpha
  expect_true(outside_calibration_tolerance(950, 309, 0.001))
  expect_false(outside_calibration_tolerance(15, 2, 0.001))
})
