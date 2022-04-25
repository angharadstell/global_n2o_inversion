# plots the fluxes with the prior for two cases
source(Sys.getenv('RESULTS_BASE_PARTIAL'))
source(Sys.getenv('RESULTS_DISPLAY_PARTIAL'))
source(Sys.getenv('RESULTS_TABLES_PARTIAL'))
library(argparse)
library(lubridate, warn.conflicts = FALSE)
library(patchwork)

options(dplyr.summarise.inform = FALSE)

parser <- ArgumentParser()
parser$add_argument('--region', nargs = '+')
parser$add_argument('--height', type = 'double')
parser$add_argument('--flux-samples')
parser$add_argument('--anal-samples')
parser$add_argument('--show-prior-uncertainty', action = 'store_true', default = FALSE)
parser$add_argument('--small-y-axes', action = 'store_true', default = FALSE)
parser$add_argument('--start-date')
parser$add_argument('--end-date')
parser$add_argument('--output')
args <- parser$parse_args()

flux_samples <- bind_rows(
  readRDS(args$flux_samples) %>%
    mutate(
      is_prior = estimate == 'Prior',
      observation_group = ifelse(
        is_prior,
        'Prior',
        'Hierarchical Posterior'
      )
    ),
  readRDS(args$anal_samples) %>%
    mutate(
      is_prior = estimate == 'Prior',
      observation_group = ifelse(
        is_prior,
        'Prior',
        'Analytical Posterior'
      )
    ) %>%
    filter(estimate != "Prior")
)

#flux_samples$flux_mean <- flux_samples$flux_mean * ((14*2)/12) * 1000
#flux_samples$flux_samples <- flux_samples$flux_samples * ((14*2)/12) * 1000

legend_n_columns <- 3
show_prior_uncertainty <- args$show_prior_uncertainty
show_mip_fluxes <- FALSE
small_y_axes <- args$small_y_axes

start_date <- args$start_date
end_date <- args$end_date

source(Sys.getenv('RESULTS_FLUX_AGGREGATES_PARTIAL'))
