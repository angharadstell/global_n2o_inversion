"""
Tests process_geos_output.py

@author: Angharad Stell
"""
import numpy as np
import pandas as pd
import xarray as xr

from n2o_inv.intermediates import process_geos_output


def test_monthly_mean_obspack_id():
    test_site = "TST"
    test_date = "2021-07-01"
    expected_result = "obspack_multi-species_1_CCGGSurfaceFlask_v2.0_2021-02-09~n2o_TST_surface-flask_1_ccgg_Event~TST202107"
    assert expected_result == process_geos_output.monthly_mean_obspack_id(test_site, test_date)

def test_find_unique_sites():
    test_site_list = [b"~n2o_TST_", b"~n2o_TST_", b"~n2o_TST_", b"~n2o_TSD_"]
    test_combined = xr.Dataset({"obspack_id":test_site_list,
                                "network":["A", "B", "A", "A"]})
    list_of_sites, unique_sites = process_geos_output.find_unique_sites(test_combined)

    assert ["TSTA", "TSTB", "TSTA", "TSDA"] == list_of_sites
    assert (np.array(["TSDA", "TSTA", "TSTB"]) == unique_sites).all() # output in alphabetical order

def test_monthly_measurement_unc_zeros():
    dates = pd.date_range("2010-01-01", "2010-12-31", freq="D")
    onesite = xr.Dataset({"obs_time": dates,
                          "obs_value": ("obs_time", np.array([0] * len(dates))),
                          "obs_value_unc": ("obs_time", np.array([0] * len(dates)))})

    onesite_resampled_unc_comb = process_geos_output.monthly_measurement_unc(onesite)
    assert (onesite_resampled_unc_comb == np.array([0] * 12)).all()

def test_monthly_measurement_unc_med_bigger():
    dates = pd.date_range("2010-01-01", "2010-12-31", freq="D")
    onesite = xr.Dataset({"obs_time": dates,
                          "obs_value": ("obs_time", np.array([0] * len(dates))),
                          "obs_value_unc": ("obs_time", np.array([1] * len(dates)))})

    onesite_resampled_unc_comb = process_geos_output.monthly_measurement_unc(onesite)
    assert (onesite_resampled_unc_comb == np.array([1] * 12)).all()

def test_monthly_measurement_unc_std_bigger():
    dates = pd.date_range("2010-01-01", "2010-12-31", freq="D")

    # draw samples froma normal distribution
    rng = np.random.default_rng(2021)

    onesite = xr.Dataset({"obs_time": dates,
                          "obs_value": ("obs_time", rng.normal(size=len(dates))),
                          "obs_value_unc": ("obs_time", np.array([0] * len(dates)))})

    onesite_resampled_unc_comb = process_geos_output.monthly_measurement_unc(onesite)
    assert (onesite_resampled_unc_comb > 0).all()

def test_monthly_measurement_unc_nan():
    dates = pd.date_range("2010-01-01", "2010-01-01", freq="D")
    onesite = xr.Dataset({"obs_time": dates,
                          "obs_value": ("obs_time", np.array([0] * len(dates))),
                          "obs_value_unc": ("obs_time", np.array([0] * len(dates)))})

    onesite_resampled_unc_comb = process_geos_output.monthly_measurement_unc(onesite)
    assert (onesite_resampled_unc_comb == 0).all()




