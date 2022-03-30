here::i_am("tests/testthat/test_intermediates_sensitivities.R")

library(testthat)
library(here)
library(ini)

options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/intermediates/sensitivities.R"), chdir = TRUE)

# use same fake_combined_mf function
source(paste0(here(), "/tests/testthat/fake_data.R"), chdir = TRUE)

fake_control_mf <- function() {
    # create a fake mole fraction intermediate for testing
    fake_observation_id <- c(sprintf("obspack_multi-species_1_CCGGSurfaceFlask_v2.0_2021-02-09~n2o_aNOAAsurf_surface-flask_1_ccgg_Event~a2010%02d", 1:10),
                             sprintf("obspack_multi-species_1_CCGGSurfaceFlask_v2.0_2021-02-09~n2o_bNOAAsurf_surface-flask_1_ccgg_Event~b2010%02d", 1:10))

    data.frame(observation_id = fake_observation_id,
               observation_type = "obspack",
               resolution = "obspack",
               control_co2 = seq(331, 341, length.out = 20),
               model_id = 1:20)
}

test_that("sum_ch4_tracers_perturbed with zeros", {
    v_base <- function(name) array(0, c(72, 46, 132))
    v_pert <- function(name) array(0, c(72, 46, 132))
    total_ch4 <- sum_ch4_tracers_perturbed(v_base, v_pert,
                                           perturbed_region = 5, no_regions = 22)
    expect_equal(total_ch4, rep(0, (72 * 46 * 132)))
})

test_that("sum_ch4_tracers_perturbed with perturbed ones", {
    v_base <- function(name) array(0, c(72, 46, 132))
    v_pert <- function(name) array(1, c(72, 46, 132))
    total_ch4 <- sum_ch4_tracers_perturbed(v_base, v_pert,
                                           perturbed_region = 5, no_regions = 22)
    ideal_ch4 <- rep(1, 72 * 46 * 132)

    expect_equal(total_ch4, ideal_ch4)
})


test_that("process_sensitivity_part with zeros in perturbed run", {
    v_base <- function(name) array(0, c(2 * 10))

    v <- function(name) {
        if (name == "obspack_id") {
            c(sprintf("obspack_multi-species_1_CCGGSurfaceFlask_v2.0_2021-02-09~n2o_aNOAAsurf_surface-flask_1_ccgg_Event~a2010%02d", 1:10),
            sprintf("obspack_multi-species_1_CCGGSurfaceFlask_v2.0_2021-02-09~n2o_bNOAAsurf_surface-flask_1_ccgg_Event~b2010%02d", 1:10))
        }
        else {
            array(0, c(2 * 10))
        }
    }

    config <- read.ini(paste0(here(), "/config.ini"))
    no_regions <- as.numeric(config$inversion_constants$no_regions) + 1

    processed_sensitivity <- process_sensitivity_part(2010, 1, v_base, v, fake_control_mf(), config)

    expect_equal(processed_sensitivity$co2_sensitivity, rep(seq(-331, -341, length.out=20), no_regions))
})


test_that("process_sensitivity_part with values in perturbed run", {
    v_base <- function(name) array(0, c(2 * 10))

    v <- function(name) {
        if (name == "obspack_id") {
            c(sprintf("obspack_multi-species_1_CCGGSurfaceFlask_v2.0_2021-02-09~n2o_aNOAAsurf_surface-flask_1_ccgg_Event~a2010%02d", 1:10),
            sprintf("obspack_multi-species_1_CCGGSurfaceFlask_v2.0_2021-02-09~n2o_bNOAAsurf_surface-flask_1_ccgg_Event~b2010%02d", 1:10))
        }
        else {
            seq(330, 340, length.out = 20)
        }
    }

    config <- read.ini(paste0(here(), "/config.ini"))
    no_regions <- as.numeric(config$inversion_constants$no_regions) + 1

    processed_sensitivity <- process_sensitivity_part(2010, 1, v_base, v, fake_control_mf(), config)

    expect_equal(processed_sensitivity$co2_sensitivity, rep(-1, 2 * 10 * no_regions))
})
