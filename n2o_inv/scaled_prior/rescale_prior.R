library(dplyr)
library(here)
library(ini)
library(Matrix)



###############################################################################
# GLOBAL CONSTANTS
###############################################################################
config <- read.ini(paste0(here(), "/config.ini"))

###############################################################################
# FUNCTIONS
###############################################################################
# rescale the inversion intermediates for scaling the prior
rescale_inputs <- function(scaling, alpha, scaling_word, suffix1, suffix2, directory) {
  print(paste(scaling_word, "rescaling..."))

  # read in inversion intermediates
  control_em <- fst::read_fst(sprintf("%s/control-emissions%s.fst", directory, suffix1))
  control_mf <- fst::read_fst(sprintf("%s/control-mole-fraction%s.fst", directory, suffix1))
  perturbations <- fst::read_fst(sprintf("%s/perturbations%s.fst", directory, suffix2))
  sensitivities <- fst::read_fst(sprintf("%s/sensitivities%s.fst", directory, suffix2))
  if (suffix2 == "_window01") {
    case <- "IS-RHO0-FIXEDA-VARYW-NOBIAS-model-err-n2o_std"
    process_model <- readRDS(sprintf("%s/process-model-%s%s.rds", config$paths$moving_window_dir, case, suffix2))
  } else {
    process_model <- readRDS(sprintf("%s/process-model.rds", directory))
  }

  # rescale
  if (length(alpha) == 1) {
    rescaled_control_mf <- control_mf %>% mutate(co2 = co2 + as.numeric(process_model$H %*% as.matrix(rep(alpha, dim(t(process_model$H))[1]))))
  } else {
    rescaled_control_mf <- control_mf %>% mutate(co2 = co2 + as.numeric(process_model$H %*% as.matrix(rep(alpha, (dim(t(process_model$H))[1]) / length(alpha)))))
  }

  if (grepl("land", scaling_word)) {
    rescaled_control_em <- control_em %>% mutate(flux_density = ifelse(type == "land", flux_density * scaling, flux_density))
    rescaled_perturbations <- perturbations %>% mutate(flux_density = ifelse(type == "land", flux_density * scaling, flux_density))
    rescaled_sensitivities <- sensitivities %>% mutate(co2_sensitivity = ifelse(region < no_land_regions , co2_sensitivity * scaling, co2_sensitivity))

  } else if (grepl("ocean", scaling_word)) {
    rescaled_control_em <- control_em %>% mutate(flux_density = ifelse(type == "ocean", flux_density * scaling, flux_density))
    rescaled_perturbations <- perturbations %>% mutate(flux_density = ifelse(type == "ocean", flux_density * scaling, flux_density))
    rescaled_sensitivities <- sensitivities %>% mutate(co2_sensitivity = ifelse(region >= no_land_regions , co2_sensitivity * scaling, co2_sensitivity))

  } else {
    rescaled_control_em <- control_em %>% mutate(flux_density = flux_density * scaling)
    rescaled_perturbations <- perturbations %>% mutate(flux_density = flux_density * scaling)
    rescaled_sensitivities <- sensitivities %>% mutate(co2_sensitivity = co2_sensitivity * scaling)
  }

  # save
  fst::write_fst(rescaled_control_em, sprintf("%s/control-emissions%s-rescaled-%s.fst", directory, suffix1, scaling_word))
  fst::write_fst(rescaled_control_mf, sprintf("%s/control-mole-fraction%s-rescaled-%s.fst", directory, suffix1, scaling_word))
  fst::write_fst(rescaled_perturbations, sprintf("%s/perturbations%s-rescaled-%s.fst", directory, suffix2, scaling_word))
  fst::write_fst(rescaled_sensitivities, sprintf("%s/sensitivities%s-rescaled-%s.fst", directory, suffix2, scaling_word))
}

###############################################################################
# EXECUTED CODE
###############################################################################

# create mask for land or ocean
no_land_regions <- as.numeric(config$inversion_constants$no_land_regions)
no_ocean_regions <- as.numeric(config$inversion_constants$no_regions) + 1 - no_land_regions

land_alphas <- c(rep(1, no_land_regions), rep(0, no_ocean_regions))
ocean_alphas <- c(rep(0, no_land_regions), rep(1, no_ocean_regions))


# double the prior
#rescale_inputs(2, 1, "double", "", "", config$paths$geos_inte)
#rescale_inputs(2, 1, "double", "-window01", "_window01", config$paths$geos_inte)
rescale_inputs(2, land_alphas, "doubleland", "-window01", "_window01", config$paths$geos_inte)
rescale_inputs(2, ocean_alphas, "doubleocean", "-window01", "_window01", config$paths$geos_inte)
#rescale_inputs(2, 1, "double", config$paths$pseudodata_dir)
# half the prior
#rescale_inputs(0.5, -0.5, "half", "", "", config$paths$geos_inte)
#rescale_inputs(0.5, -0.5, "half", "-window01", "_window01", config$paths$geos_inte)
rescale_inputs(0.5, -0.5 * land_alphas, "halfland", "-window01", "_window01", config$paths$geos_inte)
rescale_inputs(0.5, -0.5 * ocean_alphas, "halfocean", "-window01", "_window01", config$paths$geos_inte)
#rescale_inputs(0.5, -0.5, "half", config$paths$pseudodata_dir)
