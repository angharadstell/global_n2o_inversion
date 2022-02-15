#!/bin/bash

#SBATCH --job-name=plot_inv
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=1:00:00
#SBATCH --mem=5G
#SBATCH --array=0-3

BASE_CASE=IS-RHO0-VARYA-VARYW-NOBIAS-model-err-n2o_std
CASE_ARRAY=(halfland doubleland halfocean doubleocean)
CASE=${BASE_CASE}-rescaled-${CASE_ARRAY[$SLURM_ARRAY_TASK_ID]}_window01
echo $CASE

# is this a model error case?
if [[ "$BASE_CASE" =~ (model-err)([^,]*) ]]
then
    observations=model-err${BASH_REMATCH[2]}-observations_window01
else
    observations=observations_window01
fi
echo "Using observations file called: $observations"

source ~/.bashrc
conda activate wombat

# read in variables
cd ../spinup
source bash_var.sh



# flux aggregate
cd ../results
./flux_aggregators.sh $CASE process-model-$CASE ${paths[moving_window_dir]}

echo "obs_matched_samples.R"
Rscript ${paths[location_of_this_file]}/../results/obs_matched_samples.R \
    --model-case ${paths[moving_window_dir]}/real-model-$CASE.rds \
    --process-model ${paths[moving_window_dir]}/process-model-$CASE.rds \
    --samples ${paths[moving_window_dir]}/real-mcmc-samples-$CASE.rds \
    --observations ${paths[geos_inte]}/${observations}.fst \
    --output ${paths[inversion_results]}/obs_matched_samples-$CASE.rds

# plot
echo "plots.sh"
cd ../results
./plots.sh ${CASE}

echo "plot_annual_ems.R"
Rscript plot_annual_ems.R --casename ${CASE}
