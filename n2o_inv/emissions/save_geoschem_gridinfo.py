#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
This script reads in the area of the GEOSChem grid from GEOSChem output.
This will only work if you've already run GEOSChem!
"""
import configparser
from pathlib import Path

import xarray as xr

# read in variables from the config file
config = configparser.ConfigParser()
config.read(Path(__file__).parent.parent.parent / 'config.ini')
GEOS_OUT = Path(config["paths"]["geos_out"])
CASE = config["inversion_constants"]["case"]

# read in GEOSChem output
out_path = GEOS_OUT / CASE                                   # will only work if youve already run GEOSCHEM!
sc_fns = sorted(out_path.glob("GEOSChem.SpeciesConc.*"))
with xr.open_dataset(sc_fns[0]) as load:
    ds_conc = load.load()

# save GEOSChem area as a nice netcdf
area = xr.Dataset({"area":(("lat", "lon"), ds_conc.AREA.values)},
                    coords={"lat":ds_conc.lat.values, "lon":ds_conc.lon.values})
area.to_netcdf(Path(config["em_n_loss"]["geos_ems"]) / "geos_grid_info.nc")
