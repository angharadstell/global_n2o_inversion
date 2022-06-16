# This script plots and analyses the inferred hyperparameters
library(dplyr)
library(ggplot2)
library(ggthemes)
library(gridExtra)
library(here)
library(ini)
library(lubridate)
library(raster)
library(RColorBrewer)
library(reshape2)
library(rnaturalearth)
library(viridis)

# read in useful functions
source(paste0(here(), "/n2o_inv/moving_window/functions.R"))

# read in config
config <- read.ini(paste0(here(), "/config.ini"))

###############################################################################
# FUNCTIONS
###############################################################################

# extract parameter data
extract_time_var <- function(window_samples, param) {
  # read in constants from config
  nwindow <- as.numeric(config$moving_window$n_window)
  start_sample <- as.numeric(config$inversion_constants$burn_in) + 1
  end_sample <- as.numeric(config$inversion_constants$no_samples)
  start_year <- year(as.Date(config$dates$perturb_start)) + 1
  end_year <- year(as.Date(config$dates$perturb_end)) - 1

  # extract mean paramter values and put into nicely presented data frame
  params <- sapply(1:nwindow, function(i) colMeans(window_samples[[i]][[param]][start_sample:end_sample, ]))
  if (is.list(params)) {
    # gammas don't combine nicely because not every site is present in each window!
    # extract complete list of sites
    unique_sites <- unique(unlist(sapply(1:nwindow, function(i) names(colMeans(window_samples[[i]]$gamma)))))
    # match the parameters to the list of sites
    matched <- lapply(1:nwindow, function(i) params[[i]][match(unique_sites, names(params[[i]]))])
    # recombined as one matrix
    params <- as.matrix(data.frame(matched))
    colnames(params) <- start_year:end_year
  } else {
    colnames(params) <- start_year:end_year
  }
  params
}

