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
    #config.read(Path(__file__).parent.parent.parent / 'config.ini')
    config.read("/home/as16992/global_n2o_inversion/config.ini")
    NO_REGIONS = int(config["inversion_constants"]["no_regions"])
    CASE = config["inversion_constants"]["model_err_case"]
    AGAGE_SITES = config["inversion_constants"]["agage_sites"].split(",")
    GEOS_OUT = Path(config["paths"]["geos_out"])
    OBSPACK_DIR = Path(config["paths"]["obspack_dir"])
    SPINUP_START = pd.to_datetime(config["dates"]["spinup_start"])
    PERTURB_START = pd.to_datetime(config["dates"]["perturb_start"])
    PERTURB_END = pd.to_datetime(config["dates"]["perturb_end"])
    FINAL_END = pd.to_datetime(config["dates"]["final_end"])

    # read in observations
    print("Reading in obs...")
    obspack_raw = process_geos_output.read_obs(OBSPACK_DIR / CASE, SPINUP_START, 
                                               FINAL_END, FINAL_END)
    print("Finding unique sites...")
    list_of_sites, unique_sites = process_geos_output.find_unique_sites(obspack_raw)
    obspack_raw["site"] = (("obs"), np.array(list_of_sites))
    obspack_baseline = obs_baseline.raw_obs_to_baseline(obspack_raw)

    # read in geos output
    obspack_geos = process_geos_output.read_geos(GEOS_OUT / CASE, obspack_baseline,
                                                 NO_REGIONS, PERTURB_START.year, (PERTURB_END.year-1))

    # sum up different regions
    obspack_geos = plot_obs.add_ch4(obspack_geos, NO_REGIONS+1)

    obspack_geos["obs_floor"] = np.floor(obspack_geos["obs"])


    # combine the two datasets
    print("Combining datasets...")
    combined = xr.merge([obspack_baseline[["latitude", "longitude", "altitude",
                                           "time", "obspack_id", "value", 
                                           "value_unc", "network", "site", "baseline"]],
                            obspack_geos])
    combined = combined.rename({"latitude":"obs_lat", "longitude":"obs_lon",
                                "altitude":"obs_alt", "time":"obs_time", 
                                "value":"obs_value", "value_unc":"obs_value_unc"})

    # make dimensions site and time
    print("Sorting out dims...")
    combined = combined.assign_coords(obs_time=combined["obs_time"])
    combined = combined.swap_dims({"obs":"obs_time"})

    # drops air sites and non-baseline points
    combined = combined.where(combined["baseline"], drop=True)

    # rescale AGAGE to NOAA
    agage_mask = combined["network"] == "AGAGEsurf"
    agage_over_noaa_ratio = pd.read_csv(OBSPACK_DIR / "agage_noaa_scaling/agage_over_noaa_ratio.csv", index_col=0).iloc[0].values[0]
    combined["obs_value"][agage_mask] = combined["obs_value"][agage_mask] / agage_over_noaa_ratio

    # combine NOAA sites and AGAGE sites where we have AGAGE data
    for site in AGAGE_SITES:
        combined["site"].loc[combined["site"] == f"{site.lower()}AGAGEsurf"] = f"{site.lower()}NOAGsurf"
        combined["site"].loc[combined["site"] == f"{site.lower()}NOAAsurf"] = f"{site.lower()}NOAGsurf"
    unique_sites = np.unique(combined["site"]) # other function uses obspackid so wont work


    combined.to_netcdf(GEOS_OUT / CASE / "combined.nc")
    # with xr.open_dataset(GEOS_OUT / CASE / "combined.nc") as load:
    #     combined = load.load()
    # unique_sites = np.unique(combined["site"]) # other function uses obspackid so wont work


    # create monthly mean for each site
    print("Making monthly mean...")
    resampled_sites = []
    for site in unique_sites:
        onesite = combined.where(combined["site"] == site, drop=True)
        # remove the extra 8 values for each obs to get correct obs_time
        onesite_ninth = onesite.where(onesite["obs"]  == onesite["obs_floor"], drop=True)
        # work out square of model std for each obs
        model_std_sq = onesite[["CH4_sum", "obs_floor"]].groupby("obs_floor").std() ** 2
        # recombine with correct obs_time
        onesite_ninth["model_std"] = (("obs_time"), model_std_sq["CH4_sum"])
        # calculate error in the mean
        onesite_resampled = onesite_ninth["model_std"].resample(obs_time="M").sum()
        no_obs = onesite_ninth["model_std"].resample(obs_time="M").count()
        onesite_std = (np.sqrt(onesite_resampled) / no_obs)
        resampled_sites.append(onesite_std)


    # recombine sites
    print("Recombining sites...")
    site_combined = xr.concat(resampled_sites, dim="site")
    site_combined["site"] = (("site"), unique_sites)




    # save combined file
    site_combined.to_netcdf(GEOS_OUT / CASE / "model_err.nc")
