"""
This module establishes which observations we want to keep.

@author: Angharad Stell
"""

import configparser
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import xarray as xr

def agage_baseline(site, time_vec):
    # read in Alistair's baseline
    filepath = Path(config["paths"]["data_dir"]) / "agage_baseline"
    located_file = next(filepath.glob(f"NAME_baseline_{site[0:3].upper()}_*.nc"))

    with xr.open_dataset(located_file) as load:
        df = load.load()

    # interpolate to measurement times
    # take only points between two baseline points in Alistair's baseline
    baseline = (df.interp(time = time_vec)["baseline_NAME"] == True).astype(int).values

    return baseline

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
            site_mask = obspack_obs["site"] == site
            if "AGAGEsurf" in site:
                obspack_obs["baseline"][site_mask] = agage_baseline(site, obspack_obs["time"][site_mask])
                # plot to check it makes sense
                fig, ax = plt.subplots()
                scatter = ax.scatter(x=obspack_obs["time"][site_mask].values, y=obspack_obs["value"][site_mask], c=obspack_obs["baseline"][site_mask])
                clegend = plt.legend(*scatter.legend_elements())
                ax.add_artist(clegend)
                plt.show()
                # how much of difference?
                print(obspack_obs["value"][site_mask].mean())
                print(obspack_obs["value"][site_mask][obspack_obs["baseline"][site_mask] == 1].mean())
            else:
                # store baseline
                obspack_obs["baseline"][site_mask] = 1
    
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
