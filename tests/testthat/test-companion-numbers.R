test_that("every number the companion quotes agrees with the oracle", {
  repo_root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
  script <- file.path(repo_root, "scripts", "companion_numbers.R")
  skip_if_not(file.exists(file.path(repo_root, "docs", "STATISTICAL-COMPANION.md")))
  out <- withr::with_dir(repo_root, system2(file.path(R.home("bin"), "Rscript"), script,
                                            stdout = TRUE, stderr = TRUE))
  status <- attr(out, "status")
  expect_true(is.null(status) || status == 0, info = paste(grep("^FAIL", out, value = TRUE), collapse = "\n"))
  expect_true(any(grepl("numbers agree with the oracle", out)))
})
