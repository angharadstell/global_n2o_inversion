library(argparser)
library(dplyr)
library(fst)
library(here)
library(ini)
library(ncdf4)
library(tidyr)
library(wombat)

###############################################################################
# GLOBAL CONSTANTS
###############################################################################
# Read in command line arguments
args <- arg_parser('', hide.opts = TRUE) %>%
  add_argument('--flux-file', '') %>%
  add_argument('--output', '') %>%
  parse_args()

# Read in config file
config <- read.ini(paste0(here(), "/config.ini"))

###############################################################################
# FUNCTIONS
###############################################################################

sum_ch4_tracers <- function(v, region_start, region_end) {
  # Sum up the emissions for each desired region in geoschem, outputting an 
  # array of their distribution in space and time.

  # Create an array of zeros that matches the shape of "EMIS_CH4_R00"
  total_ch4 <- array(rep(0, length(v("EMIS_CH4_R00"))), dim(v("EMIS_CH4_R00")))
  # Iterate over desired regions
  for (region in region_start:region_end) {
    total_ch4 <- total_ch4 + v(sprintf("EMIS_CH4_R%02d", region))
  }
  total_ch4
}

###############################################################################
# EXECUTION
###############################################################################

# Read in flux file for the base run
fn <- nc_open(sprintf("%s/%s/%s", 
                      config$paths$geos_out,
                      config$inversion_constants$case,
                      args$flux_file))
v <- function(...) ncdf4::ncvar_get(fn, ...)

# Extract some constants from the file
n_longitudes <- length(v("longitude"))              # Number of longitudes in model
n_latitudes <- length(v("latitude"))                # Number of latitudes in model
month_starts <- as.Date(ncvar_get_time(fn, "time")) # The months starts in model

# Create a model_id that is unique for each grid cell and month
# Also extract the area of each grid cell from geoschem
locations <- expand.grid(
  longitude_index = seq(1, n_longitudes),
  latitude_index = seq(1, n_latitudes),
  month_start = month_starts
) %>%
  mutate(
    model_id = 1:n(),
    area = as.vector(v("AREA"))
) %>%
  select(month_start, model_id, everything())

# Read in the number of transcom regions (and how many of those are land) from the config file.
# The distinction between land and ocean regions only matters if you want to parameterise the
# land and ocean differently in the inversion, as in the original WOMBAT paper.
no_regions <- as.numeric(config$inversion_constants$no_regions)
no_land_regions <- as.numeric(config$inversion_constants$no_land_regions)

# Read in the emissions from geoschem, and add to the data frame
emissions <- cbind(locations, data.frame(
  # Emissions come in as kg/m^2/s from geoschem
  land = as.vector(sum_ch4_tracers(v, 0, (no_land_regions - 1))),
  ocean = as.vector(sum_ch4_tracers(v, no_land_regions, no_regions))
))

# Reshape data so the land/ocean columns are combined to one value column (flux_density),
# and one category column (type)
emissions <- pivot_longer(emissions, c(land, ocean),
                          names_to = "type", values_to = "flux_density")

# Add in more information on the grid cells - longitude centre, width of the cell,
# latitude centre, height of cell
emissions <- emissions %>% left_join(
  data.frame(
    longitude_index = seq(1, n_longitudes),
    longitude = v("longitude"),
    cell_width = v("longitude_width")
  ),
  by = "longitude_index"
) %>%
left_join(
  data.frame(
    latitude_index = seq_len(n_latitudes),
    latitude = v("latitude"),
    cell_height = v("latitude_height")
  ),
  by = "latitude_index"
) %>%
select(-longitude_index, -latitude_index)

# Save control emissions intermediate
fst::write_fst(emissions, sprintf("%s/%s", config$paths$geos_inte, args$output))
