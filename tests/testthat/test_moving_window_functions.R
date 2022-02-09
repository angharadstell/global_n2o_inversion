here::i_am("tests/testthat/test_moving_window_functions.R")

library(here)
library(testthat)

options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/moving_window/functions.R"), chdir = TRUE)

test_that("updated_alphas works for a partial set of window inversions", {
    nregions <- 2           # number of regions in inversion
    ntime <- 4 * 12         # number of months in whole inversion
    windowtime <- 3 * 12    # number of months in window inversion

    # create some made up window alpha results
    test_mean_alphas <- list(rep(1, windowtime * nregions),
                             rep(2, windowtime * nregions),
                             rep(3, windowtime * nregions))
    # run the function
    function_out1 <- updated_alphas(1, test_mean_alphas, nregions, ntime)
    function_out2 <- updated_alphas(2, test_mean_alphas, nregions, ntime)
    function_out3 <- updated_alphas(3, test_mean_alphas, nregions, ntime)

    # compare
    # expect last alphas to be zero (i.e. the prior), because we haven't done
    # the window inversion to solve for them yet
    expect_equal(function_out1[1, (1 * 12 * nregions + 1):(ntime * nregions)], rep(0, 3 * 12 * nregions))
    expect_equal(function_out2[1, (2 * 12 * nregions + 1):(ntime * nregions)], rep(0, 2 * 12 * nregions))
    expect_equal(function_out3[1, (3 * 12 * nregions + 1):(ntime * nregions)], rep(0, 1 * 12 * nregions))
})

test_that("updated_alphas works for a complete set of window inversions", {
    nregions <- 2           # number of regions in inversion
    ntime <- 4 * 12         # number of months in whole inversion
    windowtime <- 3 * 12    # number of months in window inversion

    # create some made up window alpha results
    test_mean_alphas <- list(rep(1, windowtime * nregions),
                             rep(2, windowtime * nregions),
                             rep(3, windowtime * nregions))
    # run the function
    function_out <- updated_alphas(4, test_mean_alphas, nregions, ntime)

    # build the expected results
    expected_out <- rep(0, ntime * nregions)
    # spinup year
    expected_out[1:(12 * nregions)] <- 1
    # first year
    expected_out[(1 * 12 * nregions + 1):(2 * 12 * nregions)] <- 1
    # second year
    expected_out[(2 * 12 * nregions + 1):(3 * 12 * nregions)] <- 2
    # third year
    expected_out[(3 * 12 * nregions + 1):(ntime * nregions)] <- 3
    dim(expected_out) <- c(1, ntime * nregions)

    # compare
    expect_equal(function_out, expected_out)
})
