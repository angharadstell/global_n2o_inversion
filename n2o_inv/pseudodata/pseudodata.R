library(argparser)
library(dplyr)
library(ini)
library(lubridate)
library(MASS)
library(wombat)

args <- arg_parser('', hide.opts = TRUE) %>%
  add_argument('--measurement-noise', '') %>%
  add_argument('--a-corr', '') %>%
  add_argument('--alpha-range', '') %>%
  add_argument('--output-suffix', '') %>%
  parse_args()

###############################################################################
# GLOBAL CONSTANTS
###############################################################################
fileloc <- (function() {
  attr(body(sys.function()), "srcfile")
})()$filename

# config <- read.ini(paste0(gsub("n2o_inv/pseudodata.*", "", fileloc),
#                    "config.ini"))
config <- read.ini("/home/as16992/global_n2o_inversion/config.ini")

int_loc <- config$path$geos_inte

# read in proper inversion intermediates
observations <- fst::read_fst(sprintf("%s/observations_pseudo.fst", int_loc))
perturbations <- fst::read_fst(sprintf("%s/perturbations_pseudo.fst", int_loc))
control_mf <- fst::read_fst(sprintf("%s/control-mole-fraction-pseudo.fst", int_loc))
sensitivities <- fst::read_fst(sprintf("%s/sensitivities_pseudo.fst", int_loc))

###############################################################################
# FUNCTIONS
###############################################################################

alpha_to_obs <- function(alpha_samples, obs_err) {
  # match observation ids
  obs_matching <- match(
    observations$observation_id,
    control_mf$observation_id
  )

  # create H matrix
  H <- transport_matrix(perturbations,
                        control_mf,
                        sensitivities,
                        lag = Inf)
  # H_obs ordered by time then site
  H_obs <- H[obs_matching, ]

  # turn alpha samples into mole fraction samples
  Y2_prior <- control_mf$co2[obs_matching]
  Y2_tilde_samples <- as.matrix(
    H_obs %*% t(as.matrix(alpha_samples))
  )
  # add measurement noise
  set.seed(0)
  measurement_noise <-  rnorm(n = (dim(Y2_tilde_samples)[1]*dim(Y2_tilde_samples)[2]),
                              mean = 0, sd = obs_err * as.numeric(args$measurement_noise))
  dim(measurement_noise) <- dim(Y2_tilde_samples)
  obs_samples <- Y2_prior + Y2_tilde_samples + measurement_noise

  obs_samples
}

###############################################################################
# EXECUTION
###############################################################################

main <- function() {
  # number of regions
  n_regions <- as.numeric(config$inversion_constants$no_regions) + 1
  # number of alpha samples to take
  n_samples <- as.numeric(config$pseudodata$n_samples)
  # number of months in pseudodata inversion
  n_months_pseudo <- as.numeric(config$pseudodata$n_months)

  # draw alpha samples
  set.seed(0)
  # alpha_samples <- mvrnorm(n = n_samples,
  #                          mu = rep(0, n_regions * n_months_pseudo),
  #                          diag(rep((0.5 * as.numeric(args$alpha_range))^2, n_regions * n_months_pseudo)))
  alpha_samples <- t(sapply(1:n_samples,
                            function(i) {as.vector(sapply(1:n_regions,
                                                          function(i) {arima.sim(model = list(ar = as.numeric(args$a_corr)),
                                                          n = n_months_pseudo,
                                                          sd = 0.5 * as.numeric(args$alpha_range))}))}))

  # turn alpha samples into mole fraction samples
  obs_samples <- alpha_to_obs(alpha_samples, observations$co2_error)

  # save observations for inversion
  for (i  in 1:n_samples) {
      pseudo_obs <- observations %>% mutate(co2 = obs_samples[, i])
      fst::write_fst(pseudo_obs, sprintf("%s/observations_%s_%04d.fst", config$paths$pseudodata_dir, args$output_suffix, i))
  }

  saveRDS(alpha_samples,
          sprintf("%s/alpha_samples_%s.rds", config$paths$pseudodata_dir, args$output_suffix))
}

if (getOption('run.main', default = TRUE)) {
   main()
}
