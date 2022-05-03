here::i_am("tests/testthat/test_moving_window_plot_hyperparameters.R")

library(here)
library(testthat)

options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/moving_window/plot_hyperparameters.R"), chdir = TRUE)

test_that("extract_time_var works with alphas as zeros", {
    # set up some constants
    n_alphas <- 2
    n_samples <- as.numeric(config$inversion_constants$no_samples)
    start_year <- year(as.Date(config$dates$perturb_start)) + 1
    end_year <- year(as.Date(config$dates$perturb_end)) - 1

    # mock up some window inversion results
    window_samples <- list(list("alpha" = matrix(0, n_samples, n_alphas)),
                           list("alpha" = matrix(0, n_samples, n_alphas)),
                           list("alpha" = matrix(0, n_samples, n_alphas)),
                           list("alpha" = matrix(0, n_samples, n_alphas)),
                           list("alpha" = matrix(0, n_samples, n_alphas)),
                           list("alpha" = matrix(0, n_samples, n_alphas)),
                           list("alpha" = matrix(0, n_samples, n_alphas)),
                           list("alpha" = matrix(0, n_samples, n_alphas)),
                           list("alpha" = matrix(0, n_samples, n_alphas)),
                           list("alpha" = matrix(0, n_samples, n_alphas)))

    # what our results should be
    expected_out <- matrix(0, n_alphas, length(window_samples))
    colnames(expected_out) <- start_year:end_year

    # compare
    expect_equal(extract_time_var(window_samples, "alpha"), expected_out)
})

