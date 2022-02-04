library(here)
library(ini)

# Read in config file
config <- read.ini(paste0(here(), "/config.ini"))

source(paste0(config$paths$wombat_paper, "/3_inversion/src/partials/base.R"))

args <- list()
args$control_emissions <- paste0(config$paths$geos_inte, "/control-emissions.fst")
args$control_mole_fraction <- paste0(config$paths$geos_inte, "/control-mole-fraction.fst")
args$perturbations <- paste0(config$paths$geos_inte, "/perturbations.fst")
args$sensitivities <- paste0(config$paths$geos_inte, "/sensitivities.fst")

log_info('Loading control emissions')
control_emissions <- fst::read_fst(args$control_emissions)

log_info('Loading perturbations')
perturbations <- fst::read_fst(args$perturbations)

log_info('Loading control mole fraction')
control_mole_fraction <- fst::read_fst(args$control_mole_fraction) %>%
  filter(resolution != 'daily')

control_mole_fraction_arranged_time <- control_mole_fraction %>% arrange(time)

log_info('Loading sensitivities')
# Implicitly prefers hourly to daily sensitivities where available, because
# they come first in the data.frame
sensitivities <- fst::read_fst(args$sensitivities) %>%
  distinct(region, from_month_start, model_id, .keep_all = TRUE)

log_info('Constructing process model')
process_model <- flux_process_model(
  control_emissions,
  control_mole_fraction,
  perturbations,
  sensitivities,
  lag = Inf,
  w_prior = list(shape=4, rate=0.7),#gamma_quantile_prior(1 / 2.5 ^ 2, 1 / 1 ^ 2),
  Psi = matrix(0, nrow = nrow(control_mole_fraction), ncol = 0),
  eta_prior_variance = 5 ^ 2
)

process_model_arranged_time <- flux_process_model(
  control_emissions,
  control_mole_fraction_arranged_time,
  perturbations,
  sensitivities,
  lag = Inf,
  w_prior = list(shape=4, rate=0.7),#gamma_quantile_prior(1 / 2.5 ^ 2, 1 / 1 ^ 2),
  Psi = matrix(0, nrow = nrow(control_mole_fraction_arranged_time), ncol = 0),
  eta_prior_variance = 5 ^ 2
)

log_info('Saving')
saveRDS_gz1(process_model_arranged_time, paste0(config$paths$geos_inte, "/process-model-arranged-time.rds"))