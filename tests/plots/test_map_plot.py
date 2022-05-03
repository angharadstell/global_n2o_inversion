"""
Tests map_plot.py

@author: Angharad Stell
"""
import numpy as np
import xarray as xr

from n2o_inv.plots import map_plot



def test_colormesh_lon_mozart():
    assert (map_plot.colormesh_lon(np.array([45, 135, 225, 315])) == np.array([0, 90, 180, 270, 360])).all()

def test_colormesh_lon_geoschem():
    assert (map_plot.colormesh_lon(np.array([-135, -45, 45, 135])) == np.array([-180, -90, 0, 90, 180])).all()

def test_colormesh_lat_two_boxes():
    assert (map_plot.colormesh_lat(np.array([-45, 45])) == np.array([-90, 0, 90])).all()

def test_cartopy_plot_runs():
    ems_field = np.zeros((2, 4))
    ems = xr.DataArray(ems_field,
                            coords={"lat":np.array([-45, 45]),
                                    "lon":np.array([-135, -45, 45, 135])})
    map_plot.cartopy_plot(ems, "test", None)

def test_cartopy_plot_savefile(tmp_path):
    ems_field = np.zeros((2, 4))
    ems = xr.DataArray(ems_field,
                            coords={"lat":np.array([-45, 45]),
                                    "lon":np.array([-135, -45, 45, 135])})
    map_plot.cartopy_plot(ems, "test", tmp_path / "test.png")
