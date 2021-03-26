#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Mar  3 10:32:26 2021

@author: as16992
"""
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import sys
import xarray as xr

from acrg_grid import areagrid
from acrg_grid import regrid
from acrg_mozart import acrg_MOZART_angharad as mzt

sys.path.insert(0, "/home/as16992/d2h_ch4")
import make_pretty_d2h_map_plots as make_pretty

SHARED_N2O = Path("/work/chxmr/shared/Gridded_fluxes/N2O")

N2O_MW = 44.02

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
    ems_regridded = np.zeros((len(ems["time"]), len(geos_lat), len(geos_lon)))
    with mzt.suppress_stdout():
        for month in range(len(ems["time"])):
            ems_regridded[month, :, :] = regrid.regrid2d(ems["emi_n2o"].values[month, :, :], 
                                                         ems["lat"].values,
                                                         ems["lon"].values, 
                                                         geos_lat, geos_lon, 
                                                         global_grid=True)[0]
    
    ems = xr.Dataset({"emi_n2o":(("time", "lat", "lon"), ems_regridded)},
                             coords={"time":ems["time"],
                                     "lat":geos_lat,
                                     "lon":geos_lon})
    return ems

def to_tgyr(ems, var="emi_n2o"):
    """ Converts 2008 emissions to Tgyr-1 for comparison to Wells paper.
        (Assumes LEAP YEAR, so not widely applicable).
        My answers are all lower than Wells but my answer agrees with 
        GFED totals better... Part of the issue could be that acrg code 
        disagrees with GEOS-Chem about the area of the grid. Should be
        minor problem as most differences at the poles where there are no
        emissions.
    """
    # take GEOS-Chem area if GEOS-Chem grid
    if np.logical_and(len(ems["lat"].values) == 46, len(ems["lon"].values) == 72):
        out_path = Path("/work/as16992/geoschem/N2O/output/")
        sc_fns = sorted(out_path.glob("GEOSChem.SpeciesConc.*"))
        ds_conc = xr_read(sc_fns[0])
        area = xr.Dataset({"area":(("lat", "lon"), ds_conc.AREA.values)},
                            coords={"lat":ds_conc.lat.values, "lon":ds_conc.lon.values})
    # Otherwise work out area    
    else:
        area = xr.Dataset({"area":(("lat", "lon"), areagrid(ems["lat"].values, ems["lon"].values))},
                            coords={"lat":ems["lat"].values, "lon":ems["lon"].values})
    days_in_month = np.array([31,29,31,30,31,30,31,31,30,31,30,31])
    
    area_weight_sum = (ems[var] * area["area"]).sum(["lat", "lon"]).values
    
    if ems[var].shape[0] == 12:
        return np.sum(area_weight_sum * days_in_month * (60*60*24) * 10**-9)
    else:
        return np.sum(area_weight_sum * (60*60*24*366) * 10**-9)

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
    # =============================================================================
    # GEOSChem constants
    # =============================================================================
    geos_start_year = 1970
    geos_end_year = 2020
    geos_time = mid_month_date(geos_start_year, geos_end_year)
    
    geos_lat = np.array([-89, -86, -82, -78, -74, -70, -66, -62, -58, -54, -50,
                         -46, -42, -38, -34, -30, -26, -22, -18, -14, -10, -6,
                         -2, 2, 6, 10, 14, 18, 22, 26, 30, 34, 38, 42, 46, 50,
                         54, 58, 62, 66, 70, 74, 78, 82, 86, 89])
    
    geos_lon = np.array([-180, -175, -170, -165, -160, -155, -150, -145, -140,
                         -135, -130, -125, -120, -115, -110, -105, -100, -95,
                         -90, -85, -80, -75, -70, -65, -60, -55, -50, -45, -40,
                         -35, -30, -25, -20, -15, -10, -5, 0, 5, 10, 15, 20, 25,
                         30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 
                         100, 105, 110, 115, 120, 125, 130, 135, 140, 145, 150, 
                         155, 160, 165, 170, 175])
    
    # =============================================================================
    # EDGAR
    # =============================================================================
    # List of EDGAR files
    edgar_path = SHARED_N2O / "EDGAR_v5.0/yearly"
    edgar_files = list(edgar_path.glob("v50_N2O_????.0.1x0.1.nc"))
    edgar_files.sort()
    # Read in EDGAR files
    edgar_ems = xr.concat([xr_read(file)for file in edgar_files], dim="time")
    # Sort out time and dimension order
    edgar_ems_time = pd.date_range(start="1/1/1970", end="1/1/2015", freq="YS") + pd.DateOffset(months=6)
    edgar_ems = edgar_ems.assign_coords(time=edgar_ems_time)
    edgar_ems = edgar_ems.transpose("time", "lat", "lon")
    
    # Print 2008 total
    print(f"Original EDGAR 2008 ems: {to_tgyr(edgar_ems.isel(time=38))} Tgyr-1")
    
    # regrid to GEOSChem
    edgar_ems = ems_regrid(edgar_ems)
    
    edgar_ems = edgar_ems.resample(time="MS").nearest()
    edgar_ems["time"] = pd.date_range(start="7/1/1970", end="7/31/2015", freq="MS") + pd.DateOffset(days=14)
    
    edgar_ems = edgar_ems.interp(time=geos_time, method="nearest", kwargs={"fill_value":"extrapolate"})
    
    # Print 2008 total
    print(f"GEOS EDGAR 2008 ems: {to_tgyr(edgar_ems.isel(time=slice(456, 468)))} Tgyr-1")
    
    # Visualise
    basic_plot(edgar_ems)
    
    make_pretty.cartopy_plot(edgar_ems["emi_n2o"].mean("time"), "EDGAR N2O ems / kg m-2 s-1", None)
    
    # =============================================================================
    # Saikawa 2013
    # =============================================================================
    
    saikawa_file = SHARED_N2O / "Saikawa_natural_soil/N2O_flux_natsoil_global_1990_2008.nc"
    
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
    
    make_pretty.cartopy_plot(saikawa_ems["emi_n2o"].mean("time"), "Saikawa N2O ems / kg m-2 s-1", None)
    
    # =============================================================================
    # GFED4s
    # =============================================================================
    # Do these emissions actually agree with GFED table?
    # List of GFED4 files
    gfed_path = Path("/work/chxmr/shared/Gridded_fluxes/GFED4/processed_nc_files")
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
    
    make_pretty.cartopy_plot(gfed_ems["emi_n2o"].mean("time"), "GFED4 N2O ems / kg m-2 s-1", None)
    
    
    # =============================================================================
    # ECCO2
    # =============================================================================
    
    ecco2_path = Path("/work/chxmr/shared/Gridded_fluxes/N2O/ECCO2_Dawrin_Ocean")
    
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
    
    make_pretty.cartopy_plot(ecco2_ems["emi_n2o"].mean("time"), "ECCO2 N2O ems / kg m-2 s-1", None)
    
    # =============================================================================
    # Total emissions
    # =============================================================================
    
    total_ems = edgar_ems + saikawa_ems + ecco2_ems + gfed_ems
    
    # Visualise
    basic_plot(total_ems)
    
    make_pretty.cartopy_plot(total_ems["emi_n2o"].mean("time"), "Total N2O ems / kg m-2 s-1", None)
    
    # Match time coords to HEMCO
    hours_since_start = (total_ems["time"].values - total_ems["time"].values[0]) / np.timedelta64(1, 'h') 
    total_ems = total_ems.assign_coords(time=hours_since_start.astype(int))
    
    # Units
    total_ems["lat"].attrs["units"] = "degrees_north"
    total_ems["lon"].attrs["units"] = "degrees_east"
    total_ems["time"].attrs["units"] = "hours since 1970-1-1 00:00:00"
    total_ems["emi_n2o"].attrs["units"] = "kg/m2/s"
    
    # Testing
    #total_ems["emi_n2o"][-24,:,:] = 0.
    
    # Mask anything below zero - dunno if this is right
    total_ems = total_ems.where(total_ems["emi_n2o"] > 0)
    # Replace nan with zero
    total_ems = total_ems.fillna(0)
    
    # Save total emissions
    total_ems.to_netcdf("/work/as16992/geoschem/N2O/emissions/base_emissions.nc")
