library(dplyr)
library(fst)
library(ggplot2)
library(grid)
library(gridExtra)
library(gtable)
library(here)
library(ini)

###############################################################################
# FUNCTIONS
###############################################################################

area_weighted_monthly_mean <- function(obs) {
  obs %>%
  group_by(time) %>%
  summarise(sum_co2_aw = sum(co2_aw), sum_w = sum(abs_cos_lat)) %>%
  mutate(mean_co2_aw = sum_co2_aw / sum_w) %>%
  select(time, mean_co2_aw) %>%
  mutate(growth = mean_co2_aw - lag(mean_co2_aw, 12))
}

process_obs <- function(obs) {
    obs %>%
        select(time, latitude, co2) %>%
        mutate(abs_cos_lat = abs(cos(latitude * (pi / 180))),
                co2_aw = abs_cos_lat * co2)
}

plot_growth_rate <- function(obs, title) {
    # select required fields and add cosine lat weighting
    obs <- process_obs(obs)

    # split by latitude
    obs_nh_et <- obs %>% filter(latitude > 30)
    obs_nh_tr <- obs %>% filter(latitude < 30, latitude > 0)
    obs_sh_tr <- obs %>% filter(latitude > -30, latitude < 0)
    obs_sh_et <- obs %>% filter(latitude < -30)


    # area weight, monthly mean
    obs_nh_et_aw_mm <- area_weighted_monthly_mean(obs_nh_et)
    obs_nh_tr_aw_mm <- area_weighted_monthly_mean(obs_nh_tr)
    obs_sh_tr_aw_mm <- area_weighted_monthly_mean(obs_sh_tr)
    obs_sh_et_aw_mm <- area_weighted_monthly_mean(obs_sh_et)

    obs_glob_aw_mm <- area_weighted_monthly_mean(obs)


    colors <- c("30N - 90N" = "blue", "00N - 30N" = "green",
                "30S - 00S" = "purple", "90S - 30S" = "red",
                "Global" = "black")

    p <- ggplot(NULL, aes(time, growth)) +
    geom_smooth(data = obs_nh_et_aw_mm, aes(color = "30N - 90N"), se = FALSE, span = 0.3) +
    geom_smooth(data = obs_nh_tr_aw_mm, aes(color = "00N - 30N"), se = FALSE, span = 0.3) +
    geom_smooth(data = obs_sh_et_aw_mm, aes(color = "90S - 30S"), se = FALSE, span = 0.3) +
    geom_smooth(data = obs_glob_aw_mm, aes(color = "Global"), se = FALSE, span = 0.3, size = 2) +
    scale_color_manual(values = colors) +
    ggtitle(title) + ylab(expression(paste("Growth rate / ppb ", yr^{-1}))) +
    xlab("Year") + guides(color = guide_legend(title = "Region")) + theme(text = element_text(size = 20))

    # if restricted sites can have no sites in this band
    if (dim(obs_sh_tr_aw_mm)[1] > 0) {
      p <- p + geom_smooth(data = obs_sh_tr_aw_mm, aes(color = "30S - 00S"), se = FALSE, span = 0.3)
    }

    p
}

###############################################################################
# EXECUTION
###############################################################################

main <- function() {
  # read in config
  config <- read.ini(paste0(here(), "/config.ini"))

  # read in observations
  obs <- fst::read_fst(sprintf("%s/observations.fst", config$paths$geos_inte))


  # read in control mf
  control_mf <- fst::read_fst(sprintf("%s/control-mole-fraction.fst", config$paths$geos_inte))

  # read in constant met control mf
  control_mf_constant <- fst::read_fst(sprintf("%s/control-mole-fraction-constant-met.fst", config$paths$geos_inte))
  control_mf_constant_pre <- control_mf %>% filter(time < "2016-01-31")
  control_mf_constant <- bind_rows(control_mf_constant_pre, control_mf_constant)


  # sort out posterior
  case <- "IS-RHO0-FIXEDA-VARYW-NOBIAS-model-err-n2o_std_windowall"
  post_mf <- readRDS(sprintf("%s/obs_matched_samples-%s.rds", config$paths$inversion_results, case))
  post_mf <- post_mf %>% mutate(latitude = obs$latitude) %>% rename("co2" = "Z2_hat", "obs" = "co2")


  # save just obs plot for intro
  plot_growth_rate(obs, NULL)
  ggsave(paste0(config$paths$obspack_dir, "/obs_growth_rate.pdf"))


  # create panel plot of all growth rates
  obs_growth <- plot_growth_rate(obs, "a. Observations")
  prior_growth <- plot_growth_rate(control_mf, "b. Prior")
  post_growth <- plot_growth_rate(post_mf, "c. Posterior")
  prior_constant_growth <- plot_growth_rate(control_mf_constant, "d. Prior constant met after 2015")


  layout <- rbind(c(1, 1, 1, 5), c(2, 2, 2, 5), c(3, 3, 3, 5), c(4, 4, 4, 5))
  legend <- gtable_filter(ggplotGrob(obs_growth), "guide-box")
  p <- grid.arrange(obs_growth + theme(axis.title.y = element_blank(), legend.position = "none"),
                    prior_growth + theme(axis.title.y = element_blank(), legend.position = "none"),
                    post_growth + theme(axis.title.y = element_blank(), legend.position = "none"),
                    prior_constant_growth + theme(axis.title.y = element_blank(), legend.position = "none"), ncol = 1,
                    legend,
                    left = textGrob(expression(paste("Growth rate / ppb ", yr^{-1})), rot = 90, gp = gpar(fontsize = 20)),
                    layout_matrix = layout)
  ggsave(paste0(config$paths$obspack_dir, "/all_growth_rate.pdf"), p)
}

if (getOption("run.main", default = TRUE)) {
   main()
}
