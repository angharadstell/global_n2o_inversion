"""
This module establishes which observations we want to keep.

@author: Angharad Stell
"""

import configparser
from pathlib import Path

import numpy as np
import pandas as pd
import xarray as xr

def raw_obs_to_baseline(obspack_obs):
    # create place to store baseline
    obspack_obs["baseline"] = xr.zeros_like(obspack_obs["value"])

    # pick a site
    unique_sites = np.unique(obspack_obs["site"])

    # sites that look visibly dodgy
    dodgy_sites = ['abpNOAAsurf', 'balNOAAsurf', 'bmeNOAAsurf', 'bscNOAAsurf',  # too few obs
                   'bwdNOAAsurf', 'crsNOAAsurf', 'hfmNOAAsurf', 'hsuNOAAsurf', 
                   'lacNOAAsurf', 'llbNOAAsurf', 'mknNOAAsurf', 'mrcNOAAsurf', 
                   'mshNOAAsurf', 'mvyNOAAsurf', 'nebNOAAsurf', 'nwbNOAAsurf',
                   'pcoNOAAsurf', 'pocNOAAsurf', 'ptaNOAAsurf', 'tacNOAAsurf',
                   'tmdNOAAsurf', 'tpiNOAAsurf',
                   'amyNOAAsurf', 'cibNOAAsurf', 'hpbNOAAsurf', 'hunNOAAsurf',  # polluted
                   'inxNOAAsurf', 'lefNOAAsurf', 'lewNOAAsurf', 'oxkNOAAsurf',
                   'sctNOAAsurf', 'sdzNOAAsurf', 'sgpNOAAsurf', 'strNOAAsurf',
                   'tapNOAAsurf', 'utaNOAAsurf', 'wbiNOAAsurf', 'wgcNOAAsurf',
                   'wisNOAAsurf', 'wktNOAAsurf',
                   'grfNOAAsurf', 'mlsNOAAsurf', 'mscNOAAsurf', 'spfNOAAsurf', # look weird
                   'tnkNOAAsurf', 'wpcNOAAsurf'] 

    for site in unique_sites:
        print(site)

        if site in dodgy_sites:
            pass
        elif "NOAAair" in site:
            pass
        else:
            # store baseline
            obspack_obs["baseline"][obspack_obs["site"] == site] = 1
    
    return obspack_obs

def toYearFraction(date):

    year = date.year
    startOfThisYear = pd.Timestamp(f'{year}-01-01')
    startOfNextYear = pd.Timestamp(f'{year+1}-01-01')

    yearElapsed = date - startOfThisYear
    yearDuration = startOfNextYear - startOfThisYear
    fraction = yearElapsed/yearDuration

    return date.year + fraction

if __name__ == "__main__":
    # read in variables from the config file
    config = configparser.ConfigParser()
    config.read("../../config.ini")
    OBSPACK_DIR = Path(config["paths"]["obspack_dir"])
    
    # read in raw observations
    print("Reading in obs...")
    with xr.open_dataset(OBSPACK_DIR / "raw_obs.nc") as load:
        obspack_raw = load.load()

    # filter to only baseline
    obspack_baseline = raw_obs_to_baseline(obspack_raw)

    # Save for later use
    obspack_baseline.to_netcdf(OBSPACK_DIR / "baseline_obs.nc")
