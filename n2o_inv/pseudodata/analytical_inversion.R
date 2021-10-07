library(ggplot2)
library(ini)
library(MASS)
library(Matrix)
library(wombat)


###############################################################################
# GLOBAL CONSTANTS
###############################################################################
fileloc <- (function() {
  attr(body(sys.function()), "srcfile")
})()$filename

config <- read.ini("/home/as16992/global_n2o_inversion/config.ini")

###############################################################################
# FUNCTIONS
###############################################################################

model_out <- function(m) {
  control_mf$co2[obs_matching] + G %*% m
}

m_post <- function(i) {
  as.matrix(m_prior + C_M %*% t(G) %*% solve(G %*% C_M %*% t(G) + C_D) %*% (d_obs[,i] - model_out(m_prior)))
}

m_post_cov_calc <- function() {
  C_M - C_M %*% t(G) %*% solve(G %*% C_M %*% t(G) + C_D) %*% G %*% C_M
}

m_post_sample <- function(i) {
  post_alpha_samples <- mvrnorm(n = 1000,
                              mu = m_squiggle[i, ],
                              m_post_cov)
  saveRDS(post_alpha_samples,
          sprintf("%s/real_analytical_samples_%s_%04d.rds", config$paths$pseudodata_dir, case, i))
}

###############################################################################
# EXECUTION
###############################################################################

case <- "m2_a1"

m_true <- readRDS(sprintf("%s/alpha_samples_%s.rds", config$paths$pseudodata_dir, case))

n_sample <- dim(m_true)[1]
n_region <- 23
n_month <- dim(m_true)[2] / n_region

observations <- lapply(1:n_sample, function(i) {
                       fst::read_fst(sprintf("%s/observations_%s_%04d.fst", config$paths$pseudodata_dir, case, i))})
perturbations <- fst::read_fst(sprintf("%s/perturbations_pseudo.fst", config$paths$geos_inte))
control_mf <- fst::read_fst(sprintf("%s/control-mole-fraction-pseudo.fst", config$paths$geos_inte))
sensitivities <- fst::read_fst(sprintf("%s/sensitivities_pseudo.fst", config$paths$geos_inte))

d_obs <- sapply(1:n_sample, function(i) {observations[[i]]$co2})

C_M <- diag(rep(0.5^2, dim(m_true)[2]))
C_D <- sparseMatrix(i=1:length(observations[[1]]$co2_error),
                    j=1:length(observations[[1]]$co2_error),
                    x=observations[[1]]$co2_error^2,
                    dims=list(length(observations[[1]]$co2_error),length(observations[[1]]$co2_error)))

m_prior <- rep(0, dim(m_true)[2])

obs_matching <- match(
observations[[1]]$observation_id,
control_mf$observation_id
)

# create H matrix
H <- transport_matrix(perturbations,
                      control_mf,
                      sensitivities,
                      lag = Inf)
# H_obs ordered by time then site
G <- H[obs_matching, ]



m_squiggle <- t(sapply(1:n_sample, m_post))

print(cor(as.vector(m_true), as.vector(m_squiggle)))
plot(as.vector(m_true), as.vector(m_squiggle))

region <- rep(1:n_region, times=n_month, each=n_sample)
dim(region) <- dim(m_true)
month <- rep(1:n_month, each=n_region*n_sample)
dim(month) <- dim(m_true)
run <- rep(1:n_sample, times=n_region*n_month)
dim(run) <- dim(m_true)

df <- data.frame(inversion = as.vector(m_squiggle),
                 truth = as.vector(m_true),
                 region = as.vector(region),
                 month = as.vector(month),
                 run = as.vector(run))
p <- ggplot(data=df[df$month<=3,], aes(x=truth, y=inversion, color=factor(region), shape=factor(month))) +
       geom_point() #+ theme(legend.position = "none")
plot(p)
ggsave(sprintf("%s/analytical_inversion.pdf", config$paths$pseudodata_dir),
       height = 20, width = 20)


#moved closer to obs?
sample_no <- 1
prior_diff_to_obs <- d_obs[,sample_no] - model_out(m_prior)[,1]
post_diff_to_obs <- d_obs[,sample_no] - model_out(m_squiggle[sample_no,])[,1]
truth_diff_to_obs <- d_obs[,sample_no] - model_out(m_true[sample_no,])[,1]

# save samples to compare to WOMBAT
m_post_cov <- m_post_cov_calc()
lapply(1:n_samples, m_post_sample)
