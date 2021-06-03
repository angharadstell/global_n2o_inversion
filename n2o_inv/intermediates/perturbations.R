library(dplyr)
library(fst)
library(lubridate)
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

no_regions <- as.numeric(config$inversion_constants$no_regions)
case <- config$inversion_constants$case
# locations of files
geos_out_dir <- config$paths$geos_out
inte_out_dir <- config$paths$geos_inte

perturb_start <- as.Date(config$dates$perturb_start)

###############################################################################
# FUNCTIONS
###############################################################################

sum_ch4_tracers <- function(v_base, v_pert,
                            region_start, region_end,
                            perturbed_region,
                            month_start, month_end) {
  # sum up the tracers for each perturbed run
  total_ch4 <- array(rep(0, length(v_pert("EMIS_CH4_R00"))), dim(v_pert("EMIS_CH4_R00")))
  for (region in region_start:region_end) {
    if (region == perturbed_region) {
      total_ch4 <- total_ch4 + v_pert(sprintf("EMIS_CH4_R%02d", region))
    } else {
      total_ch4 <- total_ch4 + v_base(sprintf("EMIS_CH4_R%02d", region))[, , month_start:month_end]
    }
  }
  total_ch4
}

process_perturbation_part <- function(month, year, region) {
  # Read in flux file
  flux_file <- sprintf("%s/%s%02d/monthly_fluxes.nc", geos_out_dir, year, month)
  print(flux_file)
  perturbed <- ncdf4::nc_open(flux_file)
  v <- function(...) ncdf4::ncvar_get(perturbed, ...)


  locations <- expand.grid(
    longitude = v("longitude"),
    latitude = v("latitude"),
    month_start = as.Date(ncvar_get_time(perturbed, "time"))
  )

  # bit of a hacky way to stop hitting index error - improve!
  first_year <- as.numeric(format(perturb_start, format = "%Y"))
  month_start <- (as.numeric(year) - first_year) * 12 + month
  month_end <- 12

  as_tibble(cbind(locations, data.frame(
    region = region,
    from_month_start = lubridate::ymd(sprintf("%s-%02d-01", year, month)),
    region_00 = as.vector(v("EMIS_CH4_R00")),
    land = as.vector(sum_ch4_tracers(v_base, v, 1, 11, region, month_start, month_end)),
    ocean = as.vector(sum_ch4_tracers(v_base, v, 12, 22, region, month_start, month_end))
    )
  )) %>%
    select(region, from_month_start, month_start, everything()) %>%
    filter(month_start == from_month_start) %>%
    pivot_longer(
      c(region_00, land, ocean),
      names_to = "type",
      values_to = "flux_density"
    ) %>%
    left_join(
      control %>%
        select(
          month_start,
          longitude,
          latitude,
          model_id,
          type,
          control_flux_density = flux_density
        ),
      by = c("month_start", "longitude", "latitude", "type")
    )  %>%
    mutate(
      flux_density = flux_density - control_flux_density
    ) %>%
    select(-control_flux_density) %>%
    select(
      region,
      from_month_start,
      type,
      model_id,
      flux_density
    )

}





###############################################################################
# EXECUTION
###############################################################################

control <- fst::read_fst(sprintf("%s/control-emissions.fst", inte_out_dir))

fn <- nc_open(sprintf("%s/%s/monthly_fluxes.nc", geos_out_dir, case))
v_base <- function(...) ncdf4::ncvar_get(fn, ...)

first_year <- format(perturb_start, format = "%Y")

perturbations <- mapply(function(x, y) process_perturbation_part(x, first_year, y),
                        rep(1:12, each = (no_regions + 1)),
                        rep(0:no_regions, 12),
                        SIMPLIFY = FALSE)

perturbations_combined <- bind_rows(perturbations)

fst::write_fst(perturbations_combined, sprintf("%s/perturbations.fst", inte_out_dir))
