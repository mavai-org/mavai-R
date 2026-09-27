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
#   --cores  worker processes (default: all)
#
# Surfaces:
#   regression_size.csv       largest exact unconditional size of regression/fisher at the
#                             points of the p grid, per (n_b, n_t, alpha), on two
#                             interleaved grids (the guarantee at every p is the theorem's)
#   regression_beyond.csv     the same beyond the certified range (n_b 20,000-100,000,
#                             n_t 1-100)
#   regression_settling.csv   the largest size on the p grid as n_b grows at fixed n_t
#   regression_power.csv      exact power of regression/fisher at p - delta, and the
#                             beta-binomial predictive rule's power at delta 0.05 beside it
#                             (a comparison disclosing the rule's conservatism, never a rule)
#   latency_breach.csv        latency/precedence rank, breach at the rank, saturation
#   compliance_false_compliance.csv  compliance/exact-binomial false compliance
#   compliance_sizing.csv     exact "stays-at" sizing
#   SUMMARY.md                headline numbers
#
# Exits non-zero if any rule exceeds its calibration bound (alpha) anywhere
# it is scanned, or if a cutoff is not monotone in the baseline count.
# Sizes are compared with alpha allowing a relative 1e-12 for floating-point
# summation; the decision rules themselves apply the exact-boundary
# convention of R/exact_boundary.R.

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

# Run f over X on the worker cores and bind the rows. A worker that fails
# returns a try-error; stop with its message rather than letting rbind fail
# later with an unrelated one.
par_rbind <- function(X, f) {
  res <- mclapply(X, f, mc.cores = cores)
  bad <- vapply(res, function(r) inherits(r, "try-error"), logical(1))
  if (any(bad)) {
    stop("certification worker failed: ", conditionMessage(attr(res[[which(bad)[1]]], "condition")),
         call. = FALSE)
  }
  do.call(rbind, res)
}
t_start <- proc.time()[["elapsed"]]
say <- function(...) message(sprintf(...))
within_alpha <- function(x, a) x <= a * (1 + 1e-12)

ALPHAS <- CERTIFIED_ALPHAS

# ---------------------------------------------------------------------------
# Grids. The envelope: n_b 10..10000 (certified range), n_t <= n_b,
# n_t / n_b >= 0.01, alpha in {0.001, 0.01, 0.05, 0.10}, p 0.50..0.99999.
# Every n_t is scanned for n_b <= 50; above that, a ratio grid.
# ---------------------------------------------------------------------------
NB_A <- c(10, 12, 15, 17, 20, 25, 30, 35, 40, 50, 60, 70, 80, 90, 100, 120,
          140, 160, 180, 200, 250, 300, 350, 400, 500, 600, 700, 800, 900,
          1000, 1200, 1500, 2000, 2500, 3000, 4000, 5000, 6000, 7000, 8000,
          9000, 10000)
RATIO_A <- c(0.01, 0.0125, 0.015, 0.02, 0.025, 0.03, 0.04, 0.05, 0.06, 0.07,
             0.08, 0.10, 0.12, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.50, 0.60,
             0.70, 0.80, 0.90, 1.00)
NB_B <- c(11, 13, 18, 22, 27, 33, 45, 55, 65, 75, 85, 95, 110, 130, 150, 170,
          190, 225, 275, 325, 375, 450, 550, 650, 750, 850, 950, 1100, 1350,
          1750, 2250, 2750, 3500, 4500, 5500, 6500, 7500, 8500, 9500)
