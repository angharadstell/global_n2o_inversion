library(dplyr)
library(ggplot2)
library(here)
library(ini)
library(lubridate)
library(reshape2)

# read in useful functions
source(paste0(here(), "/n2o_inv/moving_window/functions.R"))

# read in config
config <- read.ini(paste0(here(), "/config.ini"))

# set specific plots wanted
method <- "mcmc"
case <- "IS-RHO0-FIXEDA-VARYW-NOBIAS-model-err-n2o_std"

# work out what observations (the only difference is the model-measurement error) 
# need to be read in based on the case name
if (grepl("model-err-n2o_std", case)) {
  obs_file <- "model-err-n2o_std-observations.fst"
} else if (grepl("model-err-arbitrary", case)) {
  obs_file <- "model-err-arbitrary-observations.fst"
} else {
  obs_file <- "observations.fst"
}

###############################################################################
# FUNCTIONS
###############################################################################

# extract parameter data
extract_time_var <- function(param) {
  # read in constants from config
  nwindow <- as.numeric(config$moving_window$n_window)
  start_sample <- as.numeric(config$inversion_constants$burn_in) + 1
  end_sample <- as.numeric(config$inversion_constants$no_samples)
  start_year <- year(as.Date(config$dates$perturb_start)) + 1
  end_year <- year(as.Date(config$dates$perturb_end)) - 1

  # extract mean paramter values and put into nicely presented data frame
  params <- sapply(1:nwindow, function(i) colMeans(window_samples[[i]][[param]][start_sample:end_sample, ]))
  colnames(params) <- start_year:end_year

  params
}

# plot a nice histogram of parameters
plot_param_hist <- function(window_samples, param, color_by) {
  # extract mean paramter values and put into nicely presented data frame
  params <- extract_time_var(param)
  melted_params <- melt(params)
  names(melted_params) <- c("region", "year", param)

  # weird thing required to get aes to plot a variable
  param <- sym(param)
  color_by <- sym(color_by)

  # do the plotting
  p <- ggplot(melted_params, aes(x = !!param, fill = as.character(!!color_by))) +
        geom_histogram(bins = 10, position = "dodge") +
        scale_fill_discrete(name = color_by)

  p
}

# plot model-measurement error data
plot_model_measurement_error <- function(obs_file) {
  # read in constants from config
  start_year <- year(as.Date(config$dates$perturb_start))
  end_year <- year(as.Date(config$dates$perturb_end)) - 1

  # extract gamma values from the runs
  gammas <- extract_time_var("gamma")
  # include spinup year values, which have the same gamma as the first year of the real run
  gammas <- cbind(gammas[, 1], gammas)
  colnames(gammas) <- start_year:end_year

  # read in observations
  observations <- fst::read_fst(sprintf("%s/%s", config$paths$geos_inte, obs_file))

  # create a new empty data frame with site and time columns filled, co2_err columns to be filled
  rescaled_obs_err <- expand.grid(rownames(gammas), unique(observations$time)[order(unique(observations$time))])
  colnames(rescaled_obs_err) <- c("site", "time")
  rescaled_obs_err <- rescaled_obs_err %>% arrange(site) %>% mutate(rescaled_co2_err = NA, co2_err = NA)


  # iterate through each site to rescale each model-measurement error by the appropriate gamma
  for (site in row.names(gammas)) {
    # extract observations and gamma parameter for that site
    site_obs <- observations[observations$observation_group == site, ]
    site_gammas <- gammas[rownames(gammas) == site, ]

    # match each year of observations to the appropriate gamma
    obs_year <- as.numeric(format(site_obs$time, format = "%Y"))
    matching <- match(obs_year, names(site_gammas))

    # rescale model-measurement error using gamma
    scaled_site_obs <- site_obs[, c("time", "co2_error")]
    scaled_site_obs$rescaled_co2_err <- sqrt(site_obs$co2_error^2 * (1 / site_gammas[matching]))

    # store rescaled and original values to rescaled_obs_err
    matching <- match(rescaled_obs_err[rescaled_obs_err$site == site, ]$time, scaled_site_obs$time)
    rescaled_obs_err[rescaled_obs_err$site == site, ]$rescaled_co2_err <- scaled_site_obs$rescaled_co2_err[matching]
    rescaled_obs_err[rescaled_obs_err$site == site, ]$co2_err <- scaled_site_obs$co2_error[matching]

  }

  # print some useful values
  print(sprintf("Unscaled model-measurement error: %f ppb", median(rescaled_obs_err$co2_err, na.rm = TRUE)))
  print(sprintf("Posterior model-measurement error: %f ppb", median(rescaled_obs_err$rescaled_co2_err, na.rm = TRUE)))

  # plot
  p <- ggplot(data = rescaled_obs_err, aes(x = time, y = rescaled_co2_err, color = site)) +
         geom_line() + theme(legend.position = "none")

  p
}


###############################################################################
# CODE
###############################################################################

# Constants
nwindow <- as.numeric(config$moving_window$n_window)

# Read in moving window alphas
window_samples <- lapply(1:nwindow,
                         function(i) {
                           try(readRDS(sprintf("%s/real-%s-samples-%s_window%02d.rds",
                           config$paths$moving_window_dir,
                           method,
                           case,
                           i)))
                           }
)

# remove missing files data
for (i in nwindow:1) {
  if (class(window_samples[[i]]) == "try-error") {
    window_samples[[i]] <- NULL
  }
}

# repeat missing data, just til I get a full run
for (i in (length(window_samples) + 1):nwindow) {
    window_samples[[i]] <- window_samples[[length(window_samples)]]
}


### Do the plotting

# plot a
p <- plot_param_hist(window_samples, "a", "year")
plot(p)

# plot w
p <- plot_param_hist(window_samples, "w", "year")
plot(p)

# plot gamma
p <- plot_param_hist(window_samples, "gamma", "year")
plot(p)

# plot model-measurement error
p <- plot_model_measurement_error(obs_file)
plot(p)