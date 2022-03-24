here::i_am("tests/testthat/test_results_plot_annual_ems.R")

library(testthat)
library(here)

options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/results/plot_annual_ems.R"), chdir = TRUE)

test_that("get_annual_ems runs with zeros", {
    # create fake file
    config <- read.ini(paste0(here(), "/config.ini"))
    filename <- paste0(config$paths$inversion_results,
                       "/real-flux-aggregates-samples-test.rds")
    flux_samples <- tibble(name = "Global",
                           estimate = "Prior",
                           month_start = c(as.Date("2010-01-01"), as.Date("2011-01-01")),
                           flux_mean = c(0, 0),
                           flux_samples = matrix(0, 2, 10))
    saveRDS(flux_samples, filename)
    # ideal function output
    ideal_result <- tibble(estimate = "Prior",
                           name = "Global",
                           year = c(2010, 2011),
                           flux_mean = c(0, 0),
                           flux_lower = c(0, 0),
                           flux_upper = c(0, 0))
    # check function works
    func_out <- get_annual_ems("test")
    expect_equal(func_out, ideal_result, check.attributes = FALSE)
    # remove fake file
    file.remove(filename)
    })

test_that("get_annual_ems runs with non-zeros", {
    # create fake file
    config <- read.ini(paste0(here(), "/config.ini"))
    filename <- paste0(config$paths$inversion_results,
                       "/real-flux-aggregates-samples-test.rds")
    flux_samples <- tibble(name = "Global",
                           estimate = rep(c("Prior", "Posterior"), each = 2),
                           month_start = rep(c(as.Date("2010-01-01"), as.Date("2011-01-01")), 2),
                           flux_mean = 2:5,
                           flux_samples = matrix(0:7, 4, 10))
    saveRDS(flux_samples, filename)
    # ideal function output
    ideal_result <- tibble(estimate = rep(c("Posterior", "Prior"), each = 2),
                           name = "Global",
                           year = rep(c(2010, 2011), 2),
                           flux_mean = c(4, 5, 2, 3),
                           flux_lower = c(2, 3, 0, 1),
                           flux_upper = c(6, 7, 4, 5))
    # check function works
    func_out <- get_annual_ems("test")
    expect_equal(func_out, ideal_result, check.attributes = FALSE)
    # remove fake file
    file.remove(filename)
    })

test_that("plot_annual_ems runs with multiple years", {
    # create fake flux_samples
    flux_samples <- tibble(estimate = rep(c("Posterior", "Prior"), each = 2),
                           name = "Global",
                           year = rep(c(2010, 2011), 2),
                           flux_mean = c(4, 5, 2, 3),
                           flux_lower = c(2, 3, 0, 1),
                           flux_upper = c(6, 7, 4, 5))
    name_colours <- c("Prior" = "black", "Posterior" = "red")
    labels <- c("Prior", "Posterior")
    # just test that this doesn't error
    # could do a better job with vdiffr/ snapshots but not worth the effort
    expect_error(plot_annual_ems(flux_samples, name_colours, labels), NA)
    })

test_that("plot_annual_ems runs with one year", {
    # create fake flux_samples
    flux_samples <- tibble(estimate = c("Posterior", "Prior"),
                           name = "Global",
                           year = rep(2010, 2),
                           flux_mean = c(4, 5),
                           flux_lower = c(2, 3),
                           flux_upper = c(6, 7))
    name_colours <- c("Prior" = "black", "Posterior" = "red")
    labels <- c("Prior", "Posterior")
    # just test that this doesn't error
    # could do a better job with vdiffr/ snapshots but not worth the effort
    expect_error(plot_annual_ems(flux_samples, name_colours, labels), NA)
    })

test_that("regional_ems_plot runs with Global", {
    # create variables
    flux_samples <- tibble(estimate = rep(c("Posterior", "Prior"), each = 2),
                           name = "Global",
                           year = rep(c(2010, 2011), 2),
                           flux_mean = c(4, 5, 2, 3),
                           flux_lower = c(2, 3, 0, 1),
                           flux_upper = c(6, 7, 4, 5))
    region <- "Global"
    name_colours <- c("Prior" = "black", "Posterior" = "red")
    labels <- c("Prior", "Posterior")
    # just test that this doesn't error
    # could do a better job with vdiffr/ snapshots but not worth the effort
    expect_error(regional_ems_plot(flux_samples, region, name_colours, labels), NA)
    })

test_that("regional_ems_plot runs with a region", {
    # create variables
    flux_samples <- tibble(estimate = rep(c("Posterior", "Prior"), each = 2),
                           name = "T00",
                           year = rep(c(2010, 2011), 2),
                           flux_mean = c(4, 5, 2, 3),
                           flux_lower = c(2, 3, 0, 1),
                           flux_upper = c(6, 7, 4, 5))
    region <- "T00"
    name_colours <- c("Prior" = "black", "Posterior" = "red")
    labels <- c("Prior", "Posterior")
    # just test that this doesn't error
    # could do a better job with vdiffr/ snapshots but not worth the effort
    expect_error(regional_ems_plot(flux_samples, region, name_colours, labels), NA)
    })

test_that("regional_ems_plot runs with Global", {
    # create variables
    flux_samples <- tibble(estimate = rep(c("Posterior", "Prior"), each = 2),
                           name = "Global",
                           year = rep(c(2010, 2011), 2),
                           flux_mean = c(4, 5, 2, 3),
                           flux_lower = c(2, 3, 0, 1),
                           flux_upper = c(6, 7, 4, 5))
    region <- "Global"
    name_colours <- c("Prior" = "black", "Posterior" = "red")
    labels <- c("Prior", "Posterior")
    # just test that this doesn't error
    # could do a better job with vdiffr/ snapshots but not worth the effort
    expect_error(regional_ems_plot(flux_samples, region, name_colours, labels), NA)
    })

test_that("print_ems runs", {
    # create variables
    flux_samples <- tibble(estimate = rep(c("Posterior", "Prior"), each = 2),
                           name = "Global",
                           year = rep(c(2010, 2011), 2),
                           flux_mean = c(4, 5, 2, 3),
                           flux_lower = c(2, 3, 0, 1),
                           flux_upper = c(6, 7, 4, 5))
    region <- "Global"
    # check correct thing printed
    expect_message(print_ems(flux_samples, region),
                   "Global mean for 2010-2011: 4.5 (2.5-6.5) TgNyr-1",
                   fixed = TRUE)
    })
