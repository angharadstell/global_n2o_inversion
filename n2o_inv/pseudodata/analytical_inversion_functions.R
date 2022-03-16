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

model_out <- function(control_mf, G, m) {
  control_mf$co2 + G %*% m
}

m_post <- function(control_mf, m_prior, C_M, G, C_D, d_obs) {
  prior_output <- model_out(control_mf, G, m_prior)
  as.matrix(m_prior + C_M %*% t(G) %*% solve(G %*% C_M %*% t(G) + C_D) %*% (d_obs - prior_output))
}

m_post_cov_calc <- function(C_M, G, C_D) {
  C_M - C_M %*% t(G) %*% solve(G %*% C_M %*% t(G) + C_D) %*% G %*% C_M
}

m_post_sample <- function(i, m_squiggle, m_post_cov, case) {
  post_alpha_samples <- mvrnorm(n = 1000,
                              mu = m_squiggle[i, ],
                              m_post_cov)
  saveRDS(post_alpha_samples,
          sprintf("%s/real_analytical_samples_%s_%04d.rds", config$paths$pseudodata_dir, case, i))
}

make_C_D <- function(observations) {
  sparseMatrix(i = 1:length(observations$co2_error),
               j = 1:length(observations$co2_error),
               x = observations$co2_error^2,
               dims = list(length(observations$co2_error), length(observations$co2_error)))
}

make_C_M <- function(var, kappa, kappa_regions, n_regions, n_months) {
  C_M <- matrix(0, (n_regions * n_months), (n_regions * n_months))

  region <- rep(1:n_regions, n_months)
  month  <- rep(1:n_months, each = n_regions)

  for (i in 1:(n_regions * n_months)) {
    for (j in 1:(n_regions * n_months)) {
      if (i == j) {
        if (region[[i]] %in% kappa_regions) {
          C_M[i, j] <- 1 / (1 - kappa^2)
        } else {
          C_M[i, j] <- 1
        }
      } else {
        if (region[[i]] == region[[j]] & region[[i]] %in% kappa_regions) {
          C_M[i, j] <- kappa^(abs(month[[i]] - month[[j]])) / (1 - kappa^2)
        }
      }

    }
  }

  C_M <- C_M * var

  C_M
}