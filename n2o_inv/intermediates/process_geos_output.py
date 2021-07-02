import configparser
from pathlib import Path
import re
import sys

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

def obspack_geos_preprocess(ds, obspack_obs, no_regions):
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
    
    wanted_var = [f"CH4_R{region:02d}" for region in range(0, no_regions+1)]
    ds = ds[wanted_var]
    
    ds = ds * 1e9
    
    return ds

def read_obs(obspack_dir, spinup_start, perturb_end, final_end):
    """
    Read in obspack observation files as xarray dataset.
    """
    all_obs_files = set(obspack_dir.glob("obspack_n2o.*.nc"))
    unwanted_obs_files = list(obspack_dir.glob(f"obspack_n2o.{spinup_start.year}*.nc"))
    if final_end != perturb_end:
        for year in range(perturb_end.year, final_end.year):
            unwanted_obs_files = unwanted_obs_files + list(obspack_dir.glob(f"obspack_n2o.{year}*.nc"))

    obs_files = list(all_obs_files - set(unwanted_obs_files))
    obs_files.sort()
    with xr.open_mfdataset(obs_files) as load:
        obspack_obs = load.load()
    return obspack_obs

def read_geos(output_dir, spinup_start, obspack_obs, no_regions):
    """
    Read in obspack geoschem files as xarray dataset.
    """
    geos_files = list(set(output_dir.glob("GEOSChem.ObsPack.*_0000z.nc4")) - set(output_dir.glob(f"GEOSChem.ObsPack.{spinup_start.year}*_0000z.nc4")))
    geos_files.sort()

    # if first day of year end pressent, remove
    print("checking last file to be read in")
    if "0101_0000z.nc4" in str(geos_files[-1]):
        geos_files = geos_files[:-1]
    # check stopping in right place
    print(geos_files[-1])

    with xr.open_mfdataset(geos_files, 
                           preprocess=lambda ds: obspack_geos_preprocess(ds, obspack_obs, no_regions)) as load:
        obspack_geos = load.load()
    return obspack_geos

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
    #config.read(Path(__file__).parent.parent.parent / 'config.ini')
    config.read(sys.argv[1] + '/../../config.ini')
    NO_REGIONS = int(config["inversion_constants"]["no_regions"])
    CASE = config["inversion_constants"]["case"]
    AGAGE_SITES = config["inversion_constants"]["agage_sites"].split(",")
    OBSPACK_DIR = Path(config["paths"]["obspack_dir"])
    GEOSOUT_DIR = Path(config["paths"]["geos_out"])
    PERTURB_START = pd.to_datetime(config["dates"]["perturb_start"])
    SPINUP_START = pd.to_datetime(config["dates"]["spinup_start"])
    PERTURB_END = pd.to_datetime(config["dates"]["perturb_end"])
    FINAL_END = pd.to_datetime(config["dates"]["final_end"])

    # read in observations
    print("Reading in obs...")
    obspack_obs = read_obs(OBSPACK_DIR, SPINUP_START, PERTURB_END, FINAL_END)

    # read in geoschem output in each directory
    geoschem_out_dirs = list(GEOSOUT_DIR.iterdir())
    iterator = int(sys.argv[2])
    print(iterator)
    output_dir = geoschem_out_dirs[iterator]
    print(output_dir)

    print("Reading in geos...")
    obspack_geos = read_geos(output_dir, SPINUP_START, obspack_obs, NO_REGIONS)

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

    # drop air sites
    combined = combined.where(~combined["site"].str.contains("NOAAair"), drop=True)

    # drop NOAA sites where we have AGAGE data
    noaa_sites_to_drop = [site.lower() + "NOAAsurf" for site in AGAGE_SITES]
    for site in noaa_sites_to_drop:
        combined = combined.where(combined["site"] != site, drop=True)
    _, unique_sites = find_unique_sites(combined)
    # rescale AGAGE to NOAA
    agage_mask = combined["network"] == "AGAGEsurf"
    agage_over_noaa_ratio = pd.read_csv(OBSPACK_DIR / "agage_noaa_scaling/agage_over_noaa_ratio.csv", index_col=0).iloc[0].values[0]
    combined["obs_value"][agage_mask] = combined["obs_value"][agage_mask] / agage_over_noaa_ratio

    # create monthly mean for each site
    print("Making monthly mean...")
    resampled_sites = []
    for site in unique_sites:
        onesite = combined.where(combined["site"] == site, drop=True)
        onesite_resampled = onesite.resample(obs_time="M").mean()
        onesite_resampled["obs_value_unc"] = onesite["obs_value"].resample(obs_time="M").std()
        # if only one point, std is nan...
        onesite_resampled["obs_value_unc"] = onesite_resampled["obs_value_unc"].where(~xr.ufuncs.isnan(onesite_resampled["obs_value_unc"]), 
                                                                                      onesite["obs_value_unc"].median())
        # if uncertainty is zero, e.g. two identical measurements, take typical value...
        onesite_resampled["obs_value_unc"] = onesite_resampled["obs_value_unc"].where(onesite_resampled["obs_value_unc"] != 0, 
                                                                                      onesite["obs_value_unc"].median())
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
    else:
        # in perturbed runs, all months before perturbation shouldn't exist
        # some do without this code because the obspack contains 23:55-23:59 of the 
        # last day of the month
        year = int(str(output_dir)[-6:-2])
        month = int(str(output_dir)[-2:])
        site_combined = site_combined.where(site_combined["obs_time"] >= np.datetime64(f"{year}-{month:02d}-01"))

    # save combined file
    site_combined.to_netcdf(output_dir / "combined_mf.nc")
