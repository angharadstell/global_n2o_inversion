here::i_am("tests/testthat/test_results_flux_aggregators.R")

library(testthat)
library(here)

options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/results/flux-aggregators.R"), chdir = TRUE)

# cant use Rscript -e "testthat::test_dir('tests/results')" to run tests without hard coding, confused
config <- read.ini(paste0(here(), "/config.ini"))

# set up transcom regions
transcom_file <- config$inversion_constants$geo_transcom_mask

# read in transcom as raster object
transcom_raster <- process_transcom_regions(transcom_file)

# read in transcom regions using netcdf
transcom_nc <- ncdf4::nc_open(transcom_file)
v <- function(...) ncdf4::ncvar_get(transcom_nc, ...)

# check that the raster matches the original value in the netcdf file for the geoschem grid

# check each latitude
for (i in 1:length(v("lat"))) {
    test_that(paste(v("lat")[i], "lat"), {
        expect_equal(extract(transcom_raster, cbind(v("lon"), rep(v("lat")[i], length(v("lon"))))), v("regions")[, i])
    })
}

# check each longitude
for (i in 1:length(v("lon"))) {
    test_that(paste(v("lon")[i], "lon"), {
        expect_equal(extract(transcom_raster, cbind(rep(v("lon")[i], length(v("lat"))), v("lat"))), v("regions")[i, ])
    })
}
