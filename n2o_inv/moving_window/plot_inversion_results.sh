#!/bin/bash
# This script plots the WOMBAT moving window inversion results

#SBATCH --job-name=plot_inv
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=3:00:00
#SBATCH --mem=5G
#SBATCH --array=0-3


CASE_ARRAY=(IS-RHO0-VARYA-VARYW-NOBIAS-model-err-arbitrary IS-RHO0-FIXEDA-VARYW-NOBIAS-model-err-arbitrary IS-RHO0-VARYA-VARYW-NOBIAS-model-err-n2o_std IS-RHO0-FIXEDA-VARYW-NOBIAS-model-err-n2o_std)
CASE=${CASE_ARRAY[$SLURM_ARRAY_TASK_ID]}
echo $CASE

source ~/.bashrc
conda activate wombat

# read in variables
cd ../spinup
source bash_var.sh


nwindow=${moving_window[n_window]}



# is this a model error case?
if [[ "$CASE" =~ (model-err)([^,]*) ]]
then
    observations=model-err${BASH_REMATCH[2]}-observations
else
    observations=observations
fi
echo "Using observations file called: $observations"


# iterate through each window
for window in $(eval echo "{1..$nwindow}")
do
    echo "starting window $window"
    window02d=`printf %02d $window`

    window_suffix=window${window02d}
    window_case=${CASE}_$window_suffix

    FILE=${paths[moving_window_dir]}/real-mcmc-samples-$window_case.rds
    if [ -f "$FILE" ]
    then
        echo "$FILE exists."
        DIR=${paths[moving_window_dir]}
    else
        echo "$FILE doesn't exist, read in old version"
        DIR=${paths[moving_window_dir]}/old/bc4
    fi

    # traceplot
    # echo "traceplots.R"
    # Rscript ${paths[root_code_dir]}/inversion/traceplots.R --casename $window_case --sampledir ${paths[moving_window_dir]}

    # flux aggregate
    cd ../results
    ./flux_aggregators.sh $window_case process-model-$window_case $DIR

    echo "obs_matched_samples.R"
    Rscript ${paths[root_code_dir]}/results/obs_matched_samples.R \
        --model-case $DIR/real-model-$window_case.rds \
        --process-model $DIR/process-model-$window_case.rds \
        --samples $DIR/real-mcmc-samples-$window_case.rds \
        --observations ${paths[geos_inte]}/${observations}_$window_suffix.fst \
        --output ${paths[inversion_results]}/obs_matched_samples-$window_case.rds
done

cd ../moving_window
echo "join_flux_aggregates.R"
Rscript join_flux_aggregates.R --casename ${CASE}

# plot
echo "plots.sh"
cd ../results
./plots.sh ${CASE}_windowall

echo "plot_annual_ems.R"
Rscript plot_annual_ems.R --casename ${CASE}_windowall
