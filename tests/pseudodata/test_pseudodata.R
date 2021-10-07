here::i_am("tests/pseudodata/test_pseudodata.R")

library(testthat)
library(here)

options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/pseudodata/pseudodata.R"), chdir = TRUE)

config <- read.ini(paste0(here(), "/config.ini"))




obs_matching <- match(
observations$observation_id,
control_mf$observation_id
)

# check that alpha is zero returns control_mf
n_samples <- 2
n_regions <- as.numeric(config$inversion_constants$no_regions) + 1
n_months <- interval(as.Date(config$dates$perturb_start), as.Date(config$dates$perturb_end)) %/% months(1)
n_alpha <- n_regions * n_months
n_obs <- dim(observations)[1]

alpha_samples <- matrix(rep(0, n_samples * n_alpha), n_samples, n_alpha)
test_that("check that alpha is zero returns control_mf",
          expect_equal(alpha_to_obs(alpha_samples, 0) - control_mf$co2[obs_matching],
                       matrix(rep(0, n_samples * n_obs), n_obs, n_samples),
                       check.attributes = FALSE))

alpha_samples <- matrix(rep(1, n_samples * n_alpha), n_samples, n_alpha)
test_that("alpha > 0 all mf should be higher than control_mf",
          expect_true(all(alpha_to_obs(alpha_samples, 0) > control_mf$co2[obs_matching])))

alpha_samples <- matrix(rep(-1, n_samples * n_alpha), n_samples, n_alpha)
test_that("alpha < 0 all mf should be lower than control_mf",
          expect_true(all(alpha_to_obs(alpha_samples, 0) < control_mf$co2[obs_matching])))

