"""
Tests make_ems.py

@author: Angharad Stell
"""
import numpy as np
import pandas as pd
import pytest
import xarray as xr

from n2o_inv.validation import make_ems

@pytest.fixture
def fake_ems():
    ems_00 = np.zeros((12, 2, 2))
    ems_01 = np.zeros((12, 2, 2))
    ems_02 = np.zeros((12, 2, 2))
    ems_03 = np.zeros((12, 2, 2))

    ems_00[:, 0, 0] = 1
    ems_01[:, 1, 0] = 1
    ems_02[:, 0, 1] = 1
    ems_03[:, 1, 1] = 1

    fake_ems = xr.Dataset({"emi_n2o":(("time", "lat", "lon"), np.ones((12, 2, 2))),
                           "emi_R00":(("time", "lat", "lon"), ems_00),
                           "emi_R01":(("time", "lat", "lon"), ems_01),
                           "emi_R02":(("time", "lat", "lon"), ems_02),
                           "emi_R03":(("time", "lat", "lon"), ems_03)},
        coords={"lat":np.array([-45, 45]),
                "lon":np.array([-90, 90]),
                "time":pd.date_range("2010-01-01", "2011-01-01", freq="M")})

    return fake_ems



def test_month_diff_same_year():
    a = pd.to_datetime("2010-01-01")
    b = pd.to_datetime("2010-06-01")
    assert make_ems.month_diff(a, b) == 5

def test_month_diff_diff_year():
    a = pd.to_datetime("2010-01-01")
    b = pd.to_datetime("2011-06-01")
    assert make_ems.month_diff(a, b) == 17

def test_month_diff_reverse():
    b = pd.to_datetime("2010-01-01")
    a = pd.to_datetime("2011-06-01")
    assert make_ems.month_diff(a, b) == 17

def test_rescale_ems_minus_one(fake_ems):
    alphas = np.repeat(-1, 12 * 4).reshape(12, 4)

    out = make_ems.rescale_ems(fake_ems, alphas, 4)
    assert (out["emi_n2o"] == 0).all()
    assert (out["emi_R00"] == 0).all()
    assert (out["emi_R01"] == 0).all()
    assert (out["emi_R02"] == 0).all()
    assert (out["emi_R03"] == 0).all()

def test_rescale_ems_zero(fake_ems):
    alphas = np.repeat(0, 12 * 4).reshape(12, 4)

    out = make_ems.rescale_ems(fake_ems, alphas, 4)
    assert (out["emi_n2o"] == 1).all()

def test_rescale_ems_one(fake_ems):
    alphas = np.repeat(1, 12 * 4).reshape(12, 4)

    out = make_ems.rescale_ems(fake_ems, alphas, 4)
    assert (out["emi_n2o"] == 2).all()

