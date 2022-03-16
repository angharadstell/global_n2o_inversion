library(here)
library(wombat)

source(paste0(here(), "/n2o_inv/pseudodata/analytical_inversion_functions.R"), chdir = TRUE)

config <- read.ini(paste0(here(), "/config.ini"))

# used in change_control_mf.R and compare_to_full_analytical.R
# reads in the mcmc samples for a window inversion and works out the mean alpha parameters
# window is which window inversion results to read in
# case is the case name for that particular inversion set
# method is "mcmc" or "analytical" depending on which method you're looking at
inversion_alphas <- function(window, case, method) {
  start_sample <- as.numeric(config$inversion_constants$burn_in) + 1

  samples <- readRDS(sprintf("%s/real-%s-samples-%s_window%02d.rds",
                            config$paths$moving_window_dir,
                            method,
                            case,
                            window))

  nsamples <- dim(samples$alpha)[1]
  # take mean discarding burn in period
  mean_alphas <- colMeans(samples$alpha[start_sample:nsamples, ])
  print(length(mean_alphas))

  mean_alphas
}

# used in change_control_mf.R
# works out the alphas for the full inversion (up to whatever window has been reached)
# if the window hasn't been run yet, the alphas are zeros (i.e. the prior)
# window = 1 will output alphas for the spinup year, the rest are zeros
# window = 2 will output alphas for the spinup year and the first year, the rest are zeros etc
# mean alphas is a list of the window inversion alphas (e.g. a list of the output of the 
# inversion_alphas function above)
# nregions is the number of regions in the inversion
# ntime is the number of months in the whole inversion, including spinup
updated_alphas <- function(window, mean_alphas, nregions, ntime) {
  new_alphas <- rep(0, nregions * ntime)
  dim(new_alphas) <- c(1, nregions * ntime)

  # take spinup from first run
  new_alphas[1:(nregions * 12)] <- mean_alphas[[1]][1:(nregions * 12)]

  # take true results for rest
  if (window > 1) {
    for (i in 1:(window - 1)) {
      new_alphas[(nregions * 12 * i + 1):(nregions * 12 * (i + 1))] <- mean_alphas[[i]][(nregions * 12 + 1):(nregions * 12 * 2)]
    }
  }
  new_alphas
}

# used in analytical_inversion.R, check_change_control_mf.R, compare_to_full_analytical.R
# does an analytical inversion using the WOMBAT intermediates
do_analytical_inversion <- function(observations, control_mf, perturbations, sensitivities) {
  # number of regions
  n_regions <- as.numeric(config$inversion_constants$no_regions) + 1
  # number of months in pseudodata inversion
  n_months <- length(unique(observations$time))

  # make things to do analytical inversion with
  C_M <- diag(rep(0.4^2, n_regions * n_months))#make_C_M(0.5^2, 0.99, c(2, 5, 8, 12), n_regions, n_months)
  C_D <- make_C_D(observations)
  m_prior <- rep(0, n_regions * n_months)
  G <- transport_matrix(perturbations,
                        control_mf,
                        sensitivities,
                        lag = Inf)

  # do analytical inversion
  print("calculating mean...")
  m_squiggle <- m_post(control_mf, m_prior, C_M, G, C_D, observations$co2)
  print("calculating cov...")
  m_post_cov <- m_post_cov_calc(C_M, G, C_D)

  print("outputting...")
  list(mean = m_squiggle, cov = m_post_cov)
}
