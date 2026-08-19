test_that("Wilson CI produces valid intervals", {
  result <- wilson_ci(50, 100, 0.95)

  expect_true(result$lower >= 0)
  expect_true(result$upper <= 1)
  expect_true(result$lower < result$point)
  expect_true(result$upper > result$point)
  expect_equal(result$point, 0.50)
})

test_that("Wilson CI narrows with larger samples", {
  small <- wilson_ci(50, 100, 0.95)
  large <- wilson_ci(500, 1000, 0.95)

  width_small <- small$upper - small$lower
  width_large <- large$upper - large$lower

  expect_true(width_large < width_small)
})

test_that("Wilson CI widens with higher confidence", {
  ci_90 <- wilson_ci(50, 100, 0.90)
  ci_95 <- wilson_ci(50, 100, 0.95)
  ci_99 <- wilson_ci(50, 100, 0.99)

  width_90 <- ci_90$upper - ci_90$lower
  width_95 <- ci_95$upper - ci_95$lower
  width_99 <- ci_99$upper - ci_99$lower

  expect_true(width_90 < width_95)
  expect_true(width_95 < width_99)
})

test_that("Wilson CI handles boundary p_hat = 0", {
  result <- wilson_ci(0, 100, 0.95)

  expect_equal(result$point, 0)
  expect_true(result$lower >= 0)
  expect_true(result$upper > 0)
})

test_that("Wilson CI handles boundary p_hat = 1", {
  result <- wilson_ci(100, 100, 0.95)

  expect_equal(result$point, 1)
  expect_true(result$upper <= 1)
  expect_true(result$lower < 1)
})

test_that("Wilson lower bound is below two-sided lower bound", {
  # One-sided lower bound uses a larger z (less split), so it should be
  # higher than the two-sided lower bound at the same confidence level.
  # Wait — one-sided uses z_alpha (not z_alpha/2), which is *smaller*,
  # so the one-sided lower bound should be *higher* (less conservative).
  ci <- wilson_ci(95, 100, 0.95)
  lb <- wilson_lower(95, 100, 0.95)

  expect_true(lb > ci$lower)
  expect_true(lb < ci$point)
})

test_that("Wilson lower bound handles boundary p_hat = 0", {
  result <- wilson_lower(0, 100, 0.95)

  expect_true(result >= 0)
  expect_true(result < 0.05)  # should be very small
})

test_that("Wilson lower bound handles boundary p_hat = 1", {
  result <- wilson_lower(100, 100, 0.95)

  expect_true(result < 1)
  expect_true(result > 0.9)  # should be close to 1
})

test_that("Wilson lower bound handles single trial extremes", {
  # Single failure: lower bound should be 0 or very near 0
  lb_fail <- wilson_lower(0, 1, 0.95)
  expect_true(lb_fail >= 0)

  # Single success: lower bound should be positive but well below 1
  lb_pass <- wilson_lower(1, 1, 0.95)
  expect_true(lb_pass > 0)
  expect_true(lb_pass < 1)
})

test_that("Wilson lower bound decreases with higher confidence", {
  lb_90 <- wilson_lower(95, 100, 0.90)
  lb_95 <- wilson_lower(95, 100, 0.95)
  lb_99 <- wilson_lower(95, 100, 0.99)

  expect_true(lb_90 > lb_95)
  expect_true(lb_95 > lb_99)
})

test_that("wilson_lower_from_rate matches wilson_lower for integer (k, n)", {
  # The discrete entry point is a thin wrapper over the continuous one;
  # they must agree exactly when p_hat = k / n.
  expect_equal(
    wilson_lower_from_rate(95 / 100, 100, 0.95),
    wilson_lower(95, 100, 0.95))
  expect_equal(
    wilson_lower_from_rate(0,   100, 0.95),
    wilson_lower(0,   100, 0.95))
  expect_equal(
    wilson_lower_from_rate(1,   100, 0.95),
    wilson_lower(100, 100, 0.95))
})

test_that("wilson_lower_from_rate accepts continuous p_hat", {
  # Threshold-derivation feeds non-rational rates back into the formula
  # (e.g. an effective baseline rate p_0 derived from another Wilson
  # computation). The continuous form must accept these without rounding.
  result <- wilson_lower_from_rate(0.9973, 100, 0.95)
  expect_true(result < 0.9973)
  expect_true(result > 0.9)
})

test_that("a zero rate gives exactly zero, not a cancellation residue", {
  # Companion §4.3.4: at p_hat = 0 the leading term z^2/(2n) and the
  # radical are the same quantity, so the bound is exactly 0 — an
  # algebraic identity holding at every n and every confidence, not a
  # small number. `expect_identical` rather than `expect_equal`: a
  # tolerance-based comparison is precisely what fails to see this.
  # A dense sweep, not a handful of round numbers: the round ones mostly
  # cancel cleanly on their own, which is how this went unseen.
  for (n in 1:1000) {
    for (conf in c(0.90, 0.95, 0.99)) {
      expect_identical(wilson_lower_from_rate(0, n, conf), 0,
                       info = paste("n =", n, "confidence =", conf))
    }
  }
})

test_that("a zero rate leaves the integer cutoff at zero", {
  # Why the identity above is worth a test of its own. The binding
  # decision artefact is ceiling(n_test * threshold), so a residue of any
  # size at all — n = 50 and n = 200 at one-sided 95% each left one near
  # 1e-18 — raises the cutoff from 0 to 1 and demands a success of a test
  # that the evidence says can demand nothing. The threshold comparison
  # would not have caught it at any sane tolerance; the cutoff does.
  # Against the previous body this fails at 265 sizes at 90%, 201 at 95%
  # and 121 at 99% — roughly one test size in five, not a rare quirk.
  for (n_test in 1:1000) {
    for (conf in c(0.90, 0.95, 0.99)) {
      expect_identical(
        ceiling(n_test * wilson_lower_from_rate(0, n_test, conf)), 0,
        info = paste("n_test =", n_test, "confidence =", conf))
    }
  }
})
