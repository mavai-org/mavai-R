#' Exploration filename stems: the oracle for EX05's naming rules.
#'
#' An explore experiment writes one artefact per configuration, named by a
#' readable stem derived from the configuration's factor values; the same
#' string is the document's `configuration` identity (mavai-explore-1,
#' amendment 2026-11-04). These functions compute that stem independently
#' of any framework, so the conformance case
#' `inst/interchange/naming-explore-stem.yaml` can be checked here and
#' asserted by the emitters.
#'
#' The rules (catalog EX05, "Configuration naming"):
#'
#'   1. one segment per factor, in declaration order: `{name}-{value}`,
#'      where a value whose canonical form is longer than 32 characters
#'      becomes the first 24 characters of its sanitised form, `-`, and the
#'      first 4 hex characters of the SHA-256 of the full canonical value;
#'   2. the segments joined with `_`, and the whole sanitised: every
#'      character other than an ASCII letter, a digit, `.`, `-` or `_`
#'      becomes `_`, and runs of `_` collapse to one;
#'   3. the whole-stem bound (amendment 2026-11-04): a stem of at most 200
#'      UTF-8 bytes is unchanged; a longer one becomes the longest prefix
#'      of whole characters within 191 bytes, `-`, and the first 8 hex
#'      characters of the SHA-256 of the whole stem.
#'
#' The per-value step is stated here only as far as the family's emitters
#' agree on it: canonical values are strings or integers, and the case's
#' inputs avoid runs of disallowed characters and non-ASCII letters, where
#' the emitters' per-value steps still differ. The bound itself is exact
#' for any UTF-8 stem.
#'
#' SHA-256 uses the digest package (Suggests).

# The whole-stem bound, in UTF-8 bytes.
EXPLORE_STEM_MAX_BYTES <- 200L

# Hex characters of the whole-stem hash appended to a bounded stem.
EXPLORE_STEM_HASH_CHARS <- 8L

# Per-value truncation: a canonical value longer than this many characters
# is truncated.
EXPLORE_STEM_VALUE_CAP <- 32L

# Characters of the sanitised value kept when it is truncated.
EXPLORE_STEM_VALUE_PREFIX <- 24L

# Hex characters of the per-value hash.
EXPLORE_STEM_VALUE_HASH_CHARS <- 4L

sha256_hex <- function(text) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("the digest package is required for exploration stems", call. = FALSE)
  }
  digest::digest(enc2utf8(text), algo = "sha256", serialize = FALSE)
}

#' Sanitise a stem or a value per EX05.
#'
#' @param text A character scalar.
#' @return `text` with every character other than an ASCII letter, a digit,
#'   `.`, `-` or `_` replaced by `_`, and runs of `_` collapsed to one.
#' @export
explore_stem_sanitise <- function(text) {
  gsub("_+", "_", gsub("[^A-Za-z0-9._-]", "_", text, perl = TRUE), perl = TRUE)
}

#' One factor's stem segment, `{name}-{value}`.
#'
#' @param name The factor's declared name.
#' @param value The factor's value: a character scalar or an integer.
#' @return The segment, with the value sanitised and, when its canonical
#'   form exceeds 32 characters, truncated to 24 and suffixed with `-` and
#'   4 hex characters of the SHA-256 of the full canonical value.
#' @export
explore_stem_segment <- function(name, value) {
  canonical <- if (is.character(value)) value else format(value, scientific = FALSE)
  rendered <- explore_stem_sanitise(canonical)
  if (nchar(canonical, type = "chars") > EXPLORE_STEM_VALUE_CAP) {
    rendered <- paste0(
      substr(rendered, 1L, EXPLORE_STEM_VALUE_PREFIX), "-",
      substr(sha256_hex(canonical), 1L, EXPLORE_STEM_VALUE_HASH_CHARS)
    )
  }
  paste0(name, "-", rendered)
}

#' Apply the whole-stem bound.
#'
#' @param stem A sanitised stem (any UTF-8 text).
#' @return `stem` itself when it is at most 200 UTF-8 bytes; otherwise the
#'   longest prefix of whole characters within 191 bytes, `-`, and the first
#'   8 hex characters of the SHA-256 of the whole `stem`.
#' @export
explore_stem_bound <- function(stem) {
  stem <- enc2utf8(stem)
  if (nchar(stem, type = "bytes") <= EXPLORE_STEM_MAX_BYTES) {
    return(stem)
  }
  budget <- EXPLORE_STEM_MAX_BYTES - EXPLORE_STEM_HASH_CHARS - 1L
  chars <- strsplit(stem, "", fixed = TRUE)[[1L]]
  widths <- nchar(chars, type = "bytes")
  keep <- sum(cumsum(widths) <= budget)
  paste0(
    paste(chars[seq_len(keep)], collapse = ""), "-",
    substr(sha256_hex(stem), 1L, EXPLORE_STEM_HASH_CHARS)
  )
}

#' The exploration stem for one configuration.
#'
#' @param factors The configuration's factors in declaration order: a list
#'   of `list(name = , value = )` entries.
#' @return The bounded stem: the file stem and the document's
#'   `configuration`.
#' @export
explore_stem <- function(factors) {
  segments <- vapply(
    factors, function(f) explore_stem_segment(f$name, f$value), character(1L)
  )
  explore_stem_bound(explore_stem_sanitise(paste(segments, collapse = "_")))
}
