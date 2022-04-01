#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
This script establishes which observations we want to keep.
"""
import configparser
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import xarray as xr

def agage_baseline(df, time_vec):
    """ Interpolate baseline df to measurement times.

    Take only points between two baseline points in Alistair's baseline.
    """

    return (df.interp(time = time_vec)["baseline_NAME"] == True).astype(int).values

def raw_obs_to_baseline(obspack_obs, baseline_dict):
    """ Create baseline variable, which is 1 for baseline, 0 for not baseline.
    """
    # create place to store baseline
    obspack_obs["baseline"] = xr.zeros_like(obspack_obs["value"])

    # pick a site
    unique_sites = np.unique(obspack_obs["site"])

    # sites that look visibly dodgy when plotted
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
                   'tnkNOAAsurf', 'wpcNOAAsurf',
                   'dsiNOAAsurf', 'wlgNOAAsurf', 'palNOAAsurf', 'bktNOAAsurf', # too sensitive to local emissions
                   'shmNOAAsurf', 'amtNOAAsurf'] 

    for site in unique_sites:
        print(site)

        if site in dodgy_sites:
            pass
        # ignore aircraft obs
        elif "NOAAair" in site:
            pass
        else:
            site_mask = obspack_obs["site"] == site
            if "AGAGEsurf" in site:
                obspack_obs["baseline"][site_mask] = agage_baseline(baseline_dict[site[0:3].upper()], obspack_obs["time"][site_mask])
                # plot to check it makes sense
                plot_baseline(obspack_obs.where(site_mask, drop=True))
                # how much of difference?
                print(obspack_obs["value"][site_mask].mean())
                print(obspack_obs["value"][site_mask][obspack_obs["baseline"][site_mask] == 1].mean())
            else:
                # store baseline
                obspack_obs["baseline"][site_mask] = 1
    
    return obspack_obs

def plot_baseline(site_obs):
    """ Plot a scatter plot of the observations, coloured by whether it is "baseline".
    """
    _, ax = plt.subplots()
    scatter = ax.scatter(x=site_obs["time"].values, y=site_obs["value"], c=site_obs["baseline"])
    clegend = plt.legend(*scatter.legend_elements())
    ax.add_artist(clegend)
    plt.show()

def make_agage_baseline_dict(config):
    agage_sites = config["inversion_constants"]["agage_sites"].split(",")
    agage_baseline_dict = {}
    for site in agage_sites:
        filepath = Path(config["paths"]["data_dir"]) / "agage_baseline"
        located_file = next(filepath.glob(f"NAME_baseline_{site}_*.nc"))
        with xr.open_dataset(located_file) as load:
            df = load.load()
        agage_baseline_dict[site] = df
    
    return agage_baseline_dict


if __name__ == "__main__":
    # read in variables from the config file
    config = configparser.ConfigParser()
    config.read("../../config.ini")
    OBSPACK_DIR = Path(config["paths"]["obspack_dir"])
    AGAGE_SITES = config["inversion_constants"]["agage_sites"].split(",")
    
    # read in raw observations
    print("Reading in obs...")
    with xr.open_dataset(OBSPACK_DIR / "raw_obs.nc") as load:
        obspack_raw = load.load()

    # read in AGAGE baselines
    agage_baseline_dict = make_agage_baseline_dict(config)

    # filter to only baseline
    obspack_baseline = raw_obs_to_baseline(obspack_raw, agage_baseline_dict)

    # Save for later use
    obspack_baseline.to_netcdf(OBSPACK_DIR / "baseline_obs.nc")
