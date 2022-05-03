#!/bin/bash
# This script reads the config variables into bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# load the config.ini file to current BASH - quoted to preserve line breaks
# use $(dirname $0) so it hopefully works from any directory
echo "getting config from:"
echo $SCRIPT_DIR/../../config.ini
eval "$(cat $SCRIPT_DIR/../../config.ini  | $SCRIPT_DIR/ini2arr.py)"

# variables
# this seemed like a good idea at the time but is actually just annoying
# should just read variables directly form the config
geo_wrapper_dir=${paths[geo_wrapper_dir]}
geo_rundirs=${paths[geo_rundirs]}


no_spinup_years=${inversion_constants[no_spinup_years]}
no_regions=${inversion_constants[no_regions]}

output_dir=${paths[geos_out]}
ems_dir=${em_n_loss[geos_ems]}
obspack_dir=${paths[obspack_dir]}
case=${inversion_constants[case]}
ems_file=${em_n_loss[ems_file]}
loss_file=${em_n_loss[loss_file]}

mw_gas=${gas_info[molecular_weight]}
background_conc=${gas_info[background_conc]}
