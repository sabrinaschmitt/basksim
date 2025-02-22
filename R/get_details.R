#' Get Details of a Basket Trial Simulation
#'
#' @template design
#' @template dotdotdot
#'
#' @return A list containing the rejection probabilities, posterior means, mean
#' squared errors of all baskets and the family-wise error rate. For some
#' methods the mean limits of HDI intervals are also returned.
#' @export
#'
#' @examples
#' # Example for a basket trial with Fujikawa's Design
#' design <- setup_fujikawa(k = 3, p0 = 0.2)
#'
#' # Equal sample sizes
#' get_details(design = design, n = 20, p1 = c(0.2, 0.5, 0.5),
#'   lambda = 0.95, epsilon = 2, tau = 0, iter = 100)
#'
#' # Unequal sample sizes
#' get_details(design = design, n = c(15, 20, 25),
#'    p1 = c(0.2, 0.5, 0.5), lambda = 0.95, epsilon = 2,
#'    tau = 0, iter = 100)
#'
get_details <- function(design, ...) {
  UseMethod("get_details", design)
}

#' Get Details of a BMA Basket Trial Simulation
#'
#' @template design_bma
#' @template n
#' @template p1
#' @template lambda
#' @template pmp0
#' @template iter
#' @template data
#' @template dotdotdot
#'
#' @return A list containing the rejection probabilities, posterior means,
#' and mean squared errors for all baskets as well as the family-wise error
#' rate.
#' @export
#'
#' @examples
#' design <- setup_bma(k = 3, p0 = 0.2)
#'
#' # Equal sample sizes
#' get_details(design = design, n = 20, p1 = 0.5, lambda = 0.95,
#'   pmp0 = 1, iter = 100)
#'
#' # Unequal sample sizes
#' get_details(design = design, n = c(15, 20, 25), p1 = 0.5,
#'   lambda = 0.95, pmp0 = 1, iter = 100)

get_details.bma <- function(design, n, p1 = NULL, lambda, pmp0,
                            iter = 1000, data = NULL, ...) {

  # n must be passed in the correct form
  if((length(n) < design$k & length(n) != 1) | length(n) > design$k){
    stop("n must either have length 1 or k")
  }

  if (is.null(p1)) p1 <- rep(design$p0, design$k)
  targ <- design$p0 == p1
  data <- check_data_matrix(data = data, design = design, n = n, p = p1,
                            iter = iter)

  if(length(n) == 1){
    res <- foreach::foreach(i = 1:nrow(data), .combine = 'cfun2',
                            .options.future = list(seed = TRUE)) %dofuture% {
                              res_temp <- bmabasket::bma(pi0 = design$p0, y = data[i, ],
                                                         n = rep(n, design$k), pmp0 = pmp0)
                              list(
                                ifelse(as.vector(res_temp$bmaProbs) > lambda, 1, 0),
                                as.vector(res_temp$bmaMeans)
                              )
                            }
  }else{
    res <- foreach::foreach(i = 1:nrow(data), .combine = 'cfun2',
                            .options.future = list(seed = TRUE)) %dofuture% {
                              res_temp <- bmabasket::bma(pi0 = design$p0, y = data[i, ],
                                                         n = n, pmp0 = pmp0)
                              list(
                                ifelse(as.vector(res_temp$bmaProbs) > lambda, 1, 0),
                                as.vector(res_temp$bmaMeans)
                              )
                            }
  }


  list(
    Rejection_Probabilities = colMeans(res[[1]]),
    FWER = mean(apply(res[[1]], 1, function(x) any(x[targ] == 1))),
    Mean = colMeans(res[[2]]),
    MSE = colMeans(t(t(res[[2]]) - p1)^2)
  )
}



