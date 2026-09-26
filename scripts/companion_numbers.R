#!/usr/bin/env Rscript
#
# Every worked number the Statistical Companion quotes, computed from the
# package's own functions, and checked against the text.
#
# Usage (from the repository root):
#   Rscript scripts/companion_numbers.R [path/to/STATISTICAL-COMPANION.md]
#
# Each check computes a value with the oracle, formats it exactly as the
# companion prints it, and asserts that the formatted text occurs in the
# document. The script prints every number with its section and exits
# non-zero if the text disagrees with the oracle anywhere.

args <- commandArgs(trailingOnly = TRUE)
doc_path <- if (length(args)) args[1] else file.path("docs", "STATISTICAL-COMPANION.md")
for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) source(f)
doc <- paste(readLines(doc_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

checks <- list()
chk <- function(section, label, text) {
  checks[[length(checks) + 1]] <<- list(section = section, label = label, text = text)
}
pct2 <- function(x) sprintf("%.2f%%", 100 * x)
pct3 <- function(x) sprintf("%.3f%%", 100 * x)
pct2m <- function(x) sprintf("%.2f\\%%", 100 * x)  # inside $...$
pct3m <- function(x) sprintf("%.3f\\%%", 100 * x)
comma <- function(n) formatC(n, format = "d", big.mark = ",")
cp_lower <- function(k, n, a) if (k == 0) 0 else qbeta(a, k, n - k + 1)
sci <- function(x) {  # "1.70 \\times 10^{-4}"
  e <- floor(log10(x)); sprintf("%.2f \\times 10^{%d}", x / 10^e, e)
}

# --- §1.4.5b guardrail containment (Clopper–Pearson) ------------------------
ls05 <- cp_lower(99990, 1e5, 0.05)
chk("1.4.5b", "sensitivity lower bound, 99,990 of 100,000", sprintf("L_s(0.05) \\approx %.6f", ls05))
chk("1.4.5b", "miss bound", sprintf("1 - %.6f \\approx %.6f", ls05, 1 - ls05))
chk("1.4.5b", "miss bound, statement", sprintf("approximately $%s$", sci(1 - ls05)))
chk("1.4.5b", "miss bound at alpha 0.025", sprintf("U_{\\mathrm{miss}}(0.025) \\approx %.6f", 1 - cp_lower(99990, 1e5, 0.025)))
chk("1.4.5b", "joint residual bound", sprintf("0.001 \\times %.6f = %s", 1 - cp_lower(99990, 1e5, 0.025),
                                               sci(0.001 * (1 - cp_lower(99990, 1e5, 0.025)))))
chk("1.4.5b", "perfect-sensitivity lower bound", sprintf("L_s(0.05) \\approx %.6f", cp_lower(1e5, 1e5, 0.05)))
chk("1.4.5b", "perfect-sensitivity miss bound", sprintf("U_{\\mathrm{miss}}(0.05) \\approx %s", sci(1 - cp_lower(1e5, 1e5, 0.05))))
chk("1.4.5b", "Wilson bound it understates", sprintf("$%s$ here", sci(1 - wilson_lower(1e5, 1e5, 0.95))))

# --- The canonical consult-advice example (§1.4.8, §1.5.6, §10.3) -----------
c_wf <- fisher_cutoff(951, 1000, 1000, 0.05)
k_lr <- exact_binomial_k_min(0.98, 800, 0.001)
chk("1.4.8", "well-formed cutoff", sprintf("is $c = %d$ (§3.4)", c_wf))
chk("1.4.8", "layperson k_min", sprintf("is $k_{\\min} = %d$ (§3.6)", k_lr))
chk("1.4.8", "descriptive Wilson bounds", sprintf("$%.4f$ ($C_{\\text{well-formed}}$, $\\alpha = 0.05$) and $%.4f$",
                                                   wilson_lower(953, 1000, 0.95), wilson_lower(788, 800, 0.999)))
chk("1.5.6", "cutoff consumed", sprintf("951 of 1000 is $c = %d$", c_wf))
cut <- fisher_cutoffs(1000, 1000, 0.05)
wci <- wilson_ci(953, 1000, 0.95)
chk("10.3", "SE", sprintf("√(0.953 × 0.047 / 1000) ≈ %.5f", sqrt(0.953 * 0.047 / 1000)))
chk("10.3", "Wilson CI", sprintf("[%.3f, %.3f]", wci$lower, wci$upper))
chk("10.3", "integer cutoff", sprintf("c = %d   (one-sided Fisher", c_wf))
chk("10.3", "Fisher p-value", sprintf("value:              ≈ %.3f", fisher_pvalue(953, 951, 1000, 1000)))
chk("10.3", "size at the assumed common rate", sprintf("A(0.951) ≈ %.4f", regression_fail_probability(cut, 1000, 1000, 0.951, 0.951)))
chk("10.3", "diagnostic plug-in tail", sprintf("P_{p = 0.951}(K_t < %d) ≈ %.4f", c_wf, pbinom(c_wf - 1, 1000, 0.951)))
dp <- fisher_power(1000, 1000, 0.05, 0.951, 0.951 - 0.925)
rp <- pbinom(c_wf - 1, 1000, 0.925)
chk("10.3", "design power at 0.925", sprintf("design power         ≈ %.3f", dp))
chk("10.3", "resolved-test power at 0.925", sprintf("resolved-test power  ≈ %.3f", rp))
chk("10.3", "resolved cutoff", sprintf("cutoff, c = %d)", c_wf))
chk("10.3", "powers in the reading", sprintf("the design power, %.3f, averages over a baseline yet to be drawn, and the resolved-test power, %.3f,", dp, rp))
chk("10.3", "resolved cutoff in the reading", sprintf("fixed at %d.", c_wf))
mdd <- fisher_minimum_detectable_degradation(1000, 1000, 0.05, 0.951)
chk("10.3", "MDD", sprintf("at a drop of %.4f", mdd))
chk("10.3", "MDD rate", sprintf("(to ≈ %.3f)", 0.951 - mdd))
chk("10.3", "layperson SE", sprintf("√(0.985 × 0.015 / 800) ≈ %.5f", sqrt(0.985 * 0.015 / 800)))
chk("10.3", "layperson feasibility", sprintf("PASS possible from n = %d", exact_binomial_min_feasible_n(0.98, 0.001)))
chk("10.3", "layperson k_min", sprintf("k_min = %d", k_lr))
chk("10.3", "layperson Clopper–Pearson", sprintf("≈ %.4f", cp_lower(788, 800, 0.001)))
chk("10.3", "layperson Wilson", sprintf("≈ %.4f   (descriptive)", wilson_lower(788, 800, 0.999)))
chk("10.3", "layperson p-value", sprintf("value:        ≈ %.3f", pbinom(787, 800, 0.98, lower.tail = FALSE)))
chk("10.3", "layperson sizing", sprintf("n_c = %d (§5.5)", compliance_exact_sizing(0.98, 0.005, 0.001)$required_samples))

# --- §3.4 / §3.5 regression cutoffs -----------------------------------------
cut100 <- fisher_cutoffs(1000, 100, 0.05)
chk("3.4", "p-value of 90", sprintf("$k_t = 90$ is $%.4f", fisher_pvalue(90, 951, 1000, 100)))
chk("3.4", "p-value of 91", sprintf("$k_t = 91$ is $%.4f", fisher_pvalue(91, 951, 1000, 100)))
chk("3.4", "cutoff", sprintf("c = %d, \\qquad", cut100[952]))
chk("3.4", "unconditional size", sprintf("$A(0.951) = %s$", pct2m(regression_fail_probability(cut100, 1000, 100, 0.951, 0.951))))
chk("3.4", "conditional plug-in tail", sprintf("P_{0.951}(K_t < 91) = %.6f", pbinom(90, 100, 0.951)))
for (nt in c(50, 100, 200, 500, 1000)) {
  chk("3.5", sprintf("951/1000, n_t %d", nt),
      sprintf("| %d | %d | %d |", nt, fisher_cutoff(951, 1000, nt, 0.05), fisher_cutoff(951, 1000, nt, 0.01)))
}
canon <- list(list("Ordinary", 951, 1000, 100, 0.05), list("Ordinary, larger baseline", 1902, 2000, 100, 0.05),
              list("Equal sizes", 951, 1000, 1000, 0.05), list("Large baseline, small test", 9510, 10000, 100, 0.05),
              list("Near-perfect baseline", 99, 100, 100, 0.05), list("Perfect baseline", 100, 100, 100, 0.05),
              list("Perfect baseline, large", 1000, 1000, 100, 0.05), list("Zero baseline", 0, 100, 50, 0.05),
              list("Small baseline", 27, 30, 25, 0.05), list("$\\alpha = 0.01$", 951, 1000, 1000, 0.01))
for (r in canon) {
  chk("3.5", r[[1]], sprintf("| %s | %d | %d | %d | %g | %d | %d |", r[[1]], r[[2]], r[[3]], r[[4]], r[[5]],
                             fisher_cutoff(r[[2]], r[[3]], r[[4]], r[[5]]),
                             legacy_wilson_reference_cutoff(r[[2]], r[[3]], r[[4]], r[[5]])))
}
chk("3.5", "refused row", sprintf("| 95 | 100 | 200 | 0.05 | `%s` | %d |", regression_configuration_error(100, 200),
                                  legacy_wilson_reference_cutoff(95, 100, 200, 0.05)))

# --- §3.6 compliance -----------------------------------------------------------
fc <- function(pr, n) pbinom(exact_binomial_k_min(pr, n, 0.05) - 1, n, pr, lower.tail = FALSE)
chk("3.6", "95% at 150", sprintf("$k_{\\min} = %d$, and the false-compliance probability is $%s$",
                                 exact_binomial_k_min(0.95, 150, 0.05), pct3m(fc(0.95, 150))))
chk("3.6", "99% at 793", sprintf("$k_{\\min} = %d$, false compliance $%s$", exact_binomial_k_min(0.99, 793, 0.05), pct3m(fc(0.99, 793))))
chk("3.6", "99.9% feasibility", sprintf("at least %s trials", comma(exact_binomial_min_feasible_n(0.999, 0.05))))
chk("3.6", "99.9% at 2995", sprintf("$k_{\\min} = %d$, false compliance $%s$", exact_binomial_k_min(0.999, 2995, 0.05), pct3m(fc(0.999, 2995))))
stopifnot(is.na(exact_binomial_k_min(0.999, 2994, 0.05)))
sz <- function(pr, d, a = 0.05) compliance_exact_sizing(pr, d, a)$required_samples
chk("3.6", "table 0.90", sprintf("| 0.90 | 0.95 ($\\delta = 0.05$) | %s |", comma(sz(0.90, 0.05))))
chk("3.6", "table 0.95/0.02", sprintf("| 0.95 | 0.97 ($\\delta = 0.02$) | %s |", comma(sz(0.95, 0.02))))
chk("3.6", "table 0.95/0.01", sprintf("| 0.95 | 0.96 ($\\delta = 0.01$) | %s |", comma(sz(0.95, 0.01))))
chk("3.6", "table 0.99", sprintf("| 0.99 | 0.995 ($\\delta = 0.005$) | %s |", comma(sz(0.99, 0.005))))
chk("3.6", "table 0.995", sprintf("| 0.995 | 0.9975 (midway) | %s |", comma(sz(0.995, 0.01))))
stopifnot(is.na(sz(0.999, 0.01)))

# --- §4 perfect and zero baselines --------------------------------------------
chk("4.1", "perfect 1000/1000 at 100", sprintf("the cutoff is $c = %d$", fisher_cutoff(1000, 1000, 100, 0.05)))
chk("4.3.2", "perfect 1000/1000", sprintf("The Fisher cutoff (§3.4) is $c = %d$", fisher_cutoff(1000, 1000, 100, 0.05)))
chk("4.3", "legacy drop", sprintf("99 of 100 gave %d while 100 of 100 gave %d", legacy_wilson_reference_cutoff(99, 100, 100, 0.05),
                                  legacy_wilson_reference_cutoff(100, 100, 100, 0.05)))
chk("4.3", "legacy drop, 1000", sprintf("999 of 1000 gave %d while 1000 of 1000 gave %d", legacy_wilson_reference_cutoff(999, 1000, 100, 0.05),
                                        legacy_wilson_reference_cutoff(1000, 1000, 100, 0.05)))
for (nb in c(100, 300, 1000, 3000)) {
  chk("4.3.3", sprintf("perfect %d", nb), sprintf("| %d | %d (%d) | %d (%d) |", nb,
      fisher_cutoff(nb, nb, 50, 0.05), legacy_wilson_reference_cutoff(nb, nb, 50, 0.05),
      fisher_cutoff(nb, nb, 100, 0.05), legacy_wilson_reference_cutoff(nb, nb, 100, 0.05)))
}
chk("4.3.4", "zero baseline", if (all(fisher_cutoffs(100, 50, 0.05)[1] == 0L, fisher_cutoffs(1000, 200, 0.001)[1] == 0L))
  "the cutoff is $c = 0$ at every" else "ZERO-BASELINE CUTOFF IS NOT 0")
chk("4.4", "2000/2000 at 100", sprintf("For a 100-sample test, $c = %d$", fisher_cutoff(2000, 2000, 100, 0.05)))
chk("4.4", "2000/2000 at 50", sprintf("For a 50-sample test, $c = %d$", fisher_cutoff(2000, 2000, 50, 0.05)))
chk("4.4", "legacy 2000/2000", sprintf("admitted %d of 100 and %d of 50", legacy_wilson_reference_cutoff(2000, 2000, 100, 0.05),
                                       legacy_wilson_reference_cutoff(2000, 2000, 50, 0.05)))

# --- §5 power and sizing ----------------------------------------------------------
chk("5.3", "power 0.95 -> 0.90", sprintf("the exact power is $%.3f$", fisher_power(1000, 100, 0.05, 0.95, 0.05)))
chk("5.3", "legacy exact power", sprintf("exact power was %.1f%%", 100 * {
  lc <- legacy_wilson_reference_cutoff(951, 1000, 100, 0.05); pbinom(lc - 1, 100, 0.90) }))
for (pm in c(0.85, 0.90, 0.92)) {
  req <- vapply(c(0.8, 0.9, 0.95), function(pw) risk_sizing_required_n(0.95, 2000, pm, 0.05, pw), integer(1))
  chk("5.4", sprintf("table p_min %.2f", pm), sprintf("| %d | %d | %d |", req[1], req[2], req[3]))
}
chk("5.4.1", "worked example n", sprintf("n_{\\text{req}} = %d", risk_sizing_required_n(0.87, 3000, 0.84, 0.05, 0.80)))
chk("5.4.1", "worked example power", sprintf("\\text{Power}(1243) = %.4f", risk_sizing_power(1243, 0.87, 3000, 0.84, 0.05)))
chk("5.4.1", "power at 891", sprintf("the exact power is %.3f", risk_sizing_power(891, 0.87, 3000, 0.84, 0.05)))
chk("5.4.1", "detectable rate at 100", sprintf("p_{\\mathrm{design}} \\approx %.4f", risk_sizing_detectable_rate(100, 0.87, 3000, 0.05, 0.80)))
for (n in c(50, 150)) {
  chk("5.4.1", sprintf("walk-through %d", n), sprintf("| %d | %d | %.2f |", n, fisher_cutoff(1920, 2000, n, 0.05),
                                                     risk_sizing_power(n, 0.96, 2000, 0.93, 0.05)))
}
nw <- risk_sizing_required_n(0.96, 2000, 0.93, 0.05, 0.80)
chk("5.4.1", "walk-through required", sprintf("| **%d** | %d | **%.2f** |", nw, fisher_cutoff(1920, 2000, nw, 0.05),
                                              risk_sizing_power(nw, 0.96, 2000, 0.93, 0.05)))
stopifnot(is.na(risk_sizing_required_n(0.96, 300, 0.93, 0.05, 0.80)))
chk("5.4.1", "failure above the design rate", sprintf("a service truly at $0.94$ fails about half the time (%.2f), and one at $0.95$ about one time in five (%.2f)",
    risk_sizing_power(nw, 0.96, 2000, 0.94, 0.05), risk_sizing_power(nw, 0.96, 2000, 0.95, 0.05)))
s95 <- compliance_exact_sizing(0.95, 0.02, 0.05)
chk("5.5", "95% sizing", sprintf("at $\\alpha = 0.05$: $n = %d$. Power first reaches 0.80 at %d samples", s95$required_samples, s95$first_crossing))
chk("5.5", "99.5% midway sizing", sprintf("the exact size is $n = %d$", sz(0.995, 0.01)))
chk("5.5", "99.5% feasibility", sprintf("the feasibility minimum is %d", exact_binomial_min_feasible_n(0.995, 0.05)))
stopifnot(is.na(exact_binomial_k_min(0.995, 477, 0.05)))
chk("5.5", "99.9% at alpha 0.10", sprintf("(%s at $\\alpha = 0.10$)", comma(sz(0.999, 0.01, 0.10))))
chk("5.6", "MDD 1000/100", sprintf("it is %.4f: the design detects a drop to about %.3f",
                                    fisher_minimum_detectable_degradation(1000, 100, 0.05, 0.95),
                                    0.95 - fisher_minimum_detectable_degradation(1000, 100, 0.05, 0.95)))
for (pr in c(0.50, 0.80, 0.90, 0.95, 0.99, 0.995, 0.999, 0.9999)) {
  chk("5.7.1", sprintf("N_min %g", pr), sprintf("| %s | %s |", format(pr, nsmall = 2), comma(exact_binomial_min_feasible_n(pr, 0.05))))
}
chk("5.7.1", "legacy N_min list", paste0("its minimums — ", paste(comma(vapply(c(0.5, 0.8, 0.9, 0.95, 0.99, 0.995),
  function(p) legacy_wilson_feasibility_min_n(p, 0.05), integer(1))), collapse = ", ")))

# --- §6.3 threshold-first ----------------------------------------------------------
chk("6.3", "implied alpha, cutoff 91", sprintf("A declared cutoff of 91 has implied $\\alpha = %.4f$", fisher_implied_alpha(951, 1000, 100, 91)))
chk("6.3", "implied alpha, cutoff 96", sprintf("a cutoff of %d, whose implied $\\alpha$ is $%.3f$", ceiling(100 * 0.951),
                                               fisher_implied_alpha(951, 1000, 100, ceiling(100 * 0.951))))

# --- §12 latency ----------------------------------------------------------------------
k <- latency_precedence_rank(935, 192, 0.95, 0.05)
chk("12.4.5", "test rank", sprintf("\\rceil = %d$rd order statistic", latency_test_rank(192, 0.95)))
chk("12.4.5", "breach at k-1", sprintf("\\text{breach}(%d) \\approx %s > 5\\%%", k - 1, pct2m(latency_breach_probability(935, k - 1, 192, 0.95))))
chk("12.4.5", "breach at k", sprintf("\\text{breach}(%d) \\approx %s \\le 5\\%%", k, pct2m(latency_breach_probability(935, k, 192, 0.95))))
lat <- jsonlite::fromJSON(file.path("inst", "cases", "latency_threshold.json"), simplifyVector = FALSE)$cases[[1]]$expected
chk("12.4.5", "threshold value", sprintf("t_{(%d)} = %d\\text{ms}", lat$rank, lat$threshold))
chk("12.4.5", "baseline p95", sprintf("Q_{0.95} = %d\\text{ms}", lat$baseline_percentile))
chk("12.4.5", "legacy rank and breach", sprintf("used rank %d here, whose no-degradation breach probability for a 192-sample test is %s",
                                               legacy_order_statistic_rank(935, 0.95, 0.05)$rank,
                                               pct2(latency_breach_probability(935, legacy_order_statistic_rank(935, 0.95, 0.05)$rank, 192, 0.95))))
chk("12.5.2.1", "1000/15 rank", sprintf("and a baseline of 1000 can (rank %d)", latency_precedence_rank(1000, 15, 0.95, 0.05)))
stopifnot(is.na(latency_precedence_rank(100, 15, 0.95, 0.05)))
min_baseline <- function(nt, pp, a = 0.05) {  # smallest n_b >= n_t from which a rank exists
  nb <- nt
  while (latency_precedence_exists(nb, nt, pp, a)$saturated) nb <- nb + 1L
  stopifnot(!latency_precedence_exists(nb + 1L, nt, pp, a)$saturated)
  as.integer(nb)
}
for (pp in c(0.90, 0.95, 0.99)) {
  mins <- vapply(c(10L, 25L, 50L, 100L, 200L), min_baseline, integer(1), pp = pp)
  chk("12.5.2.1", sprintf("existence table p%g", 100 * pp),
      sprintf("| p%g | %s |", 100 * pp, paste(mins, collapse = " | ")))
}
chk("12.5.2.1", "p99 test of 50", sprintf("a p99 test of 50 has $r = %d$", latency_test_rank(50, 0.99)))
stopifnot(all(vapply(c(10L, 25L, 50L, 100L, 200L), function(nt) min_baseline(nt, 0.50) == nt, logical(1))))
chk("12.5.2.1", "p50 minimum", "At p50 a baseline as large as the test suffices at every test size in the table")
chk("12.5.2.1", "exact boundaries at the top rank", sprintf("needs a baseline of exactly %d, %d or %d",
    min_baseline(10L, 0.99), min_baseline(25L, 0.99), min_baseline(50L, 0.99)))
stopifnot(breach_exact(190, 190, 10, 10) == gmp::as.bigq(1, 20), breach_exact(950, 950, 50, 50) == gmp::as.bigq(1, 20))
stopifnot(fisher_pvalue_exact(2, 12, 12, 4) == gmp::as.bigq(1, 20), fisher_pvalue(2, 12, 12, 4) > 0.05)
chk("10.6", "Fisher exact-boundary example", "2 test successes in 4 against a baseline of 12 in 12 is exactly 1/20")
nte <- floor(200 * 0.80)
chk("12.5.3", "expected successes", sprintf("expects $n_{t,\\text{expected}} = %d$", nte))
chk("12.5.3", "test rank", sprintf("has $r = %d$", latency_test_rank(nte, 0.99)))
stopifnot(latency_precedence_exists(400, nte, 0.99, 0.05)$saturated)
pl <- latency_precedence_planning(400, 200, 0.80, 0.99, 0.05)
stopifnot(pl$warning, pl$expected_test_samples == nte, pl$minimum_baseline_trials == min_baseline(nte, 0.99))
chk("12.5.3", "planning figure", sprintf("a baseline of at least %d latencies supports a threshold for %d (rank %d at exactly %d)",
    min_baseline(nte, 0.99), nte, latency_precedence_rank(min_baseline(nte, 0.99), nte, 0.99, 0.05), min_baseline(nte, 0.99)))
n_sat <- nte + 1L
stopifnot(!latency_precedence_exists(min_baseline(nte, 0.99), nte, 0.99, 0.05)$saturated,
          latency_precedence_exists(min_baseline(nte, 0.99), n_sat, 0.99, 0.05)$saturated)
chk("12.5.3", "expectation is not a lower bound", sprintf("against a baseline of %d, a run that returns %d or more successful latencies finds no rank",
    min_baseline(nte, 0.99), n_sat))

# --- §12.3.4 explicit latency requirements ----------------------------------------
chk("12.3.4", "raw percentile at the boundary", sprintf("$P(\\text{Bin}(100, 0.95) \\ge 95) = %.3f$", pbinom(94, 100, 0.95, lower.tail = FALSE)))
lc <- latency_compliance_verdict(c(rep(400, 96), rep(700, 4)), 500, 0.95, 0.05)
stopifnot(lc$verdict == "FAIL", lc$advisory_percentile_pass)
chk("12.3.4", "y_min at p95 of 100", sprintf("$n_s = 100$ successful latencies): $y_{\\min} = %d$", lc$y_min))
chk("12.3.4", "feasibility minimums", sprintf("— %d at p95 and $\\alpha = 0.05$, %d at p99",
    exact_binomial_min_feasible_n(0.95, 0.05), exact_binomial_min_feasible_n(0.99, 0.05)))

# --- §3.4 design policy: a test larger than its baseline gains power ---------------
chk("3.4", "power beyond the baseline size", sprintf("the power is %.3f at $n_t = 100$ and %.3f at $n_t = 200$",
    fisher_power(100, 100, 0.05, 0.95, 0.10), fisher_power(100, 200, 0.05, 0.95, 0.10)))

# --- Worked numbers in the descriptive and planning sections ----------------------
se <- sqrt(0.951 * 0.049 / 1000)
chk("2.2", "standard error", sprintf("\\approx %.5f$$", se))
w2 <- wilson_ci(951, 1000, 0.95)
chk("2.3.1", "Wilson lower", sprintf("\\approx %.3f$$", w2$lower))
chk("2.3.1", "Wilson upper", sprintf("\\text{Upper} \\approx %.3f$$", w2$upper))
chk("2.3.2", "Wald interval", sprintf("[%.3f, %.3f]$$", 0.951 - qnorm(0.975) * se, 0.951 + qnorm(0.975) * se))
for (e in c(0.05, 0.03, 0.02, 0.01)) {
  chk("2.4", sprintf("precision %g", e), sprintf("| %s |", comma(round(qnorm(0.975)^2 * 0.95 * 0.05 / e^2))))
}
chk("3.1", "test SE", sprintf("\\approx %.4f$$", sqrt(0.951 * 0.049 / 100)))
chk("3.1", "two-sigma range", sprintf("between %.3f and %.3f", 0.951 - 2 * sqrt(0.951 * 0.049 / 100), 0.951 + 2 * sqrt(0.951 * 0.049 / 100)))
for (n in c(100, 300, 1000, 3000)) chk("4.2", sprintf("rule of three %d", n), sprintf("| %d | %.3f |", n, 1 - 3 / n))
for (m in c(5, 10, 20)) {
  chk("7.3", sprintf("family of %d", m), sprintf("| %.1f%% | %.1f%% | %s | %.1f%% |", 100 * (1 - 0.95^m), 100 * (1 - 0.99^m),
      if (m * 0.05 >= 1) "100% (capped)" else sprintf("%.1f%%", 100 * m * 0.05), 100 * m * 0.01))
}
chk("8.5", "horizon of 50", sprintf("the independence approximation gives $\\approx %d\\%%$", round(100 * (1 - 0.95^50))))
for (pp in c(0.50, 0.90, 0.95, 0.99)) chk("12.2.2", sprintf("rank p%g of 200", 100 * pp), sprintf("| %d |", ceiling(pp * 200)))
legacy_uncond <- function(nb, nt, p) {
  lc <- legacy_wilson_reference_cutoff(0:nb, nb, nt, 0.05); regression_fail_probability(lc, nb, nt, p, p)
}
chk("5.2", "1.4.1 false alarms, equal sizes", sprintf("about %d%% with equal sizes", round(100 * legacy_uncond(1000, 1000, 0.95))))
chk("5.2", "1.4.1 false alarms, ten-fold test", sprintf("about %d%% with a baseline of 100 and a test of 1000", round(100 * legacy_uncond(100, 1000, 0.95))))
chk("5.2", "1.4.1 false alarms, small test", sprintf("(%.2f%% at $p = 0.99$ for a baseline of 1000 and a test of 25)", 100 * legacy_uncond(1000, 25, 0.99)))
chk("12.4.3", "1.4.1 breach in the worked example", sprintf("%.1f%% in the §12.4.5 example",
    100 * latency_breach_probability(935, legacy_order_statistic_rank(935, 0.95, 0.05)$rank, 192, 0.95)))

# --- report --------------------------------------------------------------------------
squash <- function(x) gsub(" +", " ", x)  # tables pad their cells
doc_squashed <- squash(doc)
found <- vapply(checks, function(ch) grepl(squash(ch$text), doc_squashed, fixed = TRUE), logical(1))
for (i in seq_along(checks)) {
  cat(sprintf("%-4s §%-9s %-42s %s\n", if (found[i]) "ok" else "FAIL", checks[[i]]$section,
              checks[[i]]$label, checks[[i]]$text))
}
cat(sprintf("\n%d of %d numbers agree with the oracle\n", sum(found), length(found)))
if (!all(found)) quit(status = 1)
