# This script runs the analytical inversions for the pseudodata
library(argparser)
library(dplyr)
library(ggplot2)
library(here)
library(ini)
library(MASS)
library(Matrix)
library(wombat)

###############################################################################
# GLOBAL CONSTANTS
###############################################################################
config <- read.ini(paste0(here(), "/config.ini"))

###############################################################################
# FUNCTIONS
###############################################################################

options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/pseudodata/analytical_inversion_functions.R"), chdir = TRUE)

###############################################################################
# EXECUTION
###############################################################################

# choose case to look at
args <- arg_parser("", hide.opts = TRUE) %>%
  add_argument("--pseudo-case", "") %>%
  parse_args()
case <- args$pseudo_case

# read in true alphas
m_true <- readRDS(sprintf("%s/alpha_samples_%s.rds", config$paths$pseudodata_dir, case))

# set some constants
n_sample <- dim(m_true)[1]
n_region <- as.numeric(config$inversion_constants$no_regions) + 1
n_month <- dim(m_true)[2] / n_region

# read in intermediates
print("Reading intermediates...")
observations <- lapply(1:n_sample, function(i) {
                      fst::read_fst(sprintf("%s/observations_%s_%04d.fst", config$paths$pseudodata_dir, case, i))})
perturbations <- fst::read_fst(sprintf("%s/perturbations_window01.fst", config$paths$geos_inte))
control_mf <- fst::read_fst(sprintf("%s/control-mole-fraction-window01.fst", config$paths$geos_inte))
sensitivities <- fst::read_fst(sprintf("%s/sensitivities_window01.fst", config$paths$geos_inte))

# set up matrices required for inversion
print("Setting up matrices...")
d_obs <- sapply(1:n_sample, function(i) {observations[[i]]$co2})
C_M <- diag(rep(0.5^2, dim(m_true)[2]))
C_D <- make_C_D(observations[[1]])
m_prior <- rep(0, dim(m_true)[2])
# create H matrix
G <- transport_matrix(perturbations,
                      control_mf,
                      sensitivities,
                      lag = Inf)

# do inversion
print("Doing inversions...")
m_squiggle <- t(sapply(1:n_sample, function(i) {m_post(control_mf, m_prior, C_M, G, C_D, d_obs[, i])}))

print("Analysing...")
print(sprintf("correlation between true and posterior alphas: %f", cor(as.vector(m_true), as.vector(m_squiggle))))
plot(as.vector(m_true), as.vector(m_squiggle))

region <- rep(1:n_region, times = n_month, each = n_sample)
dim(region) <- dim(m_true)
month <- rep(1:n_month, each = n_region * n_sample)
dim(month) <- dim(m_true)
run <- rep(1:n_sample, times = n_region * n_month)
dim(run) <- dim(m_true)

df <- data.frame(inversion = as.vector(m_squiggle),
                truth = as.vector(m_true),
                region = as.vector(region),
                month = as.vector(month),
                run = as.vector(run))
p <- ggplot(data = df[df$month<=3,], aes(x = truth, y = inversion, color = factor(region), shape = factor(month))) +
      geom_point() #+ theme(legend.position = "none")
plot(p)
ggsave(sprintf("%s/analytical_inversion.pdf", config$paths$pseudodata_dir),
      height = 20, width = 20)


#moved closer to obs?
sample_no <- 1
prior_diff_to_obs <- d_obs[, sample_no] - model_out(control_mf, G, m_prior)[, 1]
post_diff_to_obs <- d_obs[, sample_no] - model_out(control_mf, G, m_squiggle[sample_no,])[, 1]
truth_diff_to_obs <- d_obs[, sample_no] - model_out(control_mf, G, m_true[sample_no,])[, 1]
print(sprintf("mean absolute difference of obs - prior: %f", mean(abs(prior_diff_to_obs))))
print(sprintf("mean absolute difference of obs - posterior: %f", mean(abs(post_diff_to_obs))))
print(sprintf("mean absolute difference of obs - truth: %f", mean(abs(truth_diff_to_obs))))

# save samples to compare to WOMBAT
m_post_cov <- m_post_cov_calc(C_M, G, C_D)
invisible(lapply(1:n_sample, m_post_sample, m_squiggle = m_squiggle, m_post_cov = m_post_cov, case = case))
