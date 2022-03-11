library(ggplot2)
library(here)
library(ini)
library(lubridate)

source(paste0(here(), "/n2o_inv/moving_window/functions.R"))

# choose which window inversion to read in
# compare analytical window inversion to check the moving window method works
# or compare to the mcmc window inversion
method <- "mcmc"
case <- "IS-RHO0-FIXEDA-VARYW-NOBIAS-model-err-n2o_std"

# work out what observations (the only difference is the model-measurement error)
# need to be read in based on the case name
if (grepl("model-err-n2o_std", case)) {
  obs_file <- "model-err-n2o_std-observations.fst"
  model_err_suffix <- "-model-err-n2o_std"
} else if (grepl("model-err-arbitrary", case)) {
  obs_file <- "model-err-arbitrary-observations.fst"
  model_err_suffix <- "-model-err-arbitrary"
} else {
  obs_file <- "observations.fst"
  model_err_suffix <- ""
}

# get constants from config
config <- read.ini(paste0(here(), "/config.ini"))
nregions <- as.numeric(config$inversion_constants$no_regions) + 1
ntime <- interval(as.Date(config$dates$perturb_start), as.Date(config$dates$perturb_end)) %/% months(1)
nwindow <- as.numeric(config$moving_window$n_window)

# Read in moving window alphas
# get inversion alphas
# try to read in files
window_alphas <- lapply(1:nwindow,
                        function(i) {try(inversion_alphas(i, case, method))})
# if file doesnt exist, just have nans
for (i in 1:length(window_alphas)) {
  if (class(window_alphas[[i]]) == "try-error") {
    window_alphas[[i]] <- rep(NA, length(window_alphas[[1]]))
  }
}

# create ic alphas for each window
spinup_alphas <- rep(0, nregions * ntime)
dim(spinup_alphas) <- c(1, nregions * ntime)
for (i in 0:(nwindow - 1)) {
      spinup_alphas[(nregions * 12 * i + 1):(nregions * 12 * (i + 1))] <- window_alphas[[i + 1]][1:(nregions * 12)]
    }

# create inversion results alphas for each window
inv_alphas <- rep(0, nregions * ntime)
dim(inv_alphas) <- c(1, nregions * ntime)
for (i in 1:nwindow) {
  inv_alphas[(nregions * 12 * i + 1):(nregions * 12 * (i + 1))] <- window_alphas[[i]][(nregions * 12 + 1):(nregions * 12 * 2)]
}

# do full series analytical inversion, or read in if already saved
print("Doing full series inversion...")
full_analytical_file <- sprintf("%s/real-mcmc-samples-analytical%s.rds", config$paths$geos_inte, model_err_suffix)
# make analytical plottable
file.copy(from = sprintf("%s/real-model-%s.rds", config$paths$geos_inte, case),
          to = sprintf("%s/real-model-analytical%s.rds", config$paths$geos_inte, model_err_suffix))

if (file.exists(full_analytical_file)) {
  print("full analytical file already exists...")
  samples <- readRDS(full_analytical_file)
  full_alphas <- colMeans(samples$alpha)
} else {
  # read in intermediates
  observations <- fst::read_fst(sprintf("%s/%s", config$paths$geos_inte, obs_file))
  perturbations <- fst::read_fst(sprintf("%s/perturbations.fst", config$paths$geos_inte))
  control_mf <- fst::read_fst(sprintf("%s/control-mole-fraction.fst", config$paths$geos_inte))
  sensitivities <- fst::read_fst(sprintf("%s/sensitivities.fst", config$paths$geos_inte))

  full_alphas <- do_analytical_inversion(observations, control_mf, perturbations, sensitivities)
  # take some samples to make it look like mcmc
  n_samples <- as.numeric(config$inversion_constants$no_samples)
  post_alpha_samples <- mvrnorm(n_samples, full_alphas$mean, full_alphas$cov)
  n_regions <- as.numeric(config$inversion_constants$no_regions) + 1
  n_sites <- length(unique(observations$obspack_site))
  # save like mcmc samples for comparison
  saveRDS(structure(list(kappa = coda::mcmc(matrix(0, n_samples, n_regions)),
                    alpha = coda::mcmc(post_alpha_samples),
                    eta = coda::mcmc(matrix(NA, n_samples, 0)),
                    a = coda::mcmc(matrix(0, n_samples, n_regions)),
                    w = coda::mcmc(matrix(5.7, n_samples, n_regions)),
                    beta = coda::mcmc(matrix(NA, n_samples, 0)),
                    gamma = coda::mcmc(matrix(1, n_samples, n_sites)),
                    rho = coda::mcmc(matrix(0, n_samples, n_sites)),
                    ell = coda::mcmc(matrix(1, n_samples, n_sites))),
                    class = 'flux_inversion_mcmc'),
                    full_analytical_file)
  full_alphas <- colMeans(post_alpha_samples)
}

# cut out 2010 and compare to fullinv
region <- rep(0:(nregions - 1), (ntime - 12))
month <- rep(1:(ntime - 12), each = nregions)
compare_df <- data.frame(region = region,
                         month = month,
                         full = full_alphas[(nregions * 12 + 1):length(inv_alphas)],
                         window = inv_alphas[(nregions * 12 + 1):length(inv_alphas)])
p <- ggplot(data = compare_df, aes(full, window, color = month)) + geom_point()
plot(p)
# ggsave(filename = sprintf("%s/corr-%s-%s-to-full.pdf",
#                           case
#                           config$paths$moving_window_dir,
#                           method)))

# what are the R squared values for the full inversion vs the window inversion / the window spinup alphas?
rsq <- cor(full_alphas[(nregions * 12 + 1):length(inv_alphas)], inv_alphas[(nregions * 12 + 1):length(inv_alphas)]) ^ 2
print(sprintf("R2 value for full analytical alphas and window inversion alphas: %f", rsq))
rsq <- cor(full_alphas[(nregions * 12 + 1):length(inv_alphas)], spinup_alphas[(nregions * 12 + 1):length(inv_alphas)]) ^ 2
print(sprintf("R2 value for full analytical alphas and window inversion spinup alphas: %f", rsq))
