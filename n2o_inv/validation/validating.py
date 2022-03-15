import configparser
from pathlib import Path

import matplotlib.pyplot as plt 
import numpy as np
import pandas as pd
import xarray as xr

from n2o_inv.intermediates import process_geos_output

def read_geos(hippo_obs, geos_dir, n_regions):
    hippo_geos = process_geos_output.read_geos(geos_dir,
                                               hippo_obs, n_regions, 2011, 2011)

    hippo_geos["CH4_sum"] = xr.zeros_like(hippo_geos["CH4_R00"])
    for i in range(0, n_regions+1):
        hippo_geos["CH4_sum"] += hippo_geos[f"CH4_R{i:02d}"]
    
    return hippo_geos

def zonal_plot(hippo_obs, hippo_geos_prior, hippo_geos_post, campaign_name, filename):
    low_mask = np.logical_and(hippo_obs["altitude"] > 1000, hippo_obs["altitude"] <= 3000)
    high_mask = np.logical_and(hippo_obs["altitude"] > 3000, hippo_obs["altitude"] <= 7000)

    hippo_obs_low = hippo_obs.where(low_mask, drop=True)
    hippo_geos_prior_low = hippo_geos_prior.where(low_mask, drop=True)
    hippo_geos_post_low = hippo_geos_post.where(low_mask, drop=True)
    hippo_obs_high = hippo_obs.where(high_mask, drop=True)
    hippo_geos_prior_high = hippo_geos_prior.where(high_mask, drop=True)
    hippo_geos_post_high = hippo_geos_post.where(high_mask, drop=True)

    fig, axs = plt.subplots(2, sharex=True, sharey=True)

    axs[0].set_title(f"a. {campaign_name}, 1-3 km", loc="left")
    axs[0].scatter(hippo_obs_low["latitude"], hippo_obs_low["value"], label = "observed")
    axs[0].scatter(hippo_obs_low["latitude"], hippo_geos_prior_low["CH4_sum"], label = "prior")
    axs[0].scatter(hippo_obs_low["latitude"], hippo_geos_post_low["CH4_sum"], label = "posterior")
    axs[0].legend(bbox_to_anchor=(1.3, 0.15), fontsize="medium")

    axs[1].set_title(f"\n b. {campaign_name}, 3-7 km", loc="left")
    axs[1].scatter(hippo_obs_high["latitude"], hippo_obs_high["value"], label = "observed")
    axs[1].scatter(hippo_obs_high["latitude"], hippo_geos_prior_high["CH4_sum"], label = "prior")
    axs[1].scatter(hippo_obs_high["latitude"], hippo_geos_post_high["CH4_sum"], label = "posterior")

    for ax in axs.flat:
        ax.set(xlabel='Latitude / $^\circ$')
        ax.label_outer()

    fig.text(0.01, 0.5, 'N$_2$O Mole fraction / ppb', va='center', rotation='vertical', size="large", color="#555555")

    plt.subplots_adjust(hspace=0.3)

    plt.savefig(filename, bbox_inches='tight')
    plt.show()
    plt.close()


if __name__ == "__main__":
    # read in variables from the config file
    config = configparser.ConfigParser()
    config.read("../../config.ini")
    NO_REGIONS = int(config["inversion_constants"]["no_regions"])
    DATA_DIR = Path(config["paths"]["data_dir"])
    OBSPACK_DIR = Path(config["paths"]["obspack_dir"])
    GEOSOUT_DIR = Path(config["paths"]["geos_out"])
    BASE_CASE = config["inversion_constants"]["case"]
    VALIDATION_CASE = config["inversion_constants"]["validation_case"]
    
    # read in observations
    print("Reading in obs...")
    with xr.open_dataset(OBSPACK_DIR / "baseline_obs.nc") as load:
        obspack_raw = load.load()

    # select observations
    #.where(obspack_raw["network"] == "NOAAair", drop=True)
    #.where(obspack_raw["baseline"] == 1, drop=True)
    #.where(obspack_raw["site"] == "hipNOAAair", drop=True)
    hippo_obs = obspack_raw.where(obspack_raw["site"] == "hipNOAAair", drop=True)
    hippo_obs = hippo_obs.where(hippo_obs["time"] >= pd.to_datetime(f"2011-01-01"), drop=True)
    hippo_obs = hippo_obs.where(hippo_obs["time"] < pd.to_datetime(f"2011-12-13 23:55"), drop=True)

    hippo_obs_4 = hippo_obs.where(hippo_obs["time"] <= pd.to_datetime(f"2011-07-31"), drop=True)
    hippo_obs_5 = hippo_obs.where(hippo_obs["time"] > pd.to_datetime(f"2011-07-31"), drop=True)

    # read in geoschem run
    hippo_geos_post_4 = read_geos(hippo_obs_4, GEOSOUT_DIR / VALIDATION_CASE, NO_REGIONS)
    hippo_geos_post_5 = read_geos(hippo_obs_5, GEOSOUT_DIR / VALIDATION_CASE, NO_REGIONS)
    hippo_geos_prior_4 = read_geos(hippo_obs_4, GEOSOUT_DIR / BASE_CASE, NO_REGIONS)
    hippo_geos_prior_5 = read_geos(hippo_obs_5, GEOSOUT_DIR / BASE_CASE, NO_REGIONS)

    #print differences to obs
    diff = (hippo_geos_prior_4["CH4_sum"] - hippo_obs_4["value"]).mean().values
    print(f"prior - HIPP04 (model - obs): {diff:.2f} ppb")
    diff = (hippo_geos_prior_5["CH4_sum"] - hippo_obs_5["value"]).mean().values
    print(f"prior - HIPP05 (model - obs): {diff:.2f} ppb")
    diff = (hippo_geos_post_4["CH4_sum"] - hippo_obs_4["value"]).mean().values
    print(f"post - HIPP04 (model - obs): {diff:.2f} ppb")
    diff = (hippo_geos_post_5["CH4_sum"] - hippo_obs_5["value"]).mean().values
    print(f"post - HIPP05 (model - obs): {diff:.2f} ppb")

    # zonal plot
    with plt.style.context('ggplot'):
        zonal_plot(hippo_obs_4, hippo_geos_prior_4, hippo_geos_post_4,
                   "HIPPO IV", DATA_DIR / VALIDATION_CASE / "hippo4.pdf")
        zonal_plot(hippo_obs_5, hippo_geos_prior_5, hippo_geos_post_5,
                   "HIPPO V", DATA_DIR / VALIDATION_CASE / "hippo5.pdf")
