#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Plots a nice version of the dD-CH4 map.

Author: Angharad Stell (angharadstell@gmail.com)
"""
import cartopy
import matplotlib.pyplot as plt
import numpy as np

# Make matplotlib look prettier
plt.style.use('seaborn-ticks')
plt.rcParams['font.family'] = 'sans-serif'
plt.rcParams['font.sans-serif'] = ['DejaVu Sans']
plt.rcParams['font.size'] = 14


def colormesh_lon(lon):
    """ Function to make lon be corners for pcolormesh plotting,
        pcolormesh wants lower left and lower right corners.
    
    Args:
        lon (1d arr): the MOZART lon
    """
    if lon[0] < 0:
        plt_lon = np.linspace(-180., 180., (len(lon) + 1))
    else:
        plt_lon = np.linspace(0., 360., (len(lon) + 1))
    return plt_lon


def colormesh_lat(lat):
    """ Function to make lat be corners for pcolormesh plotting,
    pcolormesh wants lower left and lower right corners.
    
    Args:
        lat (1d arr): the MOZART lat
    """
    plt_lat = (lat[1:] + lat[:-1]) / 2
    plt_lat = np.insert(plt_lat, 0, -90)
    plt_lat = np.insert(plt_lat, len(plt_lat), 90)
    return plt_lat

def cartopy_plot(ems_grid, colorbar_label, filename, cmap="Reds", norm=None):
    """ Plots the emissions map. """
    # Set up map
    fig = plt.figure(figsize=(10, 10))
    ax = fig.add_subplot(1, 1, 1, projection=cartopy.crs.PlateCarree())

    cs = plt.pcolormesh(colormesh_lon(ems_grid["lon"].values), colormesh_lat(ems_grid["lat"].values),
                        ems_grid,
                        transform=cartopy.crs.PlateCarree(), cmap=cmap, norm=norm, 
                        rasterized=True)

    cbar = plt.colorbar(cs, orientation="horizontal", pad=0.1)
    cbar.ax.tick_params(labelsize=14)
    cbar.set_label(colorbar_label)

    ax.coastlines()
    
    if filename is None:
        pass
    else:
        plt.savefig(filename, bbox_inches="tight")
        
    plt.show()
    plt.close()
