#' The exact-boundary convention for the exact decision rules.
#'
#' Every exact rule compares a probability with alpha by an inclusive
#' rule: a Fisher p-value FAILs a test count when it is at most alpha;
#' a binomial upper tail admits a count when it is at most alpha; a
#' precedence breach probability admits a rank when it is at most alpha.
#' At an exact boundary the probability equals alpha, and floating-point
#' evaluation can land on either side of it. The convention:
#'
#'   1. compute the probability with the standard library (double
#'      precision);
#'   2. when |value - alpha| <= BOUNDARY_GUARD * alpha, recompute it
#'      exactly, in rational arithmetic, from the declared inputs;
#'   3. apply the inclusive rule to the exact value.
#'
#' Declared rates and levels (alpha, p_req, the percentile) are taken as
#' the exact decimals they are written as: 0.05 is 1/20, 0.995 is
#' 199/200. The exact values are finite sums of rationals:
#'
#'   - Fisher p-value: sum_{x <= k_t} C(s, x) C(N - s, n_t - x) / C(N, n_t);
#'   - binomial upper tail: sum_{j >= k} C(n, j) p^j (1 - p)^(n - j);
#'   - precedence breach: sum_{j < r} C(n_t, j) B(k + j, n_b - k + 1 + n_t - j)
#'     / B(k, n_b - k + 1), with B(a, b) = (a - 1)! (b - 1)! / (a + b - 1)!
#'     (at r = n_t and k = n_b it is n_t / (n_b + n_t)).
#'
#' Rational arithmetic uses the gmp package.

# Relative guard band around alpha within which a probability is
# recomputed exactly before the inclusive comparison.
BOUNDARY_GUARD <- 1e-9

#' A declared decimal as an exact rational
#' @keywords internal
exact_decimal <- function(x) {
  s <- trimws(formatC(x, digits = 15, format = "fg"))
  s <- sub("0+$", "", sub("^([^.]*)$", "\\1.", s))
  parts <- strsplit(s, ".", fixed = TRUE)[[1]]
  frac <- if (length(parts) > 1) parts[2] else ""
  digits <- sub("^0+", "", paste0(parts[1], frac))
  if (digits == "") digits <- "0"
  gmp::as.bigq(gmp::as.bigz(digits), gmp::pow.bigz(10, nchar(frac)))
}

#' Is value <= alpha, under the exact-boundary convention?
#'
#' @param value Double-precision probabilities.
#' @param alpha The declared level.
#' @param exact_fun Function of the element index returning the exact
#'   probability as a bigq; called only inside the guard band.
#' @return Logical vector.
#' @keywords internal
at_most_alpha <- function(value, alpha, exact_fun) {
  out <- value <= alpha
  near <- which(abs(value - alpha) <= BOUNDARY_GUARD * alpha)
  if (length(near)) {
    a <- exact_decimal(alpha)
    for (i in near) out[i] <- exact_fun(i) <= a
  }
  out
}

#' Exact one-sided Fisher p-value P(X <= k_t) as a rational
#' @keywords internal
fisher_pvalue_exact <- function(k_t, k_b, n_b, n_t) {
  N <- n_b + n_t
  s <- k_b + k_t
  lo <- max(0, s - n_b)
  if (k_t < lo) return(gmp::as.bigq(0))
  x <- lo:k_t
  num <- sum(gmp::chooseZ(s, x) * gmp::chooseZ(N - s, n_t - x))
  gmp::as.bigq(num, gmp::chooseZ(N, n_t))
}

#' Exact binomial upper tail P(K >= k), K ~ Bin(n, p), as a rational
#' @keywords internal
binomial_upper_exact <- function(k, n, p) {
  if (k <= 0) return(gmp::as.bigq(1))
  if (k > n) return(gmp::as.bigq(0))
  q <- exact_decimal(p)
  j <- k:n
  sum(gmp::chooseZ(n, j) * q^j * (1 - q)^(n - j))
}

#' Exact precedence breach probability as a rational
#' @keywords internal
breach_exact <- function(n_b, k, n_t, r) {
  lbeta_z <- function(a, b) gmp::as.bigq(gmp::factorialZ(a - 1) * gmp::factorialZ(b - 1),
                                        gmp::factorialZ(a + b - 1))
  if (r == n_t && k == n_b) return(gmp::as.bigq(n_t, n_b + n_t))
  total <- gmp::as.bigq(0)
  denom <- lbeta_z(k, n_b - k + 1)
  for (j in 0:(r - 1)) {
    total <- total + gmp::chooseZ(n_t, j) * lbeta_z(k + j, n_b - k + 1 + n_t - j) / denom
  }
  total
}
