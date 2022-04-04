# This script plots qq plots for the analytical and WOMBAT pseudodata inversions,
# comapring performance in different scenarios
library(argparser)
library(dplyr)
library(ggplot2)
library(here)
library(ini)

###############################################################################
# GLOBAL CONSTANTS
###############################################################################
config <- read.ini(paste0(here(), "/config.ini"))

n_samples <- as.numeric(config$pseudodata$n_samples)
n_regions <- as.numeric(config$inversion_constants$no_regions) + 1
n_months <- as.numeric(config$pseudodata$n_months)

###############################################################################
# FUNCTIONS
###############################################################################

# read in inversion alphas from file
mcmc_alpha <- function(file) {
  burn_in <- as.numeric(config$inversion_constants$burn_in)
  no_samples <- as.numeric(config$inversion_constants$no_samples)
  # try to read in file
  if (file.exists(file)) {
    mcmc_samples <- readRDS(file)
    mcmc_samples$alpha[(burn_in + 1):dim(mcmc_samples$alpha)[1], ]
  # if file doesn't exist because run failed, just use NAs as a place holder
  } else {
    message(file, " doesn't exist")
    na_matrix <- matrix(NA, (no_samples - burn_in), (n_regions * n_months))
    return(na_matrix)
  }
}

# match true value to alpha samples' quantiles
quantile_match <- function(nsample, nalpha, alpha_samples, alpha_true) {
  # generate the quantiles for one alpha from the mcmc samples
  post_quantile <- quantile(alpha_samples[[nsample]][, nalpha],
                            probs = seq(0, 1, length.out = 1001),
                            na.rm = TRUE)
  # get the true value of alpha
  post_true <- alpha_true[nsample, nalpha]
  # mask is a boolean array
  # if true value is less than the quantile, mask is TRUE
  # if true value is more than the quantile, mask is FALSE
  # therefore, the first TRUE value is the quantile where the true value lies
  # unless the true value lies below the 0th quantile...
  mask <- post_true < post_quantile

  # if the file doesn't exist, all the quantiles are NA, return NA
  # if the true value lies below the 0th quantile, return NA
  # if the true value lies above the 100th quantile, return NA
  # this is problematic because this code just ignores all the values it got
  # totally wrong
  if (all(is.na(post_quantile[[1]]))) {
    NA
  } else if (post_true < post_quantile[[1]]) {
    NA
  } else if (post_true > post_quantile[[1001]]) {
    NA
  # otherwise extract which quantile the true value is in
  } else {
    q <- as.numeric(gsub("([.0-9]+).*$", "\\1", names(post_quantile[mask][1])))
    q / 100
  }
}

# get all the quantiles for the WOMBAT inversion
wombat_quantiles <- function(test_case, r_seq, alpha_true) {
  # extract alphas from files
  alpha_wombat <- lapply(1:n_samples, function(i) {
                         filename <- sprintf("%s/real-mcmc-samples-%s_%04d.rds",
                                             config$paths$pseudodata_dir,
                                             test_case,
                                             i)
                         mcmc_alpha(filename)
})
  # calculate quantiles
  wombat_quantile <- mapply(quantile_match,
                            rep(1:n_samples, times = length(r_seq)),
                            rep(r_seq, each = n_samples),
                            MoreArgs = list(alpha_samples = alpha_wombat,
                                            alpha_true = alpha_true))
  dim(wombat_quantile) <- c(n_samples, length(r_seq))

  list(alpha_samples = alpha_wombat, quantile = wombat_quantile)
}

# calculate RMSE
rmse <- function(actual, predicted) {
  sqrt(mean((actual - predicted)^2, na.rm = TRUE))
}

# calculate MAE
mae <- function(actual, predicted) {
  mean(abs(actual - predicted), na.rm = TRUE)
}

###############################################################################
# EXECUTED CODE
###############################################################################

