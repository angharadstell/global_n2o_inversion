#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Mar 22 14:24:39 2021

@author: as16992
"""
import configparser
from pathlib import Path

import matplotlib.pyplot as plt
import xarray as xr

# read in variables from the config file
config = configparser.ConfigParser()
config.read("../../config.ini")
GEOS_EMS = Path(config["paths"]["geos_ems"])
TRANSCOM_MASK = Path(config["paths"]["transcom_mask"])

with xr.open_dataset(GEOS_EMS / "base_emissions.nc") as load:
    ems = load.load()
    
with xr.open_dataset(TRANSCOM_MASK) as load:
    mask = load.load()  

mask["lon"] = (mask["lon"] + 180) % 360 - 180
mask = mask.sortby(mask["lon"])
mask = mask.reindex_like(ems, method="nearest")

# looks a bit weird
mask["regions"].plot()
plt.show()
plt.close()

# 23 regions but 0 not optimised
for region in range(mask["regions"].min().values.astype(int),
                    mask["regions"].max().values.astype(int)+1):
    
    ems[f"emi_R{region:02d}"] = ems["emi_n2o"].where(mask["regions"] == region)

    ems[f"emi_R{region:02d}"].mean(dim="time").plot()
    plt.show()
    plt.close()
    
# Replace nan with zero
ems = ems.fillna(0)
    
ems.to_netcdf(GEOS_EMS / "base_emissions_tagged.nc")