here::i_am("tests/testthat/test_intermediates_perturbations.R")

library(testthat)
library(here)
library(ini)

options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/intermediates/perturbations.R"), chdir = TRUE)

fake_monthly_fluxes <- function(filename, no_regions, flux_value) {
    # create a fake monthly_fluxes for testing
    dimtime <- ncdim_def("time", "days since 2010-01-01 00:00:00", 
                         c(0, cumsum(days_in_month(seq(as.Date("2010/01/01"), by = "month", length.out = 23)))))
    dimlat <- ncdim_def("latitude", "", seq(-90,90,10))
    dimlon <- ncdim_def("longitude", "", seq(-170,180,10))

    varems_list <- list()
    for (i in 0:no_regions) {
        varems_list[[i+1]] <- ncvar_def(sprintf("EMIS_CH4_R%02d", i), "", list(dimlon, dimlat, dimtime), NA, prec="double")
    }

    ncnew <- nc_create(filename, varems_list)

    arrems <- array(flux_value, c(24, 36, 19))

    for (i in 0:no_regions) {
        ncvar_put(ncnew, varems_list[[i+1]], arrems)
    }

    nc_close(ncnew)
}

fake_control_ems <- function(locations, flux_value) {
    # create a fake control emissions intermediate for testing
    data.frame(month_start=rep(locations$month_start, each=2),
               longitude=rep(locations$longitude, each=2),
               latitude=rep(locations$latitude, each=2),
               model_id=rep(1:length(locations$latitude), each=2),
               type=rep(c("land", "ocean"), length(locations$latitude)),
               flux_density=rep(flux_value, length(locations$latitude)))
}

test_that("sum_ch4_tracers with zeros", {
    v_base <- function(name) array(0,c(72,46,132))
    v_pert <- function(name) array(0,c(72,46,24))
    total_ch4 <- sum_ch4_tracers(v_base, v_pert,
                                 region_start=0, region_end=11,
                                 perturbed_region=5,
                                 month_start=1, month_end=24)
    expect_equal(total_ch4, array(0, c(72,46,132)))
})

test_that("sum_ch4_tracers with perturbed ones", {
    v_base <- function(name) array(0,c(72,46,132))
    v_pert <- function(name) array(1,c(72,46,24))
    total_ch4 <- sum_ch4_tracers(v_base, v_pert,
                                 region_start=0, region_end=11,
                                 perturbed_region=5,
                                 month_start=1, month_end=24)
    ideal_ch4 <- array(0, c(72,46,132))
    ideal_ch4[,,1:24] <- 1
    
    expect_equal(total_ch4, ideal_ch4)
})


test_that("check locations expansion code works", {
    # Read in config file
    config <- read.ini(paste0(here(), "/config.ini"))
    no_regions <- as.numeric(config$inversion_constants$no_regions)

    # create fake monthly_fluxes file
    filename <- paste0(here(), "/tests/testthat/test_monthly_fluxes.nc")
    fake_monthly_fluxes(filename, no_regions, 0)

    # test ability to extract base run and locations 
    base_info <- base_run_info(filename)
    # check dimensions and ordering of locations output
    expect_equal(dim(base_info$locations), c(24*36*19, 3))
    expect_equal(base_info$locations, base_info$locations[order(base_info$locations$month_start, base_info$locations$latitude, base_info$locations$longitude),])
    file.remove(filename)
})


test_that("check process_perturbation_part works for land region with zero emissions in base", {
  # Read in config file
  config <- read.ini(paste0(here(), "/config.ini"))
  no_regions <- as.numeric(config$inversion_constants$no_regions)

  # create fake monthly_fluxes file
  filename <- paste0(here(), "/tests/testthat/test_monthly_fluxes.nc")
  fake_monthly_fluxes(filename, no_regions, 0)

  # extract base run and locations
  base_info <- base_run_info(filename)

  # create fake control emissions intermediate
  control_ems <- fake_control_ems(base_info$locations, c(0,0))

  v_pert <- function(name) array(1, c(36,19,24))

  test_out <- process_perturbation_part(1, 2010, 0, config, v_pert, base_info$v_base, control_ems, base_info$locations)
  file.remove(filename)
  expect_equal((test_out %>% filter(type == "land"))$flux_density, rep(1, length((test_out %>% filter(type == "land"))$flux_density)))
  expect_equal((test_out %>% filter(type == "ocean"))$flux_density, rep(0, length((test_out %>% filter(type == "ocean"))$flux_density)))
})

