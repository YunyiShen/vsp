#' Non-Parametric Factor Analysis via Vintage Sparse PCA
#'
#' This code implements TODO.
#'
#' @param x Either a graph adjacency matrix, [igraph::igraph] or
#'  [tidygraph::tbl_graph]. If `x` is a [matrix] or [Matrix::Matrix]
#'  then `x[i, j]` should correspond to the edge going from node `i`
#'  to node `j`.
#'
#' @param k The number of factors to calculate.
#'
#' @param center Should the adjacency matrix be row *and* column centered?
#'  Defaults to `TRUE`.
#'
#' @param normalize Should the graph laplacian be used instead of the
#'  raw adjacency matrix? Defaults to `TRUE`. If `center = TRUE`, `A` will
#'  first be centered and then normalized.
#'
#' @param tau_row Row regularization term. Default is `NULL`, in which case
#'  we use the row degree. Ignored when `normalize = FALSE`.
#'
#' @param tau_col Column regularization term. Default is `NULL`, in which case
#'  we use the column degree. Ignored when `normalize = FALSE`.
#'
#' @param ... Ignored.
#'
#' @details Sparse SVDs use `RSpectra` for performance.
#'
#' @return An object of class `vsp`. TODO: Details
#'
#' @export
#'
#' @examples
#'
#' library(LRMF3)
#'
#' vsp(ml100k, rank = 5, scale = TRUE)
#' vsp(ml100k, rank = 5, rescale = FALSE)
#' vsp(ml100k, rank = 5)
#'
#'
vsp <- function(x, rank, ...) {
  # ellipsis::check_dots_used()
  UseMethod("vsp")
}

#' @rdname vsp
#' @export
vsp.default <- function(x, rank, ...) {
  stop(glue("No `vsp` method for objects of class {class(x)}. "))
}

#' @importFrom invertiforms DoubleCenter RegularizedLaplacian
#' @importFrom invertiforms transform inverse_transform
#' @rdname vsp
#' @export
vsp.matrix <- function(x, rank, ..., center = FALSE, recenter = FALSE,
                       scale = TRUE, rescale = scale,
                       tau_row = NULL, tau_col = NULL) {

  if (rank < 2)
    stop("`rank` must be at least two.", call. = FALSE)

  if (recenter && !center)
    stop("`recenter` must be FALSE when `center` is FALSE.", call. = FALSE)

  if (rescale && !scale)
    stop("`rescale` must be FALSE when `scale` is FALSE.", call. = FALSE)

  n <- nrow(x)
  d <- ncol(x)

  transformers <- list()

  if (center) {
    centerer <- DoubleCenter(x)
    transformers <- append(transformers, centerer)
    L <- transform(centerer, x)
  } else{
    L <- x
  }

  if (scale) {
    scaler <- RegularizedLaplacian(L, tau_row = tau_row, tau_col = tau_col)
    transformers <- append(transformers, scaler)
    L <- transform(scaler, L)
  }

  # this includes a call to isSymmetric that we might be able to skip out on
  s <- svds(L, k = rank, nu = rank, nv = rank)

  R_U <- stats::varimax(s$u, normalize = FALSE)$rotmat
  R_V <- stats::varimax(s$v, normalize = FALSE)$rotmat

  Z <- sqrt(n) * s$u %*% R_U
  Y <- sqrt(d) * s$v %*% R_V

  B <- t(R_U) %*% Diagonal(n = rank, x = s$d) %*% R_V / (sqrt(n) * sqrt(d))

  fa <- vsp_fa(
    u = s$u, d = s$d, v = s$v,
    Z = Z, B = B, Y = Y,
    R_U = R_U, R_V = R_V,
    transformers = transformers
  )

  if (rescale) {
    fa <- inverse_transform(scaler, fa)
  }

  if (recenter) {
    fa <- inverse_transform(centerer, fa)
  }

  fa <- make_skew_positive(fa)
  fa
}

#' Perform varimax rotation on a low rank matrix factorization
#'
#' @param x TODO
#'
#' @param rank TODO
#' @param ... TODO
#' @param centerer TODO
#' @param scaler TODO
#'
#' @export
#'
#' @examples
#'
#' library(fastadi)
#'
#' mf <- adaptive_impute(ml100k, rank = 20, max_iter = 5)
#' fa <- vsp(mf)
#'
vsp.svd_like <- function(x, rank, ...,
                         centerer = NULL, scaler = NULL,
                         recenter = FALSE, rescale = TRUE,
                         rownames = NULL, colnames = NULL) {

  n <- nrow(x$u)
  d <- nrow(x$v)

  R_U <- stats::varimax(x$u, normalize = FALSE)$rotmat
  R_V <- stats::varimax(x$v, normalize = FALSE)$rotmat

  Z <- sqrt(n) * x$u %*% R_U
  Y <- sqrt(d) * x$v %*% R_V

  B <- t(R_U) %*% Diagonal(n = rank, x = x$d) %*% R_V / (sqrt(n) * sqrt(d))

  fa <- vsp_fa(
    u = x$u, d = x$d, v = x$v,
    Z = Z, B = B, Y = Y,
    R_U = R_U, R_V = R_V,
    transformers = list(centerer, scaler),
    rownames = rownames, colnames = colnames
  )

  if (!is.null(scaler) && rescale) {
    fa <- inverse_transform(scaler, fa)
  }

  if (!is.null(centerer) && recenter) {
    fa <- inverse_transform(centerer, fa)
  }

  fa <- make_skew_positive(fa)
  fa
}

#' @rdname vsp
#' @export
vsp.Matrix <- vsp.matrix

#' @rdname vsp
#' @export
vsp.dgCMatrix <- vsp.matrix

#' @rdname vsp
#' @export
vsp.igraph <- function(x, rank, ..., attr = NULL) {
  x <- igraph::get.adjacency(x, sparse = TRUE, attr = attr)
  vsp.matrix(x, rank, ...)
}
