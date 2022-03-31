library(argparser)
library(here)
library(ini)
library(logger)
library(wombat)

#log_threshold(TRACE)

source(Sys.getenv("INVERSION_BASE_PARTIAL"))

###############################################################################
# GLOBAL CONSTANTS
###############################################################################

config <- read.ini(paste0(here(), "/config.ini"))

###############################################################################
# EXECUTION
###############################################################################

args <- arg_parser("", hide.opts = TRUE) %>%
  add_argument("--intermediate-dir", "") %>%
  add_argument("--process-model", "") %>%
  add_argument("--model-case", "") %>%
  add_argument("--truncation", "") %>%
  parse_args()

log_info("Loading model")
model_case <- readRDS(sprintf("%s/real-model-%s.rds", args$intermediate_dir, args$model_case))

if (is.null(model_case$process_model$H)) {
  log_info("Loading process model")
  process_model <- readRDS(sprintf("%s/%s.rds", args$intermediate_dir, args$process_model))
  model_case$process_model$H <- process_model$H
  rm(process_model)
  gc(verbose = FALSE)
}

log_info("Running MCMC")
# do inversion in WOMBAT library
# n_iterations (int): number of iterations in MCMC chain
# truncation (bool): whether to truncate alphas at -1 or not,
#                    be careful, this also truncates the beta parameters
# start (list): what starting values to use for MCMC. If not specified then
#               a random sample is taken. Start must be specified with alphas
#               that are all greater than or equal to -1 when truncation is
#               TRUE, or the inversion will fail as it starts with an
#               impossible set of values.
# measurement_model (list): WOMBAT measurement model intermediate
# process_model (list): WOMBAT process model intermediate
# show_progress (bool): whether to show a progress bar or not, but doesn't
#                       work if submitting to the queue system anyway
# use_tensorflow (bool): can only use tensorflow/ GPU set up if errors are
#                        correlated as in the original WOMBAT paper (rho is
#                        being solved for)
output <- wombat::inversion_mcmc(
  n_iterations = as.numeric(config$inversion_constants$no_samples),
  truncation = as.logical(args$truncation),
  start = list("alpha" = rep(0, ncol(model_case$process_model$H))),
  model_case$measurement_model,
  model_case$process_model,
  show_progress = FALSE,
  use_tensorflow = FALSE
)

log_info("Saving")
saveRDS(output, sprintf("%s/real-mcmc-samples-%s.rds", args$intermediate_dir, args$model_case))

log_info("Done")
