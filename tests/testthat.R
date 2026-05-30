library(testthat)

# Standard R CMD check / installed-package path: mavair has been installed
# and its tests/testthat/ directory ships inside the install tree.
installed_tests <- system.file("tests", "testthat", package = "mavair")

if (nzchar(installed_tests) && length(list.files(installed_tests)) > 0) {
  library(mavair)
  test_check("mavair")
} else {
  # Source-tree dev path: package is loaded but not installed (e.g. running
  # `Rscript tests/testthat.R` from the repo root). Fall back to devtools::test().
  if (!requireNamespace("devtools", quietly = TRUE)) {
    stop(
      "mavair is not installed with its tests, and devtools is not available ",
      "for the source-tree fallback. Either run `R CMD INSTALL .` first, or ",
      "install devtools, or run `Rscript -e 'devtools::test()'` directly.",
      call. = FALSE
    )
  }
  message("mavair not installed with tests; running devtools::test() from source.")
  devtools::test()
}
