import configparser
from pathlib import Path
import sys

import numpy as np
import xarray as xr

def geoschem_cell_size(xr_df):
    """
    For an xarray Dataset, with "lat" and "lon" present, work out the latitude heights and longitude widths.
    The lat and lon must be centres, not edges, of the boxes. The code checks whether there are half polar 
    boxes for latitude or not.
    """
    # assumes provided lats are centres not edges
    lat_edges = (xr_df.lat[:-1].values + xr_df.lat[1:].values) / 2
    lat_width = lat_edges[1:] - lat_edges[:-1]
    
    # half size polar boxes (geoschem default)
    if np.all(lat_width == lat_width[0]):
        lat_widths = np.ones(len(xr_df.lat)) * lat_width[0]
    # or full size polar boxes
    else:
        lat_widths = np.ones(len(xr_df.lat)) * np.max(lat_width)
        lat_widths[0] =  np.max(lat_width) / 2
        lat_widths[-1] =  np.max(lat_width) / 2
    
    lon_widths = xr_df.lon[1:].values - xr_df.lon[:-1].values
    
    if np.all(lon_widths == lon_widths[0]):
        lon_widths = np.ones(len(xr_df.lon)) * lon_widths[0]
    else:
        raise ValueError("Not all longitude widths are the same")
        
    return lat_widths, lon_widths


if __name__ == "__main__":
    # read in variables from the config file
    config = configparser.ConfigParser()
    config.read("../../config.ini")
    GEOSOUT_DIR = Path(config["paths"]["geos_out"])

    # variables from commandline
    first_year = int(sys.argv[1])  # first year to extract emissions for
    last_year = int(sys.argv[2])   # final year to extract emissions for
    output_file = sys.argv[3]      # name of emissions file to be saved

    print(f"Loading data from {first_year} - {last_year}")
    print(f"Saving data to {output_file}")

    # Read in model ems from each geoschem run
    for output_dir in sorted(GEOSOUT_DIR.iterdir()):
        print(output_dir)
        
        try:
            # Read in HEMCO emissions
            hemco_files = []
            for y in range(first_year, last_year+1):
                hemco_files.extend(list(output_dir.glob(f"HEMCO_diagnostics.{y}??010000.nc")))
            hemco_files.sort()
            print(hemco_files)
            
            with xr.open_mfdataset(hemco_files) as load:
                hemco_ems = load.load() 
                
            # Drop unwanted variables
            hemco_ems = hemco_ems.drop(["hyam", "hybm", "P0", "lev"])
            
            # Work out geoschem grid widths and heights
            lat_widths, lon_widths = geoschem_cell_size(hemco_ems)
            hemco_ems['longitude_width'] = lon_widths
            hemco_ems['latitude_height'] = lat_widths

            # Rename lat and lon
            hemco_ems = hemco_ems.rename({"lon": "longitude",
                                          "lat": "latitude"})

            # Save
            hemco_ems.to_netcdf(output_dir / output_file)

        # If there are no files to open within the given year range, pass over this folder.
        # This will happen if, for example, you select a smaller range of years to process
        # than the number of years present.
        except OSError:
            print("no files to open")
