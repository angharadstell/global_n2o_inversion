here::i_am("tests/testthat/test_plots_plot_sensitivities.R")

library(testthat)
library(here)
library(ini)

options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/plots/plot_sensitivities.R"), chdir = TRUE)

# use same fake_combined_mf function
source(paste0(here(), "/tests/testthat/fake_data.R"), chdir = TRUE)

test_that("plot_perturbation_dt runs", {
    config <- read.ini(paste0(here(), "/config.ini"))
    base_mf_file <- sprintf("%s/%s/test_combined_mf.nc", config$paths$geos_out, config$inversion_constants$case)
    perturb_mf_file <- sprintf("%s/201001/test_combined_mf.nc", config$paths$geos_out)

    # create fake combined_mf file
    fake_combined_mf(base_mf_file)
    fake_combined_mf(perturb_mf_file)

    # just test that this doesn't error
    # could do a better job with vdiffr/ snapshots but not worth the effort
    expect_error(plot_perturbation_dt(0, 2010, "01", "test_combined_mf.nc", 0), NA)

    # remove fake file
    file.remove(base_mf_file)
    file.remove(perturb_mf_file)
})
