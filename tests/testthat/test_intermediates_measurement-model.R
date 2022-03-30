here::i_am("tests/testthat/test_intermediates_measurement-model.R")

library(testthat)
library(here)

options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/intermediates/measurement-model.R"), chdir = TRUE)

test_that("model_matrix2 works", {
    # fake obs
    observations <- data.frame(obspack_site = c("sitea", "sitea", "siteb", "siteb"),
                               co2 = 1:4)
    # compare
    expected_out <- Matrix(c(1, 1, 1, 1, 1, 1, NA, NA, NA, NA, 1, 1), 4, 3,
                           sparse = TRUE,
                           dimnames = list(1:4, c("intercept", "obspack_sitesitea", "obspack_sitesiteb")))

    expect_equal(make_A(observations), expected_out, check.attributes = FALSE)
})

test_that("na_to_zero works", {
    x <- c(1, NA, 2, NA, 3)
    expect_equal(na_to_zero(x), c(1, 0, 2, 0, 3))
})
