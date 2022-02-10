library(ggplot2)
library(here)
library(ini)
library(reshape2)

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

###############################################################################
# CODE
###############################################################################

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
#ggsave(sprintf("%s/compare_literature_chart.png", config$paths$inversion_results))



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
#ggsave(sprintf("%s/compare_mine_and_literature_chart.png", config$paths$inversion_results))
