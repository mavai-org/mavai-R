#!/usr/bin/env Rscript
#
# Calibration certification of the Statistical Companion 1.5.0 decision
# rules over the operating envelope. Writes the certification surfaces as
# CSV plus a markdown summary; the release workflow attaches them as a
# separate asset (certification-vX.Y.Z.zip), never inside inst/cases/.
#
# Usage (from the repository root):
#   Rscript scripts/certify.R [--out DIR] [--cores N]
#
#   --out    output directory (default: certification)
#   --cores  worker processes for the regression scan (default: all)
#
# Surfaces:
#   regression_size.csv       worst-case unconditional size of regression/score-cc
#                             over p, per (n_b, n_t, alpha), on the derivation and
#                             verification grids; PASS-set interval and monotonicity
#                             checks; the published tolerance rule's verdict
#   regression_power.csv      exact power at p - delta, and the one-sided Fisher
#                             benchmark at delta 0.05 (benchmark only, never a rule)
#   regression_settling.csv   worst-case size as n_b grows at fixed n_t
#   tolerance_rule.csv        the rule derived from the derivation grid and the
#                             committed rule (R/calibration_rule.R)
#   latency_breach.csv        latency/precedence rank, breach at the rank, saturation
#   compliance_false_compliance.csv  compliance/exact-binomial false compliance
#   compliance_sizing.csv     exact "stays-at" sizing
#   SUMMARY.md                headline numbers
#
# Exits non-zero if the committed tolerance rule fails to refuse any scanned
# configuration whose worst-case size exceeds 1.2 alpha, if a PASS set has a
# hole, or if any rule exceeds its calibration bound where it must not.

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default) {
  i <- match(name, args)
  if (is.na(i)) default else args[i + 1]
}
out_dir <- opt("--out", "certification")
cores <- as.integer(opt("--cores", parallel::detectCores()))
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) source(f)
suppressPackageStartupMessages(library(parallel))
t_start <- proc.time()[["elapsed"]]
say <- function(...) message(sprintf(...))

ALPHAS <- CERTIFIED_ALPHAS
TOL <- CALIBRATION_TOLERANCE_FACTOR

# ---------------------------------------------------------------------------
# Grids. The envelope: n_b 10..10000 (certified range), n_t <= n_b,
# n_t / n_b >= 0.01, alpha in {0.001, 0.01, 0.05, 0.10}, p 0.50..0.9999.
# Every n_t is scanned for n_b <= 50; above that, a ratio grid.
# ---------------------------------------------------------------------------
NB_DERIVE <- c(10, 12, 15, 17, 20, 25, 30, 35, 40, 50, 60, 70, 80, 90, 100, 120,
               140, 160, 180, 200, 250, 300, 350, 400, 500, 600, 700, 800, 900,
               1000, 1200, 1500, 2000, 2500, 3000, 4000, 5000, 6000, 7000, 8000,
               9000, 10000)
RATIO_DERIVE <- c(0.01, 0.0125, 0.015, 0.02, 0.025, 0.03, 0.04, 0.05, 0.06, 0.07,
                  0.08, 0.10, 0.12, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.50, 0.60,
                  0.70, 0.80, 0.90, 1.00)
NB_VERIFY <- c(11, 13, 18, 22, 27, 33, 45, 55, 65, 75, 85, 95, 110, 130, 150, 170,
               190, 225, 275, 325, 375, 450, 550, 650, 750, 850, 950, 1100, 1350,
               1750, 2250, 2750, 3500, 4500, 5500, 6500, 7500, 8500, 9500)
RATIO_VERIFY <- c(0.011, 0.014, 0.017, 0.022, 0.027, 0.035, 0.045, 0.055, 0.065,
                  0.075, 0.09, 0.11, 0.135, 0.175, 0.225, 0.275, 0.325, 0.375,
                  0.45, 0.55, 0.65, 0.75, 0.85, 0.95)

config_grid <- function(nbs, ratios, label) {
  do.call(rbind, lapply(nbs, function(nb) {
    lo <- ceiling(0.01 * nb - 1e-9)
    nt <- if (nb <= 50) seq.int(max(1, lo), nb) else
      unique(pmin(nb, pmax(lo, round(ratios * nb))))
    data.frame(grid = label, n_b = nb, n_t = sort(unique(nt)))
  }))
}
CFG <- rbind(config_grid(NB_DERIVE, RATIO_DERIVE, "derivation"),
             config_grid(NB_VERIFY, RATIO_VERIFY, "verification"))

