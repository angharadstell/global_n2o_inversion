"""
This script reads in the AGAGE observations and formats them to look more like NOAA obspack.
NOAA obspack can be matched to the location and time in GEOSChem.

@author: Angharad Stell
"""

import configparser
from pathlib import Path

import numpy as np

from acrg_obs import read

""" 
Define useful functions
"""

def dt2cal(dt):
    """
    Convert array of datetime64 to a calendar list of year, month, day, hour,
    minute, seconds with these quantites indexed on the last axis.

    Parameters
    ----------
    dt : datetime64 array (...)
        numpy.ndarray of datetimes of arbitrary shape

    Returns
    -------
    cal : float list (..., 6)
        calendar list with last axis representing year, month, day, hour,
        minute, second
    """

    # allocate output 
    out = np.empty(dt.shape + (6,))
    # decompose calendar floors
    Y, M, D, h, m, s = [dt.astype(f"M8[{x}]") for x in "YMDhms"]
    out[..., 0] = Y + 1970 # Gregorian Year
    out[..., 1] = (M - Y) + 1 # month
    out[..., 2] = (D - M) + 1 # day
    out[..., 3] = (dt - D).astype("m8[h]") # hour
    out[..., 4] = (dt - h).astype("m8[m]") # minute
    out[..., 5] = (dt - m).astype("m8[s]") # second

    out = out.tolist()

    return out

def create_obspack_id(site, year, month, day, identifier):
    """
    Make an obspack id for each observation, following the pattern in the NOAA data.
    """
    date = f"{int(year)}-{int(month):02}-{int(day):02}"
    whole_string = f"obspack_multi-species_1_AGAGEInSitu_v1.0_{date}~n2o_{site.lower()}_surface-insitu_1_agage_Event~{identifier}"
    return whole_string.encode()

def create_noaa_style_flag(status_flag, integration_flag):
    """
    Make a NOAA style flag (a 3-character string).
    Note that the AGAGE status and integration flags don't match to the definition of NOAA flags.
    The AGAGE NOAA style flag is currently the first character is the status, the second is the integration.
    """
    if status_flag == 0:
        first_char = "."
    else:
        first_char = "a"

    if integration_flag == 0:
        second_char = "."
    else:
        second_char= "a"

    return f"{first_char}{second_char}.".encode()
    
def datetime_to_unix(array):
    return array.astype('datetime64[s]').astype("int") 

if __name__ == "__main__":
    """ 
    Read in config global variables
    """

    # read in variables from the config file
    config = configparser.ConfigParser()
    config.read(Path(__file__).parent.parent.parent / 'config.ini')
    OBSPACK_DIR = Path(config["paths"]["obspack_dir"])
    SPINUP_START = config["dates"]["spinup_start"]
    PERTURB_END = config["dates"]["perturb_end"]

    """ 
    Read in the AGAGE site observations for the inversion period
    """
    # Are there any other sites?
    sites = ["CGO", "SMO", "RPB", "THD", "MHD"]
    agage_obs = read.get_obs(sites=sites, start_date=SPINUP_START, end_date=PERTURB_END, species="N2O")

    """ 
    Format AGAGE data so it looks more like NOAA obspack
    """

    # keep track of number of observations so that each obs gets a unique identifier
    total_obs = 0

    # iterate through each site, format, and save
    for site in sites:
        print(site)

        # rename to match NOAA
        agage_obs[site][0] = agage_obs[site][0].rename({"mf":"value",
                                                        "mf_repeatability":"value_unc"})

        # get number of observations for the site
        no_obs = len(agage_obs[site][0]["time"])

        # sort out coords
        agage_obs[site][0] = agage_obs[site][0].assign_coords({"obs": (("time"), np.arange(total_obs, total_obs + no_obs))})
        agage_obs[site][0] = agage_obs[site][0].swap_dims({"time":"obs"})
        agage_obs[site][0] = agage_obs[site][0].reset_coords()

        # combine flags like noaa format
        # not really the same though, so be careful
        qcflag = [create_noaa_style_flag(agage_obs[site][0]["status_flag"][i].values, 
                                        agage_obs[site][0]["integration_flag"][i].values) for i in range(no_obs)]
        agage_obs[site][0]["qcflag"] = (("obs"), np.array(qcflag))
        agage_obs[site][0] = agage_obs[site][0].drop_vars(["status_flag", "integration_flag"])

        # calculate measurement height
        station_alt = agage_obs[site][0].station_height_masl + float(agage_obs[site][0].inlet_magl[:-1])
        
        # measurement location
        agage_obs[site][0]["altitude"] = (("obs"), np.array([station_alt] * no_obs))
        agage_obs[site][0]["latitude"] = (("obs"), np.array([agage_obs[site][0].station_latitude] * no_obs))
        agage_obs[site][0]["longitude"] = (("obs"), np.array([agage_obs[site][0].station_longitude] * no_obs))


        # time components
        agage_obs[site][0]["time_components"] = (("obs", "calendar_components"), dt2cal(agage_obs[site][0]["time"].values))

        # make time into unix time
        agage_obs[site][0]["time"] = (("obs"), datetime_to_unix(agage_obs[site][0]["time"].values))

        # obspack_id
        obspack_id = [create_obspack_id(site, 
                                        agage_obs[site][0]["time_components"][i][0].values,
                                        agage_obs[site][0]["time_components"][i][1].values,
                                        agage_obs[site][0]["time_components"][i][2].values,
                                        99999999 + i + total_obs) for i in range(no_obs)]  # hacky way to create unique identifier
        agage_obs[site][0]["obspack_id"] = (("obs"), np.array(obspack_id))

        # keep track of number of observations so that each obs gets a unique identifier
        total_obs += no_obs

        # save
        agage_obs[site][0].to_netcdf(OBSPACK_DIR / f"AGAGE_raw/n2o_{site.lower()}_surface-insitu_1_agage_Event.nc") # still depends on BP1 file structure
