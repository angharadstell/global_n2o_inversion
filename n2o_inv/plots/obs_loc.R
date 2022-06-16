# This script plots the location of the observations on a map
library(ggplot2)
library(ggthemes)
library(here)
library(ini)
library(ncdf4)
library(rnaturalearth)
library(rnaturalearthdata)
library(sf)

###############################################################################
# GLOBAL CONSTANTS
###############################################################################
config <- read.ini(paste0(here(), "/config.ini"))


# set ggplot theme for maps
theme_set(theme_bw())

###############################################################################
# CODE
###############################################################################


# read in observations
# individual
raw_obs <- ncdf4::nc_open(sprintf("%s/baseline_obs.nc", config$paths$obspack_dir))
v <- function(...) ncdf4::ncvar_get(raw_obs, ...)
raw_obs_df <- data.frame(latitude = v("latitude"), longitude = v("longitude"))
# monthly mean
obs <- fst::read_fst(sprintf("%s/observations.fst", config$paths$geos_inte))

# build world map
world <- ne_countries(scale = "medium", returnclass = "sf")

# plot map
# what about ship data?!
p <- ggplot(data = world) + geom_sf() +
       coord_sf(ylim = c(-90, 90), expand = FALSE) +
       geom_point(data = obs, aes(x = longitude, y = latitude), color = "#E69F00", size = 6) +
       xlab('Longitude') +
       ylab('Latitude') +
       theme(axis.title.x = element_blank(),
             axis.title.y = element_blank(),
             axis.ticks.x = element_blank(),
             axis.ticks.y = element_blank(),
             axis.text.x = element_blank(),
             axis.text.y = element_blank())

plot(p)

ggsave(paste0(config$paths$obspack_dir, "/obs_loc.pdf"),
       width = 20, height = 10)
