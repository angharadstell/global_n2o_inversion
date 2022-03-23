here::i_am("tests/testthat/test_pseudodata_pseudodata.R")

library(testthat)
library(here)

options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/pseudodata/pseudodata.R"), chdir = TRUE)

# create fake inversion intermediates to test functions
n_regions <- 2
n_months <- 3
n_alpha <- n_regions * n_months
n_samples <- 5
n_obs <- 3

perturbations <- data.frame(
    region = rep(0:1, each = n_months),
    from_month_start = rep(c(as.Date("2010-01-01"), as.Date("2010-02-01"), as.Date("2010-03-01")), times = n_regions),
    type = "all",
    model_id = rep(1:3, times = n_regions),
    flux_density = 5.3e-7
)

control_mf <- data.frame(
    observation_id = 1:3,
    observation_type = "obspack",
    resolution = "obspack",
    time = c(as.Date("2010-01-01"), as.Date("2010-02-01"), as.Date("2010-03-01")),
    lat = 0,
    lon = 0,
    co2 = 320:322,
    model_id = 1:3
)

sensitivities <- data.frame(
    region = rep(0:1, each = n_months),
    from_month_start = rep(c(as.Date("2010-01-01"), as.Date("2010-02-01"), as.Date("2010-03-01")), times = n_regions),
    model_id = rep(1:3, times = n_regions),
    co2_sensitivity = 0.5
)

# functions for testing
test_that("check that alpha is zero returns control_mf", {
          alpha_samples <- matrix(rep(0, n_samples * n_alpha), n_samples, n_alpha)
          func_out <- alpha_to_obs(alpha_samples, 0, control_mf, perturbations, sensitivities)
          expect_equal(func_out - control_mf$co2,
                       matrix(0, n_obs, n_samples),
                       check.attributes = FALSE)
          })

test_that("alpha > 0 all mf should be higher than control_mf", {
          alpha_samples <- matrix(rep(1, n_samples * n_alpha), n_samples, n_alpha)
          func_out <- alpha_to_obs(alpha_samples, 0, control_mf, perturbations, sensitivities)
          expect_true(all(func_out > control_mf$co2))
          })

test_that("alpha < 0 all mf should be lower than control_mf", {
          alpha_samples <- matrix(rep(-1, n_samples * n_alpha), n_samples, n_alpha)
          func_out <- alpha_to_obs(alpha_samples, 0, control_mf, perturbations, sensitivities)
          expect_true(all(func_out < control_mf$co2))
          })

test_that("alpha_generate runs", {
          func_out <- alpha_generate(n_samples, n_regions, n_months, 0, 0.5)
          expect_true(all(dim(func_out) == c(n_samples, n_alpha)))
          expect_true(all(func_out == 0))
          })
