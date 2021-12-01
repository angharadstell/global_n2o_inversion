#!/bin/bash

#SBATCH --job-name=plot_inv
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=3:00:00
#SBATCH --mem=5G

source ~/.bashrc
conda activate wombat

# read in variables
cd ../spinup
source bash_var.sh


nwindow=${moving_window[n_window]}

for window in $(eval echo "{1..$nwindow}")
do
    echo "starting window $window"
    window02d=`printf %02d $window`

    window_suffix=window$window02d
    window_case=${inversion_constants[land_ocean_equal_model_case]}_$window_suffix

    FILE=${paths[moving_window_dir]}/real-mcmc-samples-$window_case.rds
    if [ -f "$FILE" ]
    then
        echo "$FILE exists."
        DIR=${paths[moving_window_dir]}
    else
        echo "$FILE doesn't exist, read in old version"
        DIR=${paths[moving_window_dir]}/v1
    fi

    # traceplot
    Rscript ${paths[location_of_this_file]}/../inversion/traceplots.R --casename $window_case --sampledir $DIR

    # flux aggregate
    cd ../results
    ./flux_aggregators.sh $window_case process-model_$window_suffix $DIR

    echo "obs_matched_samples.R"
    Rscript ${paths[location_of_this_file]}/../results/obs_matched_samples.R \
        --model-case $DIR/real-model-$window_case.rds \
        --process-model $DIR/process-model_$window_suffix.rds \
        --samples $DIR/real-mcmc-samples-$window_case.rds \
        --observations ${paths[geos_inte]}/observations_$window_suffix.fst \
        --output ${paths[inversion_results]}/obs_matched_samples-$window_case.rds
done

cd ../moving_window
echo "join_flux_aggregates.R"
Rscript join_flux_aggregates.R

# plot
cd ../results
./plots.sh ${inversion_constants[land_ocean_equal_model_case]}_windowall

Rscript plot_annual_ems.R --casename ${inversion_constants[land_ocean_equal_model_case]}_windowall
