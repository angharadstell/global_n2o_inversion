here::i_am("tests/testthat/test_moving_window_plot_hyperparameters.R")

library(here)
library(testthat)

options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/moving_window/plot_hyperparameters.R"), chdir = TRUE)

test_that("extract_time_var works with zeros", {
    # set up some constants
    n_alphas <- 2
    n_samples <- as.numeric(config$inversion_constants$no_samples)
    start_year <- year(as.Date(config$dates$perturb_start)) + 1
    end_year <- year(as.Date(config$dates$perturb_end)) - 1

    # mock up some window inversion results
    window_samples <- list(list("alpha" = matrix(0, n_samples, n_alphas)),
                           list("alpha" = matrix(0, n_samples, n_alphas)),
                           list("alpha" = matrix(0, n_samples, n_alphas)),
                           list("alpha" = matrix(0, n_samples, n_alphas)),
                           list("alpha" = matrix(0, n_samples, n_alphas)),
                           list("alpha" = matrix(0, n_samples, n_alphas)),
                           list("alpha" = matrix(0, n_samples, n_alphas)),
                           list("alpha" = matrix(0, n_samples, n_alphas)),
                           list("alpha" = matrix(0, n_samples, n_alphas)),
                           list("alpha" = matrix(0, n_samples, n_alphas)))

    # what our results should be
    expected_out <- matrix(0, n_alphas, length(window_samples))
    colnames(expected_out) <- start_year:end_year

    # compare
    expect_equal(extract_time_var(window_samples, "alpha"), expected_out)
})