#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue May  4 16:36:26 2021

@author: as16992
"""
import configparser
from pathlib import Path
import sys

import numpy as np
import xarray as xr

def geoschem_cell_size(xr_df):
    # work out geoschem grid widths and heights
    lat_edges = (xr_df.lat[:-1].values + xr_df.lat[1:].values) / 2
    lat_width = lat_edges[1:] - lat_edges[:-1]
    
    lat_widths = np.ones(len(xr_df.lat)) * np.max(lat_width)
    lat_widths[0] =  np.max(lat_width) / 2
    lat_widths[-1] =  np.max(lat_width) / 2
    
    lon_widths = xr_df.lon[1:].values - xr_df.lon[:-1].values
    
    if np.all(lon_widths == lon_widths[0]):
        lon_widths = np.ones(len(xr_df.lon)) * lon_widths[0]
    else:
        raise ValueError("Not all longitude widths are the same")
        
    return lat_widths, lon_widths


if __name__ == "__main__":
    # read in variables from the config file
    config = configparser.ConfigParser()
    #config.read(Path(__file__).parent.parent.parent / 'config.ini')
    config.read("/home/as16992/global_n2o_inversion/config.ini")
    GEOSOUT_DIR = Path(config["paths"]["geos_out"])
    CASE = config["inversion_constants"]["case"]

    # variables from commandline
    first_year = int(sys.argv[1])
    last_year = int(sys.argv[2])
    output_file = sys.argv[3]

    print(f"Loading data from {first_year} - {last_year}")
    print(f"Saving data to {output_file}")

    # Read in model ems
    for output_dir in GEOSOUT_DIR.iterdir():
        print(output_dir)
        
        try:
            hemco_files = []
            for y in range(first_year, last_year+1):
                hemco_files.extend(list(output_dir.glob(f"HEMCO_diagnostics.{y}??010000.nc")))
            hemco_files.sort()
            print(hemco_files)
            
            with xr.open_mfdataset(hemco_files) as load:
                hemco_ems = load.load() 
                
            hemco_ems = hemco_ems.drop(["hyam", "hybm", "P0", "lev"])
            
            if str(output_dir)[-4:] == CASE:
                # work out geoschem grid widths and heights
                lat_widths, lon_widths = geoschem_cell_size(hemco_ems)

            hemco_ems = hemco_ems.rename({"lon": "longitude",
                                          "lat": "latitude"})

            hemco_ems['longitude_width'] = lon_widths
            hemco_ems['latitude_height'] = lat_widths
            
            hemco_ems.to_netcdf(output_dir / output_file)
        except OSError:
            print("no files to open")
