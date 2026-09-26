#' The calibration-tolerance rule of regression/score-cc
#'
#' `OUTSIDE_CALIBRATION_TOLERANCE` refuses an empirical configuration
#' (n_b, n_t, alpha) whose worst-case unconditional size under
#' regression/score-cc, over the unknown success probability p, exceeds
#' 1.2 alpha. Rather than have every framework maximise the size over p at
#' resolution time, mavai-R computes the refused region once, on a fine
#' grid, and publishes it as a conservative rule per certified alpha:
#' refuse iff, for some row of that alpha,
#'
#'     n_b >= min_baseline_trials  and  n_t * ratio_den <= ratio_num * n_b
#'
#' (integer arithmetic, so no framework rounds a ratio differently).
#'
#' Derivation (`scripts/certify.R`, which re-derives the rule and fails if
#' this committed copy stops covering the scan): the exact unconditional
#' size A(p) = sum_k P_p(K_b = k) P_p(K_t < c(k)) is evaluated at 1179
#' values of p (step 0.0005 on [0.50, 0.99], 0.00005 on (0.99, 0.9999]) for
#' every configuration of the derivation grid — 42 baseline sizes from 10
#' to 10000, every n_t for n_b <= 50 and 25 ratios n_t/n_b from 0.01 to 1
#' above — at each certified alpha. A configuration is out of tolerance
#' when its largest A exceeds 1.2 alpha. Per scanned n_b, the ratio bound
#' is the smallest scanned in-tolerance ratio above every out-of-tolerance
#' ratio (so the unscanned gap is refused); each row applies from just
#' above the previous scanned n_b (so unscanned baseline sizes below it
#' are refused); bounds are carried forward to all larger n_b; ratios are
#' rounded up to thousandths. The rule is then verified on the derivation
#' grid and on an interleaved verification grid of 39 further baseline
#' sizes and 24 further ratios: every out-of-tolerance configuration on
#' either grid is refused.
#'
#' The rule is published for the certified alphas only (0.001, 0.01, 0.05,
#' 0.10); it refuses nothing at 0.05 and 0.10.

CALIBRATION_TOLERANCE_RULE <- data.frame(
  alpha = c(0.001, 0.001, 0.001, 0.001, 0.001, 0.01),
  min_baseline_trials = c(16L, 41L, 51L, 61L, 91L, 21L),
  ratio_num = c(177L, 220L, 250L, 258L, 350L, 80L),
  ratio_den = c(1000L, 1000L, 1000L, 1000L, 1000L, 1000L)
)

#' @keywords internal
tolerance_rule_case <- function(alpha) {
  rows <- CALIBRATION_TOLERANCE_RULE[abs(CALIBRATION_TOLERANCE_RULE$alpha - alpha) < 1e-12, ]
  list(
    name = sprintf("rule_alpha_%s", format(alpha, scientific = FALSE)),
    approach = "rule",
    inputs = list(alpha = alpha),
    expected = list(refuse_when = lapply(seq_len(nrow(rows)), function(i) {
      list(min_baseline_trials = rows$min_baseline_trials[i],
           max_ratio_numerator = rows$ratio_num[i],
           max_ratio_denominator = rows$ratio_den[i])
    }))
  )
}

#' @keywords internal
tolerance_application_case <- function(name, n_b, n_t, alpha, description = NULL) {
  case <- list(name = name, approach = "application")
  if (!is.null(description)) case$description <- description
  err <- if (outside_calibration_tolerance(n_b, n_t, alpha)) "OUTSIDE_CALIBRATION_TOLERANCE" else
    NA_character_
  c(case, list(
    inputs = list(baseline_trials = as.integer(n_b), test_samples = as.integer(n_t), alpha = alpha),
    expected = list(configuration_error = err)
  ))
}

