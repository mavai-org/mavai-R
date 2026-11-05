# The exploration stem oracle (R/explore_stem.R): catalog EX05's naming
# rules, including the whole-stem bound of 2026-11-04. The conformance case
# inst/interchange/naming-explore-stem.yaml is recomputed by
# scripts/validate_interchange.R; these tests pin the oracle's own
# properties.

skip_if_not_installed("digest")

bytes <- function(x) nchar(x, type = "bytes")

test_that("a stem within the bound is unchanged", {
  expect_identical(explore_stem_bound("model-gpt-4o_temperature-0.7"),
                   "model-gpt-4o_temperature-0.7")
  at_bound <- paste0("model-", strrep("a", 194))
  expect_identical(bytes(at_bound), 200L)
  expect_identical(explore_stem_bound(at_bound), at_bound)
})

test_that("a longer stem is a 191-byte prefix, '-', and 8 hex characters", {
  bounded <- explore_stem_bound(paste0("model-", strrep("a", 195)))
  expect_identical(bytes(bounded), 200L)
  expect_match(bounded, "^model-a{185}-[0-9a-f]{8}$")
})

test_that("the bound counts UTF-8 bytes and never splits a character", {
  bounded <- explore_stem_bound(paste0("prompt-x", strrep("é", 150)))
  expect_lte(bytes(bounded), 200L)
  expect_identical(bytes(bounded), 199L)
  expect_true(validUTF8(bounded))
  expect_match(bounded, "^prompt-xé{91}-[0-9a-f]{8}$")
})

test_that("the hash covers the whole stem, so a late difference stays distinct", {
  stem <- function(ending) paste0("prompt-", strrep("b", 233), ending)
  one <- explore_stem_bound(stem("-ending-one"))
  two <- explore_stem_bound(stem("-ending-two"))
  expect_identical(substr(one, 1L, 191L), substr(two, 1L, 191L))
  expect_false(identical(one, two))
})

test_that("the bound is deterministic", {
  stem <- paste0("model-", strrep("c", 300))
  expect_identical(explore_stem_bound(stem), explore_stem_bound(stem))
})

test_that("sanitising replaces disallowed characters and collapses runs", {
  expect_identical(explore_stem_sanitise("a b, c/d"), "a_b_c_d")
  expect_identical(explore_stem_sanitise("gpt-4o.mini_x"), "gpt-4o.mini_x")
})

test_that("a long value is truncated to 24 characters and a 4-hex hash", {
  segment <- explore_stem_segment(
    "systemPrompt", "You advise travellers on the health risks of their destination."
  )
  expect_identical(segment, "systemPrompt-You_advise_travellers_on-4e92")
  expect_identical(explore_stem_segment("maxTokens", 200L), "maxTokens-200")
})

test_that("explore_stem joins segments in order and applies the bound", {
  factors <- list(list(name = "model", value = "gpt-4o"),
                  list(name = "temperature", value = "0.7"))
  expect_identical(explore_stem(factors), "model-gpt-4o_temperature-0.7")
  many <- lapply(seq_len(12), function(i) {
    list(name = sprintf("factor%02d", i), value = strrep("v", 20))
  })
  expect_identical(bytes(explore_stem(many)), 200L)
})
