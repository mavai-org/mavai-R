test_that("the beta-binomial comparison cutoff is the definition", {
  nb <- 30; nt <- 12; a <- 0.05
  lit <- vapply(0:nb, function(k) {
    d <- vapply(0:nt, function(x) choose(nt, x) * beta(x + 0.5 + k, nt - x + 0.5 + nb - k) /
                  beta(0.5 + k, 0.5 + nb - k), numeric(1))
    as.integer(sum(cumsum(d)[seq_len(nt)] <= a))
  }, integer(1))
  expect_identical(bbpred_cutoffs(nb, nt, a), lit)
})

test_that("the worst-case scan stays within alpha where score-cc did not", {
  w <- fisher_worst_size(1000, 25, 0.01, p_grid = seq(0.95, 0.99, by = 0.0005))
  expect_lte(w$worst_size, 0.01)
  expect_true(w$monotone)
  expect_lte(fisher_worst_size(100, 1, 0.01, p_grid = seq(0.9, 0.999, by = 0.0005))$worst_size, 0.01)
})

test_that("the fast precedence rank equals the literal one", {
  for (cfg in list(c(200, 50, 0.9, 0.05), c(100, 15, 0.95, 0.05), c(300, 300, 0.5, 0.01))) {
    expect_identical(latency_precedence_rank_fast(cfg[1], cfg[2], cfg[3], cfg[4]),
                     latency_precedence_rank(cfg[1], cfg[2], cfg[3], cfg[4]))
  }
})
