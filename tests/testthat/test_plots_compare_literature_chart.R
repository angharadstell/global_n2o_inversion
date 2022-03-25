here::i_am("tests/testthat/test_plots_compare_literature_chart.R")

library(testthat)
library(here)

options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/plots/compare_literature_chart.R"), chdir = TRUE)

test_that("plot_bar", {
    # generate fake data
    df <- data.frame(Case = c("a", "b", "c"),
                     Global = c(1, 2, 3),
                     Land = c(4, 5, 6),
                     Ocean = c(7, 8, 9))
    # just test that this doesn't error
    # could do a better job with vdiffr/ snapshots but not worth the effort
    expect_error(plot_bar(df), NA)
    })

test_that("subtract_mean works", {
    # generate fake data
    df <- data.frame(year = c(2010, 2015, 2021),
                     land_flux = c(1, 2, 3),
                     ocean_flux = c(4, 5, 6))
    df <- df %>% mutate(flux = land_flux + ocean_flux)
    # idealised function output
    ideal_out <- data.frame(year = 2015,
                            land_flux = 2,
                            ocean_flux = 5,
                            flux = 0)
    # compare
    func_out <- subtract_mean(df)
    expect_equal(func_out, ideal_out)
    })
