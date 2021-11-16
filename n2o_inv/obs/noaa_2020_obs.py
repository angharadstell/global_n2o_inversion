"""
This script formats all NOAA 2020 obs into an obspack style.

@author: Angharad Stell
"""
import configparser

import numpy as np
import pandas as pd
from pathlib import Path
import re
import xarray as xr
    
import agage_obs
import format_obspack_geoschem
    
def create_obspack_id(site, year, month, day, identifier):
    """
    Make an obspack id for each observation, following the pattern in the NOAA data.
    """
    date = f"{int(year)}-{int(month):02}-{int(day):02}"
    whole_string = f"obspack_multi-species_1_CCGGSurfaceFlask_v1.0_{date}~n2o_{site.lower()}_surface-flask_1_ccgg_Event~{identifier}"
    return (whole_string).encode()

if __name__ == "__main__":
    """ 
    Read in config global variables
    """

    # read in variables from the config file
    config = configparser.ConfigParser()
    config.read("../../config.ini")
    AGAGE_SITES = config["inversion_constants"]["agage_sites"].split(",")
    RAW_OBSPACK_DIR = Path(config["paths"]["raw_obspack_dir"])
    OBSPACK_DIR = Path(config["paths"]["obspack_dir"])

    # keep track of number of observations so that each obs gets a unique identifier
    noaa_surface_obspack_data = format_obspack_geoschem.read_noaa_obspack(RAW_OBSPACK_DIR / "obspack_multi-species_1_CCGGSurfaceFlask_v2.0_2021-02-09")
    noaa_aircraft_obspack_data = format_obspack_geoschem.read_noaa_obspack(RAW_OBSPACK_DIR / "obspack_multi-species_1_CCGGAircraftFlask_v2.0_2021-02-09")
    max_used_obs = np.max([noaa_surface_obspack_data["obs"].max(), noaa_aircraft_obspack_data["obs"].max()])
    total_obs = max_used_obs + 1

    # get all the NOAA surface data files
    files_dir = RAW_OBSPACK_DIR / "CCGG/surface/N2O/surface"
    files = list(files_dir.glob('*_event.txt'))

    # store site xarray format for merging later
    site_xr_list = []

    # iterate through each site file
    for file in files:
        # extract site name
        site = re.search("/n2o_(.*)_surface", str(file)).group(1)

        # find number of header lines
        with open(file) as f:
            firstline = f.readline().rstrip()
        no_head_lines = int(re.search("# number_of_header_lines: (.*)", firstline).group(1))

        # read in file
        site_file = pd.read_csv(file,
                                sep=' ', skipinitialspace=True, 
                                usecols=[1,2,3,4,5,6,11,12,13,21,22,23], 
                                names=["year", "month", "day", "hour", "minute", "second", 
                                       "value", "value_unc", "qcflag", "latitude", "longitude", "altitude"],
                                header=(no_head_lines+1))

        # time
        time_var = pd.to_datetime(site_file[["year", "month", "day", "hour", "minute", "second"]]).to_numpy()
        unix_time_var = agage_obs.datetime_to_unix(time_var)
        site_file["time"] = unix_time_var

        # only read in data which isnt in the obspack
        final_date = noaa_surface_obspack_data["time"][-1].values
        site_file_2020 = site_file.loc[site_file["time"] > final_date]

        # some sites have no data for 2020, skip these
        if len(site_file_2020) == 0:
            pass
        else:
            # get number of observations for the site
            no_obs = len(site_file_2020)

            # convert pandas to xarray
            site_xr = site_file_2020.to_xarray()

            # time components
            time_var = pd.to_datetime(site_file_2020[["year", "month", "day", "hour", "minute", "second"]]).to_numpy()
            site_xr["time_components"] = (("index", "calendar_components"), agage_obs.dt2cal(time_var))

            # obspack_id
            obspack_id = [create_obspack_id(site, 
                                            site_file_2020["year"].values[i],
                                            site_file_2020["month"].values[i],
                                            site_file_2020["day"].values[i],
                                            (111111111 * (len(AGAGE_SITES) + 2)) + i) for i in range(no_obs)]
            site_xr["obspack_id"] = (("index"), obspack_id)

            # encode qcflag
            qcflag = [i.encode() for i in site_xr["qcflag"].values]
            site_xr["qcflag"] = (("index"), qcflag)

            # drop unneeded time data
            site_xr = site_xr.drop(["year", "month", "day", "hour", "minute", "second"])

            # sort out obs index
            site_xr = site_xr.assign_coords({"obs": (("index"), np.arange(total_obs, total_obs + no_obs))})
            site_xr = site_xr.swap_dims({"index":"obs"})
            site_xr = site_xr.reset_coords()
            site_xr = site_xr.drop("index")

            # store site xarray object
            site_xr_list.append(site_xr)

            # keep track of number of observations so that each obs gets a unique identifier
            total_obs += no_obs

    # merge all the sites and save
    all_sites = xr.merge(site_xr_list)
    all_sites.to_netcdf(OBSPACK_DIR / f"noaa_2020_obs.nc")
