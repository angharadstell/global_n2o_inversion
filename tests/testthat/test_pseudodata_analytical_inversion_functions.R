here::i_am("tests/testthat/test_pseudodata_analytical_inversion_functions.R")

library(testthat)
library(here)

options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/pseudodata/analytical_inversion_functions.R"), chdir = TRUE)

test_that("model_out works with zeros", {
          control_mf <- data.frame(co2 = c(0, 0, 0))
          G <- matrix(0, 3, 2)
          m <- c(0, 0)
          func_out <- model_out(control_mf, G, m)
          expect_equal(func_out, matrix(0, 3, 1))
          })

test_that("model_out works with ones", {
          control_mf <- data.frame(co2 = c(1, 1, 1))
          G <- matrix(1, 3, 2)
          m <- c(1, 1)
          func_out <- model_out(control_mf, G, m)
          expect_equal(func_out, matrix(3, 3, 1))
          })

test_that("m_post works when prior is correct", {
          control_mf <- data.frame(co2 = c(0, 0, 0))
          m_prior <- c(0, 0)
          G <- matrix(1, 3, 2)
          C_M <- diag(1, 2, 2)
          C_D <- diag(1, 3, 3)
          d_obs <- c(0, 0, 0)
          func_out <- m_post(control_mf, m_prior, C_M, G, C_D, d_obs)
          expect_equal(func_out, matrix(0, 2, 1))
          })

test_that("m_post works when prior is too low", {
          control_mf <- data.frame(co2 = c(0, 0, 0))
          m_prior <- c(0, 0)
          G <- matrix(1, 3, 2)
          C_M <- diag(1, 2, 2)
          C_D <- diag(1, 3, 3)
          d_obs <- c(1, 1, 1)
          func_out <- m_post(control_mf, m_prior, C_M, G, C_D, d_obs)
          expect_true(all(func_out > 0))
          })

test_that("m_post works when prior is too high", {
          control_mf <- data.frame(co2 = c(0, 0, 0))
          m_prior <- c(0, 0)
          G <- matrix(1, 3, 2)
          C_M <- diag(1, 2, 2)
          C_D <- diag(1, 3, 3)
          d_obs <- c(-1, -1, -1)
          func_out <- m_post(control_mf, m_prior, C_M, G, C_D, d_obs)
          expect_true(all(func_out < 0))
          })

test_that("m_post_cov_calc runs", {
          G <- matrix(1, 3, 2)
          C_M <- diag(1, 2, 2)
          C_D <- diag(1, 3, 3)
          func_out <- m_post_cov_calc(C_M, G, C_D)
          expect_equal(dim(func_out), c(2, 2))
          expect_true(all(diag(func_out) > 0))
          })

test_that("m_post_cov_calc responds to changes in C_M", {
          G <- matrix(1, 3, 2)
          C_M <- diag(1, 2, 2)
          C_D <- diag(1, 3, 3)
          func_out_1 <- m_post_cov_calc(C_M, G, C_D)
          C_M <- diag(2, 2, 2)
          func_out_2 <- m_post_cov_calc(C_M, G, C_D)
          expect_true(all(diag(func_out_2) > diag(func_out_1)))
          })

test_that("m_post_cov_calc responds to changes in C_D", {
          G <- matrix(1, 3, 2)
          C_M <- diag(1, 2, 2)
          C_D <- diag(1, 3, 3)
          func_out_1 <- m_post_cov_calc(C_M, G, C_D)
          C_D <- diag(2, 3, 3)
          func_out_2 <- m_post_cov_calc(C_M, G, C_D)
          expect_true(all(diag(func_out_2) > diag(func_out_1)))
          })

test_that("m_post_sample runs", {
    i <- 1
    m_squiggle <- matrix(0, 1, 2)
    m_post_cov <- diag(1, 2, 2)
    case <- "test"
    func_out <- m_post_sample(i, m_squiggle, m_post_cov, case)
    filename <- sprintf("%s/real_analytical_samples_%s_%04d.rds", config$paths$pseudodata_dir, case, i)
    expect_true(file.exists(filename))
    file.remove(filename)
    })

test_that("make_C_D runs", {
    observations <- data.frame(co2_error = c(1, 1, 1))
    func_out <- make_C_D(observations)
    # dim
    expect_equal(dim(func_out), c(3, 3))
    # diag
    expect_equal(as.matrix(func_out), diag(1, 3, 3), check.attributes = FALSE)
    })

test_that("make_C_M works when kappa is zero", {
    var <- 0.5^2
    kappa <- 0
    kappa_regions <- 1
    n_regions <- 2
    n_months <- 3
    func_out <- make_C_M(var, kappa, kappa_regions, n_regions, n_months)

    expect_equal(func_out, diag(var, (n_regions * n_months), (n_regions * n_months)))
    })

test_that("make_C_M works when kappa is non-zero", {
    var <- 0.5^2
    kappa <- 0.5
    kappa_regions <- 1
    n_regions <- 2
    n_months <- 3
    func_out <- make_C_M(var, kappa, kappa_regions, n_regions, n_months)

    # check diag
    expect_equal(diag(func_out), rep(c(var / (1 - kappa^2), var), n_months))
    # check off diag
    expect_equal(func_out[row(func_out) == (col(func_out) + 1)], rep(0, (n_regions * n_months - 1)))
    expect_equal(func_out[row(func_out) == (col(func_out) - 1)], rep(0, (n_regions * n_months - 1)))
    expect_equal(func_out[row(func_out) == (col(func_out) + 2)], rep(c((kappa * var) / (1 - kappa^2), 0), 2))
    expect_equal(func_out[row(func_out) == (col(func_out) - 2)], rep(c((kappa * var) / (1 - kappa^2), 0), 2))
    expect_equal(func_out[row(func_out) == (col(func_out) + 3)], rep(0, (n_regions * n_months - 3)))
    expect_equal(func_out[row(func_out) == (col(func_out) - 3)], rep(0, (n_regions * n_months - 3)))
    expect_equal(func_out[row(func_out) == (col(func_out) + 4)], c((kappa^2 * var) / (1 - kappa^2), 0))
    expect_equal(func_out[row(func_out) == (col(func_out) - 4)], c((kappa^2 * var) / (1 - kappa^2), 0))
    expect_equal(func_out[row(func_out) == (col(func_out) + 5)], 0)
    expect_equal(func_out[row(func_out) == (col(func_out) - 5)], 0)
    })
