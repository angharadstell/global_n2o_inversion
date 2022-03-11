"""
Tests process_geos_output.py

@author: Angharad Stell
"""
import numpy as np
import pandas as pd
import pytest
import xarray as xr

from n2o_inv.intermediates import process_geos_output


def test_monthly_mean_obspack_id():
    test_site = "TST"
    test_date = "2021-07-01"
    expected_result = "obspack_multi-species_1_CCGGSurfaceFlask_v2.0_2021-02-09~n2o_TST_surface-flask_1_ccgg_Event~TST202107"
    assert expected_result == process_geos_output.monthly_mean_obspack_id(test_site, test_date)

def test_obspack_geos_preprocess_correct_values():
    ds = xr.Dataset({"obspack_id": (("obs"), ["sitea_1", "siteb_2"]),
                     "CH4_R00": (("obs"), np.array([0, 0])),
                     "CH4_R01": (("obs"), np.array([1, 1]))},
                     coords={"obs": np.array([1, 2])})
    obspack_obs = xr.Dataset({"obspack_id": (("obs"), ["sitea_1", "siteb_2"])},
                             coords={"obs": np.array([1, 2])})
    assert (process_geos_output.obspack_geos_preprocess(ds, obspack_obs, 1)["CH4_R00"] == 0).all() 
    assert (process_geos_output.obspack_geos_preprocess(ds, obspack_obs, 1)["CH4_R01"] == 1E9).all() 

def test_obspack_geos_preprocess_obspack_ordering():
    ds = xr.Dataset({"obspack_id": (("obs"), ["siteb_2", "sitea_1"]),
                     "CH4_R00": (("obs"), np.array([0, 0])),
                     "CH4_R01": (("obs"), np.array([1, 2]))},
                     coords={"obs": np.array([1, 2])})
    obspack_obs = xr.Dataset({"obspack_id": (("obs"), ["sitea_1", "siteb_2"])},
                             coords={"obs": np.array([6, 7])})
    with pytest.raises(ValueError, match="obspack obs and geoschem values don't align"):
        process_geos_output.obspack_geos_preprocess(ds, obspack_obs, 1)

def test_obspack_geos_preprocess_obs_ordering():
    ds = xr.Dataset({"obspack_id": (("obs"), ["sitea_1", "siteb_2"]),
                     "CH4_R00": (("obs"), np.array([0, 0])),
                     "CH4_R01": (("obs"), np.array([1, 2]))},
                     coords={"obs": np.array([1, 2])})
    obspack_obs = xr.Dataset({"obspack_id": (("obs"), ["sitea_1", "siteb_2"])},
                             coords={"obs": np.array([6, 7])})
    assert (process_geos_output.obspack_geos_preprocess(ds, obspack_obs, 1)["obs"] == np.array([6, 7])).all()

def test_obspack_geos_preprocess_diff_dims():
    ds = xr.Dataset({"obspack_id": (("obs"), ["sitea_1", "siteb_2"]),
                     "CH4_R00": (("obs"), np.array([0, 0])),
                     "CH4_R01": (("obs"), np.array([1, 2]))},
                     coords={"obs": np.array([1, 2])})
    obspack_obs = xr.Dataset({"obspack_id": (("obs"), ["sitea_1", "siteb_2", "sitec_3"])},
                             coords={"obs": np.array([1, 2, 3])})
    
    assert (process_geos_output.obspack_geos_preprocess(ds, obspack_obs, 1)["obs"] == np.array([1, 2])).all()

def test_read_obs_selects_right_files(tmp_path):
    # create fake files
    obs1 = xr.Dataset({"obspack_id": (("obs"), ["sitea_1", "siteb_2"])},
                      coords={"obs": np.array([1, 2])})
    obs2 = xr.Dataset({"obspack_id": (("obs"), ["sitea_2", "siteb_3"])},
                      coords={"obs": np.array([3, 4])})
    obs3 = xr.Dataset({"obspack_id": (("obs"), ["sitea_3", "siteb_4"])},
                      coords={"obs": np.array([5, 6])})
    obs1.to_netcdf(tmp_path / "obspack_n2o.20090601.nc")
    obs2.to_netcdf(tmp_path / "obspack_n2o.20100601.nc")
    obs3.to_netcdf(tmp_path / "obspack_n2o.20110601.nc")

    spinup_start = pd.to_datetime("2009-01-01")
    perturb_end = pd.to_datetime("2011-01-01")
    final_end = pd.to_datetime("2012-01-01")
    func_out = process_geos_output.read_obs(tmp_path, spinup_start, perturb_end, final_end)

    assert (func_out["obs"].values == np.array([3, 4])).all()
    assert (func_out["obspack_id"].values == ["sitea_2", "siteb_3"]).all()

