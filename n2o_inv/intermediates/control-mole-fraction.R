library(argparser)
library(dplyr)
library(fst)
library(here)
library(ini)
library(ncdf4)
library(tibble)

library(wombat)

args <- arg_parser('', hide.opts = TRUE) %>%
  add_argument('--case', '') %>%
  add_argument('--mf-file', '') %>%
  add_argument('--output', '') %>%
  parse_args()

###############################################################################
# GLOBAL CONSTANTS
###############################################################################
config <- read.ini(paste0(here(), "/config.ini"))

# locations of files
geos_out_dir <- config$paths$geos_out
inte_out_dir <- config$paths$geos_inte

###############################################################################
# FUNCTIONS
###############################################################################

process_control <- function(case, input_file, output_file) {
  # get variables from base run netcdf
  geos_obspack <- nc_open(paste0(geos_out_dir, "/", case, "/", input_file, ".nc"))
  v <- function(...) ncvar_get(geos_obspack, ...)

  # put into nice table
  control_full <- tibble(
    observation_id = as.vector(v("obspack_id")),
    observation_type = "obspack",
    resolution = "obspack",
    time = rep(ncvar_get_time(geos_obspack, "obs_time"), times = length(v("site"))),
    latitude = as.vector(v("obs_lat")),
    longitude = as.vector(v("obs_lon")),
    co2 = as.vector(v("CH4_sum")),
    model_id = seq_len(length(v("CH4_sum"))),
  ) %>%
  arrange(model_id) %>%
  filter(if_any(co2, ~ !is.na(.)))

  # save for later
  write_fst(control_full, paste0(inte_out_dir, "/", output_file, ".fst"))
}


###############################################################################
# CODE
###############################################################################

process_control(args$case, args$mf_file, args$output)

# constant case
process_control(config$inversion_constants$constant_case, "combined_mf", "control-mole-fraction-constant-met")
