import configparser
import datetime
from n2o_inv.obs.format_obspack_geoschem import PERTURB_END
from pathlib import Path
import re

import numpy as np
import pandas as pd
import xarray as xr

def monthly_mean_obspack_id(site, date):
    """
    Generate a new obspack id for the monthly mean data.
    """
    date = pd.to_datetime(str(date))
    identifier = f"{site}{date.strftime('%Y%m')}"
    obspack_id = f"obspack_multi-species_1_CCGGSurfaceFlask_v2.0_2021-02-09~n2o_{site}_surface-flask_1_ccgg_Event~{identifier}"
    return obspack_id


def obspack_geos_preprocess(ds):
    """
    Preprocess geoschem output for reading into xarray: make coord monotonically increase,
    drop unwanted vars, and turn mf to ppb.
    """ 
    # extract the obspack data for that day
    start_date_mask = (obspack_obs["time"] >= ds.averaging_interval_start.values[0])
    end_date_mask = (obspack_obs["time"] <= ds.averaging_interval_start.values[-1])
    date_mask = np.logical_and(start_date_mask, end_date_mask)

    masked_obspack = obspack_obs.where(date_mask, drop=True)

    # take the obspack dimensions
    if (masked_obspack.obspack_id == ds.obspack_id).values.all():
        ds = ds.assign_coords(obs=masked_obspack.obs.values)
    else:
        raise ValueError("obspack obs and geoschem values don't align")
    
    wanted_var = [f"CH4_R{region:02d}" for region in range(0, NO_REGIONS+1)]
    ds = ds[wanted_var]
    
    ds = ds * 1e9
    
    return ds

def find_unique_sites(combined):
    """
    Extract the site for each observation, and find the unique ones.
    """
    list_of_sites = []

    for i, elem in enumerate(combined["obspack_id"].values):
        site = re.search("~n2o_(.{3})_", elem.decode("utf-8")).group(1)
        network = combined["network"].values[i]
        list_of_sites.append(site+network)

    unique_sites = np.unique(list_of_sites)

    return list_of_sites, unique_sites

if __name__ == "__main__":
    # read in variables from the config file
    config = configparser.ConfigParser()
    config.read(Path(__file__).parent.parent.parent / 'config.ini')
    NO_REGIONS = int(config["inversion_constants"]["no_regions"])
    CASE = config["inversion_constants"]["case"]
    OBSPACK_DIR = Path(config["paths"]["obspack_dir"])
    GEOSOUT_DIR = Path(config["paths"]["geos_out"])
    PERTURB_START = pd.to_datetime(config["dates"]["perturb_start"])

    # read in observations
    print("Reading in obs...")
    obs_files = list(OBSPACK_DIR.glob(f"obspack_n2o.{PERTURB_START.year}*.nc"))
    obs_files.sort()
    with xr.open_mfdataset(obs_files) as load:
        obspack_obs = load.load()

    # read in geoschem output in each directory
    for output_dir in GEOSOUT_DIR.iterdir():
        
        print(output_dir)

        print("Reading in geos...")
        geos_files = list(output_dir.glob(f"GEOSChem.ObsPack.{PERTURB_START.year}*_0000z.nc4"))
        geos_files.sort()
        with xr.open_mfdataset(geos_files, preprocess=obspack_geos_preprocess) as load:
            obspack_geos = load.load()

        # combine the two datasets
        print("Combining datasets...")
        combined = xr.merge([obspack_obs[["latitude", "longitude", "altitude",
                                            "time", "obspack_id", "value", 
                                            "value_unc", "network"]],
                                obspack_geos])
        combined = combined.rename({"latitude":"obs_lat", "longitude":"obs_lon",
                                    "altitude":"obs_alt", "time":"obs_time", 
                                    "value":"obs_value", "value_unc":"obs_value_unc"})

        # find uniqe sites
        print("Finding unique sites...")
        list_of_sites, unique_sites = find_unique_sites(combined)

        # make dimensions site and time
        print("Sorting out dims...")
        combined = combined.assign_coords(obs_time=combined["obs_time"])
        combined["site"] = (("obs"), np.array(list_of_sites))
        combined = combined.swap_dims({"obs":"obs_time"})

        # create monthly mean for each site
        print("Making monthly mean...")
        resampled_sites = []
        for site in unique_sites:
            onesite = combined.where(combined["site"] == site, drop=True)
            onesite["obs_value_unc"] = onesite["obs_value_unc"] ** 2
            onesite_resampled = onesite.resample(obs_time="M").mean()
            no_samples = onesite.resample(obs_time="M").count()
            onesite_resampled["obs_value_unc"] = np.sqrt(onesite_resampled["obs_value_unc"]) / np.sqrt(no_samples["obs_value_unc"])
            resampled_sites.append(onesite_resampled)

        # recombine sites
        print("Recombining sites...")
        site_combined = xr.concat(resampled_sites, dim="site")
        site_combined["site"] = (("site"), unique_sites)

        # generate new obspack_id
        print("Making new obspack_id...")
        site_combined["obspack_id"] = xr.zeros_like(site_combined["obs_value"], dtype='<U200')
        for i, site in enumerate(site_combined["site"].values):
            for j, time in enumerate(site_combined["obs_time"].values):
                site_combined["obspack_id"][i, j] = monthly_mean_obspack_id(site, time)

        # sum different regions if base 
        if str(output_dir)[-4:] == CASE:
            # sum up different regions
            site_combined["CH4_sum"] = xr.zeros_like(site_combined["CH4_R00"])
            for i in range(0, NO_REGIONS+1):
                site_combined["CH4_sum"] += site_combined[f"CH4_R{i:02d}"]

        # save combined file
        site_combined.to_netcdf(output_dir / "combined_mf.nc")
