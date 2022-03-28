here::i_am("tests/testthat/test_moving_window_join_flux_aggregates.R")

library(here)
library(testthat)

options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/moving_window/join_flux_aggregates.R"), chdir = TRUE)

test_that("process_flux_aggregates works for first window", {
    # set useful constants
    window <- 1
    case <- "test"

    # create fake file
    samples <- tibble(month_start = c(as.Date("2010-01-01"), as.Date("2015-01-01"), as.Date("2021-01-01")),
                      flux_mean = c(1, 2, 3))
    filename <- sprintf("%s/real-flux-aggregates-samples-%s_window%02d.rds", config$paths$inversion_results, case, window)
    saveRDS(samples, filename)

    # compare expected and function results
    expected_out <- tibble(month_start = as.Date("2010-01-01"),
                           flux_mean = 1)
    func_out <- process_flux_aggregates(window, case)
    expect_equal(func_out, expected_out)

    # remove fake file
    file.remove(filename)
})

test_that("process_flux_aggregates works for later window", {
    # set useful constants
    window <- 5
    case <- "test"

    # create fake file
    samples <- tibble(month_start = c(as.Date("2010-01-01"), as.Date("2015-01-01"), as.Date("2021-01-01")),
                      flux_mean = c(1, 2, 3))
    filename <- sprintf("%s/real-flux-aggregates-samples-%s_window%02d.rds", config$paths$inversion_results, case, window)
    saveRDS(samples, filename)

    # compare expected and function results
    expected_out <- tibble(month_start = as.Date("2015-01-01"),
                           flux_mean = 2)
    func_out <- process_flux_aggregates(window, case)
    expect_equal(func_out, expected_out)

    # remove fake file
    file.remove(filename)
})

test_that("process_obs_matched works for first window", {
    # set useful constants
    window <- 1
    case <- "test"

    # create fake file
    samples <- tibble(time = c(as.Date("2010-01-01"), as.Date("2015-01-01"), as.Date("2021-01-01")),
                      co2 = c(1, 2, 3))
    filename <- sprintf("%s/obs_matched_samples-%s_window%02d.rds", config$paths$inversion_results, case, window)
    saveRDS(samples, filename)

    # compare expected and function results
    expected_out <- tibble(time = as.Date("2010-01-01"),
                           co2 = 1)
    func_out <- process_obs_matched(window, case)
    expect_equal(func_out, expected_out)

    # remove fake file
    file.remove(filename)
})

test_that("process_obs_matched works for later window", {
    # set useful constants
    window <- 5
    case <- "test"

    # create fake file
    samples <- tibble(time = c(as.Date("2010-01-01"), as.Date("2015-01-01"), as.Date("2021-01-01")),
                      co2 = c(1, 2, 3))
    filename <- sprintf("%s/obs_matched_samples-%s_window%02d.rds", config$paths$inversion_results, case, window)
    saveRDS(samples, filename)

    # compare expected and function results
    expected_out <- tibble(time = as.Date("2015-01-01"),
                           co2 = 2)
    func_out <- process_obs_matched(window, case)
    expect_equal(func_out, expected_out)

    # remove fake file
    file.remove(filename)
})
