library(car)
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
n_alpha <- n_regions * n_months

start_sample <- as.numeric(config$inversion_constants$burn_in) + 1

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

quantile_match <- function(nsample, nalpha, alpha_samples) {
  post_quantile <- quantile(alpha_samples[[nsample]][, nalpha],
                            probs = seq(0, 1, length.out = 1001),
                            na.rm = TRUE)

  post_true <- alpha_true[nsample, nalpha]

  mask <- post_true < post_quantile

  as.numeric(gsub("([.0-9]+).*$", "\\1", names(post_quantile[mask][1])))
}

wombat_quantiles <- function(case) {
  alpha_wombat <- lapply(1:n_samples, function(i) {
                         mcmc_alpha(sprintf("%s/real-mcmc-samples-%s_%04d.rds",
                         config$paths$pseudodata_dir,
                         case,
                         i))
})

  wombat_quantile <- mapply(quantile_match,
                            rep(1:n_samples, times = length(r_seq)),
                            rep(r_seq, each = n_samples),
                            MoreArgs = list(alpha_samples = alpha_wombat))
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

r <- 2 + 1
r_seq <- 1:n_alpha#seq(r, n_alpha, n_regions)[n_months]

case <- 'm1_ac0_ar1'

# read in true alphas
alpha_true <- readRDS(sprintf("%s/alpha_samples_%s.rds",
                      config$paths$pseudodata_dir, case))

# # read in analytical samples
# alpha_anal <- lapply(1:n_samples, function(i) {
#                      readRDS(sprintf("%s/real_analytical_samples_%s_%04d.rds",
#                      config$paths$pseudodata_dir, case, i))})

# anal_quantile <- mapply(quantile_match,
#                         rep(1:n_samples, times = length(r_seq)),
#                         rep(r_seq, each = n_samples),
#                         MoreArgs = list(alpha_samples = alpha_anal))
# dim(anal_quantile) <- c(n_samples, length(r_seq))

# read in WOMBAT alphas
vary <- wombat_quantiles(paste0(config$inversion_constants$land_ocean_equal_model_case, "_", case))

# read in WOMBAT alphas with fixeda
varya <- wombat_quantiles(paste0("IS-RHO0-FIXEDGAMMA-VARYA-FIXEDW-NOBIAS_", case))

# read in WOMBAT alphas
bog <- wombat_quantiles(paste0(config$inversion_constants$bogstandard_model_case, "_", case))

varygamma <- wombat_quantiles(paste0(config$inversion_constants$fix_alpha_distrib_model_case, "_", case))

varyw <- wombat_quantiles(paste0("IS-RHO0-FIXEDGAMMA-FIXEDA-VARYW-NOBIAS_", case))

# qqplot
#colors <- c("analytical" = "blue", "vary" = "green", "varya" = "orange", "bog" = "red")
p <- ggplot() +
      #  stat_qq(aes(sample = anal_quantile[!is.na(anal_quantile)] / 100, color="analytical"),
      #          distribution = stats::qunif, size = 0.1) +
       stat_qq(aes(sample = vary$quantile[!is.na(vary$quantile)] / 100, color="vary"),
               distribution = stats::qunif, size = 0.1, alpha = 0.5) +
       stat_qq(aes(sample = varya$quantile[!is.na(varya$quantile)] / 100, color="varya"),
               distribution = stats::qunif, size = 0.1, alpha = 0.5) +
       stat_qq(aes(sample = bog$quantile[!is.na(bog$quantile)] / 100, color="bog"),
               distribution = stats::qunif, size = 0.1, alpha = 0.5) +
       stat_qq(aes(sample = varygamma$quantile[!is.na(varygamma$quantile)] / 100, color="varygamma"),
               distribution = stats::qunif, size = 0.1, alpha = 0.5) +
       stat_qq(aes(sample = varyw$quantile[!is.na(varyw$quantile)] / 100, color="varyw"),
               distribution = stats::qunif, size = 0.1, alpha = 0.5) +
       geom_abline(aes(slope = 1, intercept = 0.0), linetype = 2) #+
       #scale_color_manual(values = colors)
plot(p)
ggsave(sprintf("%s/qqplot_%s.pdf", config$paths$pseudodata_dir, case))

# alpha_anal_mean <- sapply(alpha_anal, colMeans)
alpha_wombat_vary_mean <- sapply(vary$alpha_samples, colMeans)
alpha_wombat_varya_mean <- sapply(varya$alpha_samples, colMeans)
alpha_wombat_bog_mean <- sapply(bog$alpha_samples, colMeans)
alpha_wombat_varygamma_mean <- sapply(varygamma$alpha_samples, colMeans)
alpha_wombat_varyw_mean <- sapply(varyw$alpha_samples, colMeans)

#plot(t(alpha_true), alpha_wombat_vary_mean)
#plot(t(alpha_true), alpha_wombat_bog_mean)

# print("anal:")
# print(cor(as.vector(t(alpha_true)), as.vector(alpha_anal_mean), use = "complete.obs"))
# print(rmse(as.vector(t(alpha_true)), as.vector(alpha_anal_mean)))
print("vary:")
#print(cor(as.vector(t(alpha_true)), as.vector(alpha_wombat_vary_mean), use = "complete.obs"))
print(rmse(as.vector(t(alpha_true)), as.vector(alpha_wombat_vary_mean)))
print(mae(as.vector(t(alpha_true)), as.vector(alpha_wombat_vary_mean)))
print("varya:")
#print(cor(as.vector(t(alpha_true)), as.vector(alpha_wombat_varya_mean), use = "complete.obs"))
print(rmse(as.vector(t(alpha_true)), as.vector(alpha_wombat_varya_mean)))
print(mae(as.vector(t(alpha_true)), as.vector(alpha_wombat_varya_mean)))
print("bog:")
#print(cor(as.vector(t(alpha_true)), as.vector(alpha_wombat_bog_mean), use = "complete.obs"))
print(rmse(as.vector(t(alpha_true)), as.vector(alpha_wombat_bog_mean)))
print(mae(as.vector(t(alpha_true)), as.vector(alpha_wombat_bog_mean)))
print("varygamma:")
#print(cor(as.vector(t(alpha_true)), as.vector(alpha_wombat_varygamma_mean), use = "complete.obs"))
print(rmse(as.vector(t(alpha_true)), as.vector(alpha_wombat_varygamma_mean)))
print(mae(as.vector(t(alpha_true)), as.vector(alpha_wombat_varygamma_mean)))
print("varyw:")
#print(cor(as.vector(t(alpha_true)), as.vector(alpha_wombat_varyw_mean), use = "complete.obs"))
print(rmse(as.vector(t(alpha_true)), as.vector(alpha_wombat_varyw_mean)))
print(mae(as.vector(t(alpha_true)), as.vector(alpha_wombat_varyw_mean)))
