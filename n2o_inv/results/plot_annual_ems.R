library(argparser)
library(dplyr)
library(ggplot2)
library(ggpubr)
library(grid)
library(gridExtra)
library(here)
library(ini)
library(lubridate)

source(paste0(here(), "/n2o_inv/results/partials/tables.R"))

###############################################################################
# GLOBAL CONSTANTS AND FUNCTIONS
###############################################################################

# read in flux samples
# create annual mean with 95% confidence intervals
get_annual_ems <- function(casename) {
  flux_samples <- bind_rows(
    readRDS(paste0(config$paths$inversion_results,
                  "/real-flux-aggregates-samples-",
                  casename, ".rds")))

  annual_flux_samples <- flux_samples %>%
                         mutate(year = year(month_start)) %>%
                         group_by(estimate, name, year) %>%
                         summarise(flux_mean = sum(flux_mean),
                                   flux_lower = quantile(colSums(flux_samples), probs = 0.025, na.rm = TRUE),
                                   flux_upper = quantile(colSums(flux_samples), probs = 0.975, na.rm = TRUE)
                                  )

  annual_flux_samples
}

# Do a nice plot of the annual emissions
plot_annual_ems <- function(flux_samples, name_colours, labels) {
  first_year <- min(flux_samples$year)
  last_year <- max(flux_samples$year)
  # make a nice ggplot
  p <- ggplot(flux_samples, aes(year, flux_mean, color = estimate)) +
       {if (length(unique(flux_samples$year)) > 1) geom_line()} +
       {if (length(unique(flux_samples$year)) == 1) geom_point()} +
       {if (length(unique(flux_samples$year)) > 1) geom_ribbon(aes(ymin = flux_lower, ymax = flux_upper), alpha = 0.1)} +
       {if (length(unique(flux_samples$year)) == 1) geom_errorbar(aes(ymin = flux_lower, ymax = flux_upper), width = 0.5)} +
       ylab(expression(N[2] * "O Flux / TgN " * yr^-1)) +
       scale_x_continuous(breaks = seq(first_year, last_year, 2)) +
       scale_colour_manual(values = name_colours,
                           labels = labels) +
       theme(legend.title = element_blank(), axis.title.x = element_blank())

  p
}

# Select a region, see if there's a significant trend in its annual ems,
# and plot those annual ems
regional_ems_plot <- function(annual_flux_samples, region, name_colours, labels) {
  # select the desired region
  regional_flux_samples <- annual_flux_samples %>% filter(name == region)

  # plot annual emissions for that region
  if (region == "Global") {
    # Are there any significant linear trends?
    # need to remove prior ems first
    lm_emissions <- regional_flux_samples %>% filter(estimate == "Posterior")
    lm_analysis <- lm(lm_emissions$flux_mean ~ lm_emissions$year)
    print(summary(lm_analysis))
    p <- plot_annual_ems(regional_flux_samples, name_colours, labels)
  } else {
    nice_names <- setNames(names(REGION_NAME_TO_CODE), REGION_NAME_TO_CODE)
    p <- plot_annual_ems(regional_flux_samples, name_colours, labels) +
           ggtitle(sprintf("%s: %s", region, nice_names[region])) +
           theme(axis.title.y = element_blank())
  }

  p
}

# print out the mean annual emissions for that region, over the time period,
# including confidence intervals
print_ems <- function(annual_flux_samples, region) {
  region_post_ems <- annual_flux_samples %>%
                       filter(name == region, estimate == "Posterior")
  global_mean <- mean(region_post_ems$flux_mean)
  global_ci_l <- mean(region_post_ems$flux_lower)
  global_ci_u <- mean(region_post_ems$flux_upper)

  message(sprintf("%s mean for %d-%d: %s (%s-%s) TgNyr-1",
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

main <- function() {
  args <- arg_parser("", hide.opts = TRUE) %>%
    add_argument("--casename", "") %>%
    parse_args()

  # args <- list()
  # args$casename <- "IS-RHO0-FIXEDA-VARYW-NOBIAS-model-err-n2o_std_windowall"

  NAME_COLOURS <- c(
  'Prior' = get_colour('wombat_prior'),
  'Posterior' = get_colour('wombat_lg')
  )

  labels <- c("Prior (mean, 95% cred. int.)", "WOMBAT Posterior (mean, 95% cred. int.)")

  # read in flux samples
  # create annual mean with 95% confidence intervals
  annual_flux_samples <- get_annual_ems(args$casename)

  # first year to plot, dont plot first year due to spinup effects
  first_year <- year(config$dates$perturb_start) + 1
  annual_flux_samples <- annual_flux_samples %>% filter(year >= first_year)

  # plot global annual ems
  p_global <- regional_ems_plot(annual_flux_samples, "Global", NAME_COLOURS, labels)
  ggsave(sprintf("%s/global_annual_ems_wombat-%s.pdf", config$paths$inversion_results, args$casename))

  # print out mean and confidence interval for period
  print_ems(annual_flux_samples, "Global")
  print_ems(annual_flux_samples, "Global land")
  print_ems(annual_flux_samples, "Global oceans")

  # plot all land area annual ems
  max_land_region <- as.numeric(config$inversion_constants$no_land_regions) - 1
  regional_plots <- lapply(sprintf("T%02d", seq(0, max_land_region)), regional_ems_plot,
                           annual_flux_samples=annual_flux_samples, name_colours=NAME_COLOURS, labels=labels)
  p_regional <- ggarrange(plotlist=regional_plots, ncol=4, nrow=3, common.legend = TRUE, legend="bottom")
  p_regional <- annotate_figure(p_regional, left = textGrob(expression(N[2] * "O Flux / TgN " * yr^-1),
                                                            rot = 90, vjust = 0.5, gp = gpar(cex = 1.3)))
  ggsave(sprintf("%s/regional_land_annual_ems_wombat-%s.pdf", config$paths$inversion_results, args$casename),
        p_regional, height = 20, width = 20)

  # plot all ocean areas
  regional_plots <- lapply(sprintf("T%02d", seq(max_land_region + 1, config$inversion_constants$no_regions)),
                          regional_ems_plot, annual_flux_samples=annual_flux_samples, name_colours=NAME_COLOURS, labels=labels)
  p_regional <- ggarrange(plotlist=regional_plots, ncol=4, nrow=3, common.legend = TRUE, legend="bottom")
  p_regional <- annotate_figure(p_regional, left = textGrob(expression(N[2] * "O Flux / TgN " * yr^-1),
                                                            rot = 90, vjust = 0.5, gp = gpar(cex = 1.3)))
  ggsave(sprintf("%s/regional_ocean_annual_ems_wombat-%s.pdf", config$paths$inversion_results, args$casename),
        p_regional, height = 20, width = 20)
}

if (getOption('run.main', default = TRUE)) {
   main()
}
