"""
This script formats all the obspack style observations into a format that GEOSChem can use.

@author: Angharad Stell
"""
import configparser

import numpy as np
import pandas as pd
from pathlib import Path
import xarray as xr

""" 
Read in config global variables
"""

# read in variables from the config file
config = configparser.ConfigParser()
config.read("config.ini")
RAW_OBSPACK_DIR = Path(config["paths"]["raw_obspack_dir"])
OBSPACK_DIR = Path(config["paths"]["obspack_dir"])
SPINUP_START = config["dates"]["spinup_start"]
PERTURB_END = config["dates"]["perturb_end"]

""" 
Define useful functions
"""

def date_mask(df, date):
    """
    Create a mask that only includes a specific date.
    """
    year_mask = (df["time_components"][:, 0] == date.year)
    month_mask = (df["time_components"][:, 1] == date.month)
    day_mask = (df["time_components"][:, 2] == date.day)

    year_and_month_mask = np.logical_and(year_mask, month_mask)
    date_mask = np.logical_and(year_and_month_mask, day_mask)
    return date_mask

def preprocess(xr_df):
    """
    Process the NOAA obspack before it can be read into xarray. 
    This includes a monotonically increasing coordinate, and only
    keeping the desired variables.
    """
    # xarray needs monotonically increasing coords to join the datasets together
    xr_df = xr_df.assign_coords(obs=xr_df["obspack_num"])
    
    # Some aircraft files don't have uncertainty, so add in a load of nans
    test_unc = xr_df.get("value_unc")
    if test_unc is None:
        xr_df["value_unc"] = (("obs"), np.array([np.nan] * len(xr_df["obs"])))
    else: 
        pass

    # Only keep desired variables
    wanted_var = ["latitude", "longitude", "altitude", 
                  "time", "time_components", "obspack_id", 
                  "value", "value_unc", "qcflag"]
    xr_df = xr_df[wanted_var]
    return xr_df

def read_noaa_obspack(obspack_folder):
    """
    Create a list of the N2O files, preprocess, and combine into a single xarray object.
    """
    # Make a list of the N2O files
    obspack_dir = RAW_OBSPACK_DIR / obspack_folder / "data/nc" 
    n2o_files = list(obspack_dir.glob("n2o_*"))
    n2o_files.sort()

    # Read into xarray
    with xr.open_mfdataset(n2o_files, preprocess=preprocess, decode_times=False) as load:
        noaa_obspack_data = load.load() 
    
    return noaa_obspack_data


if __name__ == "__main__":
    """ 
    Read in desired obspacks
    """

    # Read in NOAA obs
    noaa_surface_obspack_data = read_noaa_obspack("obspack_multi-species_1_CCGGSurfaceFlask_v2.0_2021-02-09")
    noaa_aircraft_obspack_data = read_noaa_obspack("obspack_multi-species_1_CCGGAircraftFlask_v2.0_2021-02-09")

    # Read in AGAGE obs
    agage_obs_dir = OBSPACK_DIR / "AGAGE_raw"
    agage_n2o_files = list(agage_obs_dir.glob("n2o_*"))
    agage_n2o_files.sort()

    with xr.open_mfdataset(agage_n2o_files, decode_times=False) as load:
        agage_obspack_data = load.load() 

    # combine the datasets
    obspack_data = xr.merge([noaa_surface_obspack_data, noaa_aircraft_obspack_data, agage_obspack_data])
        




    # How to sample model, 4 is instantaneous
    obspack_data["CT_sampling_strategy"] = (("obs"), 
                                            np.ones(len(obspack_data["obs"]), dtype=int) * 4)
    obspack_data["CT_sampling_strategy"].attrs = {"_FillValue":-9,
                                                "long_name":"model sampling strategy",
                                                "values":"How to sample model. 1=4-hour avg; 2=1-hour avg; 3=90-min avg; 4=instantaneous"}

    # Remove missing data
    missing_data_mask = obspack_data.value == -999.99
    obspack_data = obspack_data.where(~missing_data_mask)
    # There are like 3500 entries where its all nan? Have I done something wrong?
    obspack_data = obspack_data.dropna("obs") 
    # do I want to ignore col 2 too?
    bad_data_mask = [flag.decode('utf-8')[0] == "." for flag in obspack_data.qcflag.values]
    bad_data_mask = xr.DataArray(data=bad_data_mask, dims=["obs"], coords={"obs":obspack_data.obs})
    obspack_data = obspack_data.where(bad_data_mask)
    obspack_data = obspack_data.dropna("obs") 

    # reindex so monotoically increasing
    obspack_data = obspack_data.sortby("time").assign_coords(obs=range(0, len(obspack_data.obs)))



    # special mask
    late_mask = np.logical_and(obspack_data["time_components"][:,3] >= 23,
                            obspack_data["time_components"][:,4] >= 55)

    # Desired times
    daily_dates = pd.date_range(SPINUP_START, PERTURB_END)

    for date in daily_dates:
        # select obs from day before
        day_before_mask = date_mask(obspack_data, date - pd.Timedelta(1, "D"))
        late_day_before = np.logical_and(day_before_mask, late_mask)
        
        # select obs from that day
        that_day_mask = date_mask(obspack_data, date)
        
        # remove obs that sample from next day
        late_that_day = np.logical_and(that_day_mask, late_mask)
        
        # combine masks
        combined_2masks = np.logical_or(late_day_before, that_day_mask)
        combined_3masks = np.logical_and(combined_2masks, ~late_that_day)
        
        # Do filtering
        obspack_date = obspack_data.where(combined_3masks, drop=True)
        
        # Geoschem can't read file without this
        for i in range(len(obspack_date["obspack_id"])):
            obspack_date["obspack_id"][i] = obspack_date["obspack_id"][i] + b' ' * (200 - len(obspack_date["obspack_id"].values[i]))

        
        obspack_date.to_netcdf(OBSPACK_DIR /f"obspack_n2o.{date.strftime('%Y%m%d')}.nc")