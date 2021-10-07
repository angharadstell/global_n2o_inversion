#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Mar  3 10:32:26 2021

@author: as16992
"""
import calendar
import configparser
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import xarray as xr

from acrg.grid.areagrid import areagrid
from acrg.grid.regrid import regrid2d
#from acrg_mozart import acrg_MOZART_angharad as mzt

from n2o_inv.plots import map_plot

def xr_read(file):
    """ Read in netcdf to xarray. """
    with xr.open_dataset(file) as load:
        xr_data = load.load()
    return xr_data

def mid_month_date(start_year, end_year):
    """ Create array of pandas datetime for the 15th of each month. """
    start_month = pd.date_range(start=f"1/1/{start_year}", end=f"12/31/{end_year}", freq="MS")
    mid_month = start_month + pd.DateOffset(days=14)
    return mid_month

def ems_regrid(ems):
    """ Regrid emissions to GEOS-Chem grid and format to nice xarray object. """
    # geos grid constants
    geos_grid = xr_read(Path(__file__).parent / "geos_grid_info.nc")

    ems_regridded = np.zeros((len(ems["time"]), len(geos_grid.lat), len(geos_grid.lon)))
    # with mzt.suppress_stdout():
    for month in range(len(ems["time"])):
        ems_regridded[month, :, :] = regrid2d(ems["emi_n2o"].values[month, :, :], 
                                              ems["lat"].values,
                                              ems["lon"].values, 
                                              geos_grid.lat.values,
                                              geos_grid.lon.values, 
                                              global_grid=True)[0]
    
    ems = xr.Dataset({"emi_n2o":(("time", "lat", "lon"), ems_regridded)},
                             coords={"time":ems["time"],
                                     "lat":geos_grid.lat.values,
                                     "lon":geos_grid.lon.values})
    return ems

def to_tgyr(ems, var="emi_n2o"):
    """ Converts emissions to Tg for comparison to Wells paper.
        My answers are all lower than Wells but my answer agrees with 
        GFED totals better... Part of the issue could be that acrg code 
        disagrees with GEOS-Chem about the area of the grid. Should be
        minor problem as most differences at the poles where there are no
        emissions.
    """
    # take GEOS-Chem area if GEOS-Chem grid
    if np.logical_and(len(ems["lat"].values) == 46, len(ems["lon"].values) == 72):
        # geos grid constants
        area = xr_read(Path(__file__).parent / "geos_grid_info.nc")
    # Otherwise work out area    
    else:
        area = xr.Dataset({"area":(("lat", "lon"), areagrid(ems["lat"].values, ems["lon"].values))},
                            coords={"lat":ems["lat"].values, "lon":ems["lon"].values})

    year = ems.time.dt.year
    month = ems.time.dt.month
    if year.values.size > 1:
        zipped = zip(year.values, month.values)
    else:
        zipped = [(year.values, month.values)]
    days_in_month = np.array([calendar.monthrange(m[0], m[1])[1] for m in zipped])
    
    area_weight_sum = (ems[var] * area["area"]).sum(["lat", "lon"]).values
    
    return np.sum(area_weight_sum * days_in_month * (60*60*24) * 10**-9)

def make_climatology(ems, new_year):
    """ Turn time varying emissions into a monthly climatology. """
    monthly_mean = ems.groupby(ems.time.dt.month).mean()
    monthly_mean = monthly_mean.rename({"month":"time"})
    monthly_mean["time"] = mid_month_date(new_year, new_year)
    return monthly_mean

def basic_plot(ems):
    """ Basic line plot of annual emissions. """
    annual_sum = [to_tgyr(ems.isel(time=slice(t, t+12))) for t in range(0, len(ems["time"]), 12)]
    plt.plot(ems.resample(time="Y").mean()["time"], annual_sum)
    plt.show()
    plt.close()

if __name__ == "__main__":
    # read in variables from the config file
    config = configparser.ConfigParser()
    config.read(Path(__file__).parent.parent.parent / 'config.ini')
    N2O_MW = float(config["gas_info"]["molecular_weight"])
    SHARED_N2O = Path(config["em_n_loss"]["raw_ems"]) # still relies on a file structure match BP1
    GEOS_OUT = Path(config["paths"]["geos_out"])
    GEOS_EMS = Path(config["em_n_loss"]["geos_ems"])

    # =============================================================================
    # GEOSChem constants
    # =============================================================================
    geos_start_year = 1970
    geos_end_year = 2020
    geos_time = mid_month_date(geos_start_year, geos_end_year)
    
    # =============================================================================
    # EDGAR
    # =============================================================================
    # List of EDGAR files
    edgar_path = SHARED_N2O / "N2O/EDGAR_v5.0/yearly"
    edgar_files = list(edgar_path.glob("v50_N2O_????.0.1x0.1.nc"))
    edgar_files.sort()
    # Read in EDGAR files
    edgar_ems = xr.concat([xr_read(file) for file in edgar_files], dim="time")
    # Sort out time and dimension order
    edgar_ems_time = pd.date_range(start="1/1/1970", end="1/1/2015", freq="YS") + pd.DateOffset(months=6)
    edgar_ems = edgar_ems.assign_coords(time=edgar_ems_time)
    edgar_ems = edgar_ems.transpose("time", "lat", "lon")
    
    # Print 2008 total
    print(f"Original EDGAR 2008 ems: {to_tgyr(edgar_ems.isel(time=38)) * 12} Tgyr-1")
    
    # regrid to GEOSChem
    edgar_ems = ems_regrid(edgar_ems)
    
    edgar_ems = edgar_ems.resample(time="MS").nearest()
    edgar_ems["time"] = pd.date_range(start="7/1/1970", end="7/31/2015", freq="MS") + pd.DateOffset(days=14)
    
    edgar_ems = edgar_ems.interp(time=geos_time, method="nearest", kwargs={"fill_value":"extrapolate"})
    
    # Print 2008 total
    print(f"GEOS EDGAR 2008 ems: {to_tgyr(edgar_ems.isel(time=slice(456, 468)))} Tgyr-1")
    
    # Visualise
    basic_plot(edgar_ems)
    
    map_plot.cartopy_plot(edgar_ems["emi_n2o"].mean("time"), "EDGAR N2O ems / kg m-2 s-1", None)
    
    # =============================================================================
    # Saikawa 2013
    # =============================================================================
    
    saikawa_file = SHARED_N2O / "N2O/Saikawa_natural_soil/N2O_flux_natsoil_global_1990_2008.nc"
    
    saikawa_ems = xr_read(saikawa_file)
    saikawa_ems = saikawa_ems.assign_coords(time=mid_month_date(1990, 2008))
    
    saikawa_ems = saikawa_ems.drop_vars(["date", "datesec"])
    saikawa_ems = saikawa_ems.rename({"flux":"emi_n2o"})
    
    # Print 2008 total
    saikawa_ems_2008 = saikawa_ems.isel(time=slice(-12, len(saikawa_ems["time"])))
    print(f"Original Saikawa 2008 ems: {to_tgyr(saikawa_ems_2008)} Tgyr-1")
    
    # regrid
    saikawa_ems = ems_regrid(saikawa_ems)
    
    # Print 2008 total
    saikawa_ems_2008 = saikawa_ems.isel(time=slice(-12, len(saikawa_ems["time"])))
    print(f"GEOS Saikawa 2008 ems: {to_tgyr(saikawa_ems_2008)} Tgyr-1")
    
    saikawa_ems = xr.concat([make_climatology(saikawa_ems, year) 
                             for year in range(geos_start_year, geos_end_year+1)], dim="time")
    
    # Visualise
    basic_plot(saikawa_ems)
    
    map_plot.cartopy_plot(saikawa_ems["emi_n2o"].mean("time"), "Saikawa N2O ems / kg m-2 s-1", None)
    
    # =============================================================================
    # GFED4s
    # =============================================================================
    # Do these emissions actually agree with GFED table?
    # List of GFED4 files
    gfed_path = SHARED_N2O / "GFED4/processed_nc_files"
    gfed_files = list(gfed_path.glob("n2o-fire_GLOBAL_????.nc"))
    gfed_files.sort()
    # Read in GFED4 files
    with xr.open_mfdataset(gfed_files) as load:
        gfed_ems = load.load()
    
    gfed_ems = gfed_ems.assign_coords(time=mid_month_date(1997, 2019))
    gfed_ems = gfed_ems.transpose("time", "lat", "lon")
    
    gfed_ems = gfed_ems.rename({"flux":"emi_n2o"})
    
    # Convert to kg/m2/s
    gfed_ems["emi_n2o"] = gfed_ems["emi_n2o"] * N2O_MW *10**-3
    
    # Print 2008 total
    gfed_ems_2008 = gfed_ems.isel(time=slice(132, 144))
    print(f"Original GFED4 2008 ems: {to_tgyr(gfed_ems_2008)} Tgyr-1")
    
    # regrid
    gfed_ems = ems_regrid(gfed_ems)
    
    # Print 2008 total
    gfed_ems_2008 = gfed_ems.isel(time=slice(132, 144))
    print(f"GEOS GFED4 2008 ems: {to_tgyr(gfed_ems_2008)} Tgyr-1")
    
    gfed_ems = xr.concat([make_climatology(gfed_ems, year) 
                          for year in range(geos_start_year, geos_end_year+1)], dim="time")
    
    # Visualise
    basic_plot(gfed_ems)
    
    map_plot.cartopy_plot(gfed_ems["emi_n2o"].mean("time"), "GFED4 N2O ems / kg m-2 s-1", None)
    
    
    # =============================================================================
    # ECCO2
    # =============================================================================
    
    ecco2_path = SHARED_N2O / "N2O/ECCO2_Dawrin_Ocean"
    
    ecco2_ems = xr_read(ecco2_path / "File_N2OFLXS_1by1_2006_2013_WK92_ECCO2Darwin.nc")
    ecco2_ems = ecco2_ems.assign_coords(time=mid_month_date(2006, 2013))
    
    ecco2_ems = ecco2_ems.drop_vars(["Flux_N2O_Th", "Flux_N2O_Vent", "SurfaceMask", "Area"])
    ecco2_ems = ecco2_ems.rename({"Flux_N2O_Tot":"emi_n2o", "latitude":"lat", "longitude":"lon"})
    
    # Negative flux means it comes out of the ocean, positive goes in?
    # Do I want positive ones?
    ecco2_ems["emi_n2o"] = ecco2_ems["emi_n2o"] * -1
    
    # Convert to kg/m2/s
    ecco2_ems["emi_n2o"] = ecco2_ems["emi_n2o"] * N2O_MW *10**-3
    
    # Print 2008 total
    ecco2_ems_2008 = ecco2_ems.isel(time=slice(24, 36))
    print(f"Original ECCO2 2008 ems: {to_tgyr(ecco2_ems_2008)} Tgyr-1")
    
    # regrid
    ecco2_ems = ems_regrid(ecco2_ems)
    
    # Print 2008 total
    ecco2_ems_2008 = ecco2_ems.isel(time=slice(24, 36))
    print(f"GEOS ECCO2 2008 ems: {to_tgyr(ecco2_ems_2008)} Tgyr-1")
    
    ecco2_ems = xr.concat([make_climatology(ecco2_ems, year)
                           for year in range(geos_start_year, geos_end_year+1)], dim="time")
    
    # Visualise
    basic_plot(ecco2_ems)
    
    map_plot.cartopy_plot(ecco2_ems["emi_n2o"].mean("time"), "ECCO2 N2O ems / kg m-2 s-1", None)
    
    # =============================================================================
    # Total emissions
    # =============================================================================
    
    total_ems = edgar_ems + saikawa_ems + ecco2_ems + gfed_ems
    
    # Visualise
    basic_plot(total_ems)
    
    map_plot.cartopy_plot(total_ems["emi_n2o"].mean("time"), "Total N2O ems / kg m-2 s-1", None)
    
    # Match time coords to HEMCO
    hours_since_start = (total_ems["time"].values - total_ems["time"].values[0]) / np.timedelta64(1, 'h') 
    total_ems = total_ems.assign_coords(time=hours_since_start.astype(int))
    
    # Units
    total_ems["lat"].attrs["units"] = "degrees_north"
    total_ems["lon"].attrs["units"] = "degrees_east"
    total_ems["time"].attrs["units"] = "hours since 1970-1-1 00:00:00"
    total_ems["emi_n2o"].attrs["units"] = "kg/m2/s"
    
    # Replace nan with zero
    total_ems = total_ems.fillna(0)
    
    # Save total emissions
    total_ems.to_netcdf(GEOS_EMS / "base_emissions.nc")
