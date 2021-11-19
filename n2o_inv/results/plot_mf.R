library(argparser)
library(ini)
library(tidyr, warn.conflicts = FALSE)

###############################################################################
# GLOBAL CONSTANTS
###############################################################################

args <- arg_parser('', hide.opts = TRUE) %>%
  add_argument('--obs-samples', '') %>%
  add_argument('--output', '') %>%
  parse_args()

source(Sys.getenv('RESULTS_TABLES_PARTIAL'))

# config <- read.ini(paste0(here(), "/config.ini"))

# args <- vector(mode = "list", length = 5)

# args$obs_samples <- paste0(config$paths$inversion_result, "/obs_matched_samples.rds")
# args$output <- paste0(config$paths$inversion_result, "/obs_time_series.pdf")

# source(paste0(config$paths$location_of_this_file, "/../results/partials/tables.R"))

###############################################################################
# EXECUTION
###############################################################################

NAME_COLOURS <- c(
  'Observed' = 'black',
  'WOMBAT Prior (mean)' = get_colour('wombat_prior'),
  'WOMBAT IS (mean, 95% cred. int.)' = get_colour('wombat_lg')
)

obs_samples <- readRDS(args$obs_samples) %>%
  mutate(month = lubridate::floor_date(time, 'month'))

obs_time_series_monthly <- obs_samples %>%
  group_by(obspack_site, month) %>%
  summarise(
    co2 = mean(co2),
    Y2_prior = mean(Y2_prior),
    Z2_hat = mean(Z2_hat),
    Z2_hat_lower = mean(Z2_hat_lower),
    Z2_hat_upper = mean(Z2_hat_upper)
  )

df_long <- bind_rows(
obs_time_series_monthly %>%
select(obspack_site, month, value = co2) %>%
mutate(name = 'Observed', lower = NA, upper = NA),
obs_time_series_monthly %>%
select(obspack_site, month, value = Y2_prior) %>%
mutate(name = 'WOMBAT Prior (mean)', lower = NA, upper = NA),
obs_time_series_monthly %>%
mutate(name = 'WOMBAT IS (mean, 95% cred. int.)') %>%
select(name, obspack_site, month, value = Z2_hat, lower = Z2_hat_lower, upper = Z2_hat_upper)
)

df_complete <- expand.grid(
  name = names(NAME_COLOURS),
  month = sort(unique(df_long$month)),
  obspack_site = sort(unique(df_long$obspack_site))
) %>%
  left_join(df_long, by = c('name', 'month', 'obspack_site'))

output <- df_complete %>%
  mutate(
    name = factor(name, levels = names(NAME_COLOURS)),
    # NOTE(mgnb): reverse the order of the factors to control the order of
    # panels
    #station = factor(station, levels = rev(TCCON_ORDER))
  ) %>%
  ggplot(aes(month)) +
    geom_ribbon(
      mapping = aes(ymin = lower, ymax = upper, fill = name, colour = name),
      alpha = 0.2,
      size = 0.1
    ) +
    geom_line(
      mapping = aes(y = value, colour = name),
      size = 0.3
    ) +
    scale_colour_manual(values = NAME_COLOURS) +
    scale_fill_manual(values = NAME_COLOURS) +
    facet_wrap(~ obspack_site, scales = 'free_y', ncol = 4) +
    labs(
      x = 'Month',
      y = 'Mole fraction [ppb]',
      colour = NULL,
      fill = NULL
    ) +
    guides(
      colour = guide_legend(ncol = 3),
      fill = guide_legend(ncol = 3)
    ) +
    theme(
      legend.position = 'bottom',
      axis.text.x = element_text(angle = 45, hjust = 1)
    )

ggsave_base(
  args$output,
  output,
  width = 30,
  height = 50
)
