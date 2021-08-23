library(gridExtra)
library(ini)


###############################################################################
# GLOBAL CONSTANTS
###############################################################################
fileloc <- (function() {
  attr(body(sys.function()), "srcfile")
})()$filename

config <- read.ini(paste0(gsub("n2o_inv/plots.*", "", fileloc), "config.ini"))

###############################################################################
# FUNCTIONS
###############################################################################

alpha_plot <- function(i) {
  p <- ggplot(data.frame(month=1:ntime, alpha=mean_alphas[i, ]), aes(x=month, y=alpha)) +
         geom_line() + ggtitle(paste("Region", i-1)) +
         theme(axis.title.x = element_blank(), axis.title.y = element_blank())

  p
}

###############################################################################
# MAIN CODE
###############################################################################

# read in samples
samples <- readRDS(sprintf("%s/real-mcmc-samples-%s.rds",
                           config$paths$geos_inte,
                           config$inversion_constants$model_case))

# set some constants
nregions <- as.numeric(config$inversion_constants$no_regions) + 1
nsamples <- dim(samples$alpha)[1]
ntime <- as.integer(dim(samples$alpha)[2] / nregions)
start_sample <- 1001

print("1/gamma in paper / gamma in code / measurement error inflation:")
print(colMeans(samples$gamma[start_sample:nsamples, ]))

print("tau_w in paper / w in code / measure of alpha uncertainty:")
print(colMeans(samples$w[start_sample:nsamples, ]))

print("kappa in paper / a in code / autocorrelation coefficient:")
print(colMeans(samples$a[start_sample:nsamples, ]))

print("alphas:")
mean_alphas <- colMeans(samples$alpha[start_sample:nsamples, ])
dim(mean_alphas) <- c(nregions, ntime)

alpha_plot_list <- lapply(1:nregions, alpha_plot)
do.call("grid.arrange", c(alpha_plot_list, nrow=4))