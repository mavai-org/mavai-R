# Compare regenerated fixtures with the committed ones, semantically.
#
# Byte identity is too strict across platforms: the last digit of a double can
# differ between maths libraries (macOS and Linux disagree in the 15th
# significant digit of some probabilities). This check requires everything a
# consumer binds on to match exactly - structure, names, strings, logicals,
# integers (cutoffs, ranks, counts, verdicts, error codes) - and every
# non-integer number to agree to a relative 1e-12, far below any tolerance a
# fixture declares. The manifest's md5 fields follow the file bytes and are
# not compared; the published fixtures are always the committed files.
#
# Usage (after scripts/generate_all.R has rewritten inst/cases):
#   Rscript scripts/compare_fixtures.R

rel_tol <- 1e-12

committed <- function(path) {
  txt <- system2("git", c("show", paste0("HEAD:", path)), stdout = TRUE)
  jsonlite::fromJSON(paste(txt, collapse = "\n"), simplifyVector = FALSE)
}

same_number <- function(a, b) {
  if (a == b) return(TRUE)
  if (a == round(a) && b == round(b) && abs(a) < 2^53 && abs(b) < 2^53) return(FALSE)
  abs(a - b) <= rel_tol * max(abs(a), abs(b))
}

compare <- function(a, b, where, skip) {
  if (is.list(a) || is.list(b)) {
    if (!(is.list(a) && is.list(b))) return(paste0(where, ": type differs"))
    if (length(a) != length(b)) return(paste0(where, ": length ", length(a), " != ", length(b)))
    if (!identical(names(a), names(b))) return(paste0(where, ": names differ"))
    out <- character(0)
    for (i in seq_along(a)) {
      key <- if (is.null(names(a))) as.character(i) else names(a)[i]
      if (!is.null(names(a)) && key %in% skip) next
      out <- c(out, compare(a[[i]], b[[i]], paste0(where, "/", key), skip))
    }
    return(out)
  }
  if (is.null(a) || is.null(b)) {
    if (is.null(a) && is.null(b)) return(character(0))
    return(paste0(where, ": null differs"))
  }
  if (is.numeric(a) && is.numeric(b)) {
    if (same_number(a, b)) return(character(0))
    return(sprintf("%s: %.17g != %.17g", where, a, b))
  }
  if (identical(a, b)) return(character(0))
  paste0(where, ": ", format(a), " != ", format(b))
}

files <- sort(list.files("inst/cases", pattern = "\\.json$", full.names = TRUE))
problems <- character(0)
for (f in files) {
  skip <- if (basename(f) == "manifest.json") "md5" else character(0)
  now <- jsonlite::fromJSON(f, simplifyVector = FALSE)
  problems <- c(problems, compare(committed(f), now, basename(f), skip))
}
status <- system2("git", c("status", "--porcelain", "inst/cases"), stdout = TRUE)
added <- grep("^\\?\\?", status, value = TRUE)
if (length(added)) problems <- c(problems, paste("untracked fixture:", sub("^\\?\\? ", "", added)))

if (length(problems)) {
  cat(problems, sep = "\n")
  cat(sprintf("\n%d difference(s) beyond platform rounding.\n", length(problems)))
  quit(status = 1)
}
cat(sprintf("%d fixture files match the committed ones (floats to a relative %g).\n", length(files), rel_tol))
