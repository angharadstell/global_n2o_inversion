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
    status_flag = np.array([0, 1, 0, 1])
    integration_flag = np.array([0, 0, 1, 1])
    correct_answer = [b"...", b"a..", b".a.", b"aa."]
    for i in range(4):
        assert agage_obs.create_noaa_style_flag(status_flag[i], integration_flag[i]) == correct_answer[i]

def test_datetime_to_unix_zero():
    assert agage_obs.datetime_to_unix(np.datetime64("1970-01-01T00:00:00")) == 0

def test_datetime_to_unix_day():
    assert agage_obs.datetime_to_unix(np.datetime64("1970-01-02T00:00:00")) == (60*60*24)

def test_datetime_to_unix_month():
    assert agage_obs.datetime_to_unix(np.datetime64("1970-02-01T00:00:00")) == (60*60*24*31)

def test_datetime_to_unix_year():
    assert agage_obs.datetime_to_unix(np.datetime64("1971-01-01T00:00:00")) == (60*60*24*365)