main <- function() {
  args <- arg_parser("", hide.opts = TRUE) %>%
    add_argument("--pseudo-case", "") %>%
    add_argument("--wombat-vary", "") %>%
    parse_args()

  n_alpha <- n_regions * n_months
  r_seq <- 1:n_alpha

  case <- args$pseudo_case

  # extract numbers from case
  case_no <- as.numeric(unlist(regmatches(case,
                                          gregexpr("[[:digit:]]+",
                                          case))))

  # read in true alphas
  alpha_true <- readRDS(sprintf("%s/alpha_samples_%s.rds",
                        config$paths$pseudodata_dir, case))

  # read in analytical samples
  alpha_anal <- lapply(1:n_samples, function(i) {
                      readRDS(sprintf("%s/real_analytical_samples_%s_%04d.rds",
                      config$paths$pseudodata_dir, case, i))})

  anal_quantile <- mapply(quantile_match,
                          rep(1:n_samples, times = length(r_seq)),
                          rep(r_seq, each = n_samples),
                          MoreArgs = list(alpha_samples = alpha_anal,
                                          alpha_true = alpha_true))
  dim(anal_quantile) <- c(n_samples, length(r_seq))

  # try to guess what parameter is varying is not specified
  if (is.na(args$wombat_vary)) {
    if (case_no[[1]] != 1) {
      args$wombat_vary <- "gamma"
    } else if (case_no[[2]] != 0) {
      args$wombat_vary <- "a"
    } else if (case_no[[3]] != 1) {
      args$wombat_vary <- "w"
    } else {
      stop("it is ambiguous which wombat parameter you want to vary, pick one!")
    }
  }

  # set up case specific variables
  if (args$wombat_vary == "gamma") {
    print("varygamma")
    wombat_label <- "vary gamma"
    wombat_case <- paste0("IS-RHO0-FIXEDA-FIXEDW-NOBIAS_", case)
  } else if (args$wombat_vary == "a") {
    print("varya")
    wombat_label <- "vary a"
    wombat_case <- paste0("IS-RHO0-FIXEDGAMMA-VARYA-FIXEDW-NOBIAS_", case)
  } else if (args$wombat_vary == "w") {
    print("varyw")
    wombat_label <- "vary w"
    wombat_case <- paste0("IS-RHO0-FIXEDGAMMA-FIXEDA-VARYW-NOBIAS_", case)
  }

  # read in WOMBAT alphas
  varywombat <- wombat_quantiles(wombat_case, r_seq, alpha_true)

  # qqplot
  p <- ggplot() +
        stat_qq(aes(sample = anal_quantile[!is.na(anal_quantile)],
                    color = "analytical"),
                distribution = stats::qunif, size = 0.1) +
        stat_qq(aes(sample = varywombat$quantile[!is.na(varywombat$quantile)],
                    color = wombat_label),
                distribution = stats::qunif, size = 0.1) +
        geom_abline(aes(slope = 1, intercept = 0.0), linetype = 2) +
        theme(legend.title = element_blank())
  plot(p)
  ggsave(sprintf("%s/qqplot_%s_vary%s.png",
                 config$paths$pseudodata_dir,
                 case,
                 args$wombat_vary))

  # how well does it compare to the truth?
  alpha_anal_mean <- sapply(alpha_anal, colMeans)
  alpha_wombat_mean <- sapply(varywombat$alpha_samples, colMeans)

  print("analytical RMSE and MAE:")
  print(rmse(as.vector(t(alpha_true)), as.vector(alpha_anal_mean)))
  print(mae(as.vector(t(alpha_true)), as.vector(alpha_anal_mean)))
  print("varywombat RMSE and MAE:")
  print(rmse(as.vector(t(alpha_true)), as.vector(alpha_wombat_mean)))
  print(mae(as.vector(t(alpha_true)), as.vector(alpha_wombat_mean)))
}

if (getOption("run.main", default = TRUE)) {
   main()
}
