library(dplyr)
library(ggplot2)
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

subtract_mean <- function(df) {
    df <- df %>% filter(year >= 2011, year <= 2020)
    mean_flux <- mean(df$flux)
    df <- df %>% mutate_at(vars(matches(regex("^flux"))), ~ .x - mean_flux)
    df
}

###############################################################################
# CODE
###############################################################################

main <- function() {
    # assemble literature values into a dataset
    # mine and Wells values are for 2011
    # Patra values for 2010s, could get this for 2011 but would have to download their data and try to extract
    # Thompson values for 1998-2016, could get this for 2011 but would have to download their data and try to extract
    df <- data.frame(Case = c("Patra 2022", "Wells 2018 a", "Wells 2018 b", "Wells 2018 c", "Thompson 2019 a", "Thompson 2019 b", "Thompson 2019 c"),
                    Global = c(17.2, 17.7, 17.5, 15.9, 17.4, 17, 16.6),
                    Land = c(14.3, 14.29, 14.05, 12.52, 10.2, 10.5, 13.2),
                    Ocean = c(2.91, 3.41, 3.45, 3.38, 7.2, 6.5, 3.4))

    # plot
    p <- plot_bar(df %>% arrange(desc(Global)))
    plot(p)
    ggsave(sprintf("%s/compare_literature_chart.png", config$paths$inversion_results))



    # add in my results
    my_fluxes <- readRDS(sprintf("%s/real-flux-aggregates-samples-IS-RHO0-FIXEDA-VARYW-NOBIAS-model-err-n2o_std_windowall.rds", config$paths$inversion_results))
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





    # compare IAV
    thompson_1 <- tibble(
                    year = 1998:2014,
                    land_flux = c(10.094, 9.29, 9.454, 10.112, 9.601,
                            9.601, 9.911, 9.491, 10.057, 9.71,
                            9.436, 9.418, 12.178, 10.606, 10.496,
                            11.465, 11.227),
                    ocean_flux = c(3.269, 3.269, 3.261, 3.344, 3.224,
                                3.224, 3.284, 3.193, 3.276, 3.171,
                                3.141, 3.028, 3.337, 3.209, 3.171,
                                3.269, 3.171))

    thompson_2 <- tibble(
                    year = 1998:2016,
                    land_flux = c(10.332, 9.674, 8.979, 10.35, 9.728,
                                10.131, 10.24, 8.705, 10.88, 9.491,
                                10.624, 9.326, 11.94, 10.185, 10.77,
                                13.292, 10.77, 11.794, 11.483),
                    ocean_flux = c(2.945, 2.96, 2.862, 2.952, 2.839,
                                2.915, 2.937, 2.892, 2.982, 2.869,
                                2.907, 2.764, 3.035, 2.93, 2.907,
                                3.148, 2.839, 2.839, 2.99))

    thompson_3 <- tibble(
                    year = 2000:2016,
                    land_flux = c(11.812, 12.708, 12.031, 12.616, 12.251,
                            11.775, 13.11, 12.36, 13.292, 12.232,
                            14.48, 12.159, 13.475, 14.883, 13.731,
                            13.786, 15.796),
                    ocean_flux = c(1.603, 1.603, 1.399, 1.392, 1.528,
                                1.618, 1.55, 1.49, 1.626, 1.58,
                                1.754, 1.663, 1.626, 1.648, 1.656,
                                1.693, 1.573))

    patra <- tibble(
            year = 1997:2019,
            land_flux = c(11.827, 12.988, 13.383, 12.506, 13.099,
                        12.79, 12.765, 12.951, 12.506, 13.568,
                        13.099, 13.432, 12.728, 14.679, 13.173,
                        13.852, 14.852, 14.074, 14.272, 14.444,
                        13.988, 15.123, 14.481),
            ocean_flux = c(2.862, 2.782, 2.968, 2.702, 2.766,
                            2.585, 2.723, 2.755, 2.782, 2.803,
                            2.489, 2.995, 2.803, 3.112, 2.819,
                            2.819, 2.963, 2.872, 2.926, 2.638,
                            2.83, 3.149, 2.856))

    my_fluxes_iav <- my_fluxes %>%
                    filter(estimate == "Posterior", name == "Global", month_start >= as.Date("2011-01-01")) %>%
                    mutate(year = as.integer(format(month_start, format = "%Y"))) %>%
                    group_by(year) %>%
                    summarise(flux = sum(flux_mean),
                              flux_lower = quantile(colSums(flux_samples), probs = 0.025, na.rm = TRUE),
                              flux_upper = quantile(colSums(flux_samples), probs = 0.975, na.rm = TRUE))

    thompson_1 <- thompson_1 %>% mutate(flux = land_flux + ocean_flux) %>% select(year, flux)
    thompson_2 <- thompson_2 %>% mutate(flux = land_flux + ocean_flux) %>% select(year, flux)
    thompson_3 <- thompson_3 %>% mutate(flux = land_flux + ocean_flux) %>% select(year, flux)
    patra <- patra %>% mutate(flux = land_flux + ocean_flux) %>% select(year, flux)


    thompson_1 <- subtract_mean(thompson_1)
    thompson_2 <- subtract_mean(thompson_2)
    thompson_3 <- subtract_mean(thompson_3)
    patra <- subtract_mean(patra)
    my_fluxes_iav <- subtract_mean(my_fluxes_iav)

    full_tibble <- full_join(thompson_1, thompson_2, by = "year") %>%
                    full_join(thompson_3, by = "year") %>%
                    full_join(patra, by = "year") %>%
                    full_join(my_fluxes_iav  %>% select(year, flux), by = "year")
    names(full_tibble) <- c("year", "Thompson 2019 INV1", "Thompson 2019 INV2", "Thompson 2019 INV3", "Patra 2022", "This work")
    full_tibble_melted <- melt(full_tibble, id.vars = "year")

    p <- ggplot() +
        geom_ribbon(data = my_fluxes_iav, aes(x = year, ymin=flux_lower, ymax=flux_upper), alpha = 0.25) +
        geom_line(data = full_tibble_melted, aes(x = year, y = value, color = variable)) +
        ylab(expression(N[2] * "O Flux / TgN " * yr^-1)) +
        scale_x_continuous(breaks = seq(2011, 2020, 2), expand = c(0, 0)) +
        xlab("") +
        scale_color_discrete(name = "") +
        theme(text = element_text(size = 20))

    plot(p)
    ggsave(sprintf("%s/compare_mine_and_literature_iav.pdf", config$paths$inversion_results))
}

if (getOption("run.main", default = TRUE)) {
   main()
}
