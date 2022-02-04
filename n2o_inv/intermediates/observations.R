library(argparser)
library(dplyr)
library(fst)
library(here)
library(ini)
library(ncdf4)
library(stringr)
library(tibble)
library(wombat)

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
    observation_group = stringr::str_split(observation_id, "~", simplify = TRUE)[, 2],
    observation_group_parts = stringr::str_split(observation_group, "-", simplify = TRUE),
    obspack_site_full = observation_group_parts[, 1],
    obspack_site_full_parts = stringr::str_split(obspack_site_full, "_", simplify = TRUE),
    obspack_site = obspack_site_full_parts[, 2],
    obspack_site_type = obspack_site_full_parts[, 3],
    obspack_measurement_type = stringr::str_split(observation_group_parts[, 2], "_", simplify = TRUE)[, 1]
  )  %>%
    select(-obspack_site_full, -obspack_site_full_parts, -observation_group_parts) %>%
    filter(if_any(co2, ~ !is.na(.)))
}

###############################################################################
# CODE
###############################################################################

main <- function() {
  args <- arg_parser("", hide.opts = TRUE) %>%
  add_argument("--mf-file", "") %>%
  add_argument("--model-err", "") %>%
  add_argument("--output", "") %>%
  parse_args()

  config <- ini::read.ini(paste0(here::here(), "/config.ini"))

  # read in data
  combined_obspack <- process_obspack(paste0(config$paths$geos_out, "/", config$inversion_constants$case, "/", args$mf_file))

  # add model error
  if (args$model_err == "n2o_std") {
    fn <- ncdf4::nc_open(sprintf("%s/%s/model_err.nc", config$paths$geos_out, config$inversion_constants$model_err_case))
    v <- function(...) ncdf4::ncvar_get(fn, ...)
    # ordered as site1month1, site1month2... as is observations yay
    # need to time filter for window obs etc
    model_err <- tibble(time = rep(as.Date(ncvar_get_time(fn, "obs_time")), times = length(v("site"))),
                        site = rep(v("site"), each = length(v("obs_time"))),
                        model_std = as.vector(v("model_std"))) %>%
                 filter(time >= min(combined_obspack$time), time <= max(combined_obspack$time))
    combined_obspack$co2_error <- sqrt(combined_obspack$co2_error^2 + na.omit(model_err$model_std)^2)
  } else if (args$model_err == "arbitrary") {
    combined_obspack$co2_error <- sqrt(combined_obspack$co2_error^2 + 0.3^2)
  }

  # save the observations
  fst::write_fst(combined_obspack, sprintf("%s/%s", config$paths$geos_inte, args$output))

}

if (getOption("run.main", default = TRUE)) {
   main()
}
