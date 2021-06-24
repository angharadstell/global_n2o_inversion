library(fst)
library(ggplot2)
library(gridExtra)
library(ini)
library(reshape2)
library(stringr)

###############################################################################
# GLOBAL CONSTANTS
###############################################################################
fileloc <- (function() {
  attr(body(sys.function()), "srcfile")
})()$filename

config <- read.ini(paste0(gsub("n2o_inv/plots.*", "", fileloc), "config.ini"))

# locations of files
case <- config$inversion_constants$case
no_regions <- as.numeric(config$inversion_constants$no_regions)
inte_out_dir <- config$paths$geos_inte
geos_out_dir <- config$paths$geos_out

# contains functions: base_ch4_tracers and sum_ch4_tracers_perturbed
source(paste0(gsub("plots.*", "", fileloc), "intermediates/sensitivities.R"))

###############################################################################
# FUNCTIONS
###############################################################################

plot_perturbation_dt <- function(region, year, month) {
  # read in the base run tracers
  v_base <- base_ch4_tracers()

  # read in the perturbed run tracers
  combined_file <- sprintf("%s/%s%s/combined_mf.nc", geos_out_dir, year, month)
  print(combined_file)
  perturbed <- ncdf4::nc_open(combined_file)
  v <- function(...) ncdf4::ncvar_get(perturbed, ...)

  # Take the difference between the base run and perturbed run
  base_co2 <- v_base("CH4_sum")
  perturb_co2 <- sum_ch4_tracers_perturbed(v_base, v, region)
  dim(perturb_co2) <- dim(base_co2)
  diff <- perturb_co2 - base_co2

  # Each line is an observation location
  # Too many sites to plot a line for all, just plot ones with no missing data
  no_months <- dim(diff)[1]
  mask <- apply(!is.na(diff), 2, sum) > (no_months - 1)
  # Make into nice data frame
  masked_diff <- data.frame(time = 1:no_months, obs = diff[, mask])
  melted_diff <- reshape2::melt(masked_diff, id.vars = "time")

  # Plot
  # Other hemisphere obs have a slow rise, same hemisphere have a sudden spike
  p2 <- ggplot(melted_diff, aes(time, value, color = variable)) +
          geom_line() + theme(legend.position = "none") +
          ylim(c(0, 0.1)) +
          ggtitle(sprintf("Region %s", region)) +
          theme(plot.title = element_text(hjust = 0.5),
                axis.title.x = element_blank(),
                axis.title.y = element_blank())

  p2
}

###############################################################################
# EXECUTION
###############################################################################

# Do sensitivities make sense?
# read in sensitivities
sensitivities <- fst::read_fst(sprintf("%s/sensitivities.fst", inte_out_dir))

# each site and month has a separate model id
print(unique(sensitivities$model_id))
# largest model ids are latest in the timeseries, so just plot one of those as an example
control_mf <- fst::read_fst(paste0(inte_out_dir, "/control-mole-fraction.fst"))
chosen_obs <- max(sensitivities$model_id)
obs_sens <- sensitivities[sensitivities$model_id == chosen_obs, ]
# find out which site it is
chosen_obs_info <- control_mf[control_mf$model_id == chosen_obs, ]
substrings <- str_split(chosen_obs_info$observation_id, "~")

# plot a nice graph to visualise sensitivities
# seasonal cycle as sensitivity based on doublings: bigger response when more N2O ems
# additional exponential decay over time
p <- ggplot(obs_sens,
            aes(from_month_start, co2_sensitivity,
                group = factor(region), color = factor(region))) +
            geom_point() + geom_line() +
            ggtitle(substrings[[1]][3]) +
            theme(plot.title = element_text(hjust = 0.5))
plot(p)


# Can we cut off sensitivities?

# choose a date and region to examine
# start of time series makes most sense
start_date <- as.Date(config$dates$perturb_start)
year <- format(start_date, "%Y")
month <- format(start_date, "%m")

plots <- lapply(0:config$inversion_constants$no_regions,
                function(x) plot_perturbation_dt(x, year, month))


grid_plot <- gridExtra::arrangeGrob(grobs = plots, 
                                    left = "(perturbed - base) / ppb",
                                    bottom = "Months since perturbation")
                      
ggsave(paste0(inte_out_dir, "/mf_perturbation_dt.pdf"), grid_plot)