library(dplyr)
library(ggplot2)
library(gridExtra)
library(here)
library(ini)
library(reshape2)

###############################################################################
# GLOBAL CONSTANTS
###############################################################################
config <- read.ini(paste0(here(), "/config.ini"))

###############################################################################
# FUNCTIONS
###############################################################################

alpha_plot <- function(i) {
  df <- data.frame(month=1:ntime, alpha=mean_alphas[i, ], truth=alpha_true_0001[i,])
  melted_df <- melt(df, id="month")
  p <- ggplot(melted_df) +
         geom_line(aes(x=month, y=value, color=variable)) +
         ggtitle(paste("Region", i-1)) +
         theme(axis.title.x = element_blank(), axis.title.y = element_blank(),
               legend.position = "none")

  p
}

###############################################################################
# MAIN CODE
###############################################################################

# read in samples
output_suffix <- "m1_ac0_ar1"
samples <- readRDS(sprintf("%s/real-mcmc-samples-%s_%s_0001.rds",
                           config$paths$pseudodata_dir,
                           config$inversion_constants$land_ocean_equal_model_case,
                           output_suffix))

alpha_true <- readRDS(sprintf("%s/alpha_samples_%s.rds", config$paths$pseudodata_dir, output_suffix))
alpha_true_0001 <- alpha_true[1, ]

# set some constants
nregions <- as.numeric(config$inversion_constants$no_regions) + 1
nsamples <- dim(samples$alpha)[1]
ntime <- as.integer(dim(samples$alpha)[2] / nregions)
start_sample <- (as.numeric(config$inversion_constants$burn_in) + 1)

print("1/gamma in paper / gamma in code / measurement error inflation:")
if (dim(samples$gamma)[2] == 1) {
  print(mean(samples$gamma[start_sample:nsamples, ]))
} else {
  print(colMeans(samples$gamma[start_sample:nsamples, ]))
}

# smaller tau_w means larger sd
print("tau_w in paper / w in code / measure of alpha uncertainty:")
print(colMeans(samples$w[start_sample:nsamples, ]))

print("kappa in paper / a in code / autocorrelation coefficient:")
print(colMeans(samples$a[start_sample:nsamples, ]))

print("alphas:")
mean_alphas <- colMeans(samples$alpha[start_sample:nsamples, ])
dim(mean_alphas) <- c(nregions, ntime)
dim(alpha_true_0001) <- c(nregions, ntime)

alpha_plot_list <- lapply(1:nregions, alpha_plot)
do.call("grid.arrange", c(alpha_plot_list, nrow = 4))



# # does err adequately cover the gamma variation?
# fn <- ncdf4::nc_open(sprintf("%s/%s/model_err.nc", config$paths$geos_out, config$inversion_constants$model_err_case))
# v <- function(...) ncdf4::ncvar_get(fn, ...)

# observations <- fst::read_fst(sprintf("%s/observations.fst", config$paths$geos_inte))
# obs_err <- observations %>% group_by(obspack_site) %>% summarise(obs_err=median(co2_error))

# gammas <- colMeans(samples$gamma[start_sample:nsamples, ])
# model_std <- colMeans(v("model_std"), na.rm = TRUE)


# plot(sqrt(1 / gammas * obs_err$obs_err^2), sqrt(obs_err$obs_err^2 + model_std^2))
