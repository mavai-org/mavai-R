# The committed fixtures: shape, versions, and agreement with the generator.
repo_root <- normalizePath(file.path("..", ".."))
case_dir <- file.path(repo_root, "inst", "cases")

test_that("every committed suite validates against cases.schema.json", {
  skip_if_not_installed("jsonvalidate")
  v <- jsonvalidate::json_validator(file.path(repo_root, "schema", "cases.schema.json"), engine = "ajv")
  files <- setdiff(list.files(case_dir, pattern = "\\.json$", full.names = TRUE),
                   file.path(case_dir, "manifest.json"))
  expect_gt(length(files), 0)
  for (f in files) expect_true(v(paste(readLines(f, warn = FALSE), collapse = "\n")), info = basename(f))
})

test_that("the committed manifest matches the committed files", {
  m <- jsonlite::fromJSON(file.path(case_dir, "manifest.json"), simplifyVector = FALSE)
  expect_identical(m$methodologyVersion, "1.5.0")
  files <- sort(setdiff(list.files(case_dir, pattern = "\\.json$"), "manifest.json"))
  expect_identical(unname(sort(vapply(m$suites, `[[`, character(1), "file"))), files)
  for (s in m$suites) {
    expect_identical(unname(tools::md5sum(file.path(case_dir, s$file))), s$md5, info = s$file)
    suite <- jsonlite::fromJSON(file.path(case_dir, s$file), simplifyVector = FALSE)
    expect_identical(suite$methodologyVersion, m$methodologyVersion, info = s$file)
    expect_identical(suite$fixtureSchemaVersion, m$fixtureSchemaVersion, info = s$file)
  }
  expect_identical(m$fixtureVersion, unname(read.dcf(file.path(repo_root, "DESCRIPTION"))[1, "Version"]))
})

test_that("no empirical case has a test larger than its baseline unless it is refused", {
  for (f in c("threshold_derivation", "regression_decision", "verdict", "criterion_verdict_inferential")) {
    suite <- jsonlite::fromJSON(file.path(case_dir, paste0(f, ".json")), simplifyVector = FALSE)
    for (case in suite$cases) {
      i <- case$inputs
      nt <- if (!is.null(i$test_samples)) i$test_samples else if (!is.null(i$trials)) i$trials else i$n_attempted
      if (!is.null(i$baseline_trials) && nt > i$baseline_trials) {
        expect_identical(case$expected$configuration_error[[1]], "TEST_LARGER_THAN_BASELINE", info = case$name)
      }
    }
  }
})
