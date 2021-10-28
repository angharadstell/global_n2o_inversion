library(argparser)
library(dplyr)
library(fst)
library(here)
library(ini)
library(Matrix)


source(paste0(here(), "/n2o_inv/moving_window/functions.R"))

config <- read.ini(paste0(here(), "/config.ini"))


###############################################################################
# EXECUTION
###############################################################################

args <- arg_parser('', hide.opts = TRUE) %>%
  add_argument('--window', '') %>%
  parse_args()

window <- as.numeric(args$window)

# read in intermediates
observations <- fst::read_fst(sprintf("%s/observations_window%02d.fst", config$paths$geos_inte, window))
perturbations <- fst::read_fst(sprintf("%s/perturbations_window%02d.fst", config$paths$geos_inte, window))
if (window == 1) {
  print("using not rescaled control mf...")
  control_mf <- fst::read_fst(sprintf("%s/control-mole-fraction-window%02d.fst", config$paths$geos_inte, window))
} else {
  print("using rescaled control mf...")
  control_mf <- fst::read_fst(sprintf("%s/control-mole-fraction-window%02d-rescaled.fst", config$paths$geos_inte, window))
}
sensitivities <- fst::read_fst(sprintf("%s/sensitivities_window%02d.fst", config$paths$geos_inte, window))

# do analytical inversion
analytical_results <- do_analytical_inversion(observations, control_mf, perturbations, sensitivities)

# take some samples to make it look like mcmc
post_alpha_samples <- rep(analytical_results$mean, 2000)
dim(post_alpha_samples) <- c(length(analytical_results$mean), 2000)
saveRDS(list(alpha = t(post_alpha_samples)),
        sprintf("%s/real-analytical-samples-%s_window%02d.rds",
                config$paths$moving_window_dir,
                config$inversion_constants$land_ocean_equal_model_case,
                window))
