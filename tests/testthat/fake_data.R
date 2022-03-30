here::i_am("tests/testthat/fake_data.R")

library(testthat)
library(here)
library(lubridate)
library(ncdf4)



fake_combined_mf <- function(filename) {
    # fake combined_mf
    dimtime <- ncdim_def("obs_time", "days since 2010-01-01 00:00:00",
                         c(0, cumsum(days_in_month(seq(as.Date("2010/01/01"), by = "month", length.out = 9)))))
    dimsite <- ncdim_def("site", "", 1:2)
    dimnchar <- ncdim_def("nchar",   "", 1:12, create_dimvar = FALSE)

    varlat <- ncvar_def("obs_lat", "", list(dimsite, dimtime), NA, prec = "double")
    varlon <- ncvar_def("obs_lon", "", list(dimsite, dimtime), NA, prec = "double")
    varid <- ncvar_def("obspack_id", "", list(dimnchar, dimsite, dimtime), NULL, prec = "char")
    varch4_r00 <- ncvar_def("CH4_R00", "", list(dimsite, dimtime), NA, prec = "double")
    varch4_sum <- ncvar_def("CH4_sum", "", list(dimsite, dimtime), NA, prec = "double")

    ncnew <- nc_create(filename, list(varlat, varlon, varid, varch4_r00, varch4_sum))

    arrlat <- array(45, c(10, 2))
    arrlat[, 2] <- -45
    arrlon <- array(90, c(10, 2))
    arrlon[, 2] <- -90
    arrid <- array(0, c(10, 2))
    arrid[, 1] <- sprintf("blah~a2010%02d", 1:10)
    arrid[, 2] <- sprintf("blah~b2010%02d", 1:10)
    arrco2 <- array(seq(330, 340, length.out = 20), c(10, 2))
    arrco2[5, 1] <- NA

    ncvar_put(ncnew, varlat, arrlat)
    ncvar_put(ncnew, varlon, arrlon)
    ncvar_put(ncnew, varid, arrid)
    ncvar_put(ncnew, varch4_r00, arrco2)
    ncvar_put(ncnew, varch4_sum, arrco2)

    nc_close(ncnew)
}