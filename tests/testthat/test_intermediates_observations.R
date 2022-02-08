here::i_am("tests/testthat/test_intermediates_observations.R")

library(lubridate)
library(testthat)
library(here)

options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/intermediates/observations.R"), chdir = TRUE)

fake_combined_mf <- function(filename) {
    # fake combined_mf
    dimtime <- ncdim_def("obs_time", "days since 2010-01-01 00:00:00",
                         c(0, cumsum(days_in_month(seq(as.Date("2010/01/01"), by = "month", length.out = 9)))))
    dimsite <- ncdim_def("site", "", 1:2)
    dimnchar <- ncdim_def("nchar",   "", 1:100, create_dimvar = FALSE)

    varlat <- ncvar_def("obs_lat", "", list(dimsite, dimtime), NA, prec="double")
    varlon <- ncvar_def("obs_lon", "", list(dimsite, dimtime), NA, prec="double")
    varalt <- ncvar_def("obs_alt", "", list(dimsite, dimtime), NA, prec="double")
    varid <- ncvar_def("obspack_id", "", list(dimnchar, dimsite, dimtime), NULL, prec="char")
    varvalue <- ncvar_def("obs_value", "", list(dimsite, dimtime), NA, prec="double")
    varunc <- ncvar_def("obs_value_unc", "", list(dimsite, dimtime), NA, prec="double")

    ncnew <- nc_create(filename, list(varlat, varlon, varalt, varid, varvalue, varunc))

    arrlat <- array(45, c(10, 2))
    arrlat[, 2] <- -45
    arrlon <- array(90, c(10, 2))
    arrlon[, 2] <- -90
    arralt <- array(10, c(10, 2))
    arralt[, 2] <- 20
    arrid <- array(0, c(10, 2))
    arrid[, 1] <- sprintf("obspack_multi-species_1_CCGGSurfaceFlask_v2.0_2021-02-09~n2o_aNOAAsurf_surface-flask_1_ccgg_Event~a2010%02d", 1:10)
    arrid[, 2] <- sprintf("obspack_multi-species_1_CCGGSurfaceFlask_v2.0_2021-02-09~n2o_bNOAAsurf_surface-flask_1_ccgg_Event~b2010%02d", 1:10)
    arrco2 <- array(seq(330, 340, length.out = 20), c(10, 2))
    arrco2[5, 1] <- NA
    arrunc <- array(0.2, c(10, 2))

    ncvar_put(ncnew, varlat, arrlat)
    ncvar_put(ncnew, varlon, arrlon)
    ncvar_put(ncnew, varalt, arralt)
    ncvar_put(ncnew, varid, arrid)
    ncvar_put(ncnew, varvalue, arrco2)
    ncvar_put(ncnew, varunc, arrunc)

    nc_close(ncnew)
}

test_that("control mf is ordered correctly", {
    filename <- paste0(here(), "/tests/testthat/test_combined_mf.nc")
    fake_combined_mf(filename)
    obs <- process_obspack(filename)
    expect_equal(obs$observation_id, obs$observation_id[order(obs$observation_id)])
    file.remove(filename)
})

test_that("nan dealt with correctly correctly", {
    filename <- paste0(here(), "/tests/testthat/test_combined_mf.nc")
    fake_combined_mf(filename)
    expect_equal(is.na(process_obspack(filename)$co2), rep(FALSE, 19))
    file.remove(filename)
})
