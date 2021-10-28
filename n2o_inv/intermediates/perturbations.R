library(argparser)
library(dplyr)
library(fst)
library(here)
library(ini)
library(lubridate)
library(ncdf4)
library(tidyr)
library(wombat)

args <- arg_parser('', hide.opts = TRUE) %>%
  add_argument('--flux-file', '') %>%
  add_argument('--control-ems', '') %>%
  add_argument('--output', '') %>%
  parse_args()

###############################################################################
# GLOBAL CONSTANTS
###############################################################################
config <- read.ini(paste0(here(), "/config.ini"))

no_regions <- as.numeric(config$inversion_constants$no_regions)
case <- config$inversion_constants$case
# locations of files
geos_out_dir <- config$paths$geos_out
inte_out_dir <- config$paths$geos_inte

perturb_start <- as.Date(config$dates$perturb_start)
perturb_end <- as.Date(config$dates$perturb_end)

len_perturb <- as.numeric(config$inversion_constants$len_perturb)

###############################################################################
# FUNCTIONS
###############################################################################

sum_ch4_tracers <- function(v_base, v_pert,
                            region_start, region_end,
                            perturbed_region,
                            month_start, month_end) {
  # sum up the tracers for each perturbed run
  total_ch4 <- array(rep(0, length(v_base("EMIS_CH4_R00"))), dim(v_base("EMIS_CH4_R00")))
  for (region in region_start:region_end) {
    if (region == perturbed_region) {
      total_ch4[, , month_start:month_end] <- total_ch4[, , month_start:month_end] + v_pert(sprintf("EMIS_CH4_R%02d", region))
    } else {
      total_ch4[, , month_start:month_end] <- total_ch4[, , month_start:month_end] + v_base(sprintf("EMIS_CH4_R%02d", region))[, , month_start:month_end]
    }
  }
  total_ch4
}

process_perturbation_part <- function(month, year, region) {
  # Read in flux file
  flux_file <- sprintf("%s/%s%02d/%s", geos_out_dir, year, month, args$flux_file)
  print(flux_file)
  perturbed <- ncdf4::nc_open(flux_file)
  v <- function(...) ncdf4::ncvar_get(perturbed, ...)


  locations <- expand.grid(
    longitude = v("longitude"),
    latitude = v("latitude"),
    month_start = as.Date(ncvar_get_time(fn, "time"))
  )

  # bit of a hacky way to stop hitting index error - improve!
  month_start <- (as.numeric(year) - first_year) * 12 + month
  month_end <- min(month_start + len_perturb - 1, length(unique(control$month_start)))

  print(month_start)
  print(month_end)

  as_tibble(cbind(locations, data.frame(
    region = region,
    from_month_start = lubridate::ymd(sprintf("%s-%02d-01", year, month)),
    land = as.vector(sum_ch4_tracers(v_base, v, 0, 11, region, month_start, month_end)),
    ocean = as.vector(sum_ch4_tracers(v_base, v, 12, 22, region, month_start, month_end))
    )
  )) %>%
    select(region, from_month_start, month_start, everything()) %>%
    filter(month_start == from_month_start) %>%
    pivot_longer(
      c(land, ocean),
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

control <- fst::read_fst(sprintf("%s/%s", inte_out_dir, args$control_ems))

fn <- nc_open(sprintf("%s/%s/%s", geos_out_dir, case, args$flux_file))
v_base <- function(...) ncdf4::ncvar_get(fn, ...)

unique_dates <- unique(control$month_start)
first_year <- as.numeric(format(min(unique_dates), format = "%Y"))
last_year <- as.numeric(format(max(unique_dates), format = "%Y"))
no_years <- last_year - first_year + 1

if (no_years > 0) {
  months <- rep(rep(1:12, each = (no_regions + 1)), no_years)
  years <- rep(first_year:last_year, each = (12 * (no_regions + 1)))
} else {
  months <- rep(1:length(unique_dates), each = (no_regions + 1))
  years <- rep(first_year:last_year, each = (length(unique_dates) * (no_regions + 1)))
}

perturbations <- mapply(function(m, y, r) process_perturbation_part(m, y, r),
                        months,
                        years,
                        rep(0:no_regions, length(unique_dates)),
                        SIMPLIFY = FALSE)

perturbations_combined <- bind_rows(perturbations)

fst::write_fst(perturbations_combined, sprintf("%s/%s", inte_out_dir, args$output))
