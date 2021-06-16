library(dplyr)
library(fst)
library(lubridate)
library(ncdf4)
library(tibble)

###############################################################################
# GLOBAL CONSTANTS
###############################################################################
fileloc <- (function() {
  attr(body(sys.function()), "srcfile")
})()$filename

config <- read.ini(paste0(gsub("n2o_inv/intermediates.*", "", fileloc), "config.ini"))

# locations of files
case <- config$inversion_constants$case
no_regions <- as.numeric(config$inversion_constants$no_regions)
geos_out_dir <- config$paths$geos_out
inte_out_dir <- config$paths$geos_inte
perturb_start <- as.Date(config$dates$perturb_start)
perturb_end <- as.Date(config$dates$perturb_end)

###############################################################################
# FUNCTIONS
###############################################################################

base_ch4_tracers <- function() {
  # return the variables in the base run netcdf
  base_nc <- ncdf4::nc_open(sprintf("%s/%s/combined_mf.nc", geos_out_dir, case))
  v_base <- function(...) ncdf4::ncvar_get(base_nc, ...)
  v_base
}

sum_ch4_tracers_perturbed <- function(v_base, v_pert, perturbed_region) {
  # sum up the tracers for each perturbed run
  total_ch4 <- rep(0, length(v_pert("CH4_R00")))
  for (region in 0:no_regions) {
    if (region == perturbed_region) {
      total_ch4 <- total_ch4 + as.vector(v_pert(sprintf("CH4_R%02d", region)))
    } else {
      total_ch4 <- total_ch4 + as.vector(v_base(sprintf("CH4_R%02d", region)))
    }
  }
  total_ch4
}

process_sensitivity_part <- function(year, month) {
  # Read in combined file
  combined_file <- sprintf("%s/%s%02d/combined_mf.nc", geos_out_dir, year, month)
  print(combined_file)
  perturbed <- ncdf4::nc_open(combined_file)
  v <- function(...) ncdf4::ncvar_get(perturbed, ...)

  # process each region within that file
  sensitivity_regions <- lapply(0:no_regions, function(region_iter) {
      perturbed_tibble <- tibble(
                                  region = region_iter,
                                  from_month_start = lubridate::ymd(sprintf("%s-%02d-01", year, month)),
                                  observation_id = as.vector(v("obspack_id")),
                                  observation_type = "obspack",
                                  resolution = "obspack",
                                  co2 = sum_ch4_tracers_perturbed(v_base, v, region_iter)
                                ) %>%
                          filter(if_any(co2, ~ !is.na(.))) %>%
                          inner_join(control_tibble,
                                     by = c("observation_id", "observation_type", "resolution")) %>%
                          mutate(co2_sensitivity = co2 - control_co2) %>%
                          select(region, from_month_start, model_id, resolution, co2_sensitivity)
    })
  # stick all the regions back together
  dplyr::bind_rows(sensitivity_regions)
}

###############################################################################
# EXECUTION
###############################################################################

# read in the base run tracers
v_base <- base_ch4_tracers()

# read in the processed base run
control <- fst::read_fst(sprintf("%s/control-mole-fraction.fst", inte_out_dir))
control_tibble <- select(control,
                         model_id,
                         observation_id,
                         observation_type,
                         resolution,
                         control_co2 = co2)

# process each perturbed sensitivity run
first_year <- as.numeric(format(perturb_start, format = "%Y"))
last_year <- as.numeric(format(perturb_end, format = "%Y")) - 1
no_years <- last_year - first_year + 1

sensitivities_parts <- mapply(process_sensitivity_part,
                              year = rep(first_year:last_year, each = 12),
                              month = rep(1:12, no_years),
                              SIMPLIFY = FALSE)

# stick all the perturbed sensitivities together
sensitivities <- bind_rows(sensitivities_parts) %>%
                 arrange(region, from_month_start, model_id, resolution)

# turn any nans in the sensitivity into zeros
sensitivities$co2_sensitivity <- ifelse(
  is.nan(sensitivities$co2_sensitivity),
  0,
  sensitivities$co2_sensitivity
)

# save the sensitivities
fst::write_fst(sensitivities, sprintf("%s/sensitivities.fst", inte_out_dir))
