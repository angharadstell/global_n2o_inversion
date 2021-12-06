"""
Tests process_geos_ems.py

@author: Angharad Stell
"""
import numpy as np
import pytest
import xarray as xr

from n2o_inv.intermediates import process_geos_ems

def test_geoschem_cell_size_uneven_lon():
    fake_grid = xr.Dataset({"lat": np.array([0, 0, 0]), 
                            "lon": np.array([-75, 0, 120])})

    with pytest.raises(ValueError):
        process_geos_ems.geoschem_cell_size(fake_grid)

def test_geoschem_cell_size_zeros():
    fake_grid = xr.Dataset({"lat": np.array([0, 0, 0]), 
                            "lon": np.array([0, 0, 0])})

    lat_widths, lon_widths = process_geos_ems.geoschem_cell_size(fake_grid)

    assert (0 == lat_widths).all()
    assert (0 == lon_widths).all()

def test_geoschem_cell_size_lat_range():
    fake_grid = xr.Dataset({"lat": np.linspace(-80, 80, 9), 
                            "lon": np.array([0, 0, 0])})

    lat_widths, _ = process_geos_ems.geoschem_cell_size(fake_grid)

    assert (20 == lat_widths).all()

def test_geoschem_cell_size_lat_range_halfpolar():
    half_polar_lat = np.concatenate((np.array([-87.5]), np.linspace(-80, 80, 17), np.array([87.5])))
    fake_grid = xr.Dataset({"lat": half_polar_lat, 
                            "lon": np.array([0, 0, 0])})
    lat_widths, _ = process_geos_ems.geoschem_cell_size(fake_grid)

    ideal_lat_widths = np.concatenate((np.array([5]), np.array([10]*(len(half_polar_lat)-2)), np.array([5])))

    assert (ideal_lat_widths == lat_widths).all()

def test_geoschem_cell_size_lon_range():
    fake_grid = xr.Dataset({"lat": np.array([0, 0, 0]), 
                            "lon": np.linspace(-170, 170, 35)})

    _, lon_widths = process_geos_ems.geoschem_cell_size(fake_grid)

    assert (10 == lon_widths).all()