test_that("extract_time_var works with gammas as zeros", {
    # set up some constants
    n_gammas <- 2
    n_samples <- as.numeric(config$inversion_constants$no_samples)
    start_year <- year(as.Date(config$dates$perturb_start)) + 1
    end_year <- year(as.Date(config$dates$perturb_end)) - 1

    # mock up some window inversion results
    window_samples <- list(list("gamma" = matrix(0, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb")))),
                           list("gamma" = matrix(0, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb")))),
                           list("gamma" = matrix(0, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb")))),
                           list("gamma" = matrix(0, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb")))),
                           list("gamma" = matrix(0, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb")))),
                           list("gamma" = matrix(0, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb")))),
                           list("gamma" = matrix(0, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb")))),
                           list("gamma" = matrix(0, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb")))),
                           list("gamma" = matrix(0, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb")))),
                           list("gamma" = matrix(0, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb")))))


    # what our results should be
    expected_out <- matrix(0, n_gammas, length(window_samples))
    colnames(expected_out) <- start_year:end_year
    rownames(expected_out) <- c("sitea", "siteb")

    # compare
    expect_equal(extract_time_var(window_samples, "gamma"), expected_out)
})

test_that("plot_param_hist works", {
    # set up some constants
    n_alphas <- 2
    n_samples <- as.numeric(config$inversion_constants$no_samples)
    start_year <- year(as.Date(config$dates$perturb_start)) + 1
    end_year <- year(as.Date(config$dates$perturb_end)) - 1

    # mock up some window inversion results
    window_samples <- list(list("alpha" = matrix(0, n_samples, n_alphas)),
                           list("alpha" = matrix(0, n_samples, n_alphas)),
                           list("alpha" = matrix(0, n_samples, n_alphas)),
                           list("alpha" = matrix(0, n_samples, n_alphas)),
                           list("alpha" = matrix(0, n_samples, n_alphas)),
                           list("alpha" = matrix(0, n_samples, n_alphas)),
                           list("alpha" = matrix(0, n_samples, n_alphas)),
                           list("alpha" = matrix(0, n_samples, n_alphas)),
                           list("alpha" = matrix(0, n_samples, n_alphas)),
                           list("alpha" = matrix(0, n_samples, n_alphas)))

    # just test that this doesn't error
    # could do a better job with vdiffr/ snapshots but not worth the effort
    expect_error(plot_param_hist(window_samples, "alpha", "year"), NA)
})

test_that("plot_param_map works", {
    # set up some constants
    n_gammas <- 2
    n_regions <- as.numeric(config$inversion_constants$no_regions) + 1
    n_samples <- as.numeric(config$inversion_constants$no_samples)
    start_year <- year(as.Date(config$dates$perturb_start)) + 1
    end_year <- year(as.Date(config$dates$perturb_end)) - 1

    # mock up some window inversion results
    window_samples <- list(list("gamma" = matrix(0, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb"))),
                                "w" = matrix(0, n_samples, n_regions)),
                           list("gamma" = matrix(0, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb"))),
                                "w" = matrix(0, n_samples, n_regions)),
                           list("gamma" = matrix(0, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb"))),
                                "w" = matrix(0, n_samples, n_regions)),
                           list("gamma" = matrix(0, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb"))),
                                "w" = matrix(0, n_samples, n_regions)),
                           list("gamma" = matrix(0, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb"))),
                                "w" = matrix(0, n_samples, n_regions)),
                           list("gamma" = matrix(0, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb"))),
                                "w" = matrix(0, n_samples, n_regions)),
                           list("gamma" = matrix(0, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb"))),
                                "w" = matrix(0, n_samples, n_regions)),
                           list("gamma" = matrix(0, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb"))),
                                "w" = matrix(0, n_samples, n_regions)),
                           list("gamma" = matrix(0, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb"))),
                                "w" = matrix(0, n_samples, n_regions)),
                           list("gamma" = matrix(0, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb"))),
                                "w" = matrix(0, n_samples, n_regions)))

    # just test that this doesn't error
    # could do a better job with vdiffr/ snapshots but not worth the effort
    expect_error(plot_param_map(window_samples), NA)

     # for some reason grid.arrange makes Rplots.pdf, just remove it
     # couldnt find a more intelligent solution
     rplots_file <- sprintf("%s/../../tests/testthat/Rplots.pdf", config$paths$location_of_this_file)
     if (file.exists(rplots_file)) {
          file.remove(rplots_file)
     }
})

test_that("plot_model_measurement_error", {
    # set up some constants
    n_gammas <- 2
    n_samples <- as.numeric(config$inversion_constants$no_samples)
    start_year <- year(as.Date(config$dates$perturb_start)) + 1
    end_year <- year(as.Date(config$dates$perturb_end)) - 1

    # mock up some window inversion results
    window_samples <- list(list("gamma" = matrix(1, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb")))),
                           list("gamma" = matrix(1, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb")))),
                           list("gamma" = matrix(1, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb")))),
                           list("gamma" = matrix(1, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb")))),
                           list("gamma" = matrix(1, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb")))),
                           list("gamma" = matrix(1, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb")))),
                           list("gamma" = matrix(1, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb")))),
                           list("gamma" = matrix(1, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb")))),
                           list("gamma" = matrix(1, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb")))),
                           list("gamma" = matrix(1, n_samples, n_gammas, dimnames = list(NULL, c("sitea", "siteb")))))

    # mock up some observations
    obs_file <- "test-observations.fst"
    obs <- tibble(observation_group = c("sitea", "siteb"),
                  time = c(as.Date("2010-01-01"), as.Date("2010-01-01")),
                  co2_error = c(1, 1))
    fst::write_fst(obs, sprintf("%s/%s", config$paths$geos_inte, obs_file))

    # just test that this doesn't error
    # could do a better job with vdiffr/ snapshots but not worth the effort
    expect_error(plot_model_measurement_error(window_samples, obs_file), NA)
    expect_message(plot_model_measurement_error(window_samples, obs_file), "Unscaled model-measurement error: 1.000000 ppb")
    expect_message(plot_model_measurement_error(window_samples, obs_file), "Posterior model-measurement error: 1.000000 ppb")

    # remove fake file
    file.remove(sprintf("%s/%s", config$paths$geos_inte, obs_file))
})
