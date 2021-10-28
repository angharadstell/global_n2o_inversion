library(dplyr)
library(here)
library(ini)
library(Matrix)



###############################################################################
# GLOBAL CONSTANTS
###############################################################################
config <- read.ini(paste0(here(), "/config.ini"))

# locations of files
inte_out_dir <- config$paths$geos_inte

###############################################################################
# FUNCTIONS
###############################################################################
# rescale the inversion intermediates for scaling the prior
rescale_inputs <- function(scaling, alpha, scaling_word, directory) {
  print(paste(scaling_word, "rescaling..."))

  # read in inversion intermediates
  control_em <- fst::read_fst(sprintf("%s/control-emissions.fst", directory))
  control_mf <- fst::read_fst(sprintf("%s/control-mole-fraction.fst", directory))
  perturbations <- fst::read_fst(sprintf("%s/perturbations.fst", directory))
  sensitivities <- fst::read_fst(sprintf("%s/sensitivities.fst", directory))
  process_model <- readRDS(sprintf("%s/process-model.rds", directory))

  # rescale
  rescaled_control_em <- control_em %>% mutate(flux_density = flux_density * scaling)
  rescaled_control_mf <- control_mf %>% mutate(co2 = co2 + as.numeric(process_model$H %*% as.matrix(rep(alpha, dim(t(process_model$H))[1]))))
  rescaled_perturbations <- perturbations %>% mutate(flux_density = flux_density * scaling)
  rescaled_sensitvities <- sensitivities %>% mutate(co2_sensitivity = co2_sensitivity * scaling)

  # save
  fst::write_fst(rescaled_control_em, sprintf("%s/control-emissions-rescaled-%s.fst", directory, scaling_word))
  fst::write_fst(rescaled_control_mf, sprintf("%s/control-mole-fraction-rescaled-%s.fst", directory, scaling_word))
  fst::write_fst(rescaled_perturbations, sprintf("%s/perturbations-rescaled-%s.fst", directory, scaling_word))
  fst::write_fst(rescaled_sensitvities, sprintf("%s/sensitivities-rescaled-%s.fst", directory, scaling_word))
}

###############################################################################
# EXECUTED CODE
###############################################################################

# double the prior
rescale_inputs(2, 1, "double", config$paths$geos_inte)
#rescale_inputs(2, 1, "double", config$paths$pseudodata_dir)
# half the prior
rescale_inputs(0.5, -0.5, "half", config$paths$geos_inte)
#rescale_inputs(0.5, -0.5, "half", config$paths$pseudodata_dir)
