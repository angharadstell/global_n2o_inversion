
import configparser
from pathlib import Path

import numpy as np
import pandas as pd
import xarray as xr


# read in variables from the config file
config = configparser.ConfigParser()
config.read(Path(__file__).parent.parent.parent / 'config.ini')
BCKGRND_CONC = float(config["gas_info"]["background_conc"])
GEOS_EMS = Path(config["em_n_loss"]["geos_ems"])
GEOS_OUT = Path(config["paths"]["geos_out"])
PERTURB_START = config["dates"]["perturb_start"]
PERTURB_START = config["dates"]["perturb_start"]
SPINUP_START = config["dates"]["spinup_start"]

# Read in emissions
with xr.open_dataset(GEOS_EMS / "base_emissions_tagged.nc") as load:
    ems = load.load()

# select spinup ems
ems = ems.sel(time=slice(SPINUP_START, PERTURB_START))

days_in_month = pd.date_range(SPINUP_START, PERTURB_START, freq="MS").days_in_month
secs_in_month = np.array(days_in_month * 24 * 60 * 60)


# if geoschem ends on the start of month, this month is not in the spinup
if PERTURB_START[8:] == '01':
    secs_in_month = secs_in_month[:-1]
    ems = ems.isel(time=slice(0, -1))

# get GEOSCHEM area
with xr.open_dataset(Path(__file__).parent / "geos_grid_info.nc") as load:
    area = load.load()



all_ems = (ems * area["area"]).sum(dim=["lon","lat"])
annual_all_ems = (all_ems * secs_in_month).sum()

ems_ratios = annual_all_ems / annual_all_ems["emi_n2o"] * BCKGRND_CONC
ems_ratios.to_netcdf(GEOS_EMS / "ems_frac.nc")
