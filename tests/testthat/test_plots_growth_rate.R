here::i_am("tests/testthat/test_plots_growth_rate.R")

library(testthat)
library(here)

options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/plots/growth_rate.R"), chdir = TRUE)

test_that("area_weighted_monthly_mean works with one latitude", {
    # generate fake obs
    obs <- data.frame(time = seq(as.Date("2010-01-01"), by = "month", length.out = 24),
                      latitude = 0,
                      co2 = 320:343)
    obs <- process_obs(obs)
    # idealised function output
    ideal_out <- tibble(time = seq(as.Date("2010-01-01"), by = "month", length.out = 24),
                        mean_co2_aw = 320:343,
                        growth = rep(c(NA, 12), each = 12))
    # compare
    func_out <- area_weighted_monthly_mean(obs)
    expect_equal(func_out, ideal_out)
    })

test_that("area_weighted_monthly_mean works with two latitudes where one is 90", {
    # generate fake obs
    obs <- data.frame(time = rep(seq(as.Date("2010-01-01"), by = "month", length.out = 24), each = 2),
                      latitude = rep(c(0, 90), 12),
                      co2 = rep(c(320, 330), 12))
    obs <- process_obs(obs)
    # idealised function output
    ideal_out <- tibble(time = seq(as.Date("2010-01-01"), by = "month", length.out = 24),
                        mean_co2_aw = 320,
                        growth = rep(c(NA, 0), each = 12))
    # compare
    func_out <- area_weighted_monthly_mean(obs)
    expect_equal(func_out, ideal_out)
    })

test_that("area_weighted_monthly_mean works with two latitudes where neither is 90", {
    # generate fake obs
    obs <- data.frame(time = rep(seq(as.Date("2010-01-01"), by = "month", length.out = 24), each = 2),
                      latitude = rep(c(0, 60), 12),
                      co2 = rep(c(320, 330), 12))
    obs <- process_obs(obs)
    # idealised function output
    ideal_out <- tibble(time = seq(as.Date("2010-01-01"), by = "month", length.out = 24),
                        mean_co2_aw = 320 + (330 - 320) / 3,
                        growth = rep(c(NA, 0), each = 12))
    # compare
    func_out <- area_weighted_monthly_mean(obs)
    expect_equal(func_out, ideal_out)
    })

test_that("process_obs with latitude 0", {
    # generate fake data
    obs <- data.frame(time = as.Date("2010-01-01"),
                      latitude = 0,
                      co2 = 320)
    # idealised function output
    ideal_out <- data.frame(time = as.Date("2010-01-01"),
                            latitude = 0,
                            co2 = 320,
                            abs_cos_lat = 1,
                            co2_aw = 320)
    # compare
    func_out <- process_obs(obs)
    expect_equal(func_out, ideal_out)
    })

test_that("process_obs with latitude 60", {
    # generate fake data
    obs <- data.frame(time = as.Date("2010-01-01"),
                      latitude = 60,
                      co2 = 320)
    # idealised function output
    ideal_out <- data.frame(time = as.Date("2010-01-01"),
                            latitude = 60,
                            co2 = 320,
                            abs_cos_lat = 0.5,
                            co2_aw = 320 * 0.5)
    # compare
    func_out <- process_obs(obs)
    expect_equal(func_out, ideal_out)
    })

test_that("process_obs with latitude 90", {
    # generate fake data
    obs <- data.frame(time = as.Date("2010-01-01"),
                      latitude = 90,
                      co2 = 320)
    # idealised function output
    ideal_out <- data.frame(time = as.Date("2010-01-01"),
                            latitude = 90,
                            co2 = 320,
                            abs_cos_lat = 0,
                            co2_aw = 0)
    # compare
    func_out <- process_obs(obs)
    expect_equal(func_out, ideal_out)
    })

test_that("process_obs with latitude -60", {
    # generate fake data
    obs <- data.frame(time = as.Date("2010-01-01"),
                      latitude = -60,
                      co2 = 320)
    # idealised function output
    ideal_out <- data.frame(time = as.Date("2010-01-01"),
                            latitude = -60,
                            co2 = 320,
                            abs_cos_lat = 0.5,
                            co2_aw = 320 * 0.5)
    # compare
    func_out <- process_obs(obs)
    expect_equal(func_out, ideal_out)
    })

test_that("process_obs with latitude -90", {
    # generate fake data
    obs <- data.frame(time = as.Date("2010-01-01"),
                      latitude = -90,
                      co2 = 320)
    # idealised function output
    ideal_out <- data.frame(time = as.Date("2010-01-01"),
                            latitude = -90,
                            co2 = 320,
                            abs_cos_lat = 0,
                            co2_aw = 0)
    # compare
    func_out <- process_obs(obs)
    expect_equal(func_out, ideal_out)
    })

test_that("plot_growth_rate runs", {
    # generate fake obs
    obs <- data.frame(time = rep(seq(as.Date("2010-01-01"), by = "month", length.out = 24), each = 3),
                      latitude = rep(c(-45, 10, 45), 12),
                      co2 = rep(c(320, 325, 330), 12))
    # just test that this doesn't error
    # could do a better job with vdiffr/ snapshots but not worth the effort
    expect_error(plot_growth_rate(obs, "test"), NA)
    })
