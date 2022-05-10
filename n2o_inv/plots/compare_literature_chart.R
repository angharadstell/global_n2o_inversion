library(dplyr)
library(ggplot2)
library(grid)
library(gridExtra)
library(gtable)
library(here)
library(ini)
library(reshape2)
library(stringr)

config <- read.ini(paste0(here(), "/config.ini"))

###############################################################################
# FUNCTIONS
###############################################################################

# plot a bar chart that compares different estimates
plot_bar <- function(df) {
    melted_df <- melt(df, id.vars = "Case")
    # Can order bars by one of the sets of values, not sure it really helps
    #position <- melted_df %>% filter(variable == "Ocean") %>% mutate(position = rank(value))
    #melted_df <- melted_df %>% mutate(position = rep(position$position, 3))

    p <- ggplot(melted_df, aes(fill = Case, y = value, x = variable)) +#, group = position)) +
    geom_bar(position = "dodge", stat = "identity") +
    ylab(expression(N[2] * "O Flux / TgN " * yr^-1)) +
    scale_y_continuous(limits = c(0, NA), expand = c(0, 0)) +
    xlab("") + scale_fill_discrete(name = "") + theme(text = element_text(size = 20))

    p
}

# get my flux aggregates to right format for inter annual variation plot
process_fluxes_iav <- function(my_word, fluxes) {
    fluxes_iav <- fluxes %>%
                  filter(estimate == "Posterior", name == my_word, month_start >= as.Date("2011-01-01")) %>%
                  mutate(year = as.integer(format(month_start, format = "%Y"))) %>%
                  group_by(year) %>%
                  summarise(flux = sum(flux_mean),
                            flux_lower = quantile(colSums(flux_samples), probs = 0.025, na.rm = TRUE),
                            flux_upper = quantile(colSums(flux_samples), probs = 0.975, na.rm = TRUE))

    fluxes_iav
}

# plot a time series of fluxes from different inversions, for either global land, global ocean, or global total
plot_iav <- function(my_word, other_word, my_fluxes, patra, thompson_1, thompson_2, thompson_3) {
    # my hierarchical results
    my_fluxes_iav <- process_fluxes_iav(my_word, my_fluxes)

    # my analytical results
    ana_fluxes <- readRDS(sprintf("%s/real-flux-aggregates-samples-analytical-IS-FIXEDGAMMA-NOBIAS-model-err-n2o_std.rds", config$paths$inversion_results))
    ana_fluxes_iav <- process_fluxes_iav(my_word, ana_fluxes)

    # select and rename variables
    patra <- patra %>% select(year, other_word) %>% rename(flux = other_word)
    thompson_1 <- thompson_1 %>% select(year, other_word) %>% rename(flux = other_word)
    thompson_2 <- thompson_2 %>% select(year, other_word) %>% rename(flux = other_word)
    thompson_3 <- thompson_3 %>% select(year, other_word) %>% rename(flux = other_word)

    # join results together
    full_tibble <-  full_join(my_fluxes_iav %>% dplyr::select(year, flux), ana_fluxes_iav %>% dplyr::select(year, flux), by = "year") %>%
                    full_join(patra, by = "year") %>%
                    full_join(thompson_1, by = "year") %>%
                    full_join(thompson_2, by = "year") %>%
                    full_join(thompson_3, by = "year")
    names(full_tibble) <- c("year", "This work (hierarchical)", "This work (analytical)", "Patra 2022", "Thompson 2019 INV1", "Thompson 2019 INV2", "Thompson 2019 INV3")
    full_tibble_melted <- melt(full_tibble, id.vars = "year")

    # only include years in my inversion
    full_tibble_melted <- full_tibble_melted %>% filter(year >= 2011, year <= 2020)

    # colour blind friendly colours
    cbbPalette <- c("#000000", "#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7")

    # plotting
    p <- ggplot() +
        geom_ribbon(data = my_fluxes_iav, aes(x = year, ymin = flux_lower, ymax = flux_upper), alpha = 0.25) +
        geom_line(data = full_tibble_melted, aes(x = year, y = value, color = variable)) +
        ylab(expression(N[2] * "O Flux / TgN " * yr^-1)) +
        scale_x_continuous(breaks = seq(2011, 2020, 2), expand = c(0, 0)) +
        xlab("") +
        scale_color_manual(values = cbbPalette,
                           name = "") +
        theme(text = element_text(size = 20))

    p
}

###############################################################################
# CODE
###############################################################################

