library(ggplot2)
library(here)


options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/results/plot_annual_ems.R"), chdir = TRUE)

config <- read.ini(paste0(here(), "/config.ini"))

###############################################################################
# FUNCTIONS
###############################################################################

compare_two <- function(case1, case2, title, labels) {
    case1_annual_flux_samples <- get_annual_ems(case1) %>%
                                   mutate(case = case1) %>%
                                   filter(year == 2011, estimate == "Posterior")
    case2_annual_flux_samples <- get_annual_ems(case2) %>%
                                   mutate(case = case2) %>%
                                   filter(year == 2011, estimate == "Posterior")

    # select just single region fluxes
    annual_flux_samples <- bind_rows(case1_annual_flux_samples %>% filter(grepl("^T", name)),
                                     case2_annual_flux_samples %>% filter(grepl("^T", name)))

    p <- ggplot(annual_flux_samples,
                aes(fill = case, y = flux_mean, ymin = flux_lower, ymax = flux_upper, x = name)) +
    geom_bar(position = "dodge", stat = "identity") +
    geom_errorbar(position = "dodge", alpha = 0.5) +
    ylab(expression(N[2] * "O Flux / TgN " * yr^-1)) +
    xlab("Region") +
    scale_fill_discrete(name = title,
                        breaks = c(case1, case2),
                        labels = labels) +
    theme(text = element_text(size = 20),
          axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1))

    p
}

###############################################################################
# CODE
###############################################################################


# p <- compare_two("analytical-model-err", "analytical-sd1-model-err", "prior uncertainty", c("50%", "100%"))
# plot(p)
# ggsave(sprintf("%s/compare_two_bar_chart_varyw.png", config$paths$inversion_results))



# p <- compare_two("IS-RHO0-FIXEDGAMMA-VARYA-VARYW-NOBIAS_window01_model_err",
#                 "IS-RHO0-VARYA-VARYW-NOBIAS_window01_model_err",
#                 NULL,
#                 c("prescribed", "derived"))
# plot(p)
# ggsave(sprintf("%s/compare_two_bar_chart_fixedgamma.png", config$paths$inversion_results))



# p <- compare_two("IS-RHO0-VARYA-VARYW-NOBIAS_window01-rescaled-halfland",
#                 "IS-RHO0-VARYA-VARYW-NOBIAS_window01-rescaled-doubleland",
#                 NULL,
#                 c("half", "double"))
# plot(p)
# ggsave(sprintf("%s/compare_two_bar_chart_rescaleland.png", config$paths$inversion_results))

# p <- compare_two("IS-RHO0-VARYA-VARYW-NOBIAS_window01-rescaled-halfocean",
#                 "IS-RHO0-VARYA-VARYW-NOBIAS_window01-rescaled-doubleocean",
#                 NULL,
#                 c("half", "double"))
# plot(p)
# ggsave(sprintf("%s/compare_two_bar_chart_rescaleocean.png", config$paths$inversion_results))



p <- compare_two("IS-RHO0-VARYA-VARYW-NOBIAS-model-err-n2o_std_window01",
                 "IS-RHO0-FIXEDA-VARYW-NOBIAS-model-err-n2o_std_window01",
                 NULL,
                 c("varya", "fixeda"))
plot(p)
#ggsave(sprintf("%s/compare_two_bar_chart_fixeda.png", config$paths$inversion_results))
