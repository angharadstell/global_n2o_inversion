here::i_am("tests/testthat/test_intermediates_control-mole-fraction.R")

library(testthat)
library(here)
library(lubridate)
library(ncdf4)

options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/intermediates/control-mole-fraction.R"), chdir = TRUE)

# use same fake_combined_mf function
source(paste0(here(), "/tests/testthat/fake_data.R"), chdir = TRUE)

test_that("control mf is ordered correctly", {
    filename <- paste0(here(), "/tests/testthat/test_combined_mf.nc")
    fake_combined_mf(filename)
    control_full <- process_control(filename)
    expect_equal(control_full$observation_id, control_full$observation_id[order(control_full$observation_id)])
    expect_equal(control_full$model_id, control_full$model_id[order(control_full$observation_id)])
    file.remove(filename)
})

test_that("nan dealt with correctly correctly", {
    filename <- paste0(here(), "/tests/testthat/test_combined_mf.nc")
    fake_combined_mf(filename)
    expect_equal(is.na(process_control(filename)$co2), rep(FALSE, 19))
    file.remove(filename)
})
