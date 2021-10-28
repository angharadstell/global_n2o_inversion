#This script sees if there are any relationships between met data and fluxes

import configparser
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from sklearn import linear_model
from sklearn import preprocessing
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split

config = configparser.ConfigParser()
config.read(Path(__file__).parent.parent.parent / 'config.ini')


# read in met_data
met_data = pd.read_csv(Path(config["paths"]["meteo"]) / "region_training_data.csv", delimiter=" ")

# read in and process flux data
fluxes = pd.read_csv(Path(config["paths"]["inversion_results"]) / f"flux-aggregates-table-{config['inversion_constants']['land_ocean_equal_model_case']}.txt", 
                     delimiter="|", header=1109, usecols=[1,2,3,4], 
                     names=["estimate", "transcom_region", "date", "flux_mean"])
fluxes_select = fluxes[np.logical_and(fluxes["estimate"] == "WOMBAT IS    ", fluxes["transcom_region"].str.match(r"T[0-9]{2}"))]
fluxes_select["transcom_region"] = fluxes_select["transcom_region"].str.strip()
fluxes_select["date"] = fluxes_select["date"].str.strip()
fluxes_select = fluxes_select.drop("estimate", axis=1)
fluxes_select["flux_mean"] = pd.to_numeric(fluxes_select["flux_mean"])

# join two datasets together
joint = met_data.merge(fluxes_select, on=["date", "transcom_region"])

# select jsut land regions
joint_land = joint[joint["transcom_region"].str.match(r"T(0[0-9]{1}|1[0-1]{1})")]

#any relations between met and flux in each region?
for i in range(0, 12):
    # select region
    joint_T08 = joint_land[joint_land["transcom_region"]==f"T{i:02d}"]

    # rescale between 0 and 1
    min_max_scaler = preprocessing.MinMaxScaler()
    x_scaled = min_max_scaler.fit_transform(joint_T08[["sum_ppt", "mean_temp_aw", "month"]])

    # split into test and train data
    X_train, X_test, y_train, y_test = train_test_split(x_scaled, joint_T08["flux_mean"], test_size=0.2, random_state=0)

    # can we predict?
    regr = linear_model.LinearRegression()#RandomForestRegressor()#
    regr.fit(X_train,
            y_train)

    # absolutely not
    print(f"Region {i}")
    print(regr.score(X_test, y_test))

    # do some plots to check
    plt.scatter(joint_T08["mean_temp_aw"], joint_T08["flux_mean"])
    plt.show()
    plt.close()
