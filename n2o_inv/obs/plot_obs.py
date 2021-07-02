import configparser
from pathlib import Path

from matplotlib.backends.backend_pdf import PdfPages
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
    NO_REGIONS = int(config["inversion_constants"]["no_regions"])
    CASE = config["inversion_constants"]["case"]
    OBSPACK_DIR = Path(config["paths"]["obspack_dir"])
    GEOSOUT_DIR = Path(config["paths"]["geos_out"])
    SPINUP_START = pd.to_datetime(config["dates"]["spinup_start"])
    PERTURB_END = pd.to_datetime(config["dates"]["perturb_end"])
    FINAL_END = pd.to_datetime(config["dates"]["final_end"])
    
    
    # read in observations
    print("Reading in obs...")
    obspack_obs = process_geos_output.read_obs(OBSPACK_DIR, SPINUP_START, 
                                               FINAL_END, FINAL_END)

    print("Finding unique sites...")
    list_of_sites, unique_sites = process_geos_output.find_unique_sites(obspack_obs)
    obspack_obs["site"] = (("obs"), np.array(list_of_sites))

    print("Reading in geos...")
    obspack_geos = process_geos_output.read_geos(GEOSOUT_DIR / CASE, SPINUP_START, obspack_obs, NO_REGIONS)


    combined = xr.merge([obspack_obs[["latitude", "longitude", "altitude",
                                      "time", "obspack_id", "value", 
                                      "value_unc", "network", "site", "qcflag"]],
                         obspack_geos])

    combined = combined.rename({"latitude":"obs_lat", "longitude":"obs_lon",
                                "altitude":"obs_alt", "time":"obs_time", 
                                "value":"obs_value", "value_unc":"obs_value_unc"})

    # sum up different regions
    combined["CH4_sum"] = xr.zeros_like(combined["CH4_R00"])
    for i in range(0, NO_REGIONS+1):
        combined["CH4_sum"] += combined[f"CH4_R{i:02d}"]

    #%config InlineBackend.figure_format = 'png'
    pp = PdfPages(OBSPACK_DIR / 'obs_plots.pdf')
    print("Plotting desired sites...")
    for site in unique_sites:
        if "NOAAair" in site:
            pass
        else:
            onesite = combined.where(combined["site"] == site, drop=True)
              

            any_flag = (onesite["qcflag"] == b'...')
            dodgy_low = (onesite["obs_value"] < 320)

            # also want to plot model base run
            fig = plt.figure()
            onesite.where(any_flag, drop=True).plot.scatter("obs_time", "obs_value")
            onesite.where(~any_flag, drop=True).plot.scatter("obs_time", "obs_value", c="r")
            onesite.where(dodgy_low, drop=True).plot.scatter("obs_time", "obs_value", c="g")
            if all(xr.ufuncs.isnan(onesite["CH4_sum"])):
                pass
            else:
                onesite.plot.scatter("obs_time", "CH4_sum", c="k")
            plt.title(site)
            #plt.show()
            pp.savefig()
            plt.close()
    pp.close()

