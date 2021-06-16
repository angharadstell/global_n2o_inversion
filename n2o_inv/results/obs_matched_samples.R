library(argparser)
library(coda)
library(Matrix)
library(tidyr, warn.conflicts = FALSE)

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

source(Sys.getenv('RESULTS_BASE_PARTIAL'))
source(Sys.getenv('RESULTS_TABLES_PARTIAL'))
source(Sys.getenv('RESULTS_DISPLAY_PARTIAL'))

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

saveRDS(output, args$output)
