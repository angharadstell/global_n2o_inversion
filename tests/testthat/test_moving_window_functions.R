here::i_am("tests/testthat/test_moving_window_functions.R")

library(here)
library(testthat)

options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/moving_window/functions.R"), chdir = TRUE)

test_that("inversion_alphas runs", {
    # set up some constants
    n_alphas <- 2
    n_samples <- as.numeric(config$inversion_constants$no_samples)
    window <- 1
    case <- "test"
    method <- "mcmc"

    # make fake file
    samples <- list("alpha" = matrix(0, n_samples, n_alphas))
    filename <- sprintf("%s/real-%s-samples-%s_window%02d.rds",
                        config$paths$moving_window_dir,
                        method,
                        case,
                        window)
    saveRDS(samples, filename)

    # compare
    func_out <- inversion_alphas(window, case, method)
    expect_equal(func_out, c(0, 0))

    # remove fake file
    file.remove(filename)
})

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

test_that("do_analytical_inversion runs", {
    # set constants
    n_regions <- as.numeric(config$inversion_constants$no_regions) + 1
    n_months <- 2

    # create fake data
    month_starts <- as.Date(c('2016-01-01', '2016-02-01'))
    regions <- 1 : n_regions
    model_ids <- 1 : n_months

    observations <- data.frame(time = month_starts,
                               co2 = c(0, 0),
                               co2_error = c(1, 1))
    control_mf <- data.frame(time = month_starts,
                             model_id = model_ids,
                             co2 = c(0, 0))

    control_emissions <- expand.grid(month_start = month_starts,
                                     region = regions
    ) %>%
    mutate(
        model_id = 1 : n(),
        area = 1,
        flux_density = 0
    )

    perturbations <- expand.grid(from_month_start = month_starts,
                                 month_start = month_starts,
                                 region = regions
    ) %>%
    left_join(
    control_emissions %>%
      dplyr::select(month_start, region, model_id),
    by = c('month_start', 'region')
    ) %>%
    dplyr::select(-month_start) %>%
    mutate(flux_density = 0)

    sensitivities <- expand.grid(from_month_start = month_starts,
                                 model_id = model_ids,
                                 region = regions
    ) %>%
    mutate(co2_sensitivity = 1)

    # run function
    func_out <- do_analytical_inversion(observations, control_mf, perturbations, sensitivities)

    # check mean
    expect_equal(func_out$mean, matrix(0, (n_regions * n_months), 1), check.attributes = FALSE)
    # check cov
    expect_equal(dim(func_out$cov), c((n_regions * n_months), (n_regions * n_months)))
    expect_true(all(diag(as.matrix(func_out$cov)) > 0))
})
