library(argparser)
library(dplyr)
library(here)
library(ini)
library(lubridate)
library(MASS)
library(wombat)

###############################################################################
# GLOBAL CONSTANTS
###############################################################################

config <- read.ini(paste0(here(), "/config.ini"))

###############################################################################
# FUNCTIONS
###############################################################################

# turn alphas into observations
alpha_to_obs <- function(alpha_samples, obs_err, control_mf, perturbations, sensitivities) {
  # create H matrix
  H <- transport_matrix(perturbations,
                        control_mf,
                        sensitivities,
                        lag = Inf)

  # turn alpha samples into mole fraction samples
  Y2_prior <- control_mf$co2
  Y2_tilde_samples <- as.matrix(
    H %*% t(as.matrix(alpha_samples))
  )
  # add measurement noise
  set.seed(0)
  measurement_noise <- rnorm(n = (dim(Y2_tilde_samples)[1] * dim(Y2_tilde_samples)[2]),
                             mean = 0, sd = obs_err)
  dim(measurement_noise) <- dim(Y2_tilde_samples)
  obs_samples <- Y2_prior + Y2_tilde_samples + measurement_noise

  obs_samples
}

# create a series of AR(1) alphas using arima.sim
alpha_generate <- function(n_samples, n_regions, n_months, a_std, a_corr) {
  set.seed(0)
  epsilon_std <- sqrt(a_std^2 * (1 - a_corr^2))
  alpha_samples <- t(sapply(1:n_samples,
                            function(i) {
                              as.vector(sapply(1:n_regions,
                                               function(i) {
                                                 arima.sim(model = list(ar = a_corr),
                                                           n = n_months,
                                                           sd = epsilon_std)}))}))

  alpha_samples
}

###############################################################################
# EXECUTION
###############################################################################

main <- function() {
  args <- arg_parser("", hide.opts = TRUE) %>%
    add_argument("--measurement-noise", "") %>%
    add_argument("--acorr", "") %>%
    add_argument("--alpha-range", "") %>%
    add_argument("--output-suffix", "") %>%
    parse_args()

  print(as.numeric(args$measurement_noise))
  print(as.numeric(args$acorr))
  print(as.numeric(args$alpha_range))

  # read in inversion intermediates
  observations <- fst::read_fst(sprintf("%s/model-err-n2o_std-observations_window01.fst", config$path$geos_inte))
  perturbations <- fst::read_fst(sprintf("%s/perturbations_window01.fst", config$path$geos_inte))
  control_mf <- fst::read_fst(sprintf("%s/control-mole-fraction-window01.fst", config$path$geos_inte))
  sensitivities <- fst::read_fst(sprintf("%s/sensitivities_window01.fst", config$path$geos_inte))

  # number of regions
  n_regions <- as.numeric(config$inversion_constants$no_regions) + 1
  # number of alpha samples to take
  n_samples <- as.numeric(config$pseudodata$n_samples)
  # number of months in pseudodata inversion
  n_months_pseudo <- as.numeric(config$pseudodata$n_months)

  # draw alpha samples
  alpha_std <- 0.5 * as.numeric(args$alpha_range)
  alpha_samples <- alpha_generate(n_samples, n_regions, n_months_pseudo, alpha_std, as.numeric(args$acorr))

  # turn alpha samples into mole fraction samples
  obs_samples <- alpha_to_obs(alpha_samples,
                              observations$co2_error * as.numeric(args$measurement_noise),
                              control_mf, perturbations, sensitivities)

  # save observations for inversion
  for (i  in 1:n_samples) {
      pseudo_obs <- observations %>% mutate(co2 = obs_samples[, i])
      fst::write_fst(pseudo_obs, sprintf("%s/observations_%s_%04d.fst", config$paths$pseudodata_dir, args$output_suffix, i))
  }

  saveRDS(alpha_samples,
          sprintf("%s/alpha_samples_%s.rds", config$paths$pseudodata_dir, args$output_suffix))
}

if (getOption("run.main", default = TRUE)) {
   main()
}
