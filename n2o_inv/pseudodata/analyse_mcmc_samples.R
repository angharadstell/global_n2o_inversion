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
start_sample <- as.numeric(config$inversion_constants$burn_in) + 1

###############################################################################
# FUNCTIONS
###############################################################################

mcmc_alpha <- function(file) {
    tryCatch({
      mcmc_samples <- readRDS(file)
      mcmc_samples$alpha[start_sample:dim(mcmc_samples$alpha)[1], ]},
      error = function(cond) {
      message(cond)
      na_matrix <- rep(NA, 10000 * n_regions * n_months)
      dim(na_matrix) <- c(10000, n_regions * n_months)
      return(na_matrix)})
}

quantile_match <- function(nsample, nalpha, alpha_samples, alpha_true) {
  post_quantile <- quantile(alpha_samples[[nsample]][, nalpha],
                            probs = seq(0, 1, length.out = 1001),
                            na.rm = TRUE)

  post_true <- alpha_true[nsample, nalpha]

  mask <- post_true < post_quantile

  as.numeric(gsub("([.0-9]+).*$", "\\1", names(post_quantile[mask][1])))
}

wombat_quantiles <- function(case, r_seq, alpha_true) {
  alpha_wombat <- lapply(1:n_samples, function(i) {
                         filename <- sprintf("%s/real-mcmc-samples-%s_%04d.rds",
                                             config$paths$pseudodata_dir,
                                             case,
                                             i)
                         mcmc_alpha(filename)
})

  wombat_quantile <- mapply(quantile_match,
                            rep(1:n_samples, times = length(r_seq)),
                            rep(r_seq, each = n_samples),
                            MoreArgs = list(alpha_samples = alpha_wombat,
                                            alpha_true = alpha_true))
  dim(wombat_quantile) <- c(n_samples, length(r_seq))

  list(alpha_samples = alpha_wombat, quantile = wombat_quantile)

}

rmse <- function(actual, predicted) {
  sqrt(mean((actual - predicted)^2))
}

mae <- function(actual, predicted) {
  mean(abs(actual - predicted))
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
  case_no <- as.numeric(unlist(regmatches(case, gregexpr("[[:digit:]]+", case))))

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

  # read in WOMBAT alphas
  if (is.na(args$wombat_vary)) {
    if (case_no[[1]] != 1) {
      print("varygamma")
      wombat_label <- "vary gamma"
      varywombat <- wombat_quantiles(paste0("IS-RHO0-FIXEDA-FIXEDW-NOBIAS_", case), r_seq, alpha_true)
    } else if (case_no[[2]] != 0) {
      print("varya")
      wombat_label <- "vary a"
      varywombat <- wombat_quantiles(paste0("IS-RHO0-FIXEDGAMMA-VARYA-FIXEDW-NOBIAS_", case), r_seq, alpha_true)
    } else if (case_no[[3]] != 1) {
      print("varyw")
      wombat_label <- "vary w"
      varywombat <- wombat_quantiles(paste0("IS-RHO0-FIXEDGAMMA-FIXEDA-VARYW-NOBIAS_", case), r_seq, alpha_true)
    } else {
      stop("it is ambiguous which wombat parameter you want to vary, pick one!")
    }
  } else {
    if (args$wombat_vary == "gamma") {
      print("varygamma")
      wombat_label <- "vary gamma"
      varywombat <- wombat_quantiles(paste0("IS-RHO0-FIXEDA-FIXEDW-NOBIAS_", case), r_seq, alpha_true)
    } else if (args$wombat_vary == "a") {
      print("varya")
      wombat_label <- "vary a"
      varywombat <- wombat_quantiles(paste0("IS-RHO0-FIXEDGAMMA-VARYA-FIXEDW-NOBIAS_", case), r_seq, alpha_true)
    } else if (args$wombat_vary == "w") {
      print("varyw")
      wombat_label <- "vary w"
      varywombat <- wombat_quantiles(paste0("IS-RHO0-FIXEDGAMMA-FIXEDA-VARYW-NOBIAS_", case), r_seq, alpha_true)
    }
  }

  # qqplot
  p <- ggplot() +
        stat_qq(aes(sample = anal_quantile[!is.na(anal_quantile)] / 100, color="analytical"),
                distribution = stats::qunif, size = 0.1) +
        stat_qq(aes(sample = varywombat$quantile[!is.na(varywombat$quantile)] / 100, color=wombat_label),
                distribution = stats::qunif, size = 0.1) +
        geom_abline(aes(slope = 1, intercept = 0.0), linetype = 2) +
        theme(legend.title = element_blank())
  plot(p)
  ggsave(sprintf("%s/qqplot_%s_vary%s-ams.png", config$paths$pseudodata_dir, case, args$wombat_vary))

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