test_that("check process_perturbation_part works for ocean region with zero emissions in base", {
  # Read in config file
  config <- read.ini(paste0(here(), "/config.ini"))
  no_regions <- as.numeric(config$inversion_constants$no_regions)

  # create fake monthly_fluxes file
  filename <- paste0(here(), "/tests/testthat/test_monthly_fluxes.nc")
  fake_monthly_fluxes(filename, no_regions, 0)

  # extract base run and locations
  base_info <- base_run_info(filename)

  # create fake control emissions intermediate
  control_ems <- fake_control_ems(base_info$locations, c(0,0))

  v_pert <- function(name) array(1, c(36,19,24))

  test_out <- process_perturbation_part(1, 2010, no_regions, config, v_pert, base_info$v_base, control_ems, base_info$locations)
  file.remove(filename)
  expect_equal((test_out %>% filter(type == "ocean"))$flux_density, rep(1, length((test_out %>% filter(type == "ocean"))$flux_density)))
  expect_equal((test_out %>% filter(type == "land"))$flux_density, rep(0, length((test_out %>% filter(type == "land"))$flux_density)))
})

test_that("check process_perturbation_part works for land region with one emissions in base", {
  # Read in config file
  config <- read.ini(paste0(here(), "/config.ini"))
  no_regions <- as.numeric(config$inversion_constants$no_regions)

  # create fake monthly_fluxes file
  filename <- paste0(here(), "/tests/testthat/test_monthly_fluxes.nc")
  fake_monthly_fluxes(filename, no_regions, 1)

  # extract base run and locations
  base_info <- base_run_info(filename)

  # current set up means each region contributes 1 in the base
  land_total <- as.numeric(config$inversion_constants$no_land_regions)
  ocean_total <- no_regions - as.numeric(config$inversion_constants$no_land_regions) + 1

  # create fake control emissions intermediate
  control_ems <- fake_control_ems(base_info$locations, c(land_total, ocean_total))

  v_pert <- function(name) array(2, c(36,19,24))

  test_out <- process_perturbation_part(1, 2010, 0, config, v_pert, base_info$v_base, control_ems, base_info$locations)
  file.remove(filename)
  expect_equal((test_out %>% filter(type == "land"))$flux_density, rep(1, length((test_out %>% filter(type == "land"))$flux_density)))
  expect_equal((test_out %>% filter(type == "ocean"))$flux_density, rep(0, length((test_out %>% filter(type == "ocean"))$flux_density)))
})

test_that("check process_perturbation_part works for ocean region with one emissions in base", {
  # Read in config file
  config <- read.ini(paste0(here(), "/config.ini"))
  no_regions <- as.numeric(config$inversion_constants$no_regions)

  # create fake monthly_fluxes file
  filename <- paste0(here(), "/tests/testthat/test_monthly_fluxes.nc")
  fake_monthly_fluxes(filename, no_regions, 1)

  # extract base run and locations
  base_info <- base_run_info(filename)

  # current set up means each region contributes 1 in the base, and then the perturbed region contributes 2
  land_total <- as.numeric(config$inversion_constants$no_land_regions)
  ocean_total <- no_regions - as.numeric(config$inversion_constants$no_land_regions) + 1

  # create fake control emissions intermediate
  control_ems <- fake_control_ems(base_info$locations, c(land_total, ocean_total))

  v_pert <- function(name) array(2, c(36,19,24))

  test_out <- process_perturbation_part(1, 2010, no_regions, config, v_pert, base_info$v_base, control_ems, base_info$locations)
  file.remove(filename)
  expect_equal((test_out %>% filter(type == "ocean"))$flux_density, rep(1, length((test_out %>% filter(type == "ocean"))$flux_density)))
  expect_equal((test_out %>% filter(type == "land"))$flux_density, rep(0, length((test_out %>% filter(type == "land"))$flux_density)))
})