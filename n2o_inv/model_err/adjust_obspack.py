import configparser

import pandas as pd
from pathlib import Path
import xarray as xr

def reformat_obspack_id(old_obs, add_str):
    new_obspack = []
    for i in old_obs["obspack_id"].values:
        new_id = i.strip() + add_str
        new_obspack.append(new_id + b' ' * (200 - len(new_id)))

    return new_obspack

def surround_obspack(obspack_nc):
    lon_25_lat000 = obspack_nc.copy()
    lon025_lat000 = obspack_nc.copy()
    lon000_lat020 = obspack_nc.copy()
    lon000_lat_20 = obspack_nc.copy()

    lon_25_lat_20 = obspack_nc.copy()
    lon025_lat_20 = obspack_nc.copy()
    lon025_lat020 = obspack_nc.copy()
    lon_25_lat020 = obspack_nc.copy()

    lon_25_lat000["longitude"] = obspack_nc["longitude"] - 5.0
    lon025_lat000["longitude"] = obspack_nc["longitude"] + 5.0
    lon000_lat020["latitude"] = obspack_nc["latitude"] - 4.0
    lon000_lat_20["latitude"] = obspack_nc["latitude"] + 4.0

    lon_25_lat_20["longitude"] = obspack_nc["longitude"] - 5.0
    lon_25_lat_20["latitude"] = obspack_nc["latitude"] - 4.0

    lon025_lat_20["longitude"] = obspack_nc["longitude"] + 5.0
    lon025_lat_20["latitude"] = obspack_nc["latitude"] - 4.0

    lon025_lat020["longitude"] = obspack_nc["longitude"] + 5.0
    lon025_lat020["latitude"] = obspack_nc["latitude"] + 4.0

    lon_25_lat020["longitude"] = obspack_nc["longitude"] - 5.0
    lon_25_lat020["latitude"] = obspack_nc["latitude"] + 4.0

    lon_25_lat000["obs"] = obspack_nc["obs"] + 1/9
    lon025_lat000["obs"] = obspack_nc["obs"] + 2/9
    lon000_lat020["obs"] = obspack_nc["obs"] + 3/9
    lon000_lat_20["obs"] = obspack_nc["obs"] + 4/9
    lon_25_lat_20["obs"] = obspack_nc["obs"] + 5/9
    lon025_lat_20["obs"] = obspack_nc["obs"] + 6/9
    lon025_lat020["obs"] = obspack_nc["obs"] + 7/9
    lon_25_lat020["obs"] = obspack_nc["obs"] + 8/9

    lon_25_lat000["obspack_id"].values = reformat_obspack_id(obspack_nc, b".1")
    lon025_lat000["obspack_id"].values = reformat_obspack_id(obspack_nc, b".2")
    lon000_lat020["obspack_id"].values = reformat_obspack_id(obspack_nc, b".3")
    lon000_lat_20["obspack_id"].values = reformat_obspack_id(obspack_nc, b".4")
    lon_25_lat_20["obspack_id"].values = reformat_obspack_id(obspack_nc, b".5")
    lon025_lat_20["obspack_id"].values = reformat_obspack_id(obspack_nc, b".6")
    lon025_lat020["obspack_id"].values = reformat_obspack_id(obspack_nc, b".7")
    lon_25_lat020["obspack_id"].values = reformat_obspack_id(obspack_nc, b".8")

    merged = xr.merge([obspack_nc, lon_25_lat000, lon025_lat000,
                       lon000_lat020, lon000_lat_20, lon_25_lat_20,
                       lon025_lat_20, lon025_lat020, lon_25_lat020])

    # could be doubles at poles
    # this does mean anything at the poles repeats so will have an artificially low std...
    merged["latitude"] = xr.where(merged["latitude"] > 90, 
                                  90.0,
                                  merged["latitude"])

    merged["latitude"] = xr.where(merged["latitude"] < -90, 
                                  -90.0,
                                  merged["latitude"])

    merged["longitude"] = xr.where(merged["longitude"] < -180, 
                                  180 + (merged["longitude"] + 180),
                                  merged["longitude"])

    merged["longitude"] = xr.where(merged["longitude"] >= 180, 
                                  (merged["longitude"] - 180) - 180,
                                  merged["longitude"])

    return merged



if __name__ == "__main__":
    """ 
    Read in config global variables
    """

    # read in variables from the config file
    config = configparser.ConfigParser()
    config.read('../../config.ini')
    RAW_OBSPACK_DIR = Path(config["paths"]["raw_obspack_dir"])
    OBSPACK_DIR = Path(config["paths"]["obspack_dir"])
    SPINUP_START = config["dates"]["spinup_start"]
    FINAL_END = config["dates"]["final_end"]

    daily_dates = pd.date_range(SPINUP_START, FINAL_END)[:-1]
    for date in daily_dates:
        formatted_date = date.strftime('%Y%m%d')
        # read in original xarray file
        # xarray messes up the times without turning off decode_times
        with xr.open_dataset(OBSPACK_DIR / f"obspack_n2o.{formatted_date}.nc", decode_times=False) as load:
            obspack_nc = load.load()

        # make new surrounding obspack
        new_obpack = surround_obspack(obspack_nc)

        # save 
        new_obpack.to_netcdf(OBSPACK_DIR / f"model_err/obspack_n2o.{formatted_date}.nc", 
                             encoding={"obs":{"dtype":"float64"}})
