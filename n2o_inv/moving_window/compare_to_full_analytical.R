library(ggplot2)
library(here)
library(ini)
library(lubridate)


source(paste0(here(), "/n2o_inv/moving_window/functions.R"))

config <- read.ini(paste0(here(), "/config.ini"))

method <- "analytical"

# Read in moving window alphas
nregions <- as.numeric(config$inversion_constants$no_regions) + 1
ntime <- interval(as.Date(config$dates$perturb_start), as.Date(config$dates$perturb_end)) %/% months(1)
nwindow <- as.numeric(config$moving_window$n_window)

# get inversion alphas
window_alphas <- lapply(1:nwindow, function(i) {inversion_alphas(i, method)})

# create ic alphas
spinup_alphas <- updated_alphas(nwindow, window_alphas, nregions, ntime)

inv_alphas <- rep(0, nregions * ntime)
dim(inv_alphas) <- c(1, nregions * ntime)
for (i in 1:nwindow) {
  inv_alphas[(nregions*12*i+1):(nregions*12*(i+1))] <- window_alphas[[i]][(nregions*12+1):(nregions*12*2)]
}

#plot(spinup_alphas, inv_alphas)


# do whole series analytical inversion
# read in intermediates
observations <- fst::read_fst(sprintf("%s/observations.fst", config$paths$geos_inte))
perturbations <- fst::read_fst(sprintf("%s/perturbations.fst", config$paths$geos_inte))
control_mf <- fst::read_fst(sprintf("%s/control-mole-fraction.fst", config$paths$geos_inte))
sensitivities <- fst::read_fst(sprintf("%s/sensitivities.fst", config$paths$geos_inte))

# do analytical inversion
print("Doing full series inversion...")
full_alphas <- do_analytical_inversion(observations, control_mf, perturbations, sensitivities)

# samples <- readRDS(paste0(config$paths$geos_inte, "/real-mcmc-samples-IS-RHO0-VARYA-VARYW-NOBIAS.rds")) 
# full_alphas_wombat <- colMeans(samples$alpha)

# cut out 2010 and compare to fullinv
region <- rep(0:(nregions-1), (ntime - 12))
month <- rep(1:(ntime - 12), each=nregions)
compare_df <- data.frame(region = region,
                         month = month,
                         full = full_alphas$mean[(nregions*12+1):length(inv_alphas)],
                         window = inv_alphas[(nregions*12+1):length(inv_alphas)])
p <- ggplot(data = compare_df, aes(full, window, color = month)) + geom_point()
plot(p)
# ggsave(filename = sprintf("%s/corr-%s-to-full-%02d.pdf", 
#                           config$paths$moving_window_dir,
#                           method,
#                           as.numeric(config$moving_window$n_years)))

rsq <- cor(full_alphas$mean[(nregions*12+1):length(inv_alphas)], inv_alphas[(nregions*12+1):length(inv_alphas)]) ^ 2
print(rsq)
