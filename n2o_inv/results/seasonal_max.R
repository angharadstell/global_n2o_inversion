# calculates the maximum month for N extratropics 30-90

library(dplyr)
library(here)
library(ini)

# read in config file
config <- read.ini(paste0(here(), "/config.ini"))

# read in flux samples
case <- "IS-RHO0-FIXEDA-VARYW-NOBIAS-model-err-n2o_std_windowall"
flux_samples <- sprintf("%s/real-flux-aggregates-samples-%s.rds", config$paths$inversion_results, case)

# extract samples
flux_samples <- bind_rows(
  readRDS(flux_samples) %>%
    filter(estimate == "Posterior",
    name == "N extratropics (30 - 90)") %>%
    mutate(year = format(month_start, "%Y")) %>%
    select(c("month_start", "year", "flux_mean")))
    
# calculate maximum monthly emissions and what month that is in
flux_samples_processed <- flux_samples %>%
    group_by(year) %>%
    summarise(annual_max = max(flux_mean),
    max_month = month_start[flux_mean == max(flux_mean)])

# print results
print(flux_samples_processed)
