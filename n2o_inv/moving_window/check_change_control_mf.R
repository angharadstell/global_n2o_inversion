library(dplyr)
library(ggplot2)
library(here)
library(ini)
library(reshape2)

options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/pseudodata/pseudodata.R"), chdir = TRUE)
source(paste0(here(), "/n2o_inv/moving_window/functions.R"))

config <- read.ini(paste0(here(), "/config.ini"))


test_window <- 2

# read in proper inversion intermediates
observations <- fst::read_fst(sprintf("%s/observations.fst", config$path$geos_inte))
control_mf <- fst::read_fst(sprintf("%s/control-mole-fraction.fst", config$path$geos_inte))

next_control_mf <- fst::read_fst(sprintf("%s/control-mole-fraction-window%02d-rescaled.fst", 
                                         config$path$geos_inte, test_window))



# full inv mf
# do whole series analytical inversion
# read in intermediates
perturbations <- fst::read_fst(sprintf("%s/perturbations.fst", config$paths$geos_inte))
sensitivities <- fst::read_fst(sprintf("%s/sensitivities.fst", config$paths$geos_inte))

# do analytical inversion
print("Doing full series inversion...")
full_alphas <- do_analytical_inversion(observations, control_mf, perturbations, sensitivities)
full_inv_mf <- alpha_to_obs(t(full_alphas$mean), 0,
                            control_mf, perturbations, sensitivities)


len_window <- 10

start_index <- ((12*(test_window-1))+1)
end_index <- ((test_window+(len_window-1))*12)

print(start_index)
print(end_index)

df <- data.frame(time = observations$time[start_index:end_index],
                 rescaled = (next_control_mf %>% arrange(observation_id))$co2[1:(len_window*12)],
                 prior = (control_mf %>% arrange(observation_id))$co2[start_index:end_index],
                 full_inv = full_inv_mf[start_index:end_index, 1],
                 observed = observations$co2[start_index:end_index])

melted_df <- melt(df, id.var="time")

p <- ggplot(melted_df, aes(x=time, y=value, color=variable)) + geom_line()

plot(p)
