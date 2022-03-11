ESTIMATE_COLOURS <- c(
  'Prior (mean)' = get_colour('wombat_prior'),
  'Posterior (mean, 95% cred. int.)' = get_colour('wombat_lg')
)

ESTIMATE_LINETYPES = c(
  'Prior (mean)' = 'solid',
  'Posterior (mean, 95% cred. int.)' = 'solid'
)

log_info('Loading flux samples')
flux_samples <- flux_samples %>%
  mutate(
    year = year(month_start),
    estimate = factor(ifelse(
      is_prior,
      sprintf('%s (mean)', observation_group),
      sprintf('%s (mean, 95%% cred. int.)', observation_group)
    ), levels = names(ESTIMATE_COLOURS))
  ) %>%
  select(-observation_group)

log_info('Calculating')
annual_fluxes <- flux_samples %>%
  group_by(is_prior, estimate, name, year) %>%
  summarise(
    flux_mean = sum(flux_mean),
    flux_lower = quantile(colSums(flux_samples), probs = 0.025, na.rm = TRUE),
    flux_upper = quantile(colSums(flux_samples), probs = 0.975, na.rm = TRUE)
  ) %>%
  ungroup() %>%
  mutate(
    flux_lower = if_else(
      is_prior & !show_prior_uncertainty,
      as.double(NA),
      flux_lower
    ),
    flux_upper = if_else(
      is_prior & !show_prior_uncertainty,
      as.double(NA),
      flux_upper
    )
  ) %>%
  filter(
    year %in% head(substr(start_date, 1, 4):substr(end_date, 1, 4), -1)
  )

monthly_fluxes <- flux_samples %>%
  filter(
    month_start >= start_date,
    month_start < end_date
  ) %>%
  ungroup() %>%
  mutate(
    flux_lower = if_else(
      is_prior & !show_prior_uncertainty,
      as.double(NA),
      matrixStats::rowQuantiles(flux_samples, probs = 0.025)
    ),
    flux_upper = if_else(
      is_prior & !show_prior_uncertainty,
      as.double(NA),
      matrixStats::rowQuantiles(flux_samples, probs = 0.975)
    )
  ) %>%
  select(estimate, name, month_start, flux_mean, flux_lower, flux_upper)

scale_colour_estimate <- scale_colour_manual(values = ESTIMATE_COLOURS)
scale_linetype_estimate <- scale_linetype_manual(values = ESTIMATE_LINETYPES)
scale_fill_estimate <- scale_fill_manual(values = ESTIMATE_COLOURS)

region_plots <- lapply(args$region, function(region_i) {
  annual_plot <- ggplot() +
    geom_crossbar(
      data = annual_fluxes %>%
        filter(name == region_i),
      mapping = aes(
        x = factor(year),
        y = flux_mean,
        ymin = flux_lower,
        ymax = flux_upper,
        colour = estimate,
        fill = estimate,
        linetype = estimate
      ),
      alpha = 0.4,
      position = 'dodge'
    ) +
    scale_colour_estimate +
    scale_linetype_estimate +
    scale_fill_estimate +
    guides(
      colour = guide_legend(ncol = legend_n_columns),
      fill = guide_legend(ncol = legend_n_columns),
      linetype = guide_legend(ncol = legend_n_columns)
    ) +
    scale_x_discrete(breaks = seq(substr(start_date, 1, 4), substr(end_date, 1, 4), 3)) +
    labs(x = 'Year', y = expression('Flux / TgN '*yr^-1), colour = NULL, fill = NULL, linetype = NULL)

  monthly_data <- monthly_fluxes %>%
    filter(name == region_i)

  monthly_plot <- ggplot() +
    geom_ribbon(
      data = monthly_data,
      mapping = aes(
        x = month_start,
        ymin = flux_lower,
        ymax = flux_upper,
        colour = estimate,
        fill = estimate,
        linetype = estimate
      ),
      size = 0.1,
      alpha = 0.15
    ) +
    geom_line(
      data = monthly_data,
      mapping = aes(
        x = month_start,
        y = flux_mean,
        colour = estimate,
        linetype = estimate
      )
    ) +
    scale_x_date(expand = c(0, 0)) +
    scale_colour_estimate +
    scale_linetype_estimate +
    scale_fill_estimate +
    labs(x = 'Month', y = expression('Flux / TgN '*mo^-1), colour = NULL, fill = NULL, linetype = NULL) +
    guides(fill = "none", colour = "none", linetype = "none")

  region_name <- region_i
  if (region_i %in% names(REGION_TITLE)) {
    region_name <- REGION_TITLE[region_i]
  }

  list(
    title = region_name,
    annual = annual_plot,
    monthly = monthly_plot
  )
})

stopifnot(length(region_plots) %in% c(3, 4))

output <- wrap_plots(
  do.call(c, lapply(1:length(region_plots), function(x) {
    list(
      wrap_elements(
        grid::textGrob(
          paste0(letters[[x]], ". ", region_plots[[x]]$title),
          x = unit(0, "lines"), y = unit(0, "lines"),
          just = "left", hjust = 0, vjust = 0,
          gp = grid::gpar(fontsize = 11, fontface = 'bold')
        ),
        clip = FALSE
      ),
      region_plots[[x]]$annual,
      region_plots[[x]]$monthly
    )
  })),
  guides = 'collect',
  design = if (length(region_plots) == 3) '
    AAA
    BCC
    DDD
    EFF
    GGG
    HII
  ' else if (length(region_plots) == 4) '
    AAA
    BCC
    DDD
    EFF
    GGG
    HII
    JJJ
    KLL
  ',
  heights = if (length(region_plots) == 3) {
    rep(c(0.1, 1), 3)
  } else if (length(region_plots) == 4) {
    rep(c(0.2, 1), 4)
  }
) &
  theme(legend.position = 'bottom')

if (small_y_axes) {
  output <- output &
    theme(
      axis.title.y = element_text(size = 8)
    )
}

log_info('Saving')
ggsave(
  args$output,
  plot = output,
  width = DISPLAY_SETTINGS$full_width,
  height = args$height,
  units = 'cm'
)

log_info('Done')
