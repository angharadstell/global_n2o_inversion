library(argparser)
library(dplyr)
library(fst)
library(here)
library(ini)
library(ncdf4)
library(stringr)
library(tibble)
library(wombat)

args <- arg_parser('', hide.opts = TRUE) %>%
  add_argument('--mf-file', '') %>%
  add_argument('--output', '') %>%
  parse_args()

###############################################################################
# GLOBAL CONSTANTS
###############################################################################
fileloc <- (function() {
  attr(body(sys.function()), "srcfile")
})()$filename

config <- read.ini(paste0(here(), "/config.ini"))

# locations of files
case <- config$inversion_constants$case
geos_out_dir <- config$paths$geos_out
inte_out_dir <- config$paths$geos_inte

###############################################################################
# FUNCTIONS
###############################################################################

process_obspack <- function(filename) {
  fn <- ncdf4::nc_open(filename)
  v <- function(...) ncdf4::ncvar_get(fn, ...)

  tibble(
    observation_id = as.vector(v("obspack_id")),
    observation_type = "obspack",
    time = rep(ncvar_get_time(fn, "obs_time"), times = length(v("site"))),
    longitude = as.vector(v("obs_lon")),
    latitude = as.vector(v("obs_lat")),
    co2 = as.vector(v("obs_value")),
    co2_error = as.vector(v("obs_value_unc")),
    oco2_airmass = NA,
    oco2_co2_grad_del = NA,
    oco2_log_dws = NA,
    oco2_dp = NA,
    oco2_s31 = NA,
    oco2_operation_mode = NA,
    tccon_station_id = NA,
    altitude = as.vector(v("obs_alt")),
    overall_observation_mode = "IS",
    observation_group = stringr::str_split(observation_id, "~", simplify = TRUE)[, 2], #"IS", #
    observation_group_parts = stringr::str_split(observation_group, "-", simplify = TRUE), #"obspack", #
    obspack_site_full = observation_group_parts[, 1], #"obspack", #
    obspack_site_full_parts = stringr::str_split(obspack_site_full, "_", simplify = TRUE), #"obspack", #
    obspack_site = obspack_site_full_parts[, 2], #"obspack", #
    obspack_site_type = obspack_site_full_parts[, 3], #"obspack", #
    obspack_measurement_type = stringr::str_split(observation_group_parts[, 2], "_", simplify = TRUE)[, 1] #"obspack", #
  )  %>%
    select(-obspack_site_full, -obspack_site_full_parts, -observation_group_parts) %>% 
    filter(if_any(co2, ~ !is.na(.)))
}

###############################################################################
# CODE
###############################################################################

main <- function() {
  # read in data
  combined_obspack <- process_obspack(paste0(geos_out_dir, "/", case, "/", args$mf_file))

  # add model error
  #model_err <- readRDS(sprintf("%s/model-rep-err.rds", inte_out_dir))
  #combined_obspack$co2_error <- sqrt(combined_obspack$co2_error^2 + model_err^2)

  # save the observations
  fst::write_fst(combined_obspack, sprintf("%s/%s", inte_out_dir, args$output))
}

if (getOption('run.main', default=TRUE)) {
   main()
}
