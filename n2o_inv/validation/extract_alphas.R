library(ggplot2)
library(here)
library(ini)
library(lubridate)

source(paste0(here(), "/n2o_inv/moving_window/functions.R"))

# choose which window inversion to read in
method <- "mcmc"
case <- "IS-RHO0-FIXEDA-VARYW-NOBIAS-model-err-n2o_std"

# get constants from config
config <- read.ini(paste0(here(), "/config.ini"))
nregions <- as.numeric(config$inversion_constants$no_regions) + 1
ntime <- interval(as.Date(config$dates$perturb_start), as.Date(config$dates$perturb_end)) %/% months(1)
nwindow <- as.numeric(config$moving_window$n_window)

# Read in moving window alphas
# get inversion alphas
# try to read in files
window_alphas <- lapply(1:nwindow,
                        function(i) try(inversion_alphas(i, case, method)))
# if file doesnt exist, just have nans
for (i in 1:length(window_alphas)) {
  if (class(window_alphas[[i]]) == "try-error") {
    window_alphas[[i]] <- rep(NA, length(window_alphas[[1]]))
  }
}

# create inversion results alphas for each window
inv_alphas <- rep(0, nregions * ntime)
name_alphas <- rep(0, nregions * ntime)
for (i in 1:nwindow) {
  inv_alphas[(nregions * 12 * i + 1):(nregions * 12 * (i + 1))] <- window_alphas[[i]][(nregions * 12 + 1):(nregions * 12 * 2)]
  name_alphas[(nregions * 12 * i + 1):(nregions * 12 * (i + 1))] <- names(window_alphas[[i]][(nregions * 12 + 1):(nregions * 12 * 2)])
}

# put in spinup year
inv_alphas[0:(nregions * 12)] <- window_alphas[[1]][0:(nregions * 12)]
name_alphas[0:(nregions * 12)] <- names(window_alphas[[i]][0:(nregions * 12)])

# put into dataframe
alpha_df <- data.frame(label = name_alphas, value = inv_alphas)

# save for later use
write.csv(x = alpha_df, file = sprintf("%s/alphas-%s-%s.csv", config$paths$geos_inte, method, case))
