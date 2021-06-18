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

source(Sys.getenv('RESULTS_BASE_PARTIAL'))
source(Sys.getenv('RESULTS_TABLES_PARTIAL'))
source(Sys.getenv('RESULTS_DISPLAY_PARTIAL'))

# interactive
# fileloc <- (function() {
#   attr(body(sys.function()), "srcfile")
# })()$filename

# config <- read.ini(paste0(gsub("n2o_inv/results.*", "", fileloc), "config.ini"))

# casename <- config$inversion_constants$model_case

# args <- vector(mode = "list", length = 5)

# args$obs_samples <- paste0(config$paths$inversion_result, "/obs_matched_samples.rds")
# args$output <- paste0(config$paths$inversion_result, "/obs_time_series.pdf")

# source(paste0(config$paths$wombat_paper, "/4_results/src/partials/base.R"))
# source(paste0(config$paths$wombat_paper, "/4_results/src/partials/tables.R"))
# source(paste0(config$paths$wombat_paper, "/4_results/src/partials/display.R"))

###############################################################################
# EXECUTION
###############################################################################

NAME_COLOURS <- c(
  'Observed' = 'black',
  'WOMBAT Prior (mean)' = get_colour('wombat_prior'),
  'WOMBAT IS (mean, 95% cred. int.)' = get_colour('wombat_lg')
)

obs_samples <- readRDS(args$obs_samples) %>%
  filter(variant == 'Correlated') %>%
  mutate(month = lubridate::floor_date(time, 'month'))

obs_standard_deviations <- obs_samples %>%
  group_by(observation_group, obspack_site) %>%
  summarise(
    # NOTE(mgnb): we assume perfect correlation
    Y2_tilde_sd = sqrt(mean(co2_error ^ 2))
  ) %>%
  ungroup()

obs_time_series_monthly <- obs_samples %>%
  group_by(observation_group, obspack_site, month) %>%
  summarise(
    co2 = mean(co2),
    Y2_prior = mean(Y2_prior),
    Y2_tilde_samples = t(colMeans(Y2_tilde_samples))
  ) %>%
  ungroup() %>%
  left_join(
    obs_standard_deviations,
    by = c('observation_group', 'obspack_site')
  ) %>%
  mutate(
    Y2 = Y2_prior + rowMeans(Y2_tilde_samples),
    Z2_tilde_samples = Y2_tilde_samples + rnorm(matrix(
      rnorm(n() * ncol(Y2_tilde_samples), sd = Y2_tilde_sd),
      nrow = n()
    )),
    Z2_lower = Y2_prior + matrixStats::rowQuantiles(Z2_tilde_samples, probs = 0.025),
    Z2_upper = Y2_prior + matrixStats::rowQuantiles(Z2_tilde_samples, probs = 0.975)
  ) #%>%
  #select(-Z2_tilde_samples)

df_long <- bind_rows(
obs_time_series_monthly %>%
filter(observation_group == 'IS') %>%
select(obspack_site, month, value = co2) %>%
mutate(name = 'Observed', lower = NA, upper = NA),
obs_time_series_monthly %>%
filter(observation_group == 'IS') %>%
select(obspack_site, month, value = Y2_prior) %>%
mutate(name = 'WOMBAT Prior (mean)', lower = NA, upper = NA),
obs_time_series_monthly %>%
mutate(name = sprintf('WOMBAT %s (mean, 95%% cred. int.)', observation_group)) %>%
select(name, obspack_site, month, value = Y2, lower = Z2_lower, upper = Z2_upper)
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
      y = 'Mole fraction [ppm]',
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