#' Get Details of a BHM Basket Trial Simulation
#'
#' @template design_bhm
#' @template n
#' @template p1
#' @template lambda
#' @template level
#' @template tau_bhm
#' @template iter
#' @template n_mcmc
#' @template data_bhm
#' @template dotdotdot
#'
#' @return A list containing the rejection probabilities, posterior means,
#' mean squared errors and mean limits of HDI intervals for all baskets as well
#' as the family-wise error rate.
#' @export
#'
#' @examples
#' design <- setup_bhm(k = 3, p0 = 0.2, p_target = 0.5)
#'
#' # Equal sample sizes
#' get_details(design = design, n = 20, p1 = c(0.2, 0.5, 0.5),
#'   lambda = 0.95, tau_scale = 1, iter = 100)
#'
#' # Unequal sample sizes
#' get_details(design = design, n = c(15, 20, 25), p1 = c(0.2, 0.5, 0.5),
#'   lambda = 0.95, tau_scale = 1, iter = 100)
get_details.bhm <- function(design, n, p1 = NULL, lambda, level = 0.95,
                            tau_scale, iter = 1000, n_mcmc = 10000,
                            data = NULL, ...) {

  # n must be passed in the correct form
  if((length(n) < design$k & length(n) != 1) | length(n) > design$k){
    stop("n must either have length 1 or k")
  }

  if (is.null(p1)) p1 <- rep(design$p0, design$k)
  targ <- design$p0 == p1
  data <- check_data_bhmbasket(data = data, design = design, n = n, p = p1,
    iter = iter)

  analyses <- suppressMessages(bhmbasket::performAnalyses(
    scenario_list = data,
    evidence_levels = c(lambda, 1 - level),
    method_names = "berry",
    target_rates = rep(design$p_target, design$k),
    prior_parameters_list = bhmbasket::setPriorParametersBerry(
      mu_mean = design$mu_mean,
      mu_sd = design$mu_sd,
      tau_scale = tau_scale
    ),
    n_mcmc_iterations = n_mcmc
  ))

  br <- paste0("c(", paste0("x[", 1:design$k, "] > ", design$p0,
    collapse = ", "), ")")

  res <- bhmbasket::getGoDecisions(
    analyses_list = analyses,
    cohort_names = paste("p", 1:design$k, sep = "_"),
    evidence_levels = rep(lambda, design$k),
    boundary_rules = str2lang(br)
  )$scenario_1$decisions_list$berry[, -1]

  est <- bhmbasket::getEstimates(analyses, point_estimator = "mean",
    alpha_level = (1 - level))$berry

  list(
    Rejection_Probabilities = unname(colMeans(res)),
    FWER = mean(apply(res, 1, function(x) any(x[targ] == 1))),
    Mean = unname(est[, 1]),
    MSE = unname(est[, 7]),
    Lower_CL = unname(est[, 3]),
    Upper_CL = unname(est[, 5])
  )
}

#' Get Details of a Basket Trial Simulation with the EXNEX Design
#'
#' @template design_exnex
#' @template n
#' @template p1
#' @template lambda
#' @template level
#' @template tau_exnex
#' @template w_exnex
#' @template iter
#' @template n_mcmc
#' @template data_bhm
#' @template dotdotdot
#'
#' @return A list containing the rejection probabilities, posterior means,
#' mean squared errors and mean limits of HDI intervals for all baskets as well
#' as the family-wise error rate.
#' @export
#'
#' @examples
#' design <- setup_exnex(k = 3, p0 = 0.2)
#'
#' # Equal sample sizes
#' get_details(design = design, n = 20, p1 = c(0.2, 0.5, 0.5),
#'   lambda = 0.95, tau_scale = 1, w = 0.5, iter = 100)
#'
#' # Unequal sample sizes
#' get_details(design = design, n = c(15, 20, 25), p1 = c(0.2, 0.5, 0.5),
#'   lambda = 0.95, tau_scale = 1, w = 0.5, iter = 100)
get_details.exnex <- function(design, n, p1 = NULL, lambda, level = 0.95,
                              tau_scale, w, iter = 1000, n_mcmc = 10000,
                              data = NULL, ...) {

  # n must be passed in the correct form
  if((length(n) < design$k & length(n) != 1) | length(n) > design$k){
    stop("n must either have length 1 or k")
  }

  if (is.null(p1)) p1 <- rep(design$p0, design$k)
  targ <- design$p0 == p1
  data <- check_data_bhmbasket(data = data, design = design, n = n, p = p1,
    iter = iter)

  analyses <- suppressMessages(bhmbasket::performAnalyses(
    scenario_list = data,
    evidence_levels = c(lambda, 1 - level),
    method_names = "exnex",
    prior_parameters_list = bhmbasket::setPriorParametersExNex(
      mu_mean = design$mu_mean,
      mu_sd = design$mu_sd,
      tau_scale = tau_scale,
      mu_j = rep(design$basket_mean, design$k),
      tau_j = rep(design$basket_sd, design$k),
      w_j = w
    ),
    n_mcmc_iterations = n_mcmc
  ))

  br <- paste0("c(", paste0("x[", 1:design$k, "] > ", design$p0,
    collapse = ", "), ")")
  res <- bhmbasket::getGoDecisions(
    analyses_list = analyses,
    cohort_names = paste("p", 1:design$k, sep = "_"),
    evidence_levels = rep(lambda, design$k),
    boundary_rules = str2lang(br)
  )$scenario_1$decisions_list$exnex[, -1]

  est <- bhmbasket::getEstimates(analyses, point_estimator = "mean",
    alpha_level = (1 - level))$exnex

  list(
    Rejection_Probabilities = unname(colMeans(res)),
    FWER = mean(apply(res, 1, function(x) any(x[targ] == 1))),
    Mean = unname(est[, 1]),
    MSE = unname(est[, 7]),
    Lower_CL = unname(est[, 3]),
    Upper_CL = unname(est[, 5])
  )
}

