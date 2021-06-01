"""
This script reads in GEOSChem output and plots it to check it makes sense.

@author: Angharad Stell
"""
import configparser
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import xarray as xr

from n2o_inv.plots import map_plot

# =============================================================================
# Functions
# =============================================================================

def time_adjust_spinup(out_files):
    """
    Read in spinup geoschem output and adjust the dates so they can be merged 
    into a single xarray object that contains all the years.
    """ 
    spinup_list = []
    for i in range(0, len(out_files), 12):
        with xr.open_mfdataset(out_files[i:i+12]) as load:
            geos_out = load.load() 
        # doesn't deal with leap years, but is good enough for plotting purposes
        no_years = int(len(out_files) / 12)
        t_adjust = np.timedelta64((365 * (no_years - int(i / 12))), "D")
        geos_out["time"] = geos_out["time"].values - t_adjust
        spinup_list.append(geos_out)
        geos_all = xr.merge(spinup_list)

    return geos_all

def calc_monthly_mean_conc(geos_out):   
    """
    Calculate the monthly mean value for the GEOSChem output.
    """ 
    geos_n2o_area = geos_out["SpeciesConc_CH4"] * geos_out["AREA"]
    total_area = geos_out["AREA"].sum(dim=["lat", "lon"])
    geos_n2o_mean = geos_n2o_area.isel(lev=0).sum(dim=["lat", "lon"]) * 10**9 / total_area
    return geos_n2o_mean

def plot_monthly_mean(geos_out):
    """
    Calculate and plot the monthly mean value for the GEOSChem output.
    """ 
    monthly_mean = calc_monthly_mean_conc(geos_out)
    plt.plot(monthly_mean.time, monthly_mean)
    plt.ylabel("N2O mole fraction / ppb")
    plt.xticks(rotation=45)
    plt.show()
    plt.close()

def calc_height(geos_out):
    """
    Calculate the approximate height of geoschem levels.
    """ 
    Pm = geos_out.hyam + geos_out.hybm * geos_out.P0 
    Hm = np.log(Pm/1000) * -7640  
    return Hm  

def plot_zonal_mean(geos_out):
    """
    Plot a zonal mean of the geoschem output.
    """ 
    # work out altitude
    Hm = calc_height(geos_out)

    zonal_n2o = geos_out["SpeciesConc_CH4"].mean(dim=["lon", "time"]) * 10**9
    zonal_n2o["height"] = Hm.mean("time")
    zonal_n2o.plot(y="height")
    plt.show()
    plt.close()

def sum_tracers(geos_out, no_regions):
    """
    Sum up the geoschem tracers to give a total tracer.
    """ 
    total = xr.zeros_like(geos_out["SpeciesConc_CH4"])
    transcom = [f"SpeciesConc_CH4_R{index:02d}" for index in range(0, no_regions)]
    for region in transcom:
        total += geos_out[region]
    return total

def global_total_ems(ems, varname):
    """
    Calculate the global total ems in kgs-1.
    """ 
    # get geoschem area
    with xr.open_dataset(Path(__file__).parent.parent / "emissions/geos_grid_info.nc") as load:
        geos_grid = load.load()
    # convert ems from kgm-2s-1 to kgs-1
    ems_areaweighted = ems[varname] * geos_grid["area"]
    # sum over globe
    ems_summed = ems_areaweighted.sum(dim=["lat", "lon"])
    return ems_summed

def plot_monthly_ems(geos_ems, my_ems):
    """
    Plot a monthly emissions timeseries comparing my ems and geos ems.
    """ 
    plt.plot(geos_ems.time, global_total_ems(geos_ems, "EMIS_CH4_TOTAL"), label="geos ems")
    plt.plot(geos_ems.time, global_total_ems(my_ems, "emi_n2o"), label="my ems")
    plt.legend()
    plt.ylabel("Global N2O emissions / kgs-1")
    plt.xticks(rotation=45)
    plt.show()
    plt.close()

def calc_lifetime(out_files, ch4_files, molecular_weight):
    """
    Calculate the global lifetime in years.
    """ 
    mm_air = 28.9647
    sec2year = 1/(3600*24*365.25)

    lifetimes_gc_new = np.zeros(len(out_files))
    burden_gc_new = np.zeros(len(out_files))
    #Get some stuff for a single case
    with xr.open_dataset(out_files[0]) as load:
        ds_conc = load.load()
    #Mass of air above 1 m2 in moles
    air_m2 = ds_conc.P0*100/9.81 / (mm_air*1e-3)
    #Area of each grid
    area = ds_conc.AREA
    #Mass of air in each grid cell
    air_cell = air_m2 * area
    i=0
    for sc_fn, ls_fn in zip(out_files, ch4_files):
        # Get the concentration output
        with xr.open_dataset(sc_fn) as load:
            ds_conc = load.load()
            n2o_conc = ds_conc["SpeciesConc_CH4"].mean(dim="time")
            #Get losses 
        with xr.open_dataset(ls_fn) as load:
            ds_loss = load.load()
            n2o_loss = ds_loss["LossCH4inStrat"] / (molecular_weight/1e3)
        #Fraction of air in each level
        frac_air = ds_loss.ilev.values[:-1] - ds_loss.ilev.values[1:]
        #Multiply conc. by frac of air times total per column
        total_air_cell = np.zeros_like(n2o_conc)
        for li in range(len(frac_air)):
            total_air_cell[li,:,:] = frac_air[li]*air_cell
        burden_cell = n2o_conc*total_air_cell
        #Lifetime
        lifetimes_gc_new[i] = burden_cell.sum()/n2o_loss.sum()*sec2year
        burden_gc_new[i] = burden_cell.sum()
        i += 1

    return lifetimes_gc_new