def test_read_geos_runs(tmp_path):
    ds1 = xr.Dataset({"obspack_id": (("obs"), ["sitea_1", "siteb_2"]),
                      "CH4_R00": (("obs"), np.array([0, 0])),
                      "CH4_R01": (("obs"), np.array([1, 2]))},
                      coords={"obs": np.array([1, 2])})
    ds2 = xr.Dataset({"obspack_id": (("obs"), ["sitea_3", "siteb_4"]),
                      "CH4_R00": (("obs"), np.array([0, 0])),
                      "CH4_R01": (("obs"), np.array([3, 4]))},
                      coords={"obs": np.array([3, 4])})
    ds1.to_netcdf(tmp_path / "GEOSChem.ObsPack.20100101_0000z.nc4")
    ds2.to_netcdf(tmp_path / "GEOSChem.ObsPack.20100102_0000z.nc4")
    
    obspack_obs = xr.Dataset({"obspack_id": (("obs"), ["sitea_1", "siteb_2", "sitea_3", "siteb_4"])},
                             coords={"obs": np.array([5, 6, 7, 8])})

    func_out = process_geos_output.read_geos(tmp_path, obspack_obs, 1, 2010, 2010)

    assert (func_out["obs"] == np.array([5, 6, 7, 8])).all()
    assert (func_out["CH4_R00"] == np.array([0, 0, 0, 0])).all()
    assert (func_out["CH4_R01"] == np.array([1E9, 2E9, 3E9, 4E9])).all()

def test_read_geos_firstofmonth(tmp_path):
    ds1 = xr.Dataset({"obspack_id": (("obs"), ["sitea_1", "siteb_2"]),
                      "CH4_R00": (("obs"), np.array([0, 0])),
                      "CH4_R01": (("obs"), np.array([1, 2]))},
                      coords={"obs": np.array([1, 2])})
    ds2 = xr.Dataset({"obspack_id": (("obs"), ["sitea_3", "siteb_4"]),
                      "CH4_R00": (("obs"), np.array([0, 0])),
                      "CH4_R01": (("obs"), np.array([3, 4]))},
                      coords={"obs": np.array([3, 4])})
    ds1.to_netcdf(tmp_path / "GEOSChem.ObsPack.20100131_0000z.nc4")
    ds2.to_netcdf(tmp_path / "GEOSChem.ObsPack.20100201_0000z.nc4")
    
    obspack_obs = xr.Dataset({"obspack_id": (("obs"), ["sitea_1", "siteb_2", "sitea_3", "siteb_4"])},
                             coords={"obs": np.array([5, 6, 7, 8])})

    func_out = process_geos_output.read_geos(tmp_path, obspack_obs, 1, 2010, 2010)

    assert (func_out["obs"] == np.array([5, 6])).all()
    assert (func_out["CH4_R00"] == np.array([0, 0])).all()
    assert (func_out["CH4_R01"] == np.array([1E9, 2E9])).all()

def test_read_geos_none(tmp_path):
    # one file has no obs in that we are interested in
    ds1 = xr.Dataset({"obspack_id": (("obs"), ["sitea_0", "siteb_0"]),
                      "CH4_R00": (("obs"), np.array([0, 0])),
                      "CH4_R01": (("obs"), np.array([1, 2]))},
                      coords={"obs": np.array([1, 2])})
    ds2 = xr.Dataset({"obspack_id": (("obs"), ["sitea_1", "siteb_2","sitea_3", "siteb_4"]),
                      "CH4_R00": (("obs"), np.array([0, 0, 0, 0])),
                      "CH4_R01": (("obs"), np.array([3, 4, 5, 6]))},
                      coords={"obs": np.array([3, 4, 5, 6])})
    ds1.to_netcdf(tmp_path / "GEOSChem.ObsPack.20100101_0000z.nc4")
    ds2.to_netcdf(tmp_path / "GEOSChem.ObsPack.20100102_0000z.nc4")
    
    obspack_obs = xr.Dataset({"obspack_id": (("obs"), ["sitea_1", "siteb_2", "sitea_3", "siteb_4"])},
                             coords={"obs": np.array([1, 2, 3, 4])})

    func_out = process_geos_output.read_geos(tmp_path, obspack_obs, 1, 2010, 2010)

    assert (func_out["obs"] == np.array([1, 2, 3, 4])).all()
    assert (func_out["CH4_R00"] == np.array([0, 0, 0, 0])).all()
    assert (func_out["CH4_R01"] == np.array([3E9, 4E9, 5E9, 6E9])).all()

def test_read_geos_removed_obs(tmp_path):
    # our file has more obs than we are interested in
    ds1 = xr.Dataset({"obspack_id": (("obs"), ["sitea_1", "sitea_2", "siteb_2", "sitec_0"]),
                      "CH4_R00": (("obs"), np.array([0, 0, 0, 0])),
                      "CH4_R01": (("obs"), np.array([1, 2, 3, 4]))},
                      coords={"obs": np.array([1, 2, 3, 4])})
    ds2 = xr.Dataset({"obspack_id": (("obs"), ["sitea_3", "siteb_4"]),
                      "CH4_R00": (("obs"), np.array([0, 0])),
                      "CH4_R01": (("obs"), np.array([5, 6]))},
                      coords={"obs": np.array([5, 6])})
    ds1.to_netcdf(tmp_path / "GEOSChem.ObsPack.20100101_0000z.nc4")
    ds2.to_netcdf(tmp_path / "GEOSChem.ObsPack.20100102_0000z.nc4")
    
    obspack_obs = xr.Dataset({"obspack_id": (("obs"), ["sitea_1", "siteb_2", "sitea_3", "siteb_4"])},
                             coords={"obs": np.array([7, 8, 9, 10])})

    func_out = process_geos_output.read_geos(tmp_path, obspack_obs, 1, 2010, 2010)

    assert (func_out["obs"] == np.array([7, 8, 9, 10])).all()
    assert (func_out["CH4_R00"] == np.array([0, 0, 0, 0])).all()
    assert (func_out["CH4_R01"] == np.array([1E9, 3E9, 5E9, 6E9])).all()

