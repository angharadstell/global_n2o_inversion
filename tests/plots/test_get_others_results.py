"""
Tests get_others_results.py

@author: Angharad Stell
"""
import configparser
from pathlib import Path

import pandas as pd
import os
import xarray as xr

from n2o_inv.plots import get_others_results



def test_save_df_runs():
    xr_df = xr.Dataset({"data": (("time"), range(1, 10))},
            coords = {"time": pd.date_range("2011-01-01", "2020-01-01", freq="Y")})

    filename = "tests/plots/test_processed_df.csv"

    get_others_results.save_df(xr_df, filename)

    if os.path.isfile(filename):
        os.remove(filename)
    
# assumes correct data and config
def test_read_in_raw_runs_preprocess_if():
    # read in variables from the config file
    config = configparser.ConfigParser()
    config.read(Path(__file__).parent.parent.parent / 'config.ini')
    others_results_dir = Path(config["paths"]["data_dir"]) / "others_results"

    get_others_results.read_in_raw(others_results_dir, "thompson_2019/grid_n2o_????_TOMCAT.nc")

# assumes correct data and config
def test_read_in_raw_runs_no_preprocess_if():
    # read in variables from the config file
    config = configparser.ConfigParser()
    config.read(Path(__file__).parent.parent.parent / 'config.ini')
    others_results_dir = Path(config["paths"]["data_dir"]) / "others_results"

    get_others_results.read_in_raw(others_results_dir, "thompson_2019/n2o.MACTM-r84.JAMSTEC.v1.????.nc")
