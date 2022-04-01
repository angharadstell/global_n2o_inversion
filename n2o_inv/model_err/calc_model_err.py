#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
This script calculates the model error from the GEOSChem output.
"""
import configparser

from pathlib import Path

import numpy as np
import pandas as pd
import xarray as xr

from n2o_inv.intermediates import process_geos_output
from n2o_inv.obs import obs_baseline
from n2o_inv.obs import plot_obs

if __name__ == "__main__":
    """ 
    Read in config global variables
    """

    # read in variables from the config file
    config = configparser.ConfigParser()
    config.read("../../config.ini")
    NO_REGIONS = int(config["inversion_constants"]["no_regions"])
    CASE = config["inversion_constants"]["model_err_case"]
    AGAGE_SITES = config["inversion_constants"]["agage_sites"].split(",")
    GEOS_OUT = Path(config["paths"]["geos_out"])
    OBSPACK_DIR = Path(config["paths"]["obspack_dir"])
    SPINUP_START = pd.to_datetime(config["dates"]["spinup_start"])
    PERTURB_START = pd.to_datetime(config["dates"]["perturb_start"])
    PERTURB_END = pd.to_datetime(config["dates"]["perturb_end"])
    FINAL_END = pd.to_datetime(config["dates"]["final_end"])

    """ 
    Make combined.nc file
    """

    print("Does combined.nc file already exist?")
    combined_file = GEOS_OUT / CASE / "combined.nc"
    if combined_file.is_file():
        print("Reading in existing combined.nc file...")
        with xr.open_dataset(combined_file) as load:
            combined = load.load()
            unique_sites = np.unique(combined["site"]) # other function uses obspackid so wont work
    else:
        print("Making combined.nc file, this takes a long time...")

        # read in observations
        # have to redo this (which was originally done in plot_obs.py and obs_baseline.py) because
        # need to do it with the extra eight grid cells
        print("Reading in obs...")
        obspack_raw = process_geos_output.read_obs(OBSPACK_DIR / CASE, SPINUP_START, 
                                                FINAL_END, FINAL_END)
        print("Finding unique sites...")
        list_of_sites, unique_sites = process_geos_output.find_unique_sites(obspack_raw)
        obspack_raw["site"] = (("obs"), np.array(list_of_sites))

        # read in AGAGE baselines
        agage_baseline_dict = obs_baseline.make_agage_baseline_dict(config)
        # filter to only baseline
        obspack_baseline = obs_baseline.raw_obs_to_baseline(obspack_raw, agage_baseline_dict)

        # cut unwanted years
        obspack_baseline = obspack_baseline.where(obspack_baseline["time"] >= pd.to_datetime(f"{PERTURB_START.year - 1}-12-31 23:55"), drop=True)
        obspack_baseline = obspack_baseline.where(obspack_baseline["time"] < pd.to_datetime(f"{FINAL_END.year}-12-31 23:55"), drop=True)

        # read in geos output
        # have to redo this (which was originally done in process_geos_output.py) because
        # need to do it with the extra eight grid cells
        print("Reading in geos...")
        obspack_geos = process_geos_output.read_geos(GEOS_OUT / CASE, obspack_baseline,
                                                     NO_REGIONS, PERTURB_START.year, (PERTURB_END.year-1))

        # sum up different regions
        obspack_geos = plot_obs.add_ch4(obspack_geos, NO_REGIONS+1)
        # obs_floor will be the same for each group of 9 gridcells
        obspack_geos["obs_floor"] = np.floor(obspack_geos["obs"])


        # combine the two datasets as in process_geos_output.py
        print("Combining datasets...")
        combined = xr.merge([obspack_baseline[["latitude", "longitude", "altitude",
                                            "time", "obspack_id", "value", 
                                            "value_unc", "network", "site", "baseline"]],
                                obspack_geos])
        combined = combined.rename({"latitude":"obs_lat", "longitude":"obs_lon",
                                    "altitude":"obs_alt", "time":"obs_time", 
                                    "value":"obs_value", "value_unc":"obs_value_unc"})

        # dont want 23:55-23:59 from previous year
        combined = combined.where(combined["obs_time"] >= pd.to_datetime(f"{PERTURB_START.year}-01-01"), drop=True)

        # make dimensions site and time as in process_geos_output.py
        print("Sorting out dims...")
        combined = combined.assign_coords(obs_time=combined["obs_time"])
        combined = combined.swap_dims({"obs":"obs_time"})

        # drops air sites and non-baseline points as in process_geos_output.py
        combined = combined.where(combined["baseline"], drop=True)

        # rescale AGAGE to NOAA as in process_geos_output.py
        agage_mask = combined["network"] == "AGAGEsurf"
        agage_over_noaa_ratio = pd.read_csv(OBSPACK_DIR / "agage_noaa_scaling/agage_over_noaa_ratio.csv", index_col=0).iloc[0].values[0]
        combined["obs_value"][agage_mask] = combined["obs_value"][agage_mask] / agage_over_noaa_ratio

        # combine NOAA sites and AGAGE sites where we have AGAGE data as in process_geos_output.py
        for site in AGAGE_SITES:
            combined["site"].loc[combined["site"] == f"{site.lower()}AGAGEsurf"] = f"{site.lower()}NOAGsurf"
            combined["site"].loc[combined["site"] == f"{site.lower()}NOAAsurf"] = f"{site.lower()}NOAGsurf"
        unique_sites = np.unique(combined["site"]) # other function uses obspackid so wont work

        # save for later since its so slow
        combined.to_netcdf(GEOS_OUT / CASE / "combined.nc")

    """ 
    Create monthly mean
    """

    # create monthly mean for each site
    print("Making monthly mean...")
    resampled_sites = []
    for site in unique_sites:
        onesite = combined.where(combined["site"] == site, drop=True)
        # remove the extra 8 values for each obs to get correct obs_time
        onesite_ninth = onesite.where(onesite["obs"]  == onesite["obs_floor"], drop=True)
        # work out model std for each obs
        model_std = onesite[["CH4_sum", "obs_floor"]].groupby("obs_floor").std()
        # recombine with correct obs_time
        onesite_ninth["model_std"] = (("obs_time"), model_std["CH4_sum"].values)
        # calculate median error
        onesite_resampled = onesite_ninth["model_std"].resample(obs_time="M").median()
        # save for later
        resampled_sites.append(onesite_resampled)
        # do the values make sense?
        print(site)
        print(onesite_resampled.median().values)

    # recombine sites
    print("Recombining sites...")
    site_combined = xr.concat(resampled_sites, dim="site")
    site_combined["site"] = (("site"), unique_sites)

    # save combined file
    site_combined.to_netcdf(GEOS_OUT / CASE / "model_err.nc")
