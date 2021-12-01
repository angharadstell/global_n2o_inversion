library(argparser)
library(coda)
library(here)
library(ini)
library(Matrix)
library(tidyr, warn.conflicts = FALSE)
library(wombat)

###############################################################################
# GLOBAL CONSTANTS
###############################################################################

args <- arg_parser('', hide.opts = TRUE) %>%
  add_argument('--model-case', '') %>%
  add_argument('--process-model', '') %>%
  add_argument('--samples', '') %>%
  add_argument('--observations', '') %>%
  add_argument('--output', '') %>%
  parse_args()

config <- read.ini(paste0(here(), "/config.ini"))

# args <- vector(mode = "list", length = 5)

# args$model_case <- paste0(config$paths$geos_inte, "/real-model-", config$inversion_constants$land_ocean_equal_model_case, ".rds")
# args$process_model <- paste0(config$paths$geos_inte, "/process-model.rds")
# args$samples <- paste0(config$paths$geos_inte, "/real-mcmc-samples-", config$inversion_constants$land_ocean_equal_model_case, ".rds")
# args$observations <- paste0(config$paths$geos_inte, "/observations.fst")
# args$output <- paste0(config$paths$inversion_result, "/obs_matched_samples.rds")

source(paste0(config$paths$wombat_paper, "/4_results/src/partials/base.R"))

###############################################################################
# EXECUTION
###############################################################################

log_info('Loading observations')
observations <- fst::read_fst(args$observations)

log_info('Loading model case')
model_case <- readRDS(args$model_case)

if (is.null(model_case$process_model$H)) {
  log_info('Loading process model')
  process_model <- readRDS(args$process_model)
  model_case$process_model$H <- process_model$H
  rm(process_model)
  gc(verbose = FALSE)
}

log_info('Loading samples')
samples <- readRDS(args$samples)

log_info('Computing obs samples')
Y2_prior <- model_case$process_model$control_mole_fraction$co2

observation_pp_samples <- generate_posterior_predictive(
  model_case$measurement_model,
  'Z2_hat',
  model_case$process_model,
  samples
)

pp_bounds <- matrixStats::colQuantiles(observation_pp_samples, probs = c(0.025, 0.975))

output <- as_tibble(observations) %>%
  mutate(
    Y2_prior = Y2_prior,
    Z2_hat = colMeans(observation_pp_samples),
    Z2_hat_lower = pp_bounds[,1],
    Z2_hat_upper = pp_bounds[,2])  %>%
  select(
    observation_group,
    observation_id,
    time,
    co2,
    co2_error,
    obspack_site,
    Y2_prior,
    Z2_hat,
    Z2_hat_lower,
    Z2_hat_upper
  )

saveRDS(output, args$output)
