library(dplyr)
library(here)
library(ini)
library(lubridate)

config <- read.ini(paste0(here(), "/config.ini"))






process_flux_aggregates <- function(window) {
    print(window)
    raw <- readRDS(sprintf("%s/real-flux-aggregates-samples-%s_window%02d.rds", config$paths$inversion_results, config$inversion_constants$land_ocean_equal_model_case, window))

    start_date <- as.Date(config$dates$perturb_start)
    if (window == 1) {
        processed <- raw %>% filter(month_start < (start_date + years(2)))
    } else {
        processed <- raw %>% filter(month_start >= (start_date + years(window)), month_start < (start_date + years(window + 1)))
    }
    processed
}

process_obs_matched <- function(window) {
    print(window)
    raw <- readRDS(sprintf("%s/obs_matched_samples-%s_window%02d.rds", config$paths$inversion_results, config$inversion_constants$land_ocean_equal_model_case, window))
    
    start_date <- as.Date(config$dates$perturb_start)
    if (window == 1) {
        processed <- raw %>% filter(time < (start_date + years(2)))
    } else {
        processed <- raw %>% filter(time >= (start_date + years(window)), time < (start_date + years(window + 1)))
    }
    processed
}



nwindow <- config$moving_window$n_window

flux_aggregates_samples <- lapply(1:nwindow, process_flux_aggregates)
flux_aggregates_samples_combined <- do.call(rbind, flux_aggregates_samples)
saveRDS(flux_aggregates_samples_combined, sprintf("%s/real-flux-aggregates-samples-%s_windowall.rds", config$paths$inversion_results, config$inversion_constants$land_ocean_equal_model_case))


obs_matched_samples <- lapply(1:nwindow, process_obs_matched)
obs_matched_samples_combined <- do.call(rbind, obs_matched_samples) %>% arrange(observation_id)
saveRDS(obs_matched_samples_combined, sprintf("%s/obs_matched_samples-%s_windowall.rds", config$paths$inversion_results, config$inversion_constants$land_ocean_equal_model_case))
