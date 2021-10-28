#!/bin/bash

#PBS -l select=1:ncpus=1:mem=5gb
#PBS -l walltime=3:00:00
#PBS -j oe
#PBS -J 0-2

source ~/.bashrc
conda activate wombat

cd "${PBS_O_WORKDIR}"

# read in variables
cd ../spinup
source bash_var.sh

CASE_ARRAY=(${inversion_constants[land_ocean_equal_model_case]} ${inversion_constants[land_ocean_equal_model_case]}-rescaled-double ${inversion_constants[land_ocean_equal_model_case]}-rescaled-half) 
PROCESS_ARRAY=(process-model process-model-rescaled-double process-model-rescaled-half) 

echo ${CASE_ARRAY[$PBS_ARRAY_INDEX]}
echo ${PROCESS_ARRAY[$PBS_ARRAY_INDEX]}

# traceplots
cd ../inversion
Rscript ${paths[location_of_this_file]}/../inversion/traceplots.R --casename ${CASE_ARRAY[$PBS_ARRAY_INDEX]}

# flux aggregate
cd ../results
./flux_aggregators.sh ${CASE_ARRAY[$PBS_ARRAY_INDEX]} ${PROCESS_ARRAY[$PBS_ARRAY_INDEX]}

# plot
cd ../results
./plots.sh ${CASE_ARRAY[$PBS_ARRAY_INDEX]} ${PROCESS_ARRAY[$PBS_ARRAY_INDEX]}

Rscript plot_annual_ems.R --casename ${CASE_ARRAY[$PBS_ARRAY_INDEX]}
