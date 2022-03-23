here::i_am("tests/testthat/test_pseudodata_analyse_mcmc_samples.R")

library(testthat)
library(here)

options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/pseudodata/analyse_mcmc_samples.R"), chdir = TRUE)


test_that("mcmc_alpha runs", {
    # read in constants from config
    config <- read.ini(paste0(here(), "/config.ini"))
    no_samples <- as.numeric(config$inversion_constants$no_samples)
    burn_in <- as.numeric(config$inversion_constants$burn_in)
    # create fake file
    filename <- paste0(here(), "/tests/testthat/test_mcmc_samples.rds")
    samples <- list(alpha = matrix(0, no_samples, (n_regions * n_months)))
    saveRDS(samples, filename)
    # check function works
    func_out <- mcmc_alpha(filename)
    expect_equal(func_out, matrix(0, (no_samples - burn_in), (n_regions * n_months)))
    # remove fake file
    file.remove(filename)
    })

test_that("mcmc_alpha runs when file doesn't exist", {
    # read in constants from config
    config <- read.ini(paste0(here(), "/config.ini"))
    n_regions <- as.numeric(config$inversion_constants$no_regions) + 1
    n_months <- as.numeric(config$pseudodata$n_months)
    no_samples <- as.numeric(config$inversion_constants$no_samples)
    burn_in <- as.numeric(config$inversion_constants$burn_in)
    # check function works
    func_out <- mcmc_alpha("/any/old/file.rds")
    expect_equal(func_out, matrix(NA, (no_samples - burn_in), (n_regions * n_months)))
    })

test_that("quantile_match works when true value is above the samples", {
    # read in constants from config
    config <- read.ini(paste0(here(), "/config.ini"))
    no_samples <- as.numeric(config$inversion_constants$no_samples)
    burn_in <- as.numeric(config$inversion_constants$burn_in)
    # set up variables to run function with
    nsample <- 1
    nalpha <- 1
    alpha_samples <- list(matrix(0, (no_samples - burn_in), 1))
    alpha_true <- matrix(1, 1, 1)
    # check function works
    func_out <- quantile_match(nsample, nalpha, alpha_samples, alpha_true)
    expect_equal(func_out, NA)
    })

test_that("quantile_match works when true value is below the samples", {
    # read in constants from config
    config <- read.ini(paste0(here(), "/config.ini"))
    no_samples <- as.numeric(config$inversion_constants$no_samples)
    burn_in <- as.numeric(config$inversion_constants$burn_in)
    # set up variables to run function with
    nsample <- 1
    nalpha <- 1
    alpha_samples <- list(matrix(0, (no_samples - burn_in), 1))
    alpha_true <- matrix(-1, 1, 1)
    # check function works
    func_out <- quantile_match(nsample, nalpha, alpha_samples, alpha_true)
    expect_equal(func_out, NA)
    })

test_that("quantile_match works when the true value is within the samples", {
    # read in constants from config
    config <- read.ini(paste0(here(), "/config.ini"))
    no_samples <- as.numeric(config$inversion_constants$no_samples)
    burn_in <- as.numeric(config$inversion_constants$burn_in)
    # set up variables to run function with
    set.seed(0)
    nsample <- 1
    nalpha <- 1
    alpha_samples <- list(matrix(rnorm((no_samples - burn_in)), (no_samples - burn_in), 1))
    alpha_true <- matrix(0, 1, 1)
    # check function works
    func_out <- quantile_match(nsample, nalpha, alpha_samples, alpha_true)
    expect_equal(func_out, 0.5, tolerance = 0.01)
    })

test_that("wombat_quantiles runs", {
    # read in constants from config
    config <- read.ini(paste0(here(), "/config.ini"))
    n_regions <- as.numeric(config$inversion_constants$no_regions) + 1
    n_months <- as.numeric(config$pseudodata$n_months)
    n_samples_pseudo <- as.numeric(config$pseudodata$n_samples)
    no_samples <- as.numeric(config$inversion_constants$no_samples)
    burn_in <- as.numeric(config$inversion_constants$burn_in)
    # set up variables to run function with
    n_alpha <- n_regions * n_months
    test_case <- "test" # this won't exist, expect just NAs in output
    r_seq <- 1:n_alpha
    alpha_true <- matrix(0, n_samples_pseudo, n_alpha)
    # run function
    func_out <- wombat_quantiles(test_case, r_seq, alpha_true)
    # check expected output
    expect_equal(dim(func_out$quantile), c(n_samples_pseudo, n_alpha))
    expect_true(all(is.na(func_out$quantile)))
    expect_equal(length(func_out$alpha_samples), n_samples_pseudo)
    expect_equal(dim(func_out$alpha_samples[[1]]), c((no_samples - burn_in), n_alpha))
    expect_true(all(is.na(func_out$alpha_samples[[1]])))
    })

test_that("rmse runs with zeros", {
    func_out <- rmse(c(0, 0, 0), c(0, 0, 0))
    expect_equal(func_out, 0)
    })

test_that("rmse runs with NA", {
    func_out <- rmse(c(1, 1, NA), c(0, 0, 0))
    expect_equal(func_out, 1)
    })

test_that("mae runs with zeros", {
    func_out <- mae(c(0, 0, 0), c(0, 0, 0))
    expect_equal(func_out, 0)
    })

test_that("mae runs with NA", {
    func_out <- mae(c(1, 1, NA), c(0, 0, 0))
    expect_equal(func_out, 1)
    })
