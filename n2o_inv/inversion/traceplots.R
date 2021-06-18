library(coda)
library(grid)
library(gridExtra, warn.conflicts = FALSE)

###############################################################################
# GLOBAL CONSTANTS
###############################################################################

fileloc <- (function() {
  attr(body(sys.function()), "srcfile")
})()$filename

config <- read.ini(paste0(gsub("n2o_inv/inversion.*", "", fileloc), "config.ini"))

casename <- config$inversion_constants$model_case

source(paste0(config$paths$wombat_paper, "/3_inversion/src/partials/base.R"))
source(paste0(config$paths$wombat_paper, "/3_inversion/src/partials/display.R"))

###############################################################################
# EXECUTION
###############################################################################

log_info('Loading MCMC samples')
samples <- readRDS(sprintf("%s/real-mcmc-samples-%s.rds", config$paths$geos_inte, casename)) %>%
  window(start = 101)

log_info('Plotting')
output <- plot_traces(samples)

log_info('Saving')
ggsave_size(paste0(config$paths$geos_inte, "/traceplots.png"), output,
            width = 200, height = 200, dpi = 100, bg = 'white', limitsize = FALSE)

log_info('Done')