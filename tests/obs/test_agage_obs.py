"""
Tests agage_obs.py

@author: Angharad Stell
"""

import numpy as np

from n2o_inv.obs import agage_obs

def test_dt2cal():
    assert agage_obs.dt2cal(np.datetime64("2012-02-29T12:57:09")) == [2012, 2, 29, 12, 57, 9]

def test_create_obspack_id():
    site = "ABC"
    year = 2012
    month = 2
    day = 29
    identifier = 999
    assert agage_obs.create_obspack_id(site, year, month, day, identifier) == \
        b"obspack_multi-species_1_AGAGEInSitu_v1.0_2012-02-29~n2o_abc_surface-insitu_1_agage_Event~999"

def test_create_noaa_style_flag():
    for i in range(4):
        status_flag = np.array([0, 1, 0, 1])
        integration_flag = np.array([0, 0, 1, 1])
        correct_answer = [b"...", b"a..", b".a.", b"aa."]
        assert agage_obs.create_noaa_style_flag(status_flag[i], integration_flag[i]) == correct_answer[i]
