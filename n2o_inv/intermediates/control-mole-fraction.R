library(dplyr)
library(fst)
library(ini)
library(ncdf4)
library(tibble)

library(wombat)

###############################################################################
# GLOBAL CONSTANTS
###############################################################################
fileloc <- (function() {
  attr(body(sys.function()), "srcfile")
})()$filename

config <- read.ini(paste0(gsub("n2o_inv/intermediates.*", "", fileloc),
                   "config.ini"))

case <- config$inversion_constants$case
# locations of files
geos_out_dir <- config$paths$geos_out
inte_out_dir <- config$paths$geos_inte

###############################################################################
# FUNCTIONS
###############################################################################

process_control <- function(case, filename) {
  # get variables from base run netcdf
  geos_obspack <- nc_open(paste0(geos_out_dir, "/", case, "/combined_mf.nc"))
  v <- function(...) ncvar_get(geos_obspack, ...)

  # put into nice table
  control_full <- tibble(
    observation_id = as.vector(v("obspack_id")),
    observation_type = "obspack",
    resolution = "obspack",
    time = rep(ncvar_get_time(geos_obspack, "obs_time"), times = length(v("site"))),
    latitude = as.vector(v("obs_lat")),
    longitude = as.vector(v("obs_lon")),
    co2 = as.vector(v("CH4_sum")),
    model_id = seq_len(length(v("CH4_sum"))),
  ) %>%
  arrange(time)

  # remove nan
  control_full <- control_full %>% filter(if_any(co2, ~ !is.na(.)))

  # save for later
  write_fst(control_full, paste0(inte_out_dir, "/", filename, ".fst"))
}


###############################################################################
# CODE
###############################################################################

# base case
process_control(config$inversion_constants$case, "control-mole-fraction")

# constant case
process_control(config$inversion_constants$constant_case, "control-mole-fraction-constant-met")
