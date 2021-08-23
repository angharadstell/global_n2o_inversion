"""
This module establishes which observations we want to keep.

@author: Angharad Stell
"""

import configparser
#import os
from pathlib import Path

#from matplotlib.backends.backend_pdf import PdfPages
#import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import xarray as xr

#from sklearn.ensemble import IsolationForest

#from baseline import create_datasets

def toYearFraction(date):

    year = date.year
    startOfThisYear = pd.Timestamp(f'{year}-01-01')
    startOfNextYear = pd.Timestamp(f'{year+1}-01-01')

    yearElapsed = date - startOfThisYear
    yearDuration = startOfNextYear - startOfThisYear
    fraction = yearElapsed/yearDuration

    return date.year + fraction

if __name__ == "__main__":
    # read in variables from the config file
    config = configparser.ConfigParser()
    config.read(Path(__file__).parent.parent.parent / 'config.ini')
    #config.read("/home/as16992/global_n2o_inversion/config.ini")
    OBSPACK_DIR = Path(config["paths"]["obspack_dir"])
    
    
    # read in observations
    print("Reading in obs...")
    with xr.open_dataset(OBSPACK_DIR / "raw_obs.nc") as load:
        obspack_obs = load.load()

    # create place to store baseline
    obspack_obs["baseline"] = xr.zeros_like(obspack_obs["value"])

    # pick a site
    unique_sites = np.unique(obspack_obs["site"])

    # sites that look visibly dodgy
    dodgy_sites = ['abpNOAAsurf', 'balNOAAsurf', 'bmeNOAAsurf', 'bscNOAAsurf',  # too few obs
                   'bwdNOAAsurf', 'crsNOAAsurf', 'hfmNOAAsurf', 'lacNOAAsurf',
                   'llbNOAAsurf', 'mknNOAAsurf', 'mrcNOAAsurf', 'mshNOAAsurf',
                   'mvyNOAAsurf', 'nebNOAAsurf', 'nwbNOAAsurf', 'pcoNOAAsurf',
                   'pocNOAAsurf', 'ptaNOAAsurf', 'tacNOAAsurf', 'tmdNOAAsurf',
                   'tpiNOAAsurf',
                   'amyNOAAsurf', 'cibNOAAsurf', 'hpbNOAAsurf', 'hunNOAAsurf',  # polluted
                   'inxNOAAsurf', 'lefNOAAsurf', 'lewNOAAsurf', 'oxkNOAAsurf',
                   'sctNOAAsurf', 'sdzNOAAsurf', 'sgpNOAAsurf', 'strNOAAsurf',
                   'tapNOAAsurf', 'wbiNOAAsurf', 'wgcNOAAsurf', 'wisNOAAsurf',
                   'wktNOAAsurf',
                   'grfNOAAsurf', 'mlsNOAAsurf', 'mscNOAAsurf', 'spfNOAAsurf', # look weird
                   'tnkNOAAsurf', 'wpcNOAAsurf'] 

    # initialise plots
    # pp1 = PdfPages(OBSPACK_DIR / 'obs_baseline_trends.pdf')
    # pp2 = PdfPages(OBSPACK_DIR / 'obs_baseline_detrended.pdf')
    # pp3 = PdfPages(OBSPACK_DIR / 'obs_baseline_monthlymean.pdf')

    for site in unique_sites:
        print(site)

        if site in dodgy_sites:
            pass
        elif "NOAAair" in site:
            pass
        else:
            # select needed data for that site
            eg_site = obspack_obs.where(obspack_obs["site"] == site, drop=True)
            eg_site_pd = eg_site[["time", "value"]].to_dataframe()

            # # use NOAA curve fitting 
            # # requires csv file with decimal date
            # noaa_decimal_year = [toYearFraction(eg_site_pd["time"].iloc[x]) for x in range(len(eg_site_pd))]
            # noaa_pd = pd.Series(data=eg_site["value"], index=noaa_decimal_year)
            # noaa_pd.to_csv(OBSPACK_DIR / f"noaa_ccgcrv/{site}.csv", sep=" ", header=False)
            # # run NOAA script and read in results
            # os.system(f'python3 ccgcrv.py --samplefile {OBSPACK_DIR}/noaa_ccgcrv/{site}_out.csv --func --sample {OBSPACK_DIR}/noaa_ccgcrv/{site}.csv')
            # noaa_smoothed = pd.read_csv(OBSPACK_DIR / f"noaa_ccgcrv/{site}_out.csv", header=None, names=["time", "smooth"], sep=" ")

            # # create poly fit for comparison
            # poly_curve = create_datasets.poly_curve(eg_site_pd.set_index("time")["value"])

            # # make new df with all the fits
            # fitted_data = pd.DataFrame(data={"time":eg_site_pd["time"].values,
            #                                  "orig":eg_site_pd["value"].values, 
            #                                  "poly":poly_curve,
            #                                  "smooth":noaa_smoothed["smooth"].values})
            # # normalise values by subtracting smoothed fit
            # fitted_data["detrended"] = (fitted_data["orig"] - fitted_data["smooth"]).values

            # # use IRF to decide which points are outliers
            # IRF = IsolationForest(random_state=0).fit(fitted_data["detrended"].values.reshape(-1, 1))
            # irf = IRF.predict(fitted_data["detrended"].values.reshape(-1, 1))
            # irf = (irf==1).astype(bool)

            # # plot fits along with IRF baseline
            # ax = fitted_data.plot.scatter("time", "orig", label="all")
            # fitted_data[irf].plot.scatter("time", "orig", ax=ax, color="k", label="baseline")
            # fitted_data.plot("time", "smooth", ax=ax, color="red")
            # fitted_data.plot("time", "poly", ax=ax, color="y")
            # plt.title(site)
            # pp1.savefig()
            # plt.close()

            # # plot detrended points along with their baseline
            # ax = fitted_data.plot.scatter("time", "detrended", label="all")
            # fitted_data[irf].plot.scatter("time", "detrended", ax=ax, color="k", label="baseline")
            # plt.title(site)
            # pp2.savefig()
            # plt.close()

            # # print min and max out of curiosity
            # print(fitted_data[irf]["detrended"].min())
            # print(fitted_data[irf]["detrended"].max())

            # # look at the effects of the baseline on the monthly mean
            # before = fitted_data.set_index("time").resample("M").mean()
            # after = fitted_data.set_index("time")[irf].resample("M").mean()

            # ax = fitted_data.plot.scatter("time", "orig")
            # before.reset_index().plot.scatter("time", "orig", ax=ax, color="r", label="all mm")
            # after.reset_index().plot.scatter("time", "orig", ax=ax, color="y", label="baseline mm")
            # plt.title(site)
            # pp3.savefig()
            # plt.close()

            # store baseline
            #obspack_obs["baseline"].loc[obspack_obs["site"] == site] = irf
            obspack_obs["baseline"].loc[obspack_obs["site"] == site] = 1

    # pp1.close()
    # pp2.close()
    # pp3.close()

    # Save for later use
    obspack_obs.to_netcdf(OBSPACK_DIR / "baseline_obs.nc")
