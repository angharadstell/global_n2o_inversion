#!/bin/bash

#SBATCH --job-name=plot_inv
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=3:00:00
#SBATCH --mem=5G
#SBATCH --array=0-3

source ~/.bashrc
conda activate wombat

# read in variables
cd ../spinup
source bash_var.sh

CASE_ARRAY=(${inversion_constants[land_ocean_equal_model_case]}_windowall ${inversion_constants[land_ocean_equal_model_case]} ${inversion_constants[land_ocean_equal_model_case]}-rescaled-double ${inversion_constants[land_ocean_equal_model_case]}-rescaled-half) 
PROCESS_ARRAY=(process-model process-model process-model-rescaled-double process-model-rescaled-half) 

echo ${CASE_ARRAY[$SLURM_ARRAY_TASK_ID]}
echo ${PROCESS_ARRAY[$SLURM_ARRAY_TASK_ID]}

# traceplots
cd ../inversion
Rscript ${paths[location_of_this_file]}/../inversion/traceplots.R --casename ${CASE_ARRAY[$SLURM_ARRAY_TASK_ID]} --sampledir ${paths[geos_inte]}

# flux aggregate
cd ../results
./flux_aggregators.sh ${CASE_ARRAY[$SLURM_ARRAY_TASK_ID]} ${PROCESS_ARRAY[$SLURM_ARRAY_TASK_ID]}

# plot
cd ../results
./plots.sh ${CASE_ARRAY[$SLURM_ARRAY_TASK_ID]} ${PROCESS_ARRAY[$SLURM_ARRAY_TASK_ID]}

Rscript plot_annual_ems.R --casename ${CASE_ARRAY[$SLURM_ARRAY_TASK_ID]}