#' Generate the calibration-tolerance rule suite
#'
#' @return A list suitable for JSON serialisation.
#' @export
generate_calibration_tolerance_rule_cases <- function() {
  app <- tolerance_application_case
  cases <- c(
    lapply(CERTIFIED_ALPHAS, tolerance_rule_case),
    list(
      app("canonical_refused_1000_25_a01", 1000, 25, 0.01,
          "The canonical refusal: worst-case size above 1.3% against a tolerance of 1.2%."),
      app("admitted_1000_1000_a01", 1000, 1000, 0.01),
      app("admitted_1000_25_a05", 1000, 25, 0.05, "Nothing is refused at alpha 0.05."),
      app("admitted_10000_100_a10", 10000, 100, 0.10, "Nothing is refused at alpha 0.10."),
      app("boundary_a01_at_ratio_bound_1000_80", 1000, 80, 0.01, "n_t / n_b = 80/1000 exactly: refused."),
      app("boundary_a01_above_ratio_bound_1000_81", 1000, 81, 0.01),
      app("boundary_a01_below_min_baseline_20_1", 20, 1, 0.01),
      app("boundary_a01_at_min_baseline_21_1", 21, 1, 0.01),
      app("boundary_a001_at_ratio_bound_1000_350", 1000, 350, 0.001),
      app("boundary_a001_above_ratio_bound_1000_351", 1000, 351, 0.001),
      app("boundary_a001_below_min_baseline_15_2", 15, 2, 0.001),
      app("boundary_a001_first_row_16_2", 16, 2, 0.001),
      app("boundary_a001_second_row_41_9", 41, 9, 0.001),
      app("admitted_a001_40_9", 40, 9, 0.001, "Above the first row's ratio bound, below the second row's baseline size."),
      app("refused_a001_10000_100", 10000, 100, 0.001),
      app("beyond_certified_edge_20000_100_a01", 20000, 100, 0.01,
          "Larger baselines are accepted; the rule's rows extend to them.")
    )
  )

  list(
    suite = "calibration_tolerance_rule",
    description = paste(
      "The published rule for OUTSIDE_CALIBRATION_TOLERANCE, as data frameworks apply instead of",
      "maximising the size over p at resolution time. Cases with approach 'rule' carry, per",
      "certified alpha (0.001, 0.01, 0.05, 0.10), the rows of the rule: refuse an empirical",
      "configuration with n_t <= n_b iff, for some row, n_b >= min_baseline_trials and",
      "n_t * max_ratio_denominator <= max_ratio_numerator * n_b (integer arithmetic). Cases with",
      "approach 'application' apply it. Derivation: the exact unconditional size of",
      "regression/score-cc, sum_k P_p(K_b = k) P_p(K_t < c(k)), was evaluated at 1179 values of",
      "p in [0.50, 0.9999] for every configuration of a derivation grid (42 baseline sizes from 10",
      "to 10000; every n_t for n_b <= 50, 25 ratios n_t/n_b from 0.01 to 1 above); a",
      "configuration whose largest size exceeds 1.2 alpha is out of tolerance. Per scanned n_b the",
      "ratio bound is the smallest scanned in-tolerance ratio above every out-of-tolerance ratio;",
      "each row applies from just above the previous scanned n_b; bounds carry forward to larger",
      "n_b; ratios round up to thousandths. Verified on the derivation grid and on an interleaved",
      "verification grid (39 further baseline sizes, 24 further ratios): every out-of-tolerance",
      "configuration is refused. The rule is defined at the certified alphas only; it refuses",
      "nothing at 0.05 and 0.10. The certification surfaces behind it are published as a separate",
      "release asset."
    ),
    method = paste(
      "Rule rows derived from the certification scan (scripts/certify.R) and applied with integer",
      "arithmetic: OUTSIDE_CALIBRATION_TOLERANCE iff exists row: n_b >= min_baseline_trials and",
      "n_t * max_ratio_denominator <= max_ratio_numerator * n_b."
    ),
    tolerance = 0,
    cases = cases
  )
}
