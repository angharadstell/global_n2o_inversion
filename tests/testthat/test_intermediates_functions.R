here::i_am("tests/testthat/test_intermediates_functions.R")

library(testthat)
library(here)
library(ini)

options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/intermediates/functions.R"), chdir = TRUE)

# use same fake_combined_mf function
source(paste0(here(), "/tests/testthat/fake_data.R"), chdir = TRUE)

test_that("read_nc_file runs", {
    config <- read.ini(paste0(here(), "/config.ini"))
    mf_file <- sprintf("%s/%s/test_combined_mf.nc", config$paths$geos_out, config$inversion_constants$case)

    # create fake combined_mf file
    fake_combined_mf(mf_file)

    # compare
    expected_out <- c(0, cumsum(days_in_month(seq(as.Date("2010/01/01"), by = "month", length.out = 9))))
    func_out <- read_nc_file(mf_file)
    expect_equal(func_out("obs_time"), expected_out, check.attributes = FALSE)

    # remove fake file
    file.remove(mf_file)
})