# ---------------------------------------------------------------------------
# Regression: worst-case unconditional size over p.
# ---------------------------------------------------------------------------
tasks <- merge(CFG, data.frame(alpha = ALPHAS))
tasks <- tasks[order(-(tasks$n_b + tasks$n_t) * tasks$n_b), ]
say("regression: %d configurations x %d alpha = %d scans over %d p values, %d cores",
    nrow(CFG), length(ALPHAS), nrow(tasks), length(CERTIFICATION_P_GRID), cores)
scan_one <- function(i) {
  t <- tasks[i, ]
  w <- score_cc_worst_size(t$n_b, t$n_t, t$alpha, verify_interval = TRUE)
  data.frame(grid = t$grid, n_b = t$n_b, n_t = t$n_t, ratio = t$n_t / t$n_b,
             alpha = t$alpha, worst_size = w$worst_size,
             worst_over_alpha = w$worst_size / t$alpha, at_p = w$at_p,
             p_over_tolerance = w$p_over_tolerance,
             out_of_tolerance = w$worst_size > TOL * t$alpha,
             monotone = w$monotone, interval_verified = TRUE)
}
REG <- do.call(rbind, mclapply(seq_len(nrow(tasks)), scan_one, mc.cores = cores))
REG <- REG[order(REG$grid, REG$alpha, REG$n_b, REG$n_t), ]
REG$refused_by_rule <- mapply(outside_calibration_tolerance, REG$n_b, REG$n_t, REG$alpha)
say("regression scan done (%.0f s)", proc.time()[["elapsed"]] - t_start)

# The rule derived from the derivation grid, and its verification on both grids.
derived <- do.call(rbind, lapply(ALPHAS, function(a) {
  s <- REG[REG$grid == "derivation" & REG$alpha == a, ]
  d <- derive_tolerance_staircase(data.frame(n_b = s$n_b, n_t = s$n_t, out = s$out_of_tolerance))
  if (nrow(d)) cbind(alpha = a, d) else NULL
}))
applies <- function(rule, nb, nt, a) {
  r <- rule[abs(rule$alpha - a) < 1e-12, ]
  any(nb >= r$min_baseline_trials & nt * r$ratio_den <= r$ratio_num * nb)
}
REG$refused_by_derived <- mapply(function(nb, nt, a) applies(derived, nb, nt, a),
                                 REG$n_b, REG$n_t, REG$alpha)
committed_equals_derived <- isTRUE(all.equal(
  derived[, c("alpha", "min_baseline_trials", "ratio_num", "ratio_den")],
  CALIBRATION_TOLERANCE_RULE[, c("alpha", "min_baseline_trials", "ratio_num", "ratio_den")],
  check.attributes = FALSE))
uncovered <- REG[REG$out_of_tolerance & !REG$refused_by_rule, ]
uncovered_derived <- REG[REG$out_of_tolerance & !REG$refused_by_derived, ]
rule_table <- rbind(
  if (!is.null(derived)) cbind(source = "derived", derived) else NULL,
  if (nrow(CALIBRATION_TOLERANCE_RULE)) cbind(source = "committed", CALIBRATION_TOLERANCE_RULE) else NULL)

# ---------------------------------------------------------------------------
# Regression power, and the Fisher benchmark (P2), on the derivation grid.
# ---------------------------------------------------------------------------
P_POWER <- c(0.55, 0.60, 0.70, 0.80, 0.90, 0.95, 0.98, 0.99, 0.995, 0.999)
DELTAS <- c(0.01, 0.02, 0.05, 0.10)
ptasks <- merge(CFG[CFG$grid == "derivation", ], data.frame(alpha = ALPHAS))
ptasks <- ptasks[order(-(ptasks$n_b + ptasks$n_t) * ptasks$n_b), ]
power_one <- function(i) {
  t <- ptasks[i, ]
  cs <- score_cc_cutoffs(t$n_b, t$n_t, t$alpha)
  cf <- fisher_cutoffs(t$n_b, t$n_t, t$alpha)
  do.call(rbind, lapply(P_POWER, function(p) {
    pw <- vapply(DELTAS, function(d) score_cc_fail_probability(cs, t$n_b, t$n_t, p, p - d), 0)
    data.frame(n_b = t$n_b, n_t = t$n_t, alpha = t$alpha, p = p,
               power_d01 = pw[1], power_d02 = pw[2], power_d05 = pw[3], power_d10 = pw[4],
               fisher_power_d05 = score_cc_fail_probability(cf, t$n_b, t$n_t, p, p - 0.05))
  }))
}
POW <- do.call(rbind, mclapply(seq_len(nrow(ptasks)), power_one, mc.cores = cores))
POW <- POW[order(POW$alpha, POW$n_b, POW$n_t, POW$p), ]
POW$fisher_minus_score_d05 <- POW$fisher_power_d05 - POW$power_d05
POW$p2_shortfall <- POW$fisher_minus_score_d05 > 0.05
POW$in_tolerance <- !mapply(outside_calibration_tolerance, POW$n_b, POW$n_t, POW$alpha)
say("regression power done (%.0f s)", proc.time()[["elapsed"]] - t_start)

