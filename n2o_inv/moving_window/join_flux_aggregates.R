# This script joins up the output from the moving window inversion for plotting
# and analysis
library(argparser)
library(dplyr)
library(here)
library(ini)
library(lubridate)

config <- read.ini(paste0(here(), "/config.ini"))

###############################################################################
# FUNCTIONS
###############################################################################

# open the real flux aggregates samples for a window, then select the desired
# years for the results
process_flux_aggregates <- function(window, case) {
    message("processing window ", window)
    raw <- readRDS(sprintf("%s/real-flux-aggregates-samples-%s_window%02d.rds", config$paths$inversion_results, case, window))

    start_date <- as.Date(config$dates$perturb_start)
    # if its the first window, want to include the spinup year as well as the
    # second year of the run
    if (window == 1) {
        processed <- raw %>% filter(month_start < (start_date + years(2)))
    # otherwise, only want second year of the run
    } else {
        processed <- raw %>% filter(month_start >= (start_date + years(window)), month_start < (start_date + years(window + 1)))
    }

    processed
}

# open the obs matched samples for a window, then select the desired years
# for the results
process_obs_matched <- function(window, case) {
    message("processing window ", window)
    raw <- readRDS(sprintf("%s/obs_matched_samples-%s_window%02d.rds", config$paths$inversion_results, case, window))

    start_date <- as.Date(config$dates$perturb_start)
    # if its the first window, want to include the spinup year as well as
    # the second year of the run
    if (window == 1) {
        processed <- raw %>% filter(time < (start_date + years(2)))
    # otherwise, only want second year of the run
    } else {
        processed <- raw %>% filter(time >= (start_date + years(window)), time < (start_date + years(window + 1)))
    }

    processed
}

###############################################################################
# CODE
###############################################################################

main <- function() {
    args <- arg_parser("", hide.opts = TRUE) %>%
    add_argument("--casename", "") %>%
    parse_args()

    # read in the number of windows from the config
    nwindow <- config$moving_window$n_window

    # iterate through every window, selecting the desired years from the real
    # flux aggregates samples
    # combine the samples into a complete set of results, and save
    flux_aggregates_samples <- lapply(1:nwindow, process_flux_aggregates, case=args$casename)
    flux_aggregates_samples_combined <- do.call(rbind, flux_aggregates_samples)
    saveRDS(flux_aggregates_samples_combined, sprintf("%s/real-flux-aggregates-samples-%s_windowall.rds", config$paths$inversion_results, args$casename))

    # iterate through every window, selecting the desired years from the obs
    # matched samples
    # combine the samples into a complete set of results, and save
    obs_matched_samples <- lapply(1:nwindow, process_obs_matched, case=args$casename)
    obs_matched_samples_combined <- do.call(rbind, obs_matched_samples) %>% arrange(observation_id)
    saveRDS(obs_matched_samples_combined, sprintf("%s/obs_matched_samples-%s_windowall.rds", config$paths$inversion_results, args$casename))
}

if (getOption("run.main", default = TRUE)) {
   main()
}
