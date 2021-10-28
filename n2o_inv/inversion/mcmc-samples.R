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

# check running with tensorflow if desired
tensorflow_switch <- Sys.getenv("WOMBAT_TENSORFLOW") == "1" && is.null(model_case$measurement_model[["rho"]])
log_info(sprintf("Using tensorflow: %d", tensorflow_switch))

# check there are no sites with one observation
no_obs_each_site <- sapply(1:nlevels(model_case$measurement_model$attenuation_factor),
                           function(i) sum(model_case$measurement_model$attenuation_factor == levels(model_case$measurement_model$attenuation_factor)[i]))
#log_info(print("Number of observations at each site:"))
#log_info(print(no_obs_each_site))

log_info("Running MCMC")
output <- inversion_mcmc(
  2000,
  model_case$measurement_model,
  model_case$process_model,
  show_progress = TRUE,
  use_tensorflow = tensorflow_switch
)

log_info("Saving")
saveRDS(output, sprintf("%s/real-mcmc-samples-%s.rds", intermediate_dir, casename))

log_info("Done")
