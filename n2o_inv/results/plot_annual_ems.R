library(argparser)
library(dplyr)
library(ggplot2)
library(gridExtra)
library(here)
library(ini)
library(lubridate)

args <- arg_parser('', hide.opts = TRUE) %>%
  add_argument('--casename', '') %>%
  parse_args()

###############################################################################
# GLOBAL CONSTANTS AND FUNCTIONS
###############################################################################

# Do a nice plot of the annual emissions
plot_annual_ems <- function(flux_samples) {
  # make a nice ggplot
  p <- ggplot(flux_samples, aes(year, flux_mean, color = estimate)) +
       geom_line() +
       geom_ribbon(aes(ymin = flux_lower, ymax = flux_upper), alpha = 0.1) +
       xlab("Year") + ylab(expression(N[2] * "O Flux / TgN " * yr^-1)) +
       scale_x_continuous(breaks = seq(first_year, last_year, 2)) +
       theme(legend.title = element_blank())

  p
}

# Select a region, see if there's a significant trend in its annual ems,
# and plot those annual ems
regional_ems_plot <- function(region) {
  # select the desired region
  regional_flux_samples <- annual_flux_samples %>% filter(name == region)

  # Are there any significant linear trends?
  print(region)
  # need to remove prior ems first
  lm_emissions <- regional_flux_samples %>% filter(estimate == "Posterior")
  lm_analysis <- lm(lm_emissions$flux_mean ~ lm_emissions$year)
  print(summary(lm_analysis))

  # plot annual emissions for that region
  p <- plot_annual_ems(regional_flux_samples)

  p
}

# print out the mean annual emissions for that region, over the time period,
# including confidence intervals
print_ems <- function(region) {
  region_post_ems <- annual_flux_samples %>%
                       filter(name == region, estimate == "Posterior")
  global_mean <- mean(region_post_ems$flux_mean)
  global_ci_l <- mean(region_post_ems$flux_lower)
  global_ci_u <- mean(region_post_ems$flux_upper)

  print(sprintf("%s mean for %d-%d: %s (%s-%s) TgNyr-1",
        region,
        min(region_post_ems$year),
        max(region_post_ems$year),
        format(round(global_mean, digits = 1), nsmall = 1),
        format(round(global_ci_l, digits = 1), nsmall = 1),
        format(round(global_ci_u, digits = 1), nsmall = 1)))
}

###############################################################################
# GLOBAL CONSTANTS
###############################################################################

# read in config file
config <- read.ini(paste0(here(), "/config.ini"))

###############################################################################
# EXECUTED CODE
###############################################################################

# read in flux samples
flux_samples <- bind_rows(
  readRDS(paste0(config$paths$inversion_results,
                 "/real-flux-aggregates-samples-",
                 args$casename, ".rds")))


# create annual mean with 95% confidence intervals
annual_flux_samples <- flux_samples %>% mutate(year = year(month_start)) %>%
  group_by(estimate, name, year) %>%
  summarise(
    flux_mean = sum(flux_mean),
    flux_lower = quantile(colSums(flux_samples), probs = 0.025, na.rm = TRUE),
    flux_upper = quantile(colSums(flux_samples), probs = 0.975, na.rm = TRUE)
  )

# first year to plot, dont plot first year due to spinup effects
first_year <- year(config$dates$perturb_start) + 1
annual_flux_samples <- annual_flux_samples %>% filter(year >= first_year)
last_year <- year(config$dates$perturb_end) - 1

# plot global annual ems
p_global <- regional_ems_plot("Global")
ggsave(sprintf("%s/global_annual_ems_wombat-%s.pdf", config$paths$inversion_results, args$casename))

# print out mean and confidence interval for period
print_ems("Global")
print_ems("Global land")
print_ems("Global oceans")

# plot all land area annual ems
max_land_region <- as.numeric(config$inversion_constants$no_land_regions) - 1
regional_plots <- lapply(sprintf("T%02d", seq(0, max_land_region)),
                         function(x) {regional_ems_plot(x) + ggtitle(x)})
p_regional <- do.call("arrangeGrob", c(regional_plots, nrow = 3))
ggsave(sprintf("%s/regional_land_annual_ems_wombat-%s.pdf", config$paths$inversion_results, args$casename),
       p_regional, height = 20, width = 20)

# plot all ocean areas
regional_plots <- lapply(sprintf("T%02d", seq(max_land_region + 1, config$inversion_constants$no_regions)),
                         function(x) {regional_ems_plot(x) + ggtitle(x)})
p_regional <- do.call("arrangeGrob", c(regional_plots, nrow = 3))
ggsave(sprintf("%s/regional_ocean_annual_ems_wombat-%s.pdf", config$paths$inversion_results, args$casename),
       p_regional, height = 20, width = 20)