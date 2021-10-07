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
    obspack_dir = obspack_folder / "data/nc" 
    n2o_files = list(obspack_dir.glob("n2o_*"))
    n2o_files.sort()

    # Read into xarray
    with xr.open_mfdataset(n2o_files, preprocess=preprocess, decode_times=False) as load:
        noaa_obspack_data = load.load() 
    
    return noaa_obspack_data

def geoschem_date_mask(obspack_data, date):
    """
    Create a mask that runs from 23.55 for 24h, because geoschem timestep is 10min.
    """
    late_mask = np.logical_and(obspack_data["time_components"][:,3] >= 23,
                            obspack_data["time_components"][:,4] >= 55)

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

    return combined_3masks


if __name__ == "__main__":
    """ 
    Read in config global variables
    """

    # read in variables from the config file
    config = configparser.ConfigParser()
    #config.read(Path(__file__).parent.parent.parent / 'config.ini')
    config.read("/home/as16992/global_n2o_inversion/config.ini")
    RAW_OBSPACK_DIR = Path(config["paths"]["raw_obspack_dir"])
    OBSPACK_DIR = Path(config["paths"]["obspack_dir"])
    SPINUP_START = config["dates"]["spinup_start"]
    FINAL_END = config["dates"]["final_end"]
    CONSTANT_START = config["dates"]["constant_start"]
    CONSTANT_END = config["dates"]["constant_end"]
    CONSTANT_CASE = config["inversion_constants"]["constant_case"]

    """ 
    Read in desired obspacks
    """

    # Read in NOAA obs
    noaa_surface_obspack_data = read_noaa_obspack(RAW_OBSPACK_DIR / "obspack_multi-species_1_CCGGSurfaceFlask_v2.0_2021-02-09")
    noaa_aircraft_obspack_data = read_noaa_obspack(RAW_OBSPACK_DIR / "obspack_multi-species_1_CCGGAircraftFlask_v2.0_2021-02-09")

    # add in 2020 NOAA data
    with xr.open_dataset(OBSPACK_DIR / f"noaa_2020_obs.nc") as load:
        noaa_2020_data = load.load() 
    noaa_surface_obspack_data = xr.merge([noaa_surface_obspack_data, noaa_2020_data])

    # Read in AGAGE obs
    agage_obs_dir = OBSPACK_DIR / "AGAGE_raw"
    agage_n2o_files = list(agage_obs_dir.glob("n2o_*"))
    agage_n2o_files.sort()

    with xr.open_mfdataset(agage_n2o_files, decode_times=False) as load:
        agage_obspack_data = load.load() 

    # add in network variable
    noaa_surface_obspack_data["network"] = (("obs"), np.array(["NOAAsurf"] * len(noaa_surface_obspack_data["obs"])))
    noaa_aircraft_obspack_data["network"] = (("obs"), np.array(["NOAAair"] * len(noaa_aircraft_obspack_data["obs"])))
    agage_obspack_data["network"] = (("obs"), np.array(["AGAGEsurf"] * len(agage_obspack_data["obs"])))

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
    # some aircraft have missing uncertainty - replace with median value
    obspack_data["value_unc"] = obspack_data.value_unc.fillna(obspack_data.value_unc.median())
    # large number of missing lat/lon/alt because it looks like there are calibration sites? BLD and TST
    obspack_data = obspack_data.dropna("obs") 
    # do I want to ignore col 2 too?
    bad_data_mask = [flag.decode('utf-8')[0] == "." for flag in obspack_data.qcflag.values]
    bad_data_mask = xr.DataArray(data=bad_data_mask, dims=["obs"], coords={"obs":obspack_data.obs})
    obspack_data = obspack_data.where(bad_data_mask, drop=True)

    # reindex so monotoically increasing
    obspack_data = obspack_data.sortby("time").assign_coords(obs=range(0, len(obspack_data.obs)))




    # Desired times
    daily_dates = pd.date_range(SPINUP_START, FINAL_END)[:-1]
    constant_met_dates = pd.date_range(CONSTANT_END, FINAL_END)[:-1]

    # geoschem wants a series of daily files
    for date in daily_dates:
        # create mask - geoschem reads 23.55 form the day before, through to 23.55 that day
        geoschem_mask = geoschem_date_mask(obspack_data, date)
        # Do filtering
        obspack_date = obspack_data.where(geoschem_mask, drop=True)
        
        # Geoschem can't read file without this
        for i in range(len(obspack_date["obspack_id"])):
            obspack_date["obspack_id"][i] = obspack_date["obspack_id"][i] + b' ' * (200 - len(obspack_date["obspack_id"].values[i]))

        # save file
        if len(obspack_date["obs"]) > 0: 
            obspack_date.to_netcdf(OBSPACK_DIR /f"obspack_n2o.{date.strftime('%Y%m%d')}.nc")

            if date in constant_met_dates:
                constant_met_year = pd.to_datetime(CONSTANT_START).year
                no_years_constant = date.year - constant_met_year

                obspack_date_copy = obspack_date.copy(deep=True)

                # edit time components and time
                # try to move 29th feb to 28th
                for i in range(len(obspack_date_copy["time_components"])):
                    obspack_date_copy["time_components"][i][0] = np.float64(constant_met_year)
                    if obspack_date_copy["time_components"][i][1] == 2 and obspack_date_copy["time_components"][i][2] == 29:
                        leap_year = True
                        obspack_date_copy["time_components"][i][2] = 28
                    else:
                        leap_year = False
                time_minus_year = pd.to_datetime(obspack_date_copy["time"].values, unit="s")  - pd.offsets.DateOffset(years=no_years_constant)
                # put back into seconds since 1970
                obspack_date_copy["time"].values = (time_minus_year - pd.to_datetime("1970-01-01")).total_seconds()

                # save 28th feb for leap year combinations
                if obspack_date["time_components"][i][1] == 2 and obspack_date["time_components"][i][2] == 28:
                    obspack_date_0228 = obspack_date_copy.copy(deep=True)

                if leap_year:
                    obspack_date_copy = obspack_date_copy.merge(obspack_date_0228)

                # create directory if doesnt exist
                constant_met_path = OBSPACK_DIR / f"{CONSTANT_CASE}/su_{no_years_constant:02d}"
                constant_met_path.mkdir(parents=True, exist_ok=True)

                # save final
                if leap_year:
                    obspack_date_copy.to_netcdf(constant_met_path / f"obspack_n2o.{constant_met_year}{date.strftime('%m')}28.nc")
                else:
                    obspack_date_copy.to_netcdf(constant_met_path / f"obspack_n2o.{constant_met_year}{date.strftime('%m%d')}.nc")
