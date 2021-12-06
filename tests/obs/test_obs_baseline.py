import numpy as np
import pandas as pd
import xarray as xr

from n2o_inv.obs import obs_baseline

def test_agage_baseline_no_interp():
    time_vec = pd.date_range("2010-01-01", "2010-01-02", freq="D")
    df = xr.Dataset({"baseline_NAME":(("time"), np.array([True, False]))},
                                       coords={"time": time_vec})

    output = obs_baseline.agage_baseline(df, time_vec)

    assert (output == np.array([1, 0])).all()
    
def test_agage_baseline_one_each():
    df = xr.Dataset({"baseline_NAME":(("time"), np.array([True, False]))},
                                       coords={"time": pd.date_range("2010-01-01", "2010-01-02", freq="D")})

    output = obs_baseline.agage_baseline(df, np.array([pd.to_datetime("2010-01-01 12:00")]))

    assert output == 0

def test_agage_baseline_both_base():
    df = xr.Dataset({"baseline_NAME":(("time"), np.array([True, True]))},
                                       coords={"time": pd.date_range("2010-01-01", "2010-01-02", freq="D")})

    output = obs_baseline.agage_baseline(df, np.array([pd.to_datetime("2010-01-01 12:00")]))

    assert output == 1

def test_agage_baseline_both_not_base():
    df = xr.Dataset({"baseline_NAME":(("time"), np.array([False, False]))},
                                       coords={"time": pd.date_range("2010-01-01", "2010-01-02", freq="D")})

    output = obs_baseline.agage_baseline(df, np.array([pd.to_datetime("2010-01-01 12:00")]))

    assert output == 0

def test_raw_obs_to_baseline_NOAAair():
    obspack_obs = xr.Dataset({"value": (("obs"), np.array([330])),
                              "site": (("obs"), np.array(["tstNOAAair"])),
                              "time": (("obs"), np.array([pd.to_datetime("2010-01-01")]))},
                              coords={"obs": np.array([1])})
    
    output = obs_baseline.raw_obs_to_baseline(obspack_obs, {})

    assert output["baseline"] == 0
    
def test_raw_obs_to_baseline_NOAAsurf_keep():
    obspack_obs = xr.Dataset({"value": (("obs"), np.array([330])),
                              "site": (("obs"), np.array(["tstNOAAsurf"])),
                              "time": (("obs"), np.array([pd.to_datetime("2010-01-01")]))},
                              coords={"obs": np.array([1])})
    
    output = obs_baseline.raw_obs_to_baseline(obspack_obs, {})

    assert output["baseline"] == 1

def test_raw_obs_to_baseline_NOAAsurf_delete():
    obspack_obs = xr.Dataset({"value": (("obs"), np.array([330])),
                              "site": (("obs"), np.array(["grfNOAAsurf"])),
                              "time": (("obs"), np.array([pd.to_datetime("2010-01-01")]))},
                              coords={"obs": np.array([1])})
    
    output = obs_baseline.raw_obs_to_baseline(obspack_obs, {})

    assert output["baseline"] == 0

def test_raw_obs_to_baseline_AGAGEsurf():
    obspack_obs = xr.Dataset({"value": (("obs"), np.array([330, 340])),
                              "site": (("obs"), np.array(["tstAGAGEsurf", "tstAGAGEsurf"])),
                              "time": (("obs"), pd.date_range("2010-01-01", "2010-01-02", freq="D"))},
                              coords={"obs": np.array([1, 2])})
    baseline_dict = {"TST": xr.Dataset({"baseline_NAME":(("time"), np.array([True, False]))},
                                       coords={"time": pd.date_range("2010-01-01", "2010-01-02", freq="D")})}
    output = obs_baseline.raw_obs_to_baseline(obspack_obs, baseline_dict)

    assert (output["baseline"] == [1, 0]).all()