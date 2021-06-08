library(tidyr, warn.conflicts = FALSE)

###############################################################################
# GLOBAL CONSTANTS
###############################################################################

fileloc <- (function() {
  attr(body(sys.function()), "srcfile")
})()$filename

config <- read.ini(paste0(gsub("n2o_inv/inversion.*", "", fileloc), "config.ini"))

intermediate_dir <- config$paths$geos_inte

case <- "IS-FIXEDAO-FIXEDWO5-NOBIAS"

source(paste0(config$paths$wombat_paper, "/4_results/src/partials/base.R"))
source(paste0(config$paths$wombat_paper, "/4_results/src/partials/display.R"))
source(paste0(config$paths$wombat_paper, "/4_results/src/partials/tables.R"))

###############################################################################
# EXECUTION
###############################################################################

log_info('Loading observations')
observations <- fst::read_fst(paste0(intermediate_dir, "/observations.fst"))

log_info('Loading model case')
model_case <- readRDS(paste0(intermediate_dir, "/real-model-", case, ".rds"))

if (is.null(model_case$process_model$H)) {
  log_info('Loading process model')
  process_model <- readRDS(paste0(intermediate_dir, "/process-model.rds"))
  model_case$process_model$H <- process_model$H
  rm(process_model)
  gc(verbose = FALSE)
}

log_info('Loading samples')
samples <- readRDS(paste0(intermediate_dir, "/real-mcmc-samples-", case, ".rds"))

log_info('Computing obs samples')
obs_matching <- match(
  observations$observation_id,
  model_case$process_model$control_mole_fraction$observation_id
)

H_obs <- model_case$process_model$H[obs_matching, ]
Psi_obs <- model_case$process_model$Psi[obs_matching, ]

Y2_prior <- model_case$process_model$control_mole_fraction$co2[obs_matching]
Y2_tilde_samples <- as.matrix(
  H_obs %*% t(as.matrix(window(coda::mcmc(samples$alpha), thin = 10)))
  + if (ncol(samples$eta) > 0) Psi_obs %*% t(as.matrix(window(coda::mcmc(samples$eta), thin = 10))) else 0
)

output <- as_tibble(observations) %>%
  mutate(
    Y2_prior = Y2_prior,
    Y2_tilde_samples = Y2_tilde_samples,
    Y2 = Y2_prior + rowMeans(Y2_tilde_samples),
    observation_group = 'IS',
    variant = 'Correlated')  %>%
  select(
    observation_group,
    variant,
    observation_id,
    time,
    co2,
    co2_error,
    obspack_site,
    Y2_prior,
    Y2,
    Y2_tilde_samples
  )

saveRDS(output, paste0(config$paths$inversion_results, "/obs_matched_samples.rds"))
