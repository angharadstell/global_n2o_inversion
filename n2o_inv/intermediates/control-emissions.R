library(dplyr)
library(fst)
library(ini)
library(ncdf4)
library(tidyr)
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

sum_ch4_tracers <- function(v, region_start, region_end) {
  # sum up the tracers for each perturbed run
  total_ch4 <- array(rep(0, length(v("EMIS_CH4_R00"))), dim(v("EMIS_CH4_R00")))
  for (region in region_start:region_end) {
    total_ch4 <- total_ch4 + v(sprintf("EMIS_CH4_R%02d", region))
  }
  total_ch4
}

###############################################################################
# EXECUTION
###############################################################################

fn <- nc_open(sprintf("%s/%s/monthly_fluxes.nc", geos_out_dir, case))
v <- function(...) ncdf4::ncvar_get(fn, ...)

n_longitudes <- length(v("longitude"))
n_latitudes <- length(v("latitude"))
month_starts <- as.Date(ncvar_get_time(fn, "time"))

locations <- expand.grid(
  longitude_index = seq(1, n_longitudes),
  latitude_index = seq(1, n_latitudes),
  month_start = month_starts
) %>%
  mutate(
    model_id = 1:n(),
    area = as.vector(v("AREA"))
) %>%
  select(month_start, model_id, everything())


emissions <- cbind(locations, data.frame(
  # Comes in kg/m^2/s
  region_00 = as.vector(v("EMIS_CH4_R00")),
  land = as.vector(sum_ch4_tracers(v, 1, 11)),
  ocean = as.vector(sum_ch4_tracers(v, 12, 22))
))
  
emissions <- pivot_longer(emissions, c(region_00, land, ocean),
                          names_to = "type", values_to = "flux_density")

emissions <- emissions %>% left_join(
  data.frame(
    longitude_index = seq(1, n_longitudes),
    longitude = v("longitude"),
    cell_width = v("longitude_width")
  ),
  by = "longitude_index"
) %>%
left_join(
  data.frame(
    latitude_index = seq_len(n_latitudes),
    latitude = v("latitude"),
    cell_height = v("latitude_height")
  ),
  by = "latitude_index"
) %>%
select(-longitude_index, -latitude_index)

fst::write_fst(emissions, sprintf("%s/control-emissions.fst", inte_out_dir))
