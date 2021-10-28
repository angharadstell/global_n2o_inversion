library(here)

library(wombat)

options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/pseudodata/analytical_inversion.R"), chdir = TRUE)

config <- read.ini(paste0(here(), "/config.ini"))

# from change_control_mf.R

inversion_alphas <- function(window, method) {
  start_sample <- config$inversion_constants$burn_in

  samples <- readRDS(sprintf("%s/real-%s-samples-%s_window%02d.rds",
                            config$paths$moving_window_dir,
                            method,
                            config$inversion_constants$land_ocean_equal_model_case,
                            window))

  nsamples <- dim(samples$alpha)[1]
  mean_alphas <- colMeans(samples$alpha[start_sample:nsamples, ])
  print(length(mean_alphas))

  mean_alphas
}

updated_alphas <- function(window, mean_alphas, nregions, ntime) {
  new_alphas <- rep(0, nregions * ntime)
  dim(new_alphas) <- c(1, nregions * ntime)

  # take spinup from first run
  new_alphas[1:(nregions*12)] <- mean_alphas[[1]][1:(nregions*12)]

  # take true results for rest
  if (window > 1) {
    for (i in 1:(window-1)) {
      new_alphas[(nregions*12*i+1):(nregions*12*(i+1))] <- mean_alphas[[i]][(nregions*12+1):(nregions*12*2)]
    }
  }
  new_alphas
}

# from analytical inversion


do_analytical_inversion <- function(observations, control_mf, perturbations, sensitivities) {
  # number of regions
  n_regions <- as.numeric(config$inversion_constants$no_regions) + 1
  # number of months in pseudodata inversion
  n_months <- length(unique(observations$time))

  # make things to do analytical inversion with
  C_M <- diag(rep(0.5^2, n_regions * n_months))
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
  list(mean=m_squiggle, cov=m_post_cov)

}