main <- function() {
    ###############################################################################
    # Read in fluxes
    ###############################################################################

    filename <- sprintf("%s/others_results/annual_global_total_thompson_INV1.csv", config$paths$data_dir)
    thompson_1 <- tibble(read.csv(filename))

    filename <- sprintf("%s/others_results/annual_global_total_thompson_INV2.csv", config$paths$data_dir)
    thompson_2 <- tibble(read.csv(filename))

    filename <- sprintf("%s/others_results/annual_global_total_thompson_INV3.csv", config$paths$data_dir)
    thompson_3 <- tibble(read.csv(filename))

    filename <- sprintf("%s/others_results/annual_global_total_patra.csv", config$paths$data_dir)
    patra <- tibble(read.csv(filename))

    my_fluxes <- readRDS(sprintf("%s/real-flux-aggregates-samples-IS-RHO0-FIXEDA-VARYW-NOBIAS-model-err-n2o_std_windowall.rds", config$paths$inversion_results))

    ###############################################################################
    # Plot literature values for 2011
    ###############################################################################
    # compare literature dataset for 2011
    thompson_1_2011 <- thompson_1 %>% filter(year == 2011)
    thompson_2_2011 <- thompson_2 %>% filter(year == 2011)
    thompson_3_2011 <- thompson_3 %>% filter(year == 2011)
    patra_2011 <- patra %>% filter(year == 2011)

    df <- data.frame(Case = c("Patra 2022", "Wells 2018 a", "Wells 2018 b", "Wells 2018 c", "Thompson 2019 a", "Thompson 2019 b", "Thompson 2019 c"),
                    Global = c(patra_2011$total, 17.7, 17.5, 15.9, thompson_1_2011$total, thompson_2_2011$total, thompson_3_2011$total),
                    Land = c(patra_2011$land, 14.29, 14.05, 12.52, thompson_1_2011$land, thompson_2_2011$land, thompson_3_2011$land),
                    Ocean = c(patra_2011$ocean, 3.41, 3.45, 3.38, thompson_1_2011$ocean, thompson_2_2011$ocean, thompson_3_2011$ocean))

    # plot
    p <- plot_bar(df)
    plot(p)
    ggsave(sprintf("%s/compare_literature_chart.png", config$paths$inversion_results))



    # add in my results
    my_fluxes_2011 <- my_fluxes %>%
                        filter(estimate == "Posterior", month_start >= as.Date("2011-01-01"), month_start <= as.Date("2011-12-01")) %>%
                        dplyr::select(name, estimate, month_start, flux_mean) %>%
                        group_by(name) %>%
                        summarise(flux_mean = sum(flux_mean))
    my_df <- data.frame(Case = c("hierarchical"),
                        Global = c((my_fluxes_2011 %>% filter(name == "Global"))$flux_mean),
                        Land = c((my_fluxes_2011 %>% filter(name == "Global land"))$flux_mean),
                        Ocean = c((my_fluxes_2011 %>% filter(name == "Global oceans"))$flux_mean))
    bound_df <- rbind(df, my_df)

    # plot
    p <- plot_bar(bound_df)
    plot(p)
    ggsave(sprintf("%s/compare_mine_and_literature_chart.png", config$paths$inversion_results))



    ###############################################################################
    # Plot comparing IAV
    ###############################################################################

    # plot each IAV plot
    p_land <- plot_iav("Global land", "land", my_fluxes, patra, thompson_1, thompson_2, thompson_3)
    p_ocean <- plot_iav("Global oceans", "ocean", my_fluxes, patra, thompson_1, thompson_2, thompson_3)
    p_total <- plot_iav("Global", "total", my_fluxes, patra, thompson_1, thompson_2, thompson_3)


    # plot together
    p_land <- p_land + theme(legend.position = "bottom")
    legend <- gtable_filter(ggplotGrob(p_land), "guide-box")

    p_land_neat <- p_land +
                     ggtitle("a. global land emissions") +
                     theme(legend.position = "none",
                           plot.title.position = "plot",
                           axis.title.y = element_blank())

    p_ocean_neat <- p_ocean +
                     ggtitle("b. global ocean emissions") +
                     theme(legend.position = "none",
                           plot.title.position = "plot",
                           axis.title.y = element_blank())

    p_total_neat <- p_total +
                      ggtitle("c. global total emissions") +
                      theme(legend.position = "none",
                            plot.title.position = "plot",
                            axis.title.y = element_blank())

    layout <- c(1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4)
    dim(layout) <- c(13, 1)

    p <- grid.arrange(p_land_neat,
                      p_ocean_neat,
                      p_total_neat,
                      legend,
                      left = textGrob(expression(N[2] * "O Flux / TgN " * yr^-1), rot = 90, hjust = -0.01, gp = gpar(fontsize = 18)),
                      ncol = 1,
                      layout_matrix = layout)
    plot(p)
    ggsave(sprintf("%s/compare_mine_and_literature_iav_all.pdf", config$paths$inversion_results), 
           p, height = 15, width = 10)

}

if (getOption("run.main", default = TRUE)) {
   main()
}
