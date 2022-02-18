"""
Tests adjust_obspack.py

@author: Angharad Stell
"""
import numpy as np
import pytest
import xarray as xr

from n2o_inv.model_err import adjust_obspack



@pytest.fixture
def fake_obspack_nc():
    test_obspack_id = np.array([b'obspack_multi-species_1_AGAGEInSitu_v1.0_2010-01-01~n2o_aaa_surface-insitu_1_agage_Event~1',
                                b'obspack_multi-species_1_AGAGEInSitu_v1.0_2010-01-01~n2o_bbb_surface-insitu_1_agage_Event~2',
                                b'obspack_multi-species_1_AGAGEInSitu_v1.0_2010-01-01~n2o_ccc_surface-insitu_1_agage_Event~3',
                                b'obspack_multi-species_1_AGAGEInSitu_v1.0_2010-01-01~n2o_ddd_surface-insitu_1_agage_Event~4',
                                b'obspack_multi-species_1_AGAGEInSitu_v1.0_2010-01-01~n2o_eee_surface-insitu_1_agage_Event~5'])

    test_obspack = xr.Dataset(data_vars={"longitude":(("obs"), np.array([-180, -90, 0, 90, -180])),
                                         "latitude":(("obs"), np.array([-90, -45, 0, 45, 90])),
                                         "obspack_id":(("obs"), test_obspack_id)},
                               coords={"obs":np.array([1, 2, 3, 4, 5])})
    return test_obspack


def test_surround_obspack_obs_floor(fake_obspack_nc):
    func_out = adjust_obspack.surround_obspack(fake_obspack_nc)
    assert len(func_out.obs) == (len(fake_obspack_nc.obs) * 9)
    assert (np.floor(func_out.obs.values) == np.repeat(fake_obspack_nc.obs.values, 9)).all()


def test_surround_obspack_lon_neg180(fake_obspack_nc):
    func_out = adjust_obspack.surround_obspack(fake_obspack_nc)
    func_out_lon = func_out.longitude[0:9]
    assert list(func_out_lon).count(-180) == 3
    assert list(func_out_lon).count(-175) == 3
    assert list(func_out_lon).count(175) == 3

def test_surround_obspack_lon_neg90(fake_obspack_nc):
    func_out = adjust_obspack.surround_obspack(fake_obspack_nc)
    func_out_lon = func_out.longitude[9:18]
    assert list(func_out_lon).count(-90) == 3
    assert list(func_out_lon).count(-95) == 3
    assert list(func_out_lon).count(-85) == 3

def test_surround_obspack_lon_0(fake_obspack_nc):
    func_out = adjust_obspack.surround_obspack(fake_obspack_nc)
    func_out_lon = func_out.longitude[18:27]
    assert list(func_out_lon).count(0) == 3
    assert list(func_out_lon).count(-5) == 3
    assert list(func_out_lon).count(5) == 3

def test_surround_obspack_lon_90(fake_obspack_nc):
    func_out = adjust_obspack.surround_obspack(fake_obspack_nc)
    func_out_lon = func_out.longitude[27:36]
    assert list(func_out_lon).count(90) == 3
    assert list(func_out_lon).count(95) == 3
    assert list(func_out_lon).count(85) == 3

def test_surround_obspack_lat_neg90(fake_obspack_nc):
    func_out = adjust_obspack.surround_obspack(fake_obspack_nc)
    func_out_lat = func_out.latitude[0:9]
    assert list(func_out_lat).count(-90) == 6
    assert list(func_out_lat).count(-86) == 3

def test_surround_obspack_lat_neg45(fake_obspack_nc):
    func_out = adjust_obspack.surround_obspack(fake_obspack_nc)
    func_out_lat = func_out.latitude[9:18]
    assert list(func_out_lat).count(-45) == 3
    assert list(func_out_lat).count(-49) == 3
    assert list(func_out_lat).count(-41) == 3

def test_surround_obspack_lat_0(fake_obspack_nc):
    func_out = adjust_obspack.surround_obspack(fake_obspack_nc)
    func_out_lat = func_out.latitude[18:27]
    assert list(func_out_lat).count(0) == 3
    assert list(func_out_lat).count(4) == 3
    assert list(func_out_lat).count(-4) == 3

def test_surround_obspack_lat_45(fake_obspack_nc):
    func_out = adjust_obspack.surround_obspack(fake_obspack_nc)
    func_out_lat = func_out.latitude[27:36]
    assert list(func_out_lat).count(45) == 3
    assert list(func_out_lat).count(49) == 3
    assert list(func_out_lat).count(41) == 3

def test_surround_obspack_lat_90(fake_obspack_nc):
    func_out = adjust_obspack.surround_obspack(fake_obspack_nc)
    func_out_lat = func_out.latitude[36:45]
    assert list(func_out_lat).count(90) == 6
    assert list(func_out_lat).count(86) == 3

def test_surround_obspack_unique_neg90(fake_obspack_nc):
    func_out = adjust_obspack.surround_obspack(fake_obspack_nc)
    unique = np.unique(np.column_stack((func_out.latitude[0:9], func_out.longitude[0:9])), axis=0)
    assert unique.shape == (6, 2)

def test_surround_obspack_unique_neg45(fake_obspack_nc):
    func_out = adjust_obspack.surround_obspack(fake_obspack_nc)
    unique = np.unique(np.column_stack((func_out.latitude[9:18], func_out.longitude[9:18])), axis=0)
    assert unique.shape == (9, 2)

def test_surround_obspack_unique_0(fake_obspack_nc):
    func_out = adjust_obspack.surround_obspack(fake_obspack_nc)
    unique = np.unique(np.column_stack((func_out.latitude[18:27], func_out.longitude[18:27])), axis=0)
    assert unique.shape == (9, 2)

def test_surround_obspack_unique_45(fake_obspack_nc):
    func_out = adjust_obspack.surround_obspack(fake_obspack_nc)
    unique = np.unique(np.column_stack((func_out.latitude[27:36], func_out.longitude[27:36])), axis=0)
    assert unique.shape == (9, 2)

def test_surround_obspack_unique_90(fake_obspack_nc):
    func_out = adjust_obspack.surround_obspack(fake_obspack_nc)
    unique = np.unique(np.column_stack((func_out.latitude[36:45], func_out.longitude[36:45])), axis=0)
    assert unique.shape == (6, 2)
