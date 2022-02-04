library(logger)
library(wombat)

#log_threshold(TRACE)

source(Sys.getenv("INVERSION_BASE_PARTIAL"))

###############################################################################
# GLOBAL CONSTANTS
###############################################################################
# locations of files
intermediate_dir <-  Sys.getenv("INTERMEDIATE_DIR")
process_model <- Sys.getenv("PROCESS_MODEL")
casename <- Sys.getenv("CASE")

###############################################################################
# EXECUTION
###############################################################################

log_info("Loading model")
model_case <- readRDS(sprintf("%s/real-model-%s.rds", intermediate_dir, casename))

if (is.null(model_case$process_model$H)) {
  log_info("Loading process model")
  process_model <- readRDS(sprintf("%s/%s.rds", intermediate_dir, process_model))
  model_case$process_model$H <- process_model$H
  rm(process_model)
  gc(verbose = FALSE)
}

log_info("Running MCMC")
output <- inversion_mcmc(
  11000,
  start = list("alpha" = rep(0, ncol(model_case$process_model$H))),
  model_case$measurement_model,
  model_case$process_model,
  show_progress = FALSE,
  use_tensorflow = 0
)

log_info("Saving")
saveRDS(output, sprintf("%s/real-mcmc-samples-%s.rds", intermediate_dir, casename))

log_info("Done")
