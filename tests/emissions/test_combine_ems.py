"""
Tests agage_obs.py

@author: Angharad Stell
"""
import configparser
from pathlib import Path

import numpy as np
import pandas as pd
import pytest
import xarray as xr

from n2o_inv.emissions import combine_ems

@pytest.fixture
def geos_grid():
    config = configparser.ConfigParser()
    config.read(Path(__file__).parent.parent.parent / 'config.ini')
    return combine_ems.xr_read(Path(config["em_n_loss"]["geos_ems"]) / "geos_grid_info.nc")

def test_mid_month_date():
    desired_dates = pd.DatetimeIndex(['2012-01-15', '2012-02-15', '2012-03-15', '2012-04-15',
                                      '2012-05-15', '2012-06-15', '2012-07-15', '2012-08-15',
                                      '2012-09-15', '2012-10-15', '2012-11-15', '2012-12-15'])
    
    assert (combine_ems.mid_month_date(2012, 2012) == desired_dates).all()

def test_ems_regrid_zero(geos_grid):
    ems_field = np.zeros((12, len(geos_grid.lat), len(geos_grid.lon)))
    ems_time = pd.date_range(start="1/1/2012", end="12/31/2012", freq="MS")
    ems = xr.Dataset({"emi_n2o":(("time", "lat", "lon"), ems_field)},
                            coords={"time":ems_time,
                                    "lat":geos_grid.lat,
                                    "lon":geos_grid.lon})

    xr.testing.assert_equal(combine_ems.ems_regrid(ems), ems)

def test_ems_regrid_one(geos_grid):
    ems_field = np.ones((12, len(geos_grid.lat), len(geos_grid.lon)))
    ems_time = pd.date_range(start="1/1/2012", end="12/31/2012", freq="MS")
    ems = xr.Dataset({"emi_n2o":(("time", "lat", "lon"), ems_field)},
                            coords={"time":ems_time,
                                    "lat":geos_grid.lat,
                                    "lon":geos_grid.lon})

    xr.testing.assert_equal(combine_ems.ems_regrid(ems), ems)

def test_to_tgyr_zero(geos_grid):
    # relies on having run geoschem to get area, not good
    ems_field = np.zeros((12, len(geos_grid.lat), len(geos_grid.lon)))
    ems_time = pd.date_range(start="1/1/2012", end="12/31/2012", freq="MS")
    ems = xr.Dataset({"emi_n2o":(("time", "lat", "lon"), ems_field)},
                            coords={"time":ems_time,
                                    "lat":geos_grid.lat,
                                    "lon":geos_grid.lon})

    assert combine_ems.to_tgyr(ems, var="emi_n2o") == 0

def test_to_tgyr_one(geos_grid):
    # relies on having run geoschem to get area, not good
    ems_field = np.ones((12, len(geos_grid.lat), len(geos_grid.lon))) 
    # turn Tgyr-1 to kg/m2/s
    ems_field = ems_field / (366 * (60*60*24) * 10**-9)
    ems_field = ems_field / (510.1E6*(10**3)**2)
    ems_time = pd.date_range(start="1/1/2012", end="12/31/2012", freq="MS")
    ems = xr.Dataset({"emi_n2o":(("time", "lat", "lon"), ems_field)},
                            coords={"time":ems_time,
                                    "lat":geos_grid.lat,
                                    "lon":geos_grid.lon})

    assert combine_ems.to_tgyr(ems, var="emi_n2o") == pytest.approx(1, 1E-4)

def test_to_tgyr_notgeoschem_zero():
    ems_field = np.zeros((12, 2, 4))
    ems_time = pd.date_range(start="1/1/2012", end="12/31/2012", freq="MS")
    ems = xr.Dataset({"emi_n2o":(("time", "lat", "lon"), ems_field)},
                            coords={"time":ems_time,
                                    "lat":np.array([-45, 45]),
                                    "lon":np.array([-180, -90, 0, 90])})

    assert combine_ems.to_tgyr(ems, var="emi_n2o") == 0

def test_to_tgyr_notgeoschem_one():
    ems_field = np.ones((12, 2, 4))
    # turn Tgyr-1 to kg/m2/s
    ems_field = ems_field / (366 * (60*60*24) * 10**-9)
    ems_field = ems_field / (510.1E6*(10**3)**2)
    ems_time = pd.date_range(start="1/1/2012", end="12/31/2012", freq="MS")
    ems = xr.Dataset({"emi_n2o":(("time", "lat", "lon"), ems_field)},
                            coords={"time":ems_time,
                                    "lat":np.array([-45, 45]),
                                    "lon":np.array([-180, -90, 0, 90])})

    assert combine_ems.to_tgyr(ems, var="emi_n2o") == pytest.approx(1, 1E-2)

def test_to_tgyr_onetime_zero():
    ems_field = np.zeros((2, 4))
    ems = xr.Dataset({"emi_n2o":(("lat", "lon"), ems_field),
                      "time":pd.to_datetime("1/1/2012")},
                            coords={"lat":np.array([-45, 45]),
                                    "lon":np.array([-180, -90, 0, 90])})

    assert combine_ems.to_tgyr(ems, var="emi_n2o") == 0

def test_to_tgyr_onetime_one():
    ems_field = np.ones((2, 4))
    # turn Tgyr-1 to kg/m2/s
    ems_field = ems_field / (366 * (60*60*24) * 10**-9)
    ems_field = ems_field / (510.1E6*(10**3)**2)
    ems = xr.Dataset({"emi_n2o":(("lat", "lon"), ems_field),
                      "time":pd.to_datetime("1/1/2012")},
                            coords={"lat":np.array([-45, 45]),
                                    "lon":np.array([-180, -90, 0, 90])})

    assert combine_ems.to_tgyr(ems, var="emi_n2o") == pytest.approx(1/12, 2E-2)

def test_make_climatology_zero():
    ems_field = np.zeros((24, 2, 4))
    ems_time = pd.date_range(start="1/1/2012", end="12/31/2013", freq="MS")
    ems = xr.Dataset({"emi_n2o":(("time", "lat", "lon"), ems_field)},
                            coords={"time":ems_time,
                                    "lat":np.array([-45, 45]),
                                    "lon":np.array([-180, -90, 0, 90])})
    assert len(combine_ems.make_climatology(ems, 2014)["time"]) == 12
    assert (combine_ems.make_climatology(ems, 2014)["emi_n2o"] == 0).all()

def test_make_climatology_one_one():
    ems_field = np.zeros((24, 2, 4))
    ems_field[0, :, :] = 1
    ems_time = pd.date_range(start="1/1/2012", end="12/31/2013", freq="MS")
    ems = xr.Dataset({"emi_n2o":(("time", "lat", "lon"), ems_field)},
                            coords={"time":ems_time,
                                    "lat":np.array([-45, 45]),
                                    "lon":np.array([-180, -90, 0, 90])})
    assert len(combine_ems.make_climatology(ems, 2014)["time"]) == 12
    assert (combine_ems.make_climatology(ems, 2014)["emi_n2o"][0, :, :] == 0.5).all()

def test_basic_plot_runs():
    ems_field = np.zeros((24, 2, 4))
    ems_time = pd.date_range(start="1/1/2012", end="12/31/2013", freq="MS")
    ems = xr.Dataset({"emi_n2o":(("time", "lat", "lon"), ems_field)},
                            coords={"time":ems_time,
                                    "lat":np.array([-45, 45]),
                                    "lon":np.array([-180, -90, 0, 90])})
    combine_ems.basic_plot(ems)
