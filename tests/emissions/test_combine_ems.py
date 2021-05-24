"""
Tests agage_obs.py

@author: Angharad Stell
"""

import numpy as np
import pandas as pd
import pytest
import xarray as xr

from n2o_inv.emissions import combine_ems

def test_mid_month_date():
    desired_dates = pd.DatetimeIndex(['2012-01-15', '2012-02-15', '2012-03-15', '2012-04-15',
                                      '2012-05-15', '2012-06-15', '2012-07-15', '2012-08-15',
                                      '2012-09-15', '2012-10-15', '2012-11-15', '2012-12-15'])
    
    assert (combine_ems.mid_month_date(2012, 2012) == desired_dates).all()

def test_ems_regrid():
    ems_field = np.zeros((12, len(combine_ems.geos_lat), len(combine_ems.geos_lon)))
    ems_time = pd.date_range(start="1/1/2012", end="12/31/2012", freq="MS")
    ems = xr.Dataset({"emi_n2o":(("time", "lat", "lon"), ems_field)},
                            coords={"time":ems_time,
                                    "lat":combine_ems.geos_lat,
                                    "lon":combine_ems.geos_lon})

    xr.testing.assert_equal(combine_ems.ems_regrid(ems), ems)

def test_to_tgyr_zero():
    # relies on having run geoschem to get area, not good
    ems_field = np.zeros((12, len(combine_ems.geos_lat), len(combine_ems.geos_lon)))
    ems_time = pd.date_range(start="1/1/2012", end="12/31/2012", freq="MS")
    ems = xr.Dataset({"emi_n2o":(("time", "lat", "lon"), ems_field)},
                            coords={"time":ems_time,
                                    "lat":combine_ems.geos_lat,
                                    "lon":combine_ems.geos_lon})

    assert combine_ems.to_tgyr(ems, var="emi_n2o") == 0

def test_to_tgyr_one():
    # relies on having run geoschem to get area, not good
    ems_field = np.ones((12, len(combine_ems.geos_lat), len(combine_ems.geos_lon))) 
    # turn Tgyr-1 to kg/m2/s
    ems_field = ems_field / (366 * (60*60*24) * 10**-9)
    ems_field = ems_field / (510.1E6*(10**3)**2)
    ems_time = pd.date_range(start="1/1/2012", end="12/31/2012", freq="MS")
    ems = xr.Dataset({"emi_n2o":(("time", "lat", "lon"), ems_field)},
                            coords={"time":ems_time,
                                    "lat":combine_ems.geos_lat,
                                    "lon":combine_ems.geos_lon})

    assert combine_ems.to_tgyr(ems, var="emi_n2o") == pytest.approx(1, 1E-4)