#' Get Details of a Basket Trial Simulation with Fujikawa's Design
#'
#' @template design_fujikawa
#' @template n
#' @template p1
#' @template lambda
#' @template level
#' @template tuning_fujikawa
#' @template iter
#' @template data
#' @template dotdotdot
#'
#' @return A list containing the rejection probabilities, posterior means,
#' mean squared errors and mean limits of HDI intervals for all baskets as well
#' as the family-wise error rate.
#' @export
#'
#' @examples
#' design <- setup_fujikawa(k = 3, p0 = 0.2)
#'
#' # Equal sample sizes
#' get_details(design = design, n = 20, p1 = c(0.2, 0.5, 0.5),
#'   lambda = 0.95, epsilon = 2, tau = 0, iter = 100)
#'
#' # Unequal sample sizes
#' get_details(design = design, n = c(15, 20, 25), p1 = c(0.2, 0.5, 0.5),
#'   lambda = 0.95, epsilon = 2, tau = 0, iter = 100)

get_details.fujikawa <- function(design, n, p1 = NULL, lambda, level = 0.95,
                                 epsilon, tau, logbase = 2, iter = 1000,
                                 data = NULL, ...) {
  # n must be passed in the correct form
  if((length(n) < design$k & length(n) != 1) | length(n) > design$k){
    stop("n must either have length 1 or k")
  }

  if (is.null(p1)) p1 <- rep(design$p0, design$k)
  targ <- design$p0 == p1
  weights <- get_weights_jsd(design = design, n = n, epsilon = epsilon,
                             tau = tau, logbase = logbase)
  data <- check_data_matrix(data = data, design = design, n = n, p = p1,
                            iter = iter)

  res <- foreach::foreach(i = 1:nrow(data), .combine = 'cfun1') %dofuture% {
    shape_loop <- beta_borrow_fujikawa(design = design, n = n, r = data[i, ],
                                       weights = weights)
    res_loop <- ifelse(post_beta(shape_loop, design$p0) >= lambda, 1, 0)
    mean_loop <- apply(shape_loop, 2, function(x) x[1] / (x[1] + x[2]))
    hdi_loop <- apply(shape_loop, 2, function(x) HDInterval::hdi(stats::qbeta,
                                                                 shape1 = x[1], shape2 = x[2], credMass = level))
    list(res_loop, mean_loop, hdi_loop[1, ], hdi_loop[2, ])
  }

  list(
    Rejection_Probabilities = colMeans(res[[1]]),
    FWER = mean(apply(res[[1]], 1, function(x) any(x[targ] == 1))),
    Mean = colMeans(res[[2]]),
    MSE = colMeans(t(t(res[[2]]) - p1)^2),
    Lower_CL = colMeans(res[[3]]),
    Upper_CL = colMeans(res[[4]])
  )
}




