#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
This script plots the GEOSCHEM TRANSCOM regions on a map.
"""
import configparser
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import xarray as xr

# read in variables from the config file
config = configparser.ConfigParser()
config.read(Path(__file__).parent.parent.parent / 'config.ini')
GEO_TRANSCOM_MASK = Path(config["inversion_constants"]["geo_transcom_mask"])

# read in the TRANSCOM region mask
with xr.open_dataset(GEO_TRANSCOM_MASK) as load:
    mask = load.load()  

# remove region 0 so it shows up clearly as white
test = mask["regions"].where(mask["regions"] != 0)

# plot pcolormesh map
test.plot(cmap="twilight", add_colorbar=False, xticks=[], yticks=[], size=10)

# label region 0
plt.text(0, -85, "T00", size=20)

# choose x and y adjustments for region labels
x_adjust = np.array([0,-15,0,-10,-10,-15,0,0,-20,-10,0,
                     -60,20,0,0,0,0,0,0,0,-20,0])
y_adjust = np.array([-6,0,-10,0,0,0,0,0,5,0,0,
                     0,0,0,0,0,0,0,0,0,-10,0])
# choose text colors for the region labels
text_color = ["k", "k", "k", "k", "k", "k", "k", "k", "w", "w", "w", 
              "w", "w", "k", "k", "k", "k", "k", "k", "k", "k", "k"]

# label each region
for i in range(1,23):
    masked_region = mask.where(mask["regions"] == i, drop=True)
    med_lat = masked_region["lat"].median()
    med_lon = masked_region["lon"].median()

    plt.text(med_lon + x_adjust[i-1], med_lat + y_adjust[i-1], 
             f"T{i:02}", size=20, color=text_color[i-1])

plt.xlabel(None)
plt.ylabel(None)

plt.savefig(f"{config['paths']['inversion_results']}/transcom_regions.pdf", bbox_inches="tight")
plt.show()
plt.close()
