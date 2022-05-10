here::i_am("tests/testthat/test_plots_compare_literature_chart.R")

library(testthat)
library(tibble)
library(here)

options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/plots/compare_literature_chart.R"), chdir = TRUE)

test_that("plot_bar runs", {
    # generate fake data
    df <- data.frame(Case = c("a", "b", "c"),
                     Global = c(1, 2, 3),
                     Land = c(4, 5, 6),
                     Ocean = c(7, 8, 9))
    # just test that this doesn't error
    # could do a better job with vdiffr/ snapshots but not worth the effort
    expect_error(plot_bar(df), NA)
    })

test_that("process_fluxes_iav works", {
        fluxes <- tibble(estimate = c("Prior", "Prior", "Prior", "Posterior", "Posterior", "Posterior"),
                         name = c("Global", "Global land", "Global ocean", "Global", "Global land", "Global"),
                         month_start = as.Date(c("2011-01-01", "2011-01-01", "2011-01-01", "2010-01-01", "2011-01-01", "2011-01-01")),
                         flux_mean = c(1, 2, 3, 4, 5, 6),
                         flux_samples = matrix(rep(1:6, times = 5), 6, 5))

        func_out <- process_fluxes_iav("Global", fluxes)
        ideal_out <- tibble(year = as.integer(2011), flux = 6, flux_lower = c("2.5%" = 6), flux_upper = c("97.5%" = 6))

        expect_identical(func_out, ideal_out)
    })
