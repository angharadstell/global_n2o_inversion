#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Apr 14 16:10:05 2021

@author: as16992
"""
import configparser
from pathlib import Path

import numpy as np
import pandas as pd
import xarray as xr

# read in variables from the config file
config = configparser.ConfigParser()
config.read("../../config.ini")
GEOS_EMS = Path(config["em_n_loss"]["geos_ems"])
PERTURB_START = config["dates"]["perturb_start"]
PERTURB_END = config["dates"]["perturb_end"]

with xr.open_dataset(GEOS_EMS / "base_emissions_tagged.nc") as load:
    ems = load.load()
    
friendly_dates = ems.time.dt.strftime("%Y%m%d")
    
perturb_dates = pd.date_range(PERTURB_START, PERTURB_END, freq="MS").strftime("%Y%m%d")

# if geoschem ends on the start of month, no point perturbing this month
if PERTURB_END[8:] == '01':
    perturb_dates = perturb_dates[:-1]
   
for date in perturb_dates:
    mask = np.ones(np.shape(ems["emi_n2o"]))
    mask[friendly_dates == date,:,:] = 2.

    perturb_ems = ems * mask
    
    # Multiplication ruins units
    perturb_ems["emi_n2o"].attrs["units"] = "kg/m2/s"
    for region in range(0, len(ems.keys())-1):
        perturb_ems[f"emi_R{region:02d}"].attrs["units"] = "kg/m2/s"
    
    perturb_ems.to_netcdf(GEOS_EMS / f"ems_{date[:6]}.nc")
    