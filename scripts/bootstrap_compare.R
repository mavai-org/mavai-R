#!/usr/bin/env Rscript
#
# Bootstrap vs. binomial-bound comparison for §12.4.4 of the
# STATISTICAL-COMPANION. Prints a markdown table to stdout suitable for
# pasting into §12.4.4.
#
# The binomial bound compared here is the v1.4.1 construction (legacy
# latency/order-statistic-bound); since methodology 1.5.0 the comparison
# is no longer published as a fixture suite. This script does not write
# JSON. It exists solely for the doc-side comparison table.

r_files <- list.files("R", pattern = "\\.R$", full.names = TRUE)
for (f in r_files) source(f)

suite <- generate_latency_threshold_bootstrap_cases()

cat("| Sample | n_s | p | Point estimate | Bootstrap 95% upper | Binomial bound (rank) | diff (ms) |\n")
cat("|---|---|---|---|---|---|---|\n")
for (case in suite$cases) {
  e <- case$expected
  i <- case$inputs
  # Strip the "_pXX" suffix to recover the underlying sample label.
  sample_label <- sub("_p[0-9.]+$", "", case$name)
  cat(sprintf("| %s | %d | %.2f | %g | %g | %g (k=%d) | %+g |\n",
              sample_label, e$n, i$p,
              e$point_estimate, e$bootstrap_upper,
              e$threshold, e$rank,
              e$diff))
}
