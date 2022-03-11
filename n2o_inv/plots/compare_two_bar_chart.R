library(ggplot2)
library(gtable)
library(here)


options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/results/plot_annual_ems.R"), chdir = TRUE)

config <- read.ini(paste0(here(), "/config.ini"))

###############################################################################
# FUNCTIONS
###############################################################################

compare_two <- function(case1, case2, string_pattern, title, labels) {
    case1_annual_flux_samples <- get_annual_ems(case1) %>%
                                   mutate(case = case1) %>%
                                   filter(year == 2011, estimate == "Posterior")
    case2_annual_flux_samples <- get_annual_ems(case2) %>%
                                   mutate(case = case2) %>%
                                   filter(year == 2011, estimate == "Posterior")

    # select just single region fluxes
    annual_flux_samples <- bind_rows(case1_annual_flux_samples %>% filter(grepl(string_pattern, name)),
                                     case2_annual_flux_samples %>% filter(grepl(string_pattern, name)))

    p <- ggplot(annual_flux_samples,
                aes(fill = case, y = flux_mean, ymin = flux_lower, ymax = flux_upper, x = name)) +
    geom_bar(position = "dodge", stat = "identity") +
    geom_errorbar(position = "dodge", alpha = 0.5) +
    geom_vline(xintercept = 12.5) +
    ylab(expression(N[2] * "O Flux / TgN " * yr^-1)) +
    xlab(NULL) +
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

base_case <- "IS-RHO0-FIXEDA-VARYW-NOBIAS-model-err-n2o_std"

# compare global scale rescaling prior
# land rescaling
p_land <- compare_two(paste0(base_case, "-rescaled-halfland_window01"),
                      paste0(base_case, "-rescaled-doubleland_window01"),
                      "^Global",
                      NULL,
                      c("half prior", "double prior"))

p_land <- p_land + theme(legend.position = "bottom")

p_land_neat <- p_land +
               coord_flip() +
               ggtitle("a. rescale land prior") +
               scale_x_discrete(labels = c("Global total", "Global land", "Global ocean")) +
               theme(axis.title.x = element_blank(),
                     axis.text.x  = element_blank(),
                     plot.title.position = "plot",
                     text = element_text(size = 18),
                     legend.position = "none")

# ocean rescaling
p_ocean <- compare_two(paste0(base_case, "-rescaled-halfocean_window01"),
                       paste0(base_case, "-rescaled-doubleocean_window01"),
                       "^Global",
                       NULL,
                       c("half", "double"))

p_ocean_neat <- p_ocean +
                coord_flip() +
                ggtitle("b. rescale ocean prior") +
                scale_x_discrete(labels = c("Global total", "Global land", "Global ocean")) +
                theme(axis.title.x = element_blank(),
                      axis.text.x = element_text(angle = 0, hjust = 0.5),
                      plot.title.position = "plot",
                      text = element_text(size = 18),
                      legend.position = "none")

# plot both together
layout <- c(1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 4)
dim(layout) <- c(12, 1)

legend <- gtable_filter(ggplotGrob(p_land), "guide-box")
p <- grid.arrange(p_land_neat,
                  p_ocean_neat,
                  textGrob(expression(N[2] * "O Flux / TgN " * yr^-1), gp = gpar(fontsize = 18)),
                  legend,
                  ncol = 1,
                  layout_matrix = layout)
ggsave(sprintf("%s/compare_two_bar_chart_%s_rescaleprior.pdf", config$paths$inversion_results, base_case),
       plot = p)