RATIO_B <- c(0.011, 0.014, 0.017, 0.022, 0.027, 0.035, 0.045, 0.055, 0.065,
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
CFG <- rbind(config_grid(NB_A, RATIO_A, "A"), config_grid(NB_B, RATIO_B, "B"))

scan <- function(cfg) {
  tasks <- merge(cfg, data.frame(alpha = ALPHAS))
  tasks <- tasks[order(-(tasks$n_b + tasks$n_t) * tasks$n_b), ]
  out <- par_rbind(seq_len(nrow(tasks)), function(i) {
    t <- tasks[i, ]
    w <- fisher_worst_size(t$n_b, t$n_t, t$alpha)
    cbind(t, data.frame(worst_size = w$worst_size, worst_over_alpha = w$worst_size / t$alpha,
                        at_p = w$at_p, p_over_alpha = w$p_over_alpha,
                        within_alpha = within_alpha(w$worst_size, t$alpha), monotone = w$monotone))
  })
  out[order(out$alpha, out$n_b, out$n_t), ]
}

# ---------------------------------------------------------------------------
# Regression: the largest unconditional size on the p grid, in and beyond the range.
# ---------------------------------------------------------------------------
say("regression: %d configurations x %d alpha over %d p values, %d cores",
    nrow(CFG), length(ALPHAS), length(CERTIFICATION_P_GRID), cores)
REG <- scan(CFG)
say("regression scan done (%.0f s)", proc.time()[["elapsed"]] - t_start)
BEY <- scan(merge(data.frame(grid = "beyond", n_b = c(20000, 50000, 100000)),
                  data.frame(n_t = c(1, 5, 12, 25, 100))))
SET <- scan(merge(data.frame(grid = "settling", n_t = c(25, 100, 1000)),
                  data.frame(n_b = c(1000, 2000, 5000, 10000, 20000, 50000))))
say("beyond-range and settling done (%.0f s)", proc.time()[["elapsed"]] - t_start)

# ---------------------------------------------------------------------------
# Power of regression/fisher, and the beta-binomial predictive rule beside it
# (comparison only), on grid A. The predictive cutoffs cost O(n_b n_t), so the
# comparison covers configurations with (n_b + 1)(n_t + 1) <= 4e6.
# ---------------------------------------------------------------------------
P_POWER <- c(0.55, 0.60, 0.70, 0.80, 0.90, 0.95, 0.98, 0.99, 0.995, 0.999)
DELTAS <- c(0.01, 0.02, 0.05, 0.10)
ptasks <- merge(CFG[CFG$grid == "A", ], data.frame(alpha = ALPHAS))
ptasks <- ptasks[order(-(ptasks$n_b + ptasks$n_t) * ptasks$n_b), ]
POW <- par_rbind(seq_len(nrow(ptasks)), function(i) {
  t <- ptasks[i, ]
  cf <- fisher_cutoffs(t$n_b, t$n_t, t$alpha)
  compare <- (t$n_b + 1) * (t$n_t + 1) <= 4e6
  cb <- if (compare) bbpred_cutoffs(t$n_b, t$n_t, t$alpha) else NULL
  do.call(rbind, lapply(P_POWER, function(p) {
    pw <- vapply(DELTAS, function(d) regression_fail_probability(cf, t$n_b, t$n_t, p, p - d), 0)
    data.frame(n_b = t$n_b, n_t = t$n_t, alpha = t$alpha, p = p,
               power_d01 = pw[1], power_d02 = pw[2], power_d05 = pw[3], power_d10 = pw[4],
               bbpred_power_d05 = if (compare) regression_fail_probability(cb, t$n_b, t$n_t, p, p - 0.05) else NA,
               bbpred_size = if (compare) regression_fail_probability(cb, t$n_b, t$n_t, p, p) else NA)
  }))
})
POW <- POW[order(POW$alpha, POW$n_b, POW$n_t, POW$p), ]
POW$bbpred_minus_fisher_d05 <- POW$bbpred_power_d05 - POW$power_d05
say("regression power done (%.0f s)", proc.time()[["elapsed"]] - t_start)

# ---------------------------------------------------------------------------
# Latency: precedence rank and breach.
# ---------------------------------------------------------------------------
LNB <- c(10, 15, 20, 30, 50, 75, 100, 150, 200, 300, 500, 750, 935, 1000, 1500, 2000)
LNT <- c(5, 10, 15, 25, 50, 100, 192, 200, 500, 935, 1000, 2000)
lcfg <- merge(merge(expand.grid(n_b = LNB, n_t = LNT), data.frame(p = c(0.50, 0.90, 0.95, 0.99))),
              data.frame(alpha = ALPHAS))
lcfg <- lcfg[lcfg$n_t <= lcfg$n_b, ]
LAT <- par_rbind(seq_len(nrow(lcfg)), function(i) {
  t <- lcfg[i, ]
  k <- latency_precedence_rank_fast(t$n_b, t$n_t, t$p, t$alpha)
  br <- if (is.na(k)) NA_real_ else latency_breach_probability(t$n_b, k, t$n_t, t$p)
  br_prev <- if (is.na(k) || k == 1L) NA_real_ else latency_breach_probability(t$n_b, k - 1L, t$n_t, t$p)
  data.frame(n_b = t$n_b, n_t = t$n_t, percentile = round(100 * t$p), alpha = t$alpha,
             test_rank = latency_test_rank(t$n_t, t$p), rank = k, saturated = is.na(k),
             breach_at_rank = br, breach_over_alpha = br / t$alpha,
             breach_at_rank_minus_1 = br_prev)
})
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
SZ <- par_rbind(split(merge(merge(data.frame(threshold = PREQ),
                                                 data.frame(delta = c(0.01, 0.02, 0.05, 1))),
                                           data.frame(alpha = ALPHAS)),
                                     seq_len(length(PREQ) * 4 * length(ALPHAS))), function(t) {
  s <- compliance_exact_sizing(t$threshold, t$delta, t$alpha)
  data.frame(threshold = t$threshold, delta = if (t$delta >= 1) NA else t$delta, alpha = t$alpha,
             alternative_kind = s$alternative_kind, alternative_rate = s$alternative_rate,
             first_crossing = s$first_crossing, required_samples = s$required_samples,
             achieved_power = s$achieved_power, n_max = 20000L)
})
SZ <- unique(SZ[order(SZ$threshold, SZ$alpha, SZ$alternative_rate), ])
say("compliance done (%.0f s)", proc.time()[["elapsed"]] - t_start)

# ---------------------------------------------------------------------------
# Write surfaces and summary.
# ---------------------------------------------------------------------------
w <- function(x, f) write.csv(x, file.path(out_dir, f), row.names = FALSE)
w(REG, "regression_size.csv"); w(BEY, "regression_beyond.csv"); w(SET, "regression_settling.csv")
w(POW, "regression_power.csv"); w(LAT, "latency_breach.csv")
w(CMP, "compliance_false_compliance.csv"); w(SZ, "compliance_sizing.csv")

md <- function(df) {
  c(paste0("| ", paste(names(df), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
    apply(df, 1, function(r) paste0("| ", paste(trimws(format(r)), collapse = " | "), " |")))
}
by_alpha <- function(d) do.call(rbind, lapply(ALPHAS, function(a) {
  s <- d[d$alpha == a, ]
  i <- which.max(s$worst_size)
  data.frame(alpha = a, configurations = nrow(s), above_alpha = sum(!s$within_alpha),
             max_size_over_alpha = sprintf("%.4f", s$worst_over_alpha[i]),
             at = sprintf("n_b %d, n_t %d, p %.6f", s$n_b[i], s$n_t[i], s$at_p[i]),
             median_worst_over_alpha = sprintf("%.3f", median(s$worst_over_alpha)))
}))
cmp_ok <- POW[!is.na(POW$bbpred_power_d05), ]
cmp_max <- CMP[which.max(CMP$false_compliance_over_alpha), ]
lat_max <- LAT[which.max(LAT$breach_over_alpha), ]
checks <- c(
  regression_size = all(REG$within_alpha), regression_beyond = all(BEY$within_alpha),
  regression_settling = all(SET$within_alpha),
  monotone = all(REG$monotone) && all(BEY$monotone),
  latency_bound = all(within_alpha(LAT$breach_at_rank, LAT$alpha), na.rm = TRUE) &&
    all(LAT$breach_at_rank_minus_1 > LAT$alpha, na.rm = TRUE),
  compliance_bound = all(within_alpha(CMP$false_compliance, CMP$alpha)))
summary_lines <- c(
  "# Calibration certification, Statistical Companion 1.5.0", "",
  sprintf("mavai-R %s; methodology %s; R %s; %s.", read.dcf("DESCRIPTION")[1, "Version"],
          METHODOLOGY_VERSION, getRversion(), format(Sys.Date())), "",
  "## regression/fisher", "",
  sprintf(paste0("Worst-case exact unconditional size over %d values of p in [0.50, 0.99999], ",
                 "for %d configurations (n_b 10..10000, n_t <= n_b, n_t/n_b >= 0.01; two ",
                 "interleaved grids) x %d alpha. Bound: alpha."),
          length(CERTIFICATION_P_GRID), nrow(CFG), length(ALPHAS)), "",
  md(by_alpha(REG)), "",
  sprintf("Cutoff non-decreasing in K_b in every scanned configuration: %s.", checks[["monotone"]]), "",
  "### Beyond the certified range (n_b 20,000, 50,000, 100,000; n_t 1, 5, 12, 25, 100)", "",
  md(transform(BEY[, c("n_b", "n_t", "alpha", "worst_size", "worst_over_alpha", "at_p")],
               worst_size = sprintf("%.3e", worst_size), worst_over_alpha = sprintf("%.4f", worst_over_alpha))), "",
  "### Settling at fixed n_t as n_b grows", "",
  md(transform(SET[, c("n_b", "n_t", "alpha", "worst_over_alpha", "at_p")],
               worst_over_alpha = sprintf("%.4f", worst_over_alpha))), "",
  "### Power, with the beta-binomial predictive rule beside it (disclosure of conservatism)", "",
  sprintf(paste0("Cells (n_b, n_t, alpha, p) on grid A: %d; compared with the predictive rule: %d. ",
                 "Predictive-rule power at p - 0.05 above Fisher's: %d cells; more than 0.05 above: %d ",
                 "(largest %.4f at n_b %d, n_t %d, alpha %g, p %g). The predictive rule's own size ",
                 "exceeded alpha in %d of the compared cells (largest %.3f alpha); it is not certified ",
                 "and is shown only to measure what Fisher's conservatism costs."),
          nrow(POW), nrow(cmp_ok), sum(cmp_ok$bbpred_minus_fisher_d05 > 1e-12),
          sum(cmp_ok$bbpred_minus_fisher_d05 > 0.05),
          max(cmp_ok$bbpred_minus_fisher_d05),
          cmp_ok$n_b[which.max(cmp_ok$bbpred_minus_fisher_d05)], cmp_ok$n_t[which.max(cmp_ok$bbpred_minus_fisher_d05)],
          cmp_ok$alpha[which.max(cmp_ok$bbpred_minus_fisher_d05)], cmp_ok$p[which.max(cmp_ok$bbpred_minus_fisher_d05)],
          sum(cmp_ok$bbpred_size > cmp_ok$alpha * (1 + 1e-12)),
          max(cmp_ok$bbpred_size / cmp_ok$alpha)), "",
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
if (!all(checks)) {
  message("CERTIFICATION FAILED: ", paste(names(checks)[!checks], collapse = ", "))
  quit(status = 1)
}
