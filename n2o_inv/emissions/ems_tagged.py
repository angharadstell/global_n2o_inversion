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
config.read(Path(__file__).parent.parent.parent / 'config.ini')
GEOS_EMS = Path(config["em_n_loss"]["geos_ems"])
MZT_TRANSCOM_MASK = Path(config["inversion_constants"]["mzt_transcom_mask"])
GEO_TRANSCOM_MASK = Path(config["inversion_constants"]["geo_transcom_mask"])

with xr.open_dataset(GEOS_EMS / "base_emissions.nc") as load:
    ems = load.load()
    
with xr.open_dataset(MZT_TRANSCOM_MASK) as load:
    mask = load.load()  

mask["lon"] = (mask["lon"] + 180) % 360 - 180
mask = mask.sortby(mask["lon"])
mask = mask.reindex_like(ems, method="nearest")

# looks a bit weird
mask["regions"].plot()
plt.show()
plt.close()

mask.to_netcdf(GEO_TRANSCOM_MASK)

# 23 regions but 0 often not optimised
for region in range(mask["regions"].min().values.astype(int),
                    mask["regions"].max().values.astype(int)+1):
    
    ems[f"emi_R{region:02d}"] = ems["emi_n2o"].where(mask["regions"] == region)

    # Plot the mean flux for each region
    # Check it's the right shape and land regions don't go negative
    ems[f"emi_R{region:02d}"].mean(dim="time").plot()
    plt.show()
    plt.close()

    # Because of the coarse model resolution, when the ocean got regridded some 
    # of the fluxes got assigned to the land region coasts. Therefore, if you 
    # look at the minimum rather than mean, regions 1, 7, 11 have negatives on the 
    # coast. Have a look and examine the values. I think this is OK because the 
    # difference is in the winter when regions 1 and 7 have small fluxes, so the 
    # inversion doesn't really rescale these fluxes much. This is not true for 
    # region 11, but the negatives in this region are negligible anyway (0.1% of 
    # the region's prior flux or less). For more detail, see scaled_prior/change_seasonal_cycle.R
    ems[f"emi_R{region:02d}"].min(dim="time").plot()
    print(ems[f"emi_R{region:02d}"].min())
    print(ems[f"emi_R{region:02d}"].mean())
    plt.show()
    plt.close()
    
# Replace nan with zero
ems = ems.fillna(0)
    
ems.to_netcdf(GEOS_EMS / "base_emissions_tagged.nc")