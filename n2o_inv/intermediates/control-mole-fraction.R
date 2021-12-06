library(argparser)
library(dplyr)
library(fst)
library(here)
library(ini)
library(ncdf4)
library(tibble)

library(wombat)

###############################################################################
# FUNCTIONS
###############################################################################

process_control <- function(combined_mf_file) {
  # get variables from base run netcdf
  geos_obspack <- nc_open(combined_mf_file)
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
  arrange(model_id) %>%
  filter(if_any(co2, ~ !is.na(.)))

  nc_close(geos_obspack)

  control_full 
}

###############################################################################
# CODE
###############################################################################

main <- function() {
  args <- arg_parser('', hide.opts = TRUE) %>%
  add_argument('--case', '') %>%
  add_argument('--mf-file', '') %>%
  add_argument('--output', '') %>%
  parse_args()

  # read in config
  config <- read.ini(paste0(here(), "/config.ini"))

  # for standard inversion
  combined_mf_base <- paste0(config$paths$geos_out, "/", args$case, "/", args$mf_file, ".nc")
  control_full_base <- process_control(combined_mf_base)
  write_fst(control_full_base, paste0(config$paths$geos_inte, "/", args$output, ".fst"))

  # constant case
  combined_mf_constant <- paste0(config$paths$geos_out, "/", config$inversion_constants$constant_case, "/combined_mf.nc")
  control_full_constant <- process_control(combined_mf_constant)
  write_fst(control_full_constant, paste0(config$paths$geos_inte, "/control-mole-fraction-constant-met.fst"))
}

if (getOption('run.main', default=TRUE)) {
   main()
}