library(argparser)
library(dplyr)
library(fst)
library(here)
library(ini)
library(lubridate)
library(ncdf4)
library(tidyr)
library(wombat)

source(paste0(here(), "/n2o_inv/intermediates/functions.R"))

###############################################################################
# FUNCTIONS
###############################################################################

sum_ch4_tracers <- function(v_base, v_pert,
                            region_start, region_end,
                            perturbed_region,
                            month_start, month_end) {
  # Sum up the emissions for each desired region in geoschem, outputting an
  # array of their distribution in space and time. For each perturbed run, the
  # emissions are the base emissions summed over the not perturbed regions, added
  # to the perturbed run emissions for the perturbed region

  # Create an array of zeros that matches the shape of "EMIS_CH4_R00" in the base run
  total_ch4 <- array(rep(0, length(v_base("EMIS_CH4_R00"))), dim(v_base("EMIS_CH4_R00")))
  # Iterate over desired regions
  for (region in region_start:region_end) {
    # Add on the perturbed run emissions if the region is the perturbed region, else
    # add on the base run emissions.
    # month_start and month_end needed because each perturbed run is only 2 years long
    if (region == perturbed_region) {
      total_ch4[, , month_start:month_end] <- total_ch4[, , month_start:month_end] + v_pert(sprintf("EMIS_CH4_R%02d", region))
    } else {
      total_ch4[, , month_start:month_end] <- total_ch4[, , month_start:month_end] + v_base(sprintf("EMIS_CH4_R%02d", region))[, , month_start:month_end]
    }
  }
  total_ch4
}

base_run_info <- function(base_flux_file) {
  # Read in flux file for the base run
  fn <- ncdf4::nc_open(base_flux_file)
  v_base <- function(...) ncdf4::ncvar_get(fn, ...)

  # Extract grid cell info from gesochem
  locations <- expand.grid(
    longitude = v_base("longitude"),
    latitude = v_base("latitude"),
    month_start = as.Date(ncvar_get_time(fn, "time"))
  )

  list(v_base = v_base, locations = locations)
}

process_perturbation_part <- function(month, year, region, config, v, v_base, control, locations) {
  # Extract the perturbed run emissions for a specific date and region, subtract the base run to
  # calculate perturbation emissions. The output is a nice data frame.

  # Bit of a hacky way to stop hitting index error in sum_ch4_tracers
  unique_dates <- unique(control$month_start)
  first_year <- as.numeric(format(min(unique_dates), format = "%Y"))

  len_perturb <- as.numeric(config$inversion_constants$len_perturb)
  month_start <- (as.numeric(year) - first_year) * 12 + month
  month_end <- min(month_start + len_perturb - 1, length(unique_dates))
  message("month_start: ", month_start)
  message("month_end: ", month_end)

  no_regions <- as.numeric(config$inversion_constants$no_regions)
  no_land_regions <- as.numeric(config$inversion_constants$no_land_regions)

  # Work out perturbed run emissions, add to locations data frame
  as_tibble(cbind(locations, data.frame(
    region = region,
    from_month_start = lubridate::ymd(sprintf("%s-%02d-01", year, month)),
    land = as.vector(sum_ch4_tracers(v_base, v, 0, (no_land_regions - 1), region, month_start, month_end)),
    ocean = as.vector(sum_ch4_tracers(v_base, v, no_land_regions, no_regions, region, month_start, month_end))
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
    # subtract base run emissions from perturbed run emissions to get perturbations
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

process_perturbation_part_wrapper <- function(month, year, region, config, v_base, control, locations, flux_file) {
  # Read in flux file for the perturbed run
  flux_file <- sprintf("%s/%s%02d/%s", config$paths$geos_out, year, month, flux_file)
  print(flux_file)
  v <- read_nc_file(flux_file)
  # Process
  process_perturbation_part(month, year, region, config, v, v_base, control, locations)
}

###############################################################################
# EXECUTION
###############################################################################

main <- function() {
  # Read in command line arguments
  args <- arg_parser("", hide.opts = TRUE) %>%
    add_argument("--flux-file", "") %>%
    add_argument("--control-ems", "") %>%
    add_argument("--output", "") %>%
    parse_args()

  # Read in config file
  config <- read.ini(paste0(here(), "/config.ini"))

  # Read in control emissions intermediate
  control <- fst::read_fst(sprintf("%s/%s", config$paths$geos_inte, args$control_ems))

  base_run_extracted <- base_run_info(sprintf("%s/%s/%s", config$paths$geos_out, config$inversion_constants$case, args$flux_file)) 

  # Extract information on the dates in the model runs, as well as the number of regions
  unique_dates <- unique(control$month_start)
  first_year <- as.numeric(format(min(unique_dates), format = "%Y"))
  last_year <- as.numeric(format(max(unique_dates), format = "%Y"))
  no_years <- last_year - first_year + 1

  no_regions <- as.numeric(config$inversion_constants$no_regions)

  # Make vectors of all the different months and years that perturbed emissions need to
  # be calculated for
  if (no_years > 0) {
    months <- rep(rep(1:12, each = (no_regions + 1)), no_years)
    years <- rep(first_year:last_year, each = (12 * (no_regions + 1)))
  } else {
    months <- rep(1:length(unique_dates), each = (no_regions + 1))
    years <- rep(first_year:last_year, each = (length(unique_dates) * (no_regions + 1)))
  }

  # Run process_perturbation_part for each month and region to collect all the
  # perturbed emissions data
  perturbations <- mapply(process_perturbation_part_wrapper,
                          month = months,
                          year = years,
                          region = rep(0:no_regions, length(unique_dates)),
                          MoreArgs = list(config = config,
                                          v_base = base_run_extracted$v_base,
                                          control = control,
                                          locations = base_run_extracted$locations,
                                          flux_file = args$flux_file),
                          SIMPLIFY = FALSE)
  # Recombine to one data frame
  perturbations_combined <- bind_rows(perturbations)

  # Save the perturbations intermediate
  fst::write_fst(perturbations_combined, sprintf("%s/%s", config$paths$geos_inte, args$output))
}

if (getOption("run.main", default = TRUE)) {
   main()
}
