# This script plots a comparison of the observations, the full time series
# analytical inversion posterior mole fraction, the prior control mole
# fraction, and the next rescaled moving window control mole fraction
library(dplyr)
library(ggplot2)
library(here)
library(ini)
library(reshape2)

options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/pseudodata/pseudodata.R"), chdir = TRUE)
source(paste0(here(), "/n2o_inv/moving_window/functions.R"))

config <- read.ini(paste0(here(), "/config.ini"))

# choose the case and which window to plot
test_case <- "IS-RHO0-FIXEDA-VARYW-NOBIAS-model-err-arbitrary"
test_window <- 2

# read in proper inversion intermediates
observations <- fst::read_fst(sprintf("%s/observations.fst", config$path$geos_inte))
control_mf <- fst::read_fst(sprintf("%s/control-mole-fraction.fst", config$path$geos_inte))
perturbations <- fst::read_fst(sprintf("%s/perturbations.fst", config$paths$geos_inte))
sensitivities <- fst::read_fst(sprintf("%s/sensitivities.fst", config$paths$geos_inte))

if (test_window == 1) {
    # expect this to be the same as the prior
    next_control_mf <- fst::read_fst(sprintf("%s/control-mole-fraction-window01.fst", config$path$geos_inte))
} else {
    # expect this to look like the prior but with starting point shifted to near the observations / full inversion results
    next_control_mf <- fst::read_fst(sprintf("%s/control-mole-fraction-%s-window%02d-mcmc-rescaled.fst",
                                            config$path$geos_inte,
                                            test_case,
                                            test_window))
}

# do whole series analytical inversion for comparison
print("Doing full series inversion...")
full_alphas <- do_analytical_inversion(observations, control_mf, perturbations, sensitivities)
full_inv_mf <- alpha_to_obs(t(full_alphas$mean), 0,
                            control_mf, perturbations, sensitivities)

# plot a comparison of the observations, the full time series analytical
# inversion posterior mole fraction, the prior control mole fraction, and
# the next rescaled moving window control mole fraction
# have to cut the data to just the first site (ALT) for len_window years so
# that it can be compared to the shorter window inversion time frame
len_window <- as.numeric(config$moving_window$n_years)
start_index <- ((12 * (test_window - 1)) + 1)
end_index <- ((test_window + (len_window - 1)) * 12)
# do the plotting
df <- data.frame(time = observations$time[start_index:end_index],
                 rescaled = (next_control_mf %>% arrange(observation_id))$co2[1:(len_window * 12)],
                 prior = (control_mf %>% arrange(observation_id))$co2[start_index:end_index],
                 full_inv = full_inv_mf[start_index:end_index, 1],
                 observed = observations$co2[start_index:end_index])
melted_df <- melt(df, id.var = "time")
p <- ggplot(melted_df, aes(x = time, y = value, color = variable)) + geom_line()
plot(p)