# plot a nice histogram of parameters
plot_param_hist <- function(window_samples, param, color_by) {
  # extract mean paramter values and put into nicely presented data frame
  params <- extract_time_var(window_samples, param)
  melted_params <- melt(params)
  # what is labelled as region will actually be site for gamma...
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

# plot the mean parameter values on a world map
plot_param_map <- function(window_samples) {
  # calculate the scaling factor standard deviation
  ws <- extract_time_var(window_samples, "w")
  std_df <- data.frame(std = rowMeans(1 / sqrt(ws)), region = 0:config$inversion_constants$no_regions)

  # read in transcom map and make it into a pretty dataframe
  transcom_mask <- raster(config$inversion_constants$geo_transcom_mask, stopIfNotEqualSpaced = FALSE)
  test_spdf <- as(transcom_mask, "SpatialPixelsDataFrame")
  test_df <- as.data.frame(test_spdf)
  colnames(test_df) <- c("region", "x", "y")
  matching <- match(test_df$region, std_df$region)
  test_df$std <- std_df$std[matching]

  # repeat -180 lon as 180 lon because world map includes 180, whereas geoschem includes -180
  long_175 <- test_df[test_df$x == -180, ]
  long_175$x <- 180
  test_df <- rbind(test_df, long_175)

  # get world map
  world <- ne_countries(scale = "medium", returnclass = "sf")

  # calculate scaling of std of model-measurement error
  gammas <- extract_time_var(window_samples, "gamma")
  mm_df <- data.frame(mm = rowMeans(1 / sqrt(gammas), na.rm = TRUE))

  # read in obs, match gammas to site locations
  obs_raw <- fst::read_fst(sprintf("%s/observations.fst", config$paths$geos_inte))
  matching <- match(obs_raw$observation_group, rownames(mm_df))
  obs <- obs_raw %>%
         mutate(mm = mm_df$mm[matching]) %>%
         dplyr::select(observation_group, latitude, longitude, mm) %>%
         group_by(observation_group) %>%
         summarise(lat = mean(latitude),
                   lon = mean(longitude),
                   mm_scale = mean(mm))

  # plot
  p1 <- ggplot(data = world) +
         geom_tile(data = test_df, aes(x = x, y = y, fill = std)) +
         scale_fill_viridis() +
         geom_sf(color = "white", fill = NA) +
         theme_map() +
         theme(legend.position = "bottom", legend.box = "vertical", legend.justification = "right") +
         labs(fill = expression(paste(1 / sqrt(italic(w)), "   "))) +
         theme(legend.key.width = unit(1, "cm")) +
         theme(text = element_text(size = 17)) +
         coord_sf(xlim = c(-180, 180), ylim = c(-90, 90), expand = FALSE) +
         ggtitle(expression(paste("a. Flux scaling factor precision: ",  1/sqrt(italic(w)))))

    p2 <- ggplot(data = world) +
         geom_sf(color = "white", fill = "#3f3c3c") +
         geom_point(data = obs, aes(x = lon, y = lat, color = mm_scale), size = 5) +
         scale_color_gradient2(midpoint = 1, low = "blue", mid = "white",
                     high = "red") +
         theme_map() +
         theme(legend.position = "bottom", legend.box = "vertical", legend.justification = "right") +
         labs(color = expression(paste(1 / sqrt(italic(gamma)), "   "))) +
         theme(legend.key.width = unit(1, "cm")) +
         theme(text = element_text(size = 17),
               panel.background = element_rect(fill = "#3f3c3c")) +
         coord_sf(xlim = c(-180, 180), ylim = c(-90, 90), expand = FALSE) +
         ggtitle(expression(paste("b. Error budget scaling factor: ", 1/sqrt(italic(gamma)))))


    p <- grid.arrange(p1, p2, ncol = 1)

    p
}

# examine model-measurement error data
examine_model_measurement_error <- function(window_samples, obs_file) {
  # read in constants from config
  start_year <- year(as.Date(config$dates$perturb_start))
  end_year <- year(as.Date(config$dates$perturb_end)) - 1

  # extract gamma values from the runs
  gammas <- extract_time_var(window_samples, "gamma")
  message(sprintf("Median gamma: %f", median(gammas, na.rm = TRUE)))

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
  # not sure this is a reliable measure because the distribution of co2_err changes
  # probably better to look at median gamma
  message(sprintf("Unscaled model-measurement error: %f ppb", median(rescaled_obs_err$co2_err, na.rm = TRUE)))
  message(sprintf("Posterior model-measurement error: %f ppb", median(rescaled_obs_err$rescaled_co2_err, na.rm = TRUE)))

  print("descending median error at each site before rescaling:")
  print(head(rescaled_obs_err %>% group_by(site) %>% summarise(median = median(co2_err, na.rm=TRUE)) %>% arrange(median), 10))
}

###############################################################################
# CODE
###############################################################################

main <- function() {
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


  p <- plot_param_map(window_samples)
  plot(p)
  ggsave(paste0(config$paths$inversion_results, "/hyperparameter_map.pdf"),
         p, width = 9)


  # plot gamma
  p <- plot_param_hist(window_samples, "gamma", "year")
  plot(p)

  # examine model-measurement error
  examine_model_measurement_error(window_samples, obs_file)


  # look at variation in the mean
  print("Look at hyper-parameter interannual variation:")
  gammas <- extract_time_var(window_samples, "gamma")
  ws <- extract_time_var(window_samples, "w")
  gamma_sd_df <- data.frame(mean = rowMeans(gammas, na.rm = TRUE), sd = apply(gammas, 1, sd, na.rm = TRUE))
  w_sd_df <- data.frame(mean = rowMeans(ws, na.rm = TRUE), sd = apply(ws, 1, sd, na.rm = TRUE))
  print(head(gamma_sd_df))
  print(head(w_sd_df))
}

if (getOption("run.main", default = TRUE)) {
   main()
}
