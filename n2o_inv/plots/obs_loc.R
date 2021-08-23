library(ggplot2)
library(ini)
library(ncdf4)
library(rnaturalearth)
library(rnaturalearthdata)
library(sf)

###############################################################################
# GLOBAL CONSTANTS
###############################################################################
fileloc <- (function() {
  attr(body(sys.function()), "srcfile")
})()$filename

config <- read.ini(paste0(gsub("n2o_inv/plots.*", "", fileloc), "config.ini"))


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
       geom_point(data = obs, aes(x = longitude, y = latitude), color = "blue", size = 2) +
       xlab('Longitude') + ylab('Latitude')

plot(p)

ggsave(paste0(config$paths$obspack_dir, "/obs_loc.pdf"),
       width = 20, height = 10)
