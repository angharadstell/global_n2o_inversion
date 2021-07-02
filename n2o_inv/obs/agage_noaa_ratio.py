import configparser
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import xarray as xr

from n2o_inv.intermediates import process_geos_output
    

if __name__ == "__main__":
    # read in variables from the config file
    config = configparser.ConfigParser()
    #config.read(Path(__file__).parent.parent.parent / 'config.ini')
    config.read("/home/as16992/global_n2o_inversion/config.ini")
    AGAGE_SITES = config["inversion_constants"]["agage_sites"].split(",")
    OBSPACK_DIR = Path(config["paths"]["obspack_dir"])
    SPINUP_START = pd.to_datetime(config["dates"]["spinup_start"])
    PERTURB_END = pd.to_datetime(config["dates"]["perturb_end"])
    FINAL_END = pd.to_datetime(config["dates"]["final_end"])
    
    agage_site_store = []

    # look at rescaling AGAGE
    for site in AGAGE_SITES:
        # this is very slow so use previous run if available
        site_filename = OBSPACK_DIR / f"agage_noaa_scaling/{site}.nc"
        if site_filename.is_file():
            with xr.open_dataset(site_filename) as load:
                agage_site = load.load()
        else:
            # read in observations
            print("Reading in obs...")
            obspack_obs = process_geos_output.read_obs(OBSPACK_DIR, SPINUP_START, 
                                                       FINAL_END, FINAL_END)

            # select desired site
            print(f"Extracting {site} obs...")
            agage_site = obspack_obs.where(obspack_obs["site"] == site.lower() + "AGAGEsurf", drop=True)
            noaa_site = obspack_obs.where(obspack_obs["site"] == site.lower() + "NOAAsurf", drop=True)

            # create storage for match data values
            agage_site["noaa_value"] = xr.full_like(agage_site["value"], np.nan, dtype=np.double)

            # select NOAA obs within 15mins of AGAGE obs
            for obs in range(len(agage_site["obs"])):
                # select NOAA obs within 15mins of AGAGE obs
                time_diff = abs((agage_site["time"][obs] - noaa_site["time"]) / 1E9).astype(int)
                close_times = time_diff < (15*60)

                if any(close_times):
                    # take mean if multiple values
                    agage_site["noaa_value"][obs] = noaa_site.where(close_times, drop=True)["value"].mean()

            # store ratio of values
            agage_site["agage-noaa_ratio"] = agage_site["value"] / agage_site["noaa_value"]

            # save for later
            agage_site.to_netcdf(site_filename)


        # plot
        agage_site.plot.scatter("time", "agage-noaa_ratio")

        # store
        agage_site_store.append(agage_site)

    # combine all sites together
    agage_network = xr.merge(agage_site_store)

    # plot
    plt.show()
    plt.close()
    xr.plot.hist(agage_network["agage-noaa_ratio"], bins=30)
    plt.show()

# save
ratio = agage_network["agage-noaa_ratio"].to_dataframe().mean()
print(ratio)
ratio.to_csv(OBSPACK_DIR / f"agage_noaa_scaling/agage_over_noaa_ratio.csv")