def plot_lifetime(geos_out, lifetimes_gc_new):
    """
    Plot the lifetime and compare it to the Wells paper value.
    """ 
    plt.plot(geos_out.time, lifetimes_gc_new, label="GEOS-Chem")
    plt.plot(geos_out.time, np.repeat(127, len(geos_out.time)), ":", label="Wells")
    plt.ylabel("Lifetime / years")
    plt.xticks(rotation=45)
    plt.legend()

if __name__ == "__main__":
    # read in variables from the config file
    config = configparser.ConfigParser()
    config.read(Path(__file__).parent.parent.parent / 'config.ini')
    MOLECULAR_WEIGHT = float(config["gas_info"]["molecular_weight"])
    NO_REGIONS = int(config["inversion_constants"]["no_regions"])
    GEOS_OUT = Path(config["paths"]["geos_out"])
    GEOS_EMS = Path(config["em_n_loss"]["geos_ems"])
    SPINUP_START = config["dates"]["spinup_start"]
    PERTURB_START = config["dates"]["perturb_start"]

    # =============================================================================
    # Check average output
    # =============================================================================
    # read in GEOSChem data
    subfolder = "base/su_??/"
    out_files = list(GEOS_OUT.glob(f"{subfolder}GEOSChem.SpeciesConc.*01_0000z.nc4"))
    out_files.sort()

    # if spinup and multiple years, need to reassign dates to not overlap
    if "/su_" in subfolder and len(out_files) > 12:
        print("adjusting spinup dates...")
        geos_out = time_adjust_spinup(out_files)
    else:
        with xr.open_mfdataset(out_files) as load:
            geos_out = load.load() 

    # Plot monthly mean time series
    print("Plot of monthly mean [N2O]...")
    plot_monthly_mean(geos_out)

    # Plot mole fraction map
    print("Plot of [N2O] distribution...")
    map_plot.cartopy_plot(geos_out["SpeciesConc_CH4"].isel(lev=0).mean(dim="time") * 10**9,
                        "N2O / nmol mol-1", 
                        None)

    # Plot zonal mean
    print("Plot of zonal mean [N2O]...")
    plot_zonal_mean(geos_out)

    # Check if regional tracers add up to whole tracer
    print("Checking if the sum of regional tracers is about equal to the whole tracer...")
    tracer_sum = sum_tracers(geos_out, NO_REGIONS + 1)
    max_percentage_diff = (100 *(tracer_sum - geos_out["SpeciesConc_CH4"]) / geos_out["SpeciesConc_CH4"]).max()
    print(f"Maximum difference: {max_percentage_diff.values:.2f}%")

    # =============================================================================
    # Check emissions
    # =============================================================================
    # geos ems
    # if reading in multiple spinup years, you'll only get the last year,
    # but that should be fine, all the ems should be the same then anyway
    ems_files = list(GEOS_OUT.glob(f"{subfolder}HEMCO_diagnostics.*010000.nc"))
    ems_files.sort()
    with xr.open_mfdataset(ems_files) as load:
        geos_ems = load.load()

    # my ems
    with xr.open_dataset(GEOS_EMS / "base_emissions.nc") as load:
        my_ems = load.load()
    # only select emissions for geoschem time period
    my_ems = my_ems.sel(time=slice(geos_ems.time[0].values, geos_ems.time[-1].values))

    # Plot a comparison of the monthly mean emissions as a time series
    print("Compare my ems and geoschem read ems...")
    plot_monthly_ems(geos_ems, my_ems)

    # Plot a spatial comparison of emissions
    print("Compare annual mean of my ems and geoschem read ems spatially...")
    my_ems_one_month = my_ems["emi_n2o"].mean(dim="time").astype(np.float32)
    geos_ems_one_month = geos_ems["EMIS_CH4_TOTAL"].mean(dim="time")

    percentage_diff = 100 * (my_ems_one_month - geos_ems_one_month) / my_ems_one_month
    map_plot.cartopy_plot(percentage_diff, "Percentage diff ems / %", None)

    # =============================================================================
    # Check strat loss, but no OH or Cl loss
    # =============================================================================
    # if reading in multiple spinup years, you'll only get the last year,
    # but that should be fine, should be hard for this to be different 
    # for the different spinup years
    ch4_files = list(GEOS_OUT.glob(f"{subfolder}GEOSChem.CH4.*01_0000z.nc4"))
    ch4_files.sort()

    with xr.open_mfdataset(ch4_files) as load:
        geos_ch4 = load.load()

    print("Check that the only loss that is more than zero is LossCH4inStrat...")
    print(geos_ch4.median())

    # =============================================================================
    # Check lifetime
    # =============================================================================
    # calculate lifetime
    lifetimes_gc_new = calc_lifetime(out_files, ch4_files, MOLECULAR_WEIGHT)

    # plot lifetime graph
    print("Comparing my lifetime to Wells...")
    print(f"Average lifetime is {np.mean(lifetimes_gc_new)} years")
    plot_lifetime(geos_out, lifetimes_gc_new)