#' Get Details of a Basket Trial Simulation with the Calibrated Power Prior
#' Design
#'
#' @template design_cpp
#' @template n
#' @template p1
#' @template lambda
#' @template level
#' @template tuning_cpp
#' @template iter
#' @template data
#' @template dotdotdot
#'
#' @return A list containing the rejection probabilities, posterior means,
#' mean squared errors and mean limits of HDI intervals for all baskets as well
#' as the family-wise error rate.
#' @export
#'
#' @examples
#' design <- setup_cpp(k = 3, p0 = 0.2)
#'
#' # Equal sample sizes
#' get_details(design = design, n = 20, p1 = c(0.2, 0.5, 0.5),
#'   lambda = 0.95, tune_a = 1, tune_b = 1, iter = 100)
#'
#' # Unequal sample sizes
#' get_details(design = design, n = c(15, 20, 25), p1 = c(0.2, 0.5, 0.5),
#'   lambda = 0.95, tune_a = 1, tune_b = 1, iter = 100)
get_details.cpp <- function(design, n, p1 = NULL, lambda, level = 0.95,
                            tune_a, tune_b, iter = 1000, data = NULL, ...) {
  # n must be passed in the correct form
  if((length(n) < design$k & length(n) != 1) | length(n) > design$k){
    stop("n must either have length 1 or k")
  }

  if (is.null(p1)) p1 <- rep(design$p0, design$k)
  targ <- design$p0 == p1
  weights <- get_weights_cpp(n = n, tune_a = tune_a, tune_b = tune_b)
  data <- check_data_matrix(data = data, design = design, n = n, p = p1,
                            iter = iter)

  res <- foreach::foreach(i = 1:nrow(data), .combine = 'cfun1') %dofuture% {
    shape_loop <- beta_borrow_cpp(design = design, n = n, r = data[i, ],
                                  weights = weights)
    res_loop <- ifelse(post_beta(shape_loop, design$p0) >= lambda, 1, 0)
    mean_loop <- apply(shape_loop, 2, function(x) x[1] / (x[1] + x[2]))
    hdi_loop <- apply(shape_loop, 2, function(x) HDInterval::hdi(stats::qbeta,
                                                                 shape1 = x[1], shape2 = x[2], credMass = level))
    list(res_loop, mean_loop, hdi_loop[1, ], hdi_loop[2, ])
  }
  list(
    Rejection_Probabilities = colMeans(res[[1]]),
    FWER = mean(apply(res[[1]], 1, function(x) any(x[targ] == 1))),
    Mean = colMeans(res[[2]]),
    MSE = colMeans(t(t(res[[2]]) - p1)^2),
    Lower_CL = colMeans(res[[3]]),
    Upper_CL = colMeans(res[[4]])
  )
}





