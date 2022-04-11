# This script updates the control mole fraction for the next window of the
# moving window inversion
library(argparser)
library(dplyr)
library(fst)
library(here)
library(ini)
library(lubridate)

options(run.main = FALSE)
source(paste0(here(), "/n2o_inv/pseudodata/pseudodata.R"), chdir = TRUE)
source(paste0(here(), "/n2o_inv/moving_window/functions.R"))

config <- read.ini(paste0(here(), "/config.ini"))

###############################################################################
# EXECUTION
###############################################################################

args <- arg_parser("", hide.opts = TRUE) %>%
add_argument("--window", "") %>%
add_argument("--case", "") %>%
add_argument("--method", "") %>%
parse_args()

window <- as.numeric(args$window)

# read in proper inversion intermediates
observations <- fst::read_fst(sprintf("%s/observations.fst", config$path$geos_inte))
perturbations <- fst::read_fst(sprintf("%s/perturbations.fst", config$path$geos_inte))
control_mf <- fst::read_fst(sprintf("%s/control-mole-fraction.fst", config$path$geos_inte))
sensitivities <- fst::read_fst(sprintf("%s/sensitivities.fst", config$path$geos_inte))

# read in some constants
nregions <- as.numeric(config$inversion_constants$no_regions) + 1
ntime <- interval(as.Date(config$dates$perturb_start), as.Date(config$dates$perturb_end)) %/% months(1)

# get inversion alphas
mean_alphas <- lapply(1:window,
                      inversion_alphas,
                      case = args$case,
                      method = args$method)

# create ic alphas
new_alphas <- updated_alphas(window, mean_alphas, nregions, ntime)

# turn alphas into mole fraction
new_control_mf <- alpha_to_obs(new_alphas, 0,
                               control_mf, perturbations, sensitivities)

# read in next window control mole fraction
next_control_mf <- fst::read_fst(sprintf("%s/control-mole-fraction-window%02d.fst",
                                         config$path$geos_inte, window + 1))

# put new control mole fraction into nice data frame and filter so it matches the
# time length of the next window
new_control_mf_df <- data.frame(observation_id = observations$observation_id,
                                time = observations$time,
                                co2 = new_control_mf) %>%
                                filter(time >= min(next_control_mf$time),
                                       time <= max(next_control_mf$time))

# input the new control mole fraction in the next window
new_next_control_mf <- next_control_mf %>% mutate(co2 = new_control_mf_df$co2)

# save new control mole fraction file
message("Saving...")
output_file <- sprintf("%s/control-mole-fraction-%s-window%02d-%s-rescaled.fst",
                       config$path$geos_inte, args$case, window + 1, args$method)
fst::write_fst(new_next_control_mf, output_file)