def test_read_geos_constant_runs(tmp_path):
    ds1 = xr.Dataset({"obspack_id": (("obs"), ["sitea_1", "siteb_2"]),
                      "CH4_R00": (("obs"), np.array([0, 0])),
                      "CH4_R01": (("obs"), np.array([1, 2]))},
                      coords={"obs": np.array([1, 2])})
    ds2 = xr.Dataset({"obspack_id": (("obs"), ["sitea_3", "siteb_4"]),
                      "CH4_R00": (("obs"), np.array([0, 0])),
                      "CH4_R01": (("obs"), np.array([1, 2]))},
                      coords={"obs": np.array([3, 4])})
    (tmp_path / "su_01").mkdir()
    ds1.to_netcdf(tmp_path / "su_01/GEOSChem.ObsPack.20100101_0000z.nc4")
    ds2.to_netcdf(tmp_path / "su_01/GEOSChem.ObsPack.20100102_0000z.nc4")
    
    obspack_obs = xr.Dataset({"obspack_id": (("obs"), ["sitea_1", "siteb_2", "sitea_3", "siteb_4"])},
                             coords={"obs": np.array([1, 2, 3, 4])})

    func_out = process_geos_output.read_geos_constant(tmp_path, obspack_obs, 1, 2010, 2010)

    assert (func_out["obs"] == np.array([1, 2, 3, 4])).all()
    assert (func_out["CH4_R00"] == np.array([0, 0, 0, 0])).all()
    assert (func_out["CH4_R01"] == np.array([1E9, 2E9, 1E9, 2E9])).all()

def test_find_unique_sites():
    test_site_list = [b"~n2o_TST_", b"~n2o_TST_", b"~n2o_TST_", b"~n2o_TSD_"]
    test_combined = xr.Dataset({"obspack_id":test_site_list,
                                "network":["A", "B", "A", "A"]})
    list_of_sites, unique_sites = process_geos_output.find_unique_sites(test_combined)

    assert ["TSTA", "TSTB", "TSTA", "TSDA"] == list_of_sites
    assert (np.array(["TSDA", "TSTA", "TSTB"]) == unique_sites).all() # output in alphabetical order

def test_monthly_measurement_unc_zeros():
    dates = pd.date_range("2010-01-01", "2010-12-31", freq="D")
    onesite = xr.Dataset({"obs_value": (("obs_time"), np.array([0] * len(dates))),
                          "obs_value_unc": (("obs_time"), np.array([0] * len(dates)))},
                         coords={"obs_time": dates})

    onesite_resampled_unc_comb = process_geos_output.monthly_measurement_unc(onesite)
    assert (onesite_resampled_unc_comb == np.array([0] * 12)).all()

def test_monthly_measurement_unc_med_bigger():
    dates = pd.date_range("2010-01-01", "2010-12-31", freq="D")
    onesite = xr.Dataset({"obs_value": (("obs_time"), np.array([0] * len(dates))),
                          "obs_value_unc": (("obs_time"), np.array([1] * len(dates)))},
                         coords={"obs_time": dates})

    onesite_resampled_unc_comb = process_geos_output.monthly_measurement_unc(onesite)
    assert (onesite_resampled_unc_comb == np.array([1] * 12)).all()

def test_monthly_measurement_unc_std_bigger():
    dates = pd.date_range("2010-01-01", "2010-12-31", freq="D")

    # draw samples froma normal distribution
    rng = np.random.default_rng(2021)

    onesite = xr.Dataset({"obs_value": (("obs_time"), rng.normal(size=len(dates))),
                          "obs_value_unc": (("obs_time"), np.array([0] * len(dates)))},
                          coords={"obs_time": dates})

    onesite_resampled_unc_comb = process_geos_output.monthly_measurement_unc(onesite)
    assert (onesite_resampled_unc_comb > 0).all()

def test_monthly_measurement_unc_nan():
    dates = pd.date_range("2010-01-01", "2010-01-01", freq="D")
    onesite = xr.Dataset({"obs_value": (("obs_time"), np.array([0] * len(dates))),
                          "obs_value_unc": (("obs_time"), np.array([0] * len(dates)))},
                         coords={"obs_time": dates})

    onesite_resampled_unc_comb = process_geos_output.monthly_measurement_unc(onesite)
    assert (onesite_resampled_unc_comb == 0).all()
