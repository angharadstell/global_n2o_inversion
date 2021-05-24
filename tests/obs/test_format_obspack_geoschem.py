"""
Tests format_obspack_geoschem.py

@author: Angharad Stell
"""

import numpy as np
import pandas as pd
import xarray as xr

from n2o_inv.obs import format_obspack_geoschem

def test_date_mask():
    days = range(1, 30)
    time_comp_list = np.array([[2012, 2, D, 9, 7, 0] for D in days])

    df = xr.Dataset({"time_components": (("obs", "calendar_components"), time_comp_list)},
                    coords={"obs": days, "calendar_components": range(6)})

    desired_date = pd.date_range("2012-02-15", "2012-02-15", freq="D")[0]   

    desired_mask = np.array([False]*len(days))
    desired_mask[14] = True

    assert (format_obspack_geoschem.date_mask(df, desired_date) == desired_mask).all()

def test_preprocess_surface():
    in_df = xr.Dataset({"latitude":(("obs"), np.array([0])),
                        "longitude":(("obs"), np.array([0])), 
                        "altitude":(("obs"), np.array([0])), 
                        "time":(("obs"), [np.datetime64("2012-02-29T09:07")]), 
                        "time_components":(("obs", "calendar_components"), [[2018, 2, 29, 9, 7, 0]]),
                        "obspack_id":(("obs"), np.array([999])), 
                        "obspack_num":(("obs"), np.array([888])), 
                        "value":(("obs"), np.array([300])), 
                        "value_unc":(("obs"), np.array([2])), 
                        "qcflag":(("obs"), [b"..."]),
                        "fake_var":(("obs"), np.array([7]))}, 
                        coords={"obs": np.array([1]), "calendar_components": range(6)})

    out_df = xr.Dataset({"latitude":(("obs"), np.array([0])),
                         "longitude":(("obs"), np.array([0])), 
                         "altitude":(("obs"), np.array([0])), 
                         "time":(("obs"), [np.datetime64("2012-02-29T09:07")]), 
                         "time_components":(("obs", "calendar_components"), [[2018, 2, 29, 9, 7, 0]]),
                         "obspack_id":(("obs"), np.array([999])),
                         "value":(("obs"), np.array([300])), 
                         "value_unc":(("obs"), np.array([2])), 
                         "qcflag":(("obs"), [b"..."])},
                        coords={"obs": np.array([888]), "calendar_components": range(6)})

    xr.testing.assert_equal(format_obspack_geoschem.preprocess(in_df), out_df)

def test_preprocess_aircraft_no_value_unc():
    in_df = xr.Dataset({"latitude":(("obs"), np.array([0])),
                        "longitude":(("obs"), np.array([0])), 
                        "altitude":(("obs"), np.array([0])), 
                        "time":(("obs"), [np.datetime64("2012-02-29T09:07")]), 
                        "time_components":(("obs", "calendar_components"), [[2018, 2, 29, 9, 7, 0]]),
                        "obspack_id":(("obs"), np.array([999])), 
                        "obspack_num":(("obs"), np.array([888])), 
                        "value":(("obs"), np.array([300])),
                        "qcflag":(("obs"), [b"..."]),
                        "fake_var":(("obs"), np.array([7]))}, 
                        coords={"obs": np.array([1]), "calendar_components": range(6)})

    out_df = xr.Dataset({"latitude":(("obs"), np.array([0])),
                         "longitude":(("obs"), np.array([0])), 
                         "altitude":(("obs"), np.array([0])), 
                         "time":(("obs"), [np.datetime64("2012-02-29T09:07")]), 
                         "time_components":(("obs", "calendar_components"), [[2018, 2, 29, 9, 7, 0]]),
                         "obspack_id":(("obs"), np.array([999])),
                         "value":(("obs"), np.array([300])), 
                         "value_unc":(("obs"), np.array([np.nan])), 
                         "qcflag":(("obs"), [b"..."])},
                        coords={"obs": np.array([888]), "calendar_components": range(6)})

    xr.testing.assert_equal(format_obspack_geoschem.preprocess(in_df), out_df)
