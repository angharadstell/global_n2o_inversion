library(argparser)
library(coda)
library(dplyr)
library(here)
library(ini)
library(grid)
library(gridExtra, warn.conflicts = FALSE)

args <- arg_parser('', hide.opts = TRUE) %>%
  add_argument('--casename', '') %>%
  parse_args()
# args <- list()
# args$casename <- "IS-RHO0-VARYA-VARYW-NOBIAS"


###############################################################################
# GLOBAL CONSTANTS
###############################################################################

config <- read.ini(paste0(here(), "/config.ini"))

source(paste0(config$paths$wombat_paper, "/3_inversion/src/partials/base.R"))
source(paste0(config$paths$wombat_paper, "/3_inversion/src/partials/display.R"))

###############################################################################
# EXECUTION
###############################################################################

log_info('Loading MCMC samples')
samples <- readRDS(sprintf("%s/real-mcmc-samples-%s.rds", config$paths$geos_inte, args$casename)) %>%
  window(start = (config$inversion_constants$burn_in + 1))

log_info('Plotting')
output <- plot_traces(samples)

log_info('Saving')
ggsave_size(sprintf("%s/traceplots-%s.png", config$paths$inversion_results, args$casename), output,
            width = 200, height = 200, dpi = 100, bg = 'white', limitsize = FALSE)

log_info('Done')