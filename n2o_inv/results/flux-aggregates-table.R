source(Sys.getenv('RESULTS_BASE_PARTIAL'))
source(Sys.getenv('RESULTS_TABLES_PARTIAL'))

# source('/home/as16992/wombat-paper/4_results/src/partials/base.R')
# source('/home/as16992/global_n2o_inversion/n2o_inv/results/partials/tables.R')

library(argparse)
library(lubridate, warn.conflicts = FALSE)
library(tidyr)

parser <- ArgumentParser()
parser$add_argument('--flux-samples')
parser$add_argument('--start-date')
parser$add_argument('--end-date')
parser$add_argument('--output')
args <- parser$parse_args()

# args <- vector(mode = "list", length = 4)
# names(args) <- c('flux_samples', 'start_date', 'end_date', 'output')
# args$flux_samples <- '/work/as16992/geoschem/N2O/results/real-flux-aggregates-samples-IS-RHO0-FIXEDAO-FIXEDWO5-NOBIAS.rds'
# args$start_date <- '2010-01-01'
# args$end_date <- '2021-01-01'
# args$output <- '/work/as16992/geoschem/N2O/results/flux-aggregates-table.txt'

log_info('Loading flux samples')
flux_samples <- (readRDS(args$flux_samples) %>%
    mutate(observation_group = 'IS')
) %>%
  mutate(
    year = year(month_start),
    estimate = ifelse(
      estimate == 'Prior',
      'WOMBAT Prior',
      sprintf('WOMBAT %s', observation_group)
    )
  ) %>%
  select(-observation_group)

#flux_samples$flux_mean <- flux_samples$flux_mean * ((14*2)/12) * 1000
#flux_samples$flux_samples <- flux_samples$flux_samples * ((14*2)/12) * 1000

print(unique(flux_samples$estimate))
print(unique(flux_samples$year))

no_years <- length(unique(flux_samples$year))

log_info('Calculating')
annual_fluxes <- flux_samples %>%
  group_by(estimate, name, year) %>%
  summarise(
    flux_mean = sum(flux_mean),
    flux_lower = quantile(colSums(flux_samples), probs = 0.025, na.rm = TRUE),
    flux_upper = quantile(colSums(flux_samples), probs = 0.975, na.rm = TRUE)
  ) %>%
  ungroup() %>%
  filter(
    #name %in% MIP_REGION_TO_REGION,
    year %in% unique(flux_samples$year)
  )

monthly_fluxes <- flux_samples %>%
  filter(
    #name %in% MIP_REGION_TO_REGION,
    month_start >= args$start_date,
    month_start < args$end_date
  ) %>%
  ungroup() %>%
  mutate(
    flux_lower = matrixStats::rowQuantiles(flux_samples, probs = 0.025),
    flux_upper = matrixStats::rowQuantiles(flux_samples, probs = 0.975)
  ) %>%
  select(estimate, name, month_start, flux_mean, flux_lower, flux_upper)

sink(args$output)

cat('============ Annual fluxes\n')
bind_rows(
  annual_fluxes
) %>%
  arrange(year, name, estimate) %>%
  knitr::kable(digits = 2)

cat('\n\n\n============ Average over the years:\n')
flux_samples %>%
  filter(
    year %in% head(substr(args$start_date, 1, 4):substr(args$end_date, 1, 4), -1),
    name %in% c('Global', 'Global land'),
    estimate %in% c('WOMBAT IS')
  ) %>%
  group_by(name, estimate) %>%
  summarise(
    flux_mean = mean(colSums(flux_samples) / no_years),
    flux_sd = sd(colSums(flux_samples) / no_years),
    flux_q025 = quantile(colSums(flux_samples) / no_years, probs = 0.025),
    flux_q975 = quantile(colSums(flux_samples) / no_years, probs = 0.975)
  ) %>%
  knitr::kable(digits = 2)

cat('\n\n\n============ Monthly fluxes:\n')
bind_rows(
  monthly_fluxes
) %>%
  arrange(month_start, name, estimate) %>%
  knitr::kable(digits = 2)

sink(NULL)
