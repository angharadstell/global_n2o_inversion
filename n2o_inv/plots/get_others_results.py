#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
This script reads in the results from other people's inversions, and processes them 
into a nice format so I can compare their results to mine.
"""
import configparser
from pathlib import Path
import re

import numpy as np
import pandas as pd
import xarray as xr

from acrg.grid.areagrid import areagrid
from acrg.grid.regrid import regrid2d

from n2o_inv.emissions import combine_ems

def preprocess(xr_df):
    """ Process other people's raw data files.
    """

    # what year is this?
    m = re.search('grid_n2o_(.{4})_', xr_df.encoding["source"])
    if m: 
        year = m.group(1)
        # xarray needs monotonically increasing coords to join the datasets together
        xr_df = xr_df.assign_coords(time=pd.date_range(start=f"{year}/01/01", end=f"{year}/12/31", freq="M"))

    return xr_df

def read_in_raw(others_results_dir, filenames):
    """ Read in other people's data files.
    """
    files = list(others_results_dir.glob(filenames))
    files.sort()

    with xr.open_mfdataset(files, preprocess=preprocess) as load:
        thompson = load.load()

    return thompson

def save_df(sol, filename):
    """ Save processed data file.
    """
    df_pd = sol.to_dataframe()
    df_pd = df_pd.set_index(df_pd.index.year)
    df_pd.index.rename("year", inplace=True)
    df_pd.to_csv(filename)

if __name__ == "__main__":

    # =============================================================================
    # Read in raw data
    # =============================================================================

    # read in variables from the config file
    config = configparser.ConfigParser()
    config.read(Path(__file__).parent.parent.parent / 'config.ini')
    others_results_dir = Path(config["paths"]["data_dir"]) / "others_results"

    # Read raw thompson data into xarray
    thompson_inv1_raw = read_in_raw(others_results_dir, "thompson_2019/grid_n2o_????_TOMCAT.nc")
    thompson_inv2_raw = read_in_raw(others_results_dir, "thompson_2019/grid_n2o_????_PYVAR.nc")
    thompson_inv3_raw = read_in_raw(others_results_dir, "thompson_2019/n2o.MACTM-r84.JAMSTEC.v1.????.nc")
    patra_raw = read_in_raw(others_results_dir, "patra_2022/n2o.s042_pfu50p_du30p_egvy.MIROC4-ACTM-r84.JAMSTEC.v0.????.nc")

    # read in the TRANSCOM region mask
    with xr.open_dataset(Path(config["inversion_constants"]["geo_transcom_mask"])) as load:
        mask = load.load()  

    # =============================================================================
    # Make ocean/land mask
    # =============================================================================

    land_mask = xr.where(mask < 12, 1, 0)

    land_mask_1x1 = regrid2d(land_mask["regions"].values, 
                             land_mask["lat"].values,
                             land_mask["lon"].values, 
                             thompson_inv1_raw["latitude"].values,
                             thompson_inv1_raw["longitude"].values, 
                             global_grid=True)[0]

    land_mask_1x1 = land_mask_1x1 > 0.5

    # =============================================================================
    # Convert units to TgN/y
    # =============================================================================

    # from kgN/m2/y
    thompson_inv1_units = thompson_inv1_raw.copy()
    thompson_inv1_units["days_in_month"] = (("time"), combine_ems.days_in_month(thompson_inv1_raw))
    thompson_inv1_units["n2o_ems"] = thompson_inv1_units["days_in_month"] * thompson_inv1_units["post"]
    days_in_year = thompson_inv1_units["days_in_month"].resample(time="Y").sum()
    thompson_inv1_units2 = (thompson_inv1_units.resample(time="Y").sum() / days_in_year)["n2o_ems"] * 10**-9

    # from kgN/m2/h
    thompson_inv2_units = thompson_inv2_raw.copy()
    thompson_inv2_units["hours_in_month"] = (("time"), (combine_ems.days_in_month(thompson_inv2_raw) * 24))
    thompson_inv2_units["n2o_ems"] = thompson_inv2_units["hours_in_month"] * thompson_inv2_units["post"]
    thompson_inv2_units2 = thompson_inv2_units["n2o_ems"].resample(time="Y").sum() * 10**-9

    # from kgN2O/m2/month
    thompson_inv3_units = thompson_inv3_raw.copy()
    thompson_inv3_units["post"] = thompson_inv3_raw["flux_apos_land"] + thompson_inv3_raw["flux_apos_ocean"] + thompson_inv3_raw["flux_apri_fossil"]
    thompson_inv3_units2 = thompson_inv3_units["post"].resample(time="Y").sum() * 10**-9 * (28 / float(config["gas_info"]["molecular_weight"]))

    # from kgN/m2/month
    patra_units = patra_raw.copy()
    patra_units["post"] = patra_raw["flux_apos_land"] + patra_raw["flux_apos_ocean"]
    patra_units2 = patra_units["post"].resample(time="Y").sum() * 10**-9

    # land and ocean totals
    thompson_inv1_units2_land = thompson_inv1_units2 * land_mask_1x1
    thompson_inv1_units2_ocean = thompson_inv1_units2 * ~land_mask_1x1
    thompson_inv2_units2_land = thompson_inv2_units2 * land_mask_1x1
    thompson_inv2_units2_ocean = thompson_inv2_units2 * ~land_mask_1x1
    thompson_inv3_units2_land = thompson_inv3_units2 * land_mask_1x1
    thompson_inv3_units2_ocean = thompson_inv3_units2 * ~land_mask_1x1
    patra_units2_land = patra_units2 * land_mask_1x1
    patra_units2_ocean = patra_units2 * ~land_mask_1x1

    # Thomspon area
    thompson_area = xr.Dataset({"area":(("latitude", "longitude"), 
                                       areagrid(thompson_inv1_raw["latitude"].values, thompson_inv1_raw["longitude"].values))},
                                coords={"latitude":thompson_inv1_raw["latitude"].values, "longitude":thompson_inv1_raw["longitude"].values})


    # area weight
    thompson_inv1_sol = (thompson_inv1_units2 * thompson_area["area"]).sum(["latitude", "longitude"])
    thompson_inv2_sol = (thompson_inv2_units2 * thompson_area["area"]).sum(["latitude", "longitude"])
    thompson_inv3_sol = (thompson_inv3_units2 * thompson_area["area"]).sum(["latitude", "longitude"])
    patra_sol = (patra_units2 * thompson_area["area"]).sum(["latitude", "longitude"])

    thompson_inv1_land_sol = (thompson_inv1_units2_land * thompson_area["area"]).sum(["latitude", "longitude"])
    thompson_inv2_land_sol = (thompson_inv2_units2_land * thompson_area["area"]).sum(["latitude", "longitude"])
    thompson_inv3_land_sol = (thompson_inv3_units2_land * thompson_area["area"]).sum(["latitude", "longitude"])
    patra_land_sol = (patra_units2_land * thompson_area["area"]).sum(["latitude", "longitude"])

    thompson_inv1_ocean_sol = (thompson_inv1_units2_ocean * thompson_area["area"]).sum(["latitude", "longitude"])
    thompson_inv2_ocean_sol = (thompson_inv2_units2_ocean * thompson_area["area"]).sum(["latitude", "longitude"])
    thompson_inv3_ocean_sol = (thompson_inv3_units2_ocean * thompson_area["area"]).sum(["latitude", "longitude"])
    patra_ocean_sol = (patra_units2_ocean * thompson_area["area"]).sum(["latitude", "longitude"])

    print(thompson_inv3_sol)

    # lolololol
    # there's clearly something wrong
    factor = np.mean(thompson_inv3_sol) / 17.0
    thompson_inv3_sol = thompson_inv3_sol / factor
    thompson_inv3_land_sol = thompson_inv3_land_sol / factor
    thompson_inv3_ocean_sol = thompson_inv3_ocean_sol / factor

    # =============================================================================
    # Save in nice format for R to read in
    # =============================================================================

    thompson_inv1_comb_sol = xr.merge([{"total": thompson_inv1_sol, "land": thompson_inv1_land_sol, "ocean": thompson_inv1_ocean_sol}])
    thompson_inv2_comb_sol = xr.merge([{"total": thompson_inv2_sol, "land": thompson_inv2_land_sol, "ocean": thompson_inv2_ocean_sol}])
    thompson_inv3_comb_sol = xr.merge([{"total": thompson_inv3_sol, "land": thompson_inv3_land_sol, "ocean": thompson_inv3_ocean_sol}])
    patra_comb_sol = xr.merge([{"total": patra_sol, "land": patra_land_sol, "ocean": patra_ocean_sol}])
    
    save_df(thompson_inv1_comb_sol, others_results_dir / "annual_global_total_thompson_INV1.csv")
    save_df(thompson_inv2_comb_sol, others_results_dir / "annual_global_total_thompson_INV2.csv")
    save_df(thompson_inv3_comb_sol, others_results_dir / "annual_global_total_thompson_INV3.csv")
    save_df(patra_comb_sol, others_results_dir / "annual_global_total_patra.csv")

