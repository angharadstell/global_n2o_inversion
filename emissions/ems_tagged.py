#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Mar 22 14:24:39 2021

@author: as16992
"""

import matplotlib.pyplot as plt
import xarray as xr


EMS_FILE = "/work/as16992/geoschem/N2O/emissions/base_emissions.nc"
TRANSCOM_MASK = "/work/chxmr/shared/TRANSCOM/TRANSCOM3_basis_functions/TRANSCOM_Map_MZT.nc"

with xr.open_dataset(EMS_FILE) as load:
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
    
ems.to_netcdf("/work/as16992/geoschem/N2O/emissions/base_emissions_tagged.nc")