# Settling: worst-case size as n_b grows at fixed n_t (beyond the certified edge).
SET <- do.call(rbind, mclapply(split(
  merge(expand.grid(n_t = c(25, 100, 1000), n_b = c(1000, 2000, 5000, 10000, 20000, 50000)),
        data.frame(alpha = ALPHAS)), seq_len(3 * 6 * length(ALPHAS))), function(t) {
  w <- score_cc_worst_size(t$n_b, t$n_t, t$alpha)
  data.frame(n_b = t$n_b, n_t = t$n_t, alpha = t$alpha, worst_size = w$worst_size,
             worst_over_alpha = w$worst_size / t$alpha, at_p = w$at_p)
}, mc.cores = cores))
SET <- SET[order(SET$alpha, SET$n_t, SET$n_b), ]

# ---------------------------------------------------------------------------
# Latency: precedence rank and breach.
# ---------------------------------------------------------------------------
LNB <- c(10, 15, 20, 30, 50, 75, 100, 150, 200, 300, 500, 750, 935, 1000, 1500, 2000)
LNT <- c(5, 10, 15, 25, 50, 100, 192, 200, 500, 935, 1000, 2000)
lcfg <- merge(merge(expand.grid(n_b = LNB, n_t = LNT), data.frame(p = c(0.50, 0.90, 0.95, 0.99))),
              data.frame(alpha = ALPHAS))
lcfg <- lcfg[lcfg$n_t <= lcfg$n_b, ]
LAT <- do.call(rbind, mclapply(seq_len(nrow(lcfg)), function(i) {
  t <- lcfg[i, ]
  k <- latency_precedence_rank_fast(t$n_b, t$n_t, t$p, t$alpha)
  br <- if (is.na(k)) NA_real_ else latency_breach_probability(t$n_b, k, t$n_t, t$p)
  br_prev <- if (is.na(k) || k == 1L) NA_real_ else latency_breach_probability(t$n_b, k - 1L, t$n_t, t$p)
  data.frame(n_b = t$n_b, n_t = t$n_t, percentile = round(100 * t$p), alpha = t$alpha,
             test_rank = latency_test_rank(t$n_t, t$p), rank = k, saturated = is.na(k),
             breach_at_rank = br, breach_over_alpha = br / t$alpha,
             breach_at_rank_minus_1 = br_prev)
}, mc.cores = cores))
LAT <- LAT[order(LAT$alpha, LAT$percentile, LAT$n_b, LAT$n_t), ]
say("latency done (%.0f s)", proc.time()[["elapsed"]] - t_start)

# ---------------------------------------------------------------------------
# Compliance: false compliance and exact sizing.
# ---------------------------------------------------------------------------
PREQ <- c(0.50, 0.70, 0.80, 0.90, 0.95, 0.98, 0.99, 0.995, 0.999)
NS <- c(1:200, seq(210, 1000, 10), seq(1100, 5000, 100), seq(5500, 20000, 500))
CMP <- do.call(rbind, lapply(PREQ, function(pr) do.call(rbind, lapply(ALPHAS, function(a) {
  k <- exact_binomial_k_min_vec(NS, pr, a)
  fc <- ifelse(is.na(k), 0, pbinom(k - 1, NS, pr, lower.tail = FALSE))
  data.frame(threshold = pr, alpha = a, n = NS, k_min = k, feasible = !is.na(k),
             false_compliance = fc, false_compliance_over_alpha = fc / a,
             min_feasible_n = exact_binomial_min_feasible_n(pr, a))
}))))
SZ <- do.call(rbind, mclapply(split(merge(merge(data.frame(threshold = PREQ),
                                                 data.frame(delta = c(0.01, 0.02, 0.05, 1))),
                                           data.frame(alpha = ALPHAS)),
                                     seq_len(length(PREQ) * 4 * length(ALPHAS))), function(t) {
  s <- compliance_exact_sizing(t$threshold, t$delta, t$alpha)
  data.frame(threshold = t$threshold, delta = if (t$delta >= 1) NA else t$delta, alpha = t$alpha,
             alternative_kind = s$alternative_kind, alternative_rate = s$alternative_rate,
             first_crossing = s$first_crossing, required_samples = s$required_samples,
             achieved_power = s$achieved_power, n_max = 20000L)
}, mc.cores = cores))
SZ <- unique(SZ[order(SZ$threshold, SZ$alpha, SZ$alternative_rate), ])
say("compliance done (%.0f s)", proc.time()[["elapsed"]] - t_start)

# ---------------------------------------------------------------------------
# Write surfaces and summary.
# ---------------------------------------------------------------------------
w <- function(x, f) write.csv(x, file.path(out_dir, f), row.names = FALSE)
w(REG, "regression_size.csv"); w(POW, "regression_power.csv"); w(SET, "regression_settling.csv")
w(rule_table, "tolerance_rule.csv"); w(LAT, "latency_breach.csv")
w(CMP, "compliance_false_compliance.csv"); w(SZ, "compliance_sizing.csv")

fmt_rule <- function(rule) {
  if (is.null(rule) || !nrow(rule)) return("refuse nothing at any certified alpha")
  paste(vapply(ALPHAS, function(a) {
    r <- rule[abs(rule$alpha - a) < 1e-12, ]
    if (!nrow(r)) return(sprintf("alpha %g: refuse nothing", a))
    sprintf("alpha %g: refuse when %s", a, paste(sprintf("(n_b >= %d and n_t/n_b <= %d/%d)",
            r$min_baseline_trials, r$ratio_num, r$ratio_den), collapse = " or "))
  }, ""), collapse = "; ")
}
by_alpha <- do.call(rbind, lapply(ALPHAS, function(a) {
  s <- REG[REG$alpha == a, ]
  i <- which.max(s$worst_size)
  data.frame(alpha = a, configurations = nrow(s), out_of_tolerance = sum(s$out_of_tolerance),
             refused_by_rule = sum(s$refused_by_rule),
             refused_within_tolerance = sum(s$refused_by_rule & !s$out_of_tolerance),
             max_size_over_alpha = s$worst_over_alpha[i],
             at = sprintf("n_b %d, n_t %d, p %.5f", s$n_b[i], s$n_t[i], s$at_p[i]),
             max_size_over_alpha_admitted = max(s$worst_over_alpha[!s$refused_by_rule]))
}))
md <- function(df) {
  c(paste0("| ", paste(names(df), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
    apply(df, 1, function(r) paste0("| ", paste(trimws(format(r)), collapse = " | "), " |")))
}
p2 <- POW[POW$p2_shortfall, ]
cmp_max <- CMP[which.max(CMP$false_compliance_over_alpha), ]
lat_max <- LAT[which.max(LAT$breach_over_alpha), ]
checks <- c(
  interval = all(REG$interval_verified), monotone = all(REG$monotone),
  rule_covers = nrow(uncovered) == 0, derived_covers = nrow(uncovered_derived) == 0,
  latency_bound = all(LAT$breach_at_rank <= LAT$alpha, na.rm = TRUE) &&
    all(LAT$breach_at_rank_minus_1 > LAT$alpha, na.rm = TRUE),
  compliance_bound = all(CMP$false_compliance <= CMP$alpha))
summary_lines <- c(
  "# Calibration certification, Statistical Companion 1.5.0", "",
  sprintf("mavai-R %s; methodology %s; R %s; %s.", read.dcf("DESCRIPTION")[1, "Version"],
          METHODOLOGY_VERSION, getRversion(), format(Sys.Date())), "",
  "## regression/score-cc", "",
  sprintf(paste0("Worst-case exact unconditional size over %d values of p in [0.50, 0.9999], ",
                 "for %d configurations (n_b 10..10000, n_t <= n_b, n_t/n_b >= 0.01) x %d alpha. ",
                 "Tolerance: 1.2 alpha."), length(CERTIFICATION_P_GRID), nrow(CFG), length(ALPHAS)), "",
  md(transform(by_alpha, max_size_over_alpha = sprintf("%.3f", max_size_over_alpha),
               max_size_over_alpha_admitted = sprintf("%.3f", max_size_over_alpha_admitted))), "",
  sprintf("PASS set an upper interval {c..n_t} for every K_b in every scanned configuration: %s.",
          checks[["interval"]]),
  sprintf("Cutoff non-decreasing in K_b in every scanned configuration: %s.", checks[["monotone"]]), "",
  "### Calibration-tolerance rule (OUTSIDE_CALIBRATION_TOLERANCE)", "",
  sprintf("Committed rule: %s.", fmt_rule(CALIBRATION_TOLERANCE_RULE)),
  sprintf("Rule derived from the derivation grid: %s.", fmt_rule(derived)),
  sprintf("Committed rule equals the derived rule: %s.", committed_equals_derived),
  sprintf(paste0("Verification: out-of-tolerance configurations on both grids: %d; refused by ",
                 "the committed rule: %d; not refused: %d."),
          sum(REG$out_of_tolerance), sum(REG$out_of_tolerance & REG$refused_by_rule), nrow(uncovered)), "",
  "### Settling at fixed n_t as n_b grows", "",
  md(transform(SET, worst_over_alpha = sprintf("%.3f", worst_over_alpha),
               worst_size = sprintf("%.6f", worst_size))), "",
  "### Power against the Fisher benchmark (checked here only)", "",
  sprintf(paste0("Cells (n_b, n_t, alpha, p) on the derivation grid: %d. Score-cc power at p - 0.05 ",
                 "above Fisher's: %d; below: %d; more than 0.05 below (the disclosed shortfall): %d ",
                 "(%d of them in configurations the tolerance rule admits)."),
          nrow(POW), sum(POW$fisher_minus_score_d05 < -1e-12), sum(POW$fisher_minus_score_d05 > 1e-12),
          nrow(p2), sum(p2$in_tolerance)), "",
  if (nrow(p2)) md(transform(p2[, c("n_b", "n_t", "alpha", "p", "power_d05", "fisher_power_d05",
                                    "fisher_minus_score_d05", "in_tolerance")],
                             power_d05 = sprintf("%.4f", power_d05),
                             fisher_power_d05 = sprintf("%.4f", fisher_power_d05),
                             fisher_minus_score_d05 = sprintf("%.4f", fisher_minus_score_d05))) else "None.",
  "", "## latency/precedence", "",
  sprintf(paste0("%d cells (n_b 10..2000, n_t <= n_b, p50/p90/p95/p99, 4 alpha). Saturated ",
                 "(INCONCLUSIVE): %d. Largest breach at the chosen rank: %.6f alpha (n_b %d, n_t %d, ",
                 "p%d, alpha %g). Breach <= alpha at every rank and > alpha one rank below: %s."),
          nrow(LAT), sum(LAT$saturated), lat_max$breach_over_alpha, lat_max$n_b, lat_max$n_t,
          lat_max$percentile, lat_max$alpha, checks[["latency_bound"]]),
  "", "## compliance/exact-binomial", "",
  sprintf(paste0("%d cells (9 requirements x %d sizes up to 20000 x 4 alpha). Largest false ",
                 "compliance: %.6f alpha (p_req %g, n %d, alpha %g). False compliance <= alpha ",
                 "everywhere: %s."), nrow(CMP), length(NS), cmp_max$false_compliance_over_alpha,
          cmp_max$threshold, cmp_max$n, cmp_max$alpha, checks[["compliance_bound"]]), "",
  "Exact sizing (power 0.80, searched to n = 20000; NA = not settled within the horizon):", "",
  md(transform(SZ, achieved_power = sprintf("%.4f", achieved_power),
               alternative_rate = sprintf("%.4f", alternative_rate))), "",
  "## Checks", "",
  md(data.frame(check = names(checks), passed = unname(checks))), "",
  sprintf("Elapsed: %.0f s on %d cores.", proc.time()[["elapsed"]] - t_start, cores))
writeLines(summary_lines, file.path(out_dir, "SUMMARY.md"))
say("wrote %s", out_dir)
if (!all(checks[c("interval", "monotone", "rule_covers", "latency_bound", "compliance_bound")])) {
  message("CERTIFICATION FAILED: ", paste(names(checks)[!checks], collapse = ", "))
  quit(status = 1)
}
