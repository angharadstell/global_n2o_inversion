# This script plots the temperature anomaly and precipitation rate for the land
# transcom regions. It then saves the resulting dataframe for further analysis.

library(dplyr)
library(ggplot2)
library(gridExtra)
library(here)
library(ini)
library(ncdf4)
library(raster)
library(rnaturalearth)
library(rnaturalearthdata)
library(sf)

###############################################################################
# GLOBAL CONSTANTS
###############################################################################
config <- read.ini(paste0(here(), "/config.ini"))

###############################################################################
# FUNCTIONS
###############################################################################

# plot temperature
line_plot_t <- function(region) {
    p <- ggplot(temp %>% filter(transcom_region == region),
        aes(x = date, y = mean_temp_aw)) + geom_line() + ggtitle(region) +
          theme(axis.title.x = element_blank(), axis.title.y = element_blank())
    plot(p)
}

# plot ppt
line_plot_p <- function(region) {
    p <- ggplot(ppt %>% filter(transcom_region == region),
        aes(x = date, y = sum_ppt)) + geom_line() + ggtitle(region) +
          theme(axis.title.x = element_blank(), axis.title.y = element_blank())
    plot(p)
}

# plot both temperature and ppt
line_plot_joint <- function(region) {
  joint_region <- joint %>% filter(transcom_region == region)

  coef <- mean(joint_region$sum_ppt) / mean(joint_region$mean_temp_aw)

  p <- ggplot(joint_region, aes(x = date)) +
         geom_line(aes(y = mean_temp_aw), color = "red") +
         geom_line(aes(y = sum_ppt / coef), color = "blue") +
         scale_y_continuous(name = "Temperature anomaly / K",
         sec.axis = sec_axis(~. * coef, name = "Precipitation / mmday-1")) +
         ggtitle(region) +
         theme(axis.title.x = element_blank(), axis.title.y = element_blank())
  plot(p)
}

###############################################################################
# CODE
###############################################################################

#############
# TEMPERATURE
#############
# read in temperature observations
# https://data.giss.nasa.gov/gistemp/
raw_temp <- ncdf4::nc_open(paste0(config$paths$meteo, "/gistemp250_GHCNv4.nc"))
v <- function(...) ncdf4::ncvar_get(raw_temp, ...)

# extract and label data
temp_anomaly <- v("tempanomaly")

date <- as.Date(as.numeric(v("time")), origin = "1800-01-01") - 14
lat <- v("lat")
lon <- v("lon")

dimnames(temp_anomaly)[[1]] <- lon
dimnames(temp_anomaly)[[2]] <- lat
dimnames(temp_anomaly)[[3]] <- date

# remove dates outside inversion range
date_mask <- date >= config$dates$perturb_start & date < config$dates$final_end
temp_anomaly <- temp_anomaly[, , date_mask]

# make into a data frame
temp_anomaly_df <- cbind(expand.grid(lon,  lat, date[date_mask]), val = as.vector(temp_anomaly))
names(temp_anomaly_df) <- c("longitude", "latitude", "date", "temp")

#temp_anomaly_df$year <- as.numeric(format(temp_anomaly_df$date, "%Y"))
#temp_anomaly_df$month <- as.numeric(format(temp_anomaly_df$date, "%m"))

# read in transcom mask so can match locations to regions
transcom_mask <- raster(config$inversion_constants$geo_transcom_mask,
                        stopIfNotEqualSpaced = FALSE)

temp <- temp_anomaly_df %>%
          # cos latitude weight
          mutate(abs_cos_lat = abs(cos(latitude / (pi / 180))),
                temp_aw = temp * abs_cos_lat
          ) %>%
          # match locations to regions
          mutate(transcom_region = extract(transcom_mask, cbind(longitude, latitude))
          ) %>%
          mutate(
            transcom_region = if_else(is.na(transcom_region), 0, transcom_region)
          ) %>%
          # filter(latitude > 5 & latitude < 20) %>%
          # filter(longitude > 95 & longitude < 110) %>%
          # filter(month == 8) %>%
          # filter(transcom_region == 2) %>%
          # remove nans before area weighting
          filter(!is.na(temp)) %>%
          group_by(date, transcom_region) %>%
          # summarise(mean_temp_aw = mean(temp)) %>%
          # area weight
          summarise(sum_temp_aw = sum(temp_aw), sum_w = sum(abs_cos_lat)) %>%
          mutate(mean_temp_aw = sum_temp_aw / sum_w) %>%
          # remove unwanted cols
          dplyr::select(date, transcom_region, mean_temp_aw)

# plot temperature anomaly
plot_list <- lapply(0:11, line_plot_t)
do.call("grid.arrange", c(plot_list, nrow = 3))



##########
# RAINFALL
##########
# https://psl.noaa.gov/data/gridded/data.cmap.html
raw_ppt <- ncdf4::nc_open(paste0(config$paths$meteo, "/precip.mon.mean.nc"))
v <- function(...) ncdf4::ncvar_get(raw_ppt, ...)

# extract and label data
precip <- v("precip")

date <- as.Date(as.numeric(v("time")) / 24, origin = "1800-01-01")
lat <- v("lat")
lon <- v("lon")

new_lon <- lon
new_lon[lon > 180] <- lon[lon > 180] - 360

dimnames(precip)[[1]] <- new_lon
dimnames(precip)[[2]] <- lat
dimnames(precip)[[3]] <- date

# remove dates outside inversion range
date_mask <- date >= config$dates$perturb_start & date < config$dates$final_end
precip <- precip[, , date_mask]

# make into a data frame
precip_df <- cbind(expand.grid(new_lon,  lat, date[date_mask]), val = as.vector(precip))
names(precip_df) <- c("longitude", "latitude", "date", "ppt")

ppt <- precip_df %>%
          # match locations to regions
          mutate(transcom_region = extract(transcom_mask, cbind(longitude, latitude))
          ) %>%
          mutate(
            transcom_region = if_else(is.na(transcom_region), 0, transcom_region)
          ) %>%
          # remove nans
          filter(!is.na(ppt)) %>%
          # sum up over regions
          group_by(date, transcom_region) %>%
          summarise(sum_ppt = sum(ppt)) %>%
          dplyr::select(date, transcom_region, sum_ppt)

# plot precipitation
plot_list <- lapply(0:11, line_plot_p)
do.call("grid.arrange", c(plot_list, nrow = 3))



##########
# JOINT
##########
joint <- inner_join(ppt, temp, by = c("date", "transcom_region"))

# plot
plot_list <- lapply(0:11, line_plot_joint)
do.call("grid.arrange", c(plot_list, nrow = 3))

# add month, might be useful for fertiliser application
joint$month <- as.numeric(format(joint$date, "%m"))

# label like wombat
joint$transcom_region <- sprintf("T%02d", joint$transcom_region)

write.table(joint, file = paste0(config$paths$meteo, "/region_training_data.csv"))
