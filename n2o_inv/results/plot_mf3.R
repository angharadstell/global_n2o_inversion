# plots the observed mole fractions for both the analytical and hierarchical results
library(argparser)
library(dplyr)
library(ggplot2)
library(here)
library(ini)
library(tidyr, warn.conflicts = FALSE)

###############################################################################
# GLOBAL CONSTANTS
###############################################################################

args <- arg_parser('', hide.opts = TRUE) %>%
  add_argument('--obs-samples', '') %>%
  add_argument('--anal-samples', '') %>%
  add_argument('--output', '') %>%
  parse_args()

config <- read.ini(paste0(here(), "/config.ini"))
source(paste0(config$paths$wombat_paper, "/3_inversion/src/partials/display.R"))
source(paste0(config$paths$root_code_dir, "/results/partials/tables.R"))

###############################################################################
# EXECUTION
###############################################################################

NAME_COLOURS <- c(
  'Observed' = "black",
  'Prior' = "#56B4E9",
  'Hierarchical Posterior' = "#E69F00",
  'Analytical Posterior' = "#009E73"
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
  ) %>%
  filter(month >= config["dates"]["analyse_start"])

anal_samples <- readRDS(args$anal_samples) %>%
  mutate(month = lubridate::floor_date(time, 'month'))

anal_time_series_monthly <- anal_samples %>%
  group_by(obspack_site, month) %>%
  summarise(
    co2 = mean(co2),
    Y2_prior = mean(Y2_prior),
    Z2_hat = mean(Z2_hat),
    Z2_hat_lower = mean(Z2_hat_lower),
    Z2_hat_upper = mean(Z2_hat_upper)
  ) %>%
  filter(month >= config["dates"]["analyse_start"])

df_long <- bind_rows(
obs_time_series_monthly %>%
select(obspack_site, month, value = co2) %>%
mutate(name = 'Observed', lower = NA, upper = NA),
anal_time_series_monthly %>%
select(obspack_site, month, value = Y2_prior) %>%
mutate(name = 'Prior', lower = NA, upper = NA),
obs_time_series_monthly %>%
mutate(name = 'Hierarchical Posterior') %>%
select(name, obspack_site, month, value = Z2_hat, lower = Z2_hat_lower, upper = Z2_hat_upper),
anal_time_series_monthly %>%
mutate(name = 'Analytical Posterior', lower = NA, upper = NA) %>%
select(name, obspack_site, month, value = Z2_hat)
)

# format obspack_site to be more readable
df_long$obspack_site <- toupper(substr(df_long$obspack_site, 1, 3))

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
    ylim(c(322, 336)) +
    scale_colour_manual(values = NAME_COLOURS) +
    scale_fill_manual(values = NAME_COLOURS) +
    facet_wrap(~ obspack_site, ncol = 5) +
    labs(
      x = NULL,
      y = 'Mole fraction / ppb',
      colour = NULL,
      fill = NULL
    ) +
    guides(
      colour = guide_legend(ncol = 4),
      fill = guide_legend(ncol = 4)
    ) +
    theme(
      legend.position = 'bottom',
      text = element_text(size = 20),
      axis.text.x = element_text(angle = 45, hjust = 1)
    )

ggsave_base(
  args$output,
  output,
  width = 40,
  height = 50
)
