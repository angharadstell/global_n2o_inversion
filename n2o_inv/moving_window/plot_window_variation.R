library(ggplot2)
library(here)
library(ini)
library(lubridate)
library(reshape2)


source(paste0(here(), "/n2o_inv/moving_window/functions.R"))

config <- read.ini(paste0(here(), "/config.ini"))

method <- "mcmc"


# Constants 
nregions <- as.numeric(config$inversion_constants$no_regions) + 1
ntime <- interval(as.Date(config$dates$perturb_start), as.Date(config$dates$perturb_end)) %/% months(1)
nwindow <- as.numeric(config$moving_window$n_window)


# plot time variation in parameter
plot_time_var <- function(parameter) {
  categories <- unique(unlist(lapply(1:nwindow, function(i) names(colMeans(window_samples[[i]][[parameter]])))))

  window_param <- matrix(NA, length(categories), nwindow)
  row.names(window_param) <- categories

  for (i in 1:nwindow) {
    match <- categories %in% names(colMeans(window_samples[[i]][[parameter]]))
    window_param[match, i] <- colMeans(window_samples[[i]][[parameter]][config$inversion_constants$burn_in:config$inversion_constants$no_samples, ])
  }

  melted_window_param <- melt(window_param, id.vars=0)

  p <- ggplot(data=melted_window_param, aes(x=Var2, y=value, color=Var1)) + geom_line()# + theme(legend.position = "none")
  plot(p)
}


# Read in moving window alphas
window_samples <- lapply(1:nwindow, 
                         function(i) {try(readRDS(sprintf("%s/real-%s-samples-%s_window%02d.rds",
                         config$paths$moving_window_dir,
                         method,
                         config$inversion_constants$land_ocean_equal_model_case,
                         i)))}
)

# remove missing files data
for (i in nwindow:1) {
  print(i)
  if (class(window_samples[[i]]) == "try-error") {
    window_samples[[i]] <- NULL
  }
}

# repeat missing data, just til I get a full run
for (i in (length(window_samples) + 1):nwindow) {
    window_samples[[i]] <- window_samples[[length(window_samples)]]
}




# plot time variation in gamma
#plot_time_var("gamma")

# plot time variation in a
#plot_time_var("a")

# plot time variation in w
plot_time_var("w")
