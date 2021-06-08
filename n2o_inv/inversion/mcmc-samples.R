library(logger)
library(wombat)

#log_threshold(TRACE)

source(Sys.getenv("INVERSION_BASE_PARTIAL"))

###############################################################################
# GLOBAL CONSTANTS
###############################################################################
fileloc <- (function() {
  attr(body(sys.function()), "srcfile")
})()$filename

config <- read.ini(paste0(gsub("n2o_inv/inversion.*", "", fileloc), "config.ini"))

# locations of files
intermediate_dir <- config$paths$geos_inte

casename <- "IS-FIXEDAO-FIXEDWO5-NOBIAS"

###############################################################################
# EXECUTION
###############################################################################

log_info("Loading model")
model_case <- readRDS(sprintf("%s/real-model-%s.rds", intermediate_dir, casename))

if (is.null(model_case$process_model$H)) {
  log_info("Loading process model")
  process_model <- readRDS(sprintf("%s/process-model.rds", intermediate_dir))
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
log_info(print("Number of observations at each site:"))
log_info(print(no_obs_each_site))

log_info("Running MCMC")
output <- inversion_mcmc(
  3000,
  model_case$measurement_model,
  model_case$process_model,
  show_progress = TRUE,
  use_tensorflow = tensorflow_switch
)

log_info("Saving")
saveRDS(output, sprintf("%s/real-mcmc-samples-%s.rds", intermediate_dir, casename))

log_info("Done")