#' Get Details of a Basket Trial Simulation with the Limited Calibrated Power
#' Prior Design
#'
#' @template design_cpplim
#' @template n
#' @template p1
#' @template lambda
#' @template level
#' @template tuning_cpp
#' @template iter
#' @template data
#' @template dotdotdot
#'
#' @return A list containing the rejection probabilities, posterior means,
#' mean squared errors and mean limits of HDI intervals for all baskets as well
#' as the family-wise error rate.
#' @export
#'
#' @examples
#' design <- setup_cpplim(k = 3, p0 = 0.2)
#'
#' # Equal sample sizes
#' get_details(design = design, n = 20, p1 = c(0.2, 0.5, 0.5),
#'   lambda = 0.95, tune_a = 1, tune_b = 1, iter = 100)
#'
#' # Unequal sample sizes
#' get_details(design = design, n = c(15, 20, 25), p1 = c(0.2, 0.5, 0.5),
#'   lambda = 0.95, tune_a = 1, tune_b = 1, iter = 100)
get_details.cpplim <- function(design, n, p1 = NULL, lambda, level = 0.95,
                            tune_a, tune_b, iter = 1000, data = NULL, ...) {

  # n must be passed in the correct form
  if((length(n) < design$k & length(n) != 1) | length(n) > design$k){
    stop("n must either have length 1 or k")
  }

  if (is.null(p1)) p1 <- rep(design$p0, design$k)
  targ <- design$p0 == p1

  weights <- get_weights_cpp(n = n, tune_a = tune_a, tune_b = tune_b)

  alpha_0 <- get_alpha_0_app(design = design, n = n)

  data <- check_data_matrix(data = data, design = design, n = n, p = p1,
                            iter = iter)

  res <- foreach::foreach(i = 1:nrow(data), .combine = 'cfun1') %dofuture% {
    shape_loop <- beta_borrow_cpplim(design = design, n = n, r = data[i, ],
                                  weights = weights, alpha_0 = alpha_0)
    res_loop <- ifelse(post_beta(shape_loop, design$p0) >= lambda, 1, 0)
    mean_loop <- apply(shape_loop, 2, function(x) x[1] / (x[1] + x[2]))
    hdi_loop <- apply(shape_loop, 2, function(x) HDInterval::hdi(stats::qbeta,
                                                                 shape1 = x[1], shape2 = x[2], credMass = level))
    list(res_loop, mean_loop, hdi_loop[1, ], hdi_loop[2, ])
  }
  list(
    Rejection_Probabilities = colMeans(res[[1]]),
    FWER = mean(apply(res[[1]], 1, function(x) any(x[targ] == 1))),
    Mean = colMeans(res[[2]]),
    MSE = colMeans(t(t(res[[2]]) - p1)^2),
    Lower_CL = colMeans(res[[3]]),
    Upper_CL = colMeans(res[[4]])
  )

}




#' Get Details of a Basket Trial Simulation with the Adaptive Power Prior Design
#' for sequential clinical trials
#'
#' @template design_app
#' @template n
#' @template p1
#' @template lambda
#' @template level
#' @template iter
#' @template data
#' @template dotdotdot
#'
#' @return A list containing the rejection probabilities, posterior means,
#' mean squared errors and mean limits of HDI intervals for all baskets as well
#' as the family-wise error rate.
#' @export
#'
#' @examples
#' design <- setup_app(k = 3, p0 = 0.2)
#'
#' # Equal sample sizes
#' get_details(design = design, n = 20, p1 = c(0.2, 0.5, 0.5),
#'  lambda = 0.95, iter = 100)
#'
#' # Unequal sample sizes
#' get_details(design = design, n = c(15, 20, 25), p1 = c(0.2, 0.5, 0.5),
#'  lambda = 0.95, iter = 100)
get_details.app <- function(design, n, p1 = NULL, lambda, level = 0.95,
                               iter = 1000, data = NULL, ...) {

  # n must be passed in the correct form
  if((length(n) < design$k & length(n) != 1) | length(n) > design$k){
    stop("n must either have length 1 or k")
  }

  if (is.null(p1)) p1 <- rep(design$p0, design$k)
  targ <- design$p0 == p1

  data <- check_data_matrix(data = data, design = design, n = n, p = p1,
                            iter = iter)

  alpha_0 <- get_alpha_0_app(design = design, n = n)

  res <- foreach::foreach(i = 1:nrow(data), .combine = 'cfun1') %dofuture% {
    shape_loop <- beta_borrow_app(design = design, n = n, r = data[i, ],
                                     alpha_0 = alpha_0)
    res_loop <- ifelse(post_beta(shape_loop, design$p0) >= lambda, 1, 0)
    mean_loop <- apply(shape_loop, 2, function(x) x[1] / (x[1] + x[2]))
    hdi_loop <- apply(shape_loop, 2, function(x) HDInterval::hdi(stats::qbeta,
                                                                 shape1 = x[1], shape2 = x[2], credMass = level))
    list(res_loop, mean_loop, hdi_loop[1, ], hdi_loop[2, ])
  }
  list(
    Rejection_Probabilities = colMeans(res[[1]]),
    FWER = mean(apply(res[[1]], 1, function(x) any(x[targ] == 1))),
    Mean = colMeans(res[[2]]),
    MSE = colMeans(t(t(res[[2]]) - p1)^2),
    Lower_CL = colMeans(res[[3]]),
    Upper_CL = colMeans(res[[4]])
  )

}


