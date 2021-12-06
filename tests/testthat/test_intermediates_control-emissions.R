here::i_am("tests/testthat/test_intermediates_control-emissions.R")

library(testthat)
library(here)

options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/intermediates/control-emissions.R"), chdir = TRUE)



test_that("sum_ch4_tracers with zeros", {
    v_test <- function(name) array(0,c(72,46,132))
    expect_equal(sum_ch4_tracers(v_test, 0, 22), array(0,c(72,46,132)))
})

test_that("sum_ch4_tracers with ones", {
    v_test <- function(name) array(1,c(72,46,132))
    expect_equal(sum_ch4_tracers(v_test, 0, 22), array(23,c(72,46,132)))
})