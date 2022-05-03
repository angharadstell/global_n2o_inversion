"""
Tests validating.py

@author: Angharad Stell
"""
from unittest.mock import patch

import numpy as np
import xarray as xr

from n2o_inv.validation import validating

def test_read_geos_runs(tmp_path):
    ds1 = xr.Dataset({"obspack_id": (("obs"), ["sitea_1", "siteb_2"]),
                      "CH4_R00": (("obs"), np.array([1, 2])),
                      "CH4_R01": (("obs"), np.array([5, 6]))},
                      coords={"obs": np.array([1, 2])})
    ds2 = xr.Dataset({"obspack_id": (("obs"), ["sitea_3", "siteb_4"]),
                      "CH4_R00": (("obs"), np.array([3, 4])),
                      "CH4_R01": (("obs"), np.array([7, 8]))},
                      coords={"obs": np.array([3, 4])})
    ds1.to_netcdf(tmp_path / "GEOSChem.ObsPack.20110101_0000z.nc4")
    ds2.to_netcdf(tmp_path / "GEOSChem.ObsPack.20110102_0000z.nc4")
    
    obspack_obs = xr.Dataset({"obspack_id": (("obs"), ["sitea_1", "siteb_2", "sitea_3", "siteb_4"])},
                             coords={"obs": np.array([5, 6, 7, 8])})

    func_out = validating.read_geos(obspack_obs, tmp_path, n_regions=1)

    assert (func_out["obs"] == np.array([5, 6, 7, 8])).all()
    assert (func_out["CH4_R00"] == np.array([1E9, 2E9, 3E9, 4E9])).all()
    assert (func_out["CH4_R01"] == np.array([5E9, 6E9, 7E9, 8E9])).all()
    assert (func_out["CH4_sum"] == np.array([6E9, 8E9, 10E9, 12E9])).all()

@patch("validating.plt.show")
def test_zonal_plot_runs(tmp_path):

    obspack_obs = xr.Dataset({"obspack_id": (("obs"), ["sitea_1", "siteb_2", "sitea_3", "siteb_4"]),
                              "latitude": (("obs"), np.array([-90, -45, 45, 90])),
                              "altitude": (("obs"), np.array([0, 2000, 4000, 8000])),
                              "value": (("obs"), np.array([301, 302, 303, 304]))},
                             coords={"obs": np.array([5, 6, 7, 8])})

    geos_prior = xr.Dataset({"CH4_sum": (("obs"), np.array([305, 306, 307, 308]))},
                             coords={"obs": np.array([5, 6, 7, 8])})

    geos_post = xr.Dataset({"CH4_sum": (("obs"), np.array([302, 303, 304, 305]))},
                             coords={"obs": np.array([5, 6, 7, 8])})


    validating.zonal_plot(obspack_obs, geos_prior, geos_post, "TEST", tmp_path / "test.pdf")
