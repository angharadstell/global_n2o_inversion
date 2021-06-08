library(dplyr)
library(fst)
library(ini)
library(ncdf4)
library(stringr)
library(tibble)
library(wombat)

###############################################################################
# GLOBAL CONSTANTS
###############################################################################
fileloc <- (function() {
  attr(body(sys.function()), "srcfile")
})()$filename

config <- read.ini(paste0(gsub("n2o_inv/intermediates.*", "", fileloc), "config.ini"))

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
    observation_group = stringr::str_split(observation_id, "~", simplify = TRUE)[, 2],
    observation_group_parts = stringr::str_split(observation_group, "-", simplify = TRUE),
    obspack_site_full = observation_group_parts[, 1],
    obspack_site_full_parts = stringr::str_split(obspack_site_full, "_", simplify = TRUE),
    obspack_site = obspack_site_full_parts[, 2],
    obspack_site_type = obspack_site_full_parts[, 3],
    obspack_measurement_type = stringr::str_split(observation_group_parts[, 2], "_", simplify = TRUE)[, 1],
    obspack_measurement_subtype = NA #observation_group_parts[, 3] in original, but I don"t have this
  )  %>%
    select(-obspack_site_full, -obspack_site_full_parts, -observation_group_parts)
}


combined_obspack <- process_obspack(paste0(geos_out_dir, "/", case, "/combined_mf.nc"))

# remove nan
combined_obspack <- combined_obspack %>% filter(if_any(co2, ~ !is.na(.)))

# can't cope with sites with one observation
attenuation_factor <- as.factor(combined_obspack$observation_group)
no_obs_each_site <- sapply(1:nlevels(attenuation_factor),
                           function(i) sum(combined_obspack$observation_group == levels(attenuation_factor)[i]))
mask <- no_obs_each_site < 12
mask_levels <- levels(attenuation_factor)[mask]
mask_df <- combined_obspack$observation_group %in% mask_levels
combined_obspack <- filter(combined_obspack, !mask_df)

# remove aircraft data
air_mask <- str_detect(combined_obspack$observation_group, "NOAAair")
combined_obspack <- filter(combined_obspack, !air_mask)

# save the observations
fst::write_fst(combined_obspack, sprintf("%s/observations.fst", inte_out_dir))
