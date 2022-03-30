library(argparser)
library(dplyr)
library(fst)
library(here)
library(ini)
library(lubridate)
library(stringr)
library(tibble)

source(paste0(here(), "/n2o_inv/intermediates/functions.R"))

###############################################################################
# FUNCTIONS
###############################################################################

sum_ch4_tracers_perturbed <- function(v_base, v_pert, perturbed_region, no_regions) {
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

process_sensitivity_part <- function(year, month, v_base, v, control_tibble, config) {
  # process each region within that file
  no_regions <- as.numeric(config$inversion_constants$no_regions)
  sensitivity_regions <- lapply(0:no_regions, function(region_iter) {
      perturbed_tibble <- tibble(
                                  region = region_iter,
                                  from_month_start = lubridate::ymd(sprintf("%s-%02d-01", year, month)),
                                  observation_id = as.vector(v("obspack_id")),
                                  observation_type = "obspack",
                                  resolution = "obspack",
                                  co2 = sum_ch4_tracers_perturbed(v_base, v, region_iter, no_regions),
                                  observation_group = stringr::str_split(observation_id, "~", simplify = TRUE)[, 3]
                                ) %>%
                          mutate(site = gsub("[[:digit:]]", "", observation_group),
                                 obs_date = lubridate::ym(gsub("[^[:digit:]]", "", observation_group))) %>%
                          inner_join(control_tibble,
                                     by = c("observation_id", "observation_type", "resolution")) %>%
                          mutate(co2_sensitivity = co2 - control_co2)

    #take final month of data
    final_date <- lubridate::ymd(sprintf("%s-%02d-01", year, month)) + months(as.numeric(config$inversion_constants$len_perturb) - 1)
    final_month <- perturbed_tibble %>%
                   filter((obs_date == final_date))
    # should this be a mean? They are not gaussianly distributed
    final_perturb <- mean(final_month$co2_sensitivity)

    perturbed_tibble %>% mutate(co2_sensitivity = replace(co2_sensitivity,
                                obs_date > final_date,
                                final_perturb)) %>%
                         filter(if_any(co2_sensitivity, ~ !is.na(.))) %>%
                         filter(if_any(control_co2, ~ !is.na(.))) %>%
                         select(region, from_month_start, model_id, resolution, co2_sensitivity)
    })
  # stick all the regions back together
  dplyr::bind_rows(sensitivity_regions)
}

process_sensitivity_part_wrapper <- function(year, month, v_base, flux_file, control_tibble, config) {
  # Read in flux file for the perturbed run
  combined_file <- sprintf("%s/%s%02d/%s", config$paths$geos_out, year, month, flux_file)
  print(combined_file)
  v <- read_nc_file(combined_file)
  # Process
  process_sensitivity_part(year, month, v_base, v, control_tibble, config)
}

###############################################################################
# EXECUTION
###############################################################################
main <- function() {
  print("Running main code of sensitivities script...")

  config <- read.ini(paste0(here(), "/config.ini"))

  args <- arg_parser("", hide.opts = TRUE) %>%
  add_argument("--mf-file", "") %>%
  add_argument("--control-mf", "") %>%
  add_argument("--output", "") %>%
  parse_args()

  # read in the base run tracers
  base_nc <- sprintf("%s/%s/%s", config$paths$geos_out, config$inversion_constants$case, args$mf_file)
  v_base <- read_nc_file(base_nc)

  # read in the processed base run
  control <- fst::read_fst(sprintf("%s/%s", config$paths$geos_inte, args$control_mf))
  control_tibble <- select(control,
                          model_id,
                          observation_id,
                          observation_type,
                          resolution,
                          control_co2 = co2)

  # process each perturbed sensitivity run
  unique_dates <- unique(control$time)
  first_year <- as.numeric(format(min(unique_dates), format = "%Y"))
  last_year <- as.numeric(format(max(unique_dates), format = "%Y"))
  no_years <- last_year - first_year + 1

  print(first_year)
  print(last_year)

  if (no_years > 0) {
    months <- rep(1:12, no_years)
    years <- rep(first_year:last_year, each = 12)
  } else {
    no_months <- length(v_base("obs_time"))
    months <- 1:no_months
    years <- rep(first_year, each = no_months)
  }

  sensitivities_parts <- mapply(process_sensitivity_part_wrapper,
                                year = years,
                                month = months,
                                SIMPLIFY = FALSE,
                                MoreArgs = list(v_base = v_base,
                                                flux_file = args$mf_file,
                                                control_tibble = control_tibble,
                                                config = config))

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
  fst::write_fst(sensitivities, sprintf("%s/%s", config$paths$geos_inte, args$output))
}

if (getOption("run.main", default = TRUE)) {
   main()
}
