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
    # match to obspack based on id
    intersection = np.intersect1d(ds.obspack_id, obspack_obs.obspack_id, return_indices=True)
    # need to make ds obs have the same values as the observations obs
    intersection_indices_obs = np.sort(intersection[2])
    intersection_indices_geo = np.sort(intersection[1])

    # only process if file contains desired obs, otherwise this function returns None
    if len(intersection[2]) > 0:
        # geoschem file might contain unwanted ob, remove these
        if len(obspack_obs.obspack_id[intersection_indices_obs]) < len(ds.obspack_id.values):
            ds = ds.isel(obs=intersection_indices_geo, drop=True)
            
        # take the obspack dimensions
        if (obspack_obs.obspack_id[intersection_indices_obs].values == ds.obspack_id.values).all():
            ds = ds.assign_coords(obs=obspack_obs.obs[intersection_indices_obs].values)
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

def read_geos(output_dir, obspack_obs, no_regions, first_year, last_year):
    """
    Read in obspack geoschem files as xarray dataset.
    """
    geos_files = []
    for y in range(first_year, last_year+1):
        geos_files.extend(list(output_dir.glob(f"GEOSChem.ObsPack.{y}*_0000z.nc4")))
    geos_files.sort()

    # if first day of month present, remove
    print("checking last file to be read in")
    if "01_0000z.nc4" in str(geos_files[-1]):
        geos_files = geos_files[:-1]
    # check stopping in right place
    print(geos_files[-1])

    xr_list = []
    for ds in geos_files:
        with  xr.open_dataset(ds) as load:
            ds_pp = obspack_geos_preprocess(load.load(), obspack_obs, no_regions)
        xr_list.append(ds_pp)
    
    obspack_geos = xr.concat(filter(None, xr_list), dim="obs")
    
    return obspack_geos

def read_geos_constant(output_dir, obspack_obs, no_regions, first_year, last_year):
    """
    Read in obspack geoschem files as xarray dataset for constant met run.
    """
    obspack_geos_list = []
    for output_dir_ext in sorted((output_dir).glob("su_??")):
        print(output_dir_ext)
        obspack_geos = read_geos(output_dir_ext, obspack_obs, no_regions, first_year, last_year)
        obspack_geos_list.append(obspack_geos)

    complete_obspack_geos = xr.merge(obspack_geos_list)
    return complete_obspack_geos

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

def monthly_measurement_unc(onesite):
    """
    Calculate the monthly mean measurement error.
    """
    # get variation in measurements over month and typical measurement error
    onesite_resampled_unc_std = onesite["obs_value"].resample(obs_time="M").std()
    onesite_resampled_unc_med = onesite["obs_value_unc"].resample(obs_time="M").median()
    # if only one point, std is nan...
    onesite_resampled_unc_comb = onesite_resampled_unc_std.where(~np.isnan(onesite_resampled_unc_std), 
                                                                 onesite_resampled_unc_med)
    # or if small number of obs etc, can easily get small std, so use typical value if that uncertainty is greater
    onesite_resampled_unc_comb = onesite_resampled_unc_comb.where(onesite_resampled_unc_std > onesite_resampled_unc_med, 
                                                                  onesite_resampled_unc_med)

    return onesite_resampled_unc_comb


if __name__ == "__main__":
    # read in variables from the config file
    config = configparser.ConfigParser()
    config.read('../../config.ini')
    NO_REGIONS = int(config["inversion_constants"]["no_regions"])
    CASE = config["inversion_constants"]["case"]
    CONSTANT_CASE = config["inversion_constants"]["constant_case"]
    AGAGE_SITES = config["inversion_constants"]["agage_sites"].split(",")
    OBSPACK_DIR = Path(config["paths"]["obspack_dir"])
    GEOSOUT_DIR = Path(config["paths"]["geos_out"])
    SPINUP_START = pd.to_datetime(config["dates"]["spinup_start"])
    FINAL_END = pd.to_datetime(config["dates"]["final_end"])
    CONSTANT_END = pd.to_datetime(config["dates"]["constant_end"])

    # commandline arguments
    iterator = int(sys.argv[1])   # index of output folder to process
    first_year = int(sys.argv[2]) # first year to process geoschem output for
    last_year = int(sys.argv[3])  # last year to process geoschem output for
    output_file = sys.argv[4]     # name of output mole fraction file to save

    # read in geoschem output in each directory
    geoschem_out_dirs = list(sorted(GEOSOUT_DIR.iterdir()))
    print(iterator)
    output_dir = geoschem_out_dirs[iterator]
    print(output_dir)

    # read in observations
    print("Reading in obs...")
    obs_file = OBSPACK_DIR / "baseline_obs.nc"
    if obs_file.is_file():
        with xr.open_dataset(obs_file) as load:
            obspack_obs = load.load()
    else:
        raise IOError("Need to create a baseline obsfile!")

    # cut unwanted years
    obspack_obs = obspack_obs.where(obspack_obs["time"] >= pd.to_datetime(f"{first_year - 1}-12-31 23:55"), drop=True)
    obspack_obs = obspack_obs.where(obspack_obs["time"] < pd.to_datetime(f"{last_year}-12-31 23:55"), drop=True)

    print("Reading in geos...")
    # no point including obs before constant met period
    if str(output_dir)[-12:] == CONSTANT_CASE:
        obspack_obs = obspack_obs.where(obspack_obs["time"] > CONSTANT_END, drop=True)
        obspack_geos = read_geos_constant(output_dir, obspack_obs, NO_REGIONS, first_year, last_year)
    else:
        obspack_geos = read_geos(output_dir, obspack_obs, NO_REGIONS, first_year, last_year)

    # combine the two datasets
    print("Combining datasets...")
    combined = xr.merge([obspack_obs[["latitude", "longitude", "altitude",
                                        "time", "obspack_id", "value", 
                                        "value_unc", "network", "site", "baseline"]],
                            obspack_geos])
    combined = combined.rename({"latitude":"obs_lat", "longitude":"obs_lon",
                                "altitude":"obs_alt", "time":"obs_time", 
                                "value":"obs_value", "value_unc":"obs_value_unc"})

    # dont want 23:55-23:59 from previous year
    combined = combined.where(combined["obs_time"] >= pd.to_datetime(f"{first_year}-01-01"), drop=True)

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

    # create monthly mean for each site
    print("Making monthly mean...")
    resampled_sites = []
    for site in unique_sites:
        onesite = combined.where(combined["site"] == site, drop=True)
        onesite_resampled = onesite.resample(obs_time="M").mean()
        # calculate measurement uncertainty
        onesite_resampled["obs_value_unc"] = monthly_measurement_unc(onesite)
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
    if (str(output_dir)[-4:] == CASE) or (str(output_dir)[-12:] == CONSTANT_CASE):
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


    # drop baseline, no longer means anything
    site_combined = site_combined.drop_vars("baseline")

    # save combined file
    site_combined.to_netcdf(output_dir / output_file)
