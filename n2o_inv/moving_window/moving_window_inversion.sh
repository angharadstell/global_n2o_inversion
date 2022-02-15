#!/bin/bash

#SBATCH --job-name=window_sub
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=11-00:00:00
#SBATCH --mem=5G
#SBATCH --array=0-3

CASE_ARRAY=(IS-RHO0-VARYA-VARYW-NOBIAS-model-err-arbitrary IS-RHO0-FIXEDA-VARYW-NOBIAS-model-err-arbitrary IS-RHO0-VARYA-VARYW-NOBIAS-model-err-n2o_std IS-RHO0-FIXEDA-VARYW-NOBIAS-model-err-n2o_std)
CASE=${CASE_ARRAY[$SLURM_ARRAY_TASK_ID]}
echo $CASE

source ~/.bashrc
conda activate wombat

# read in variables
source ../spinup/bash_var.sh

nwindow=${moving_window[n_window]}
analytical=FALSE

for window in $(eval echo "{1..$nwindow}")
do
    echo "starting window $window"
    window02d=`printf %02d $window`

    sed -e "s/%window02d%/$window02d/" -e "s/%CASE%/$CASE/" make_models.sh > make_models_$CASE.sh
    chmod +x make_models_$CASE.sh
    ./make_models_$CASE.sh
    rm make_models_$CASE.sh

    echo "Doing inversion..."
    if [ $analytical = TRUE ]
    then
        Rscript analytical_inversion.R --window $window --case $CASE

    else
        sed -e "s/%window02d%/$window02d/" -e "s/%CASE%/${CASE}_window$window02d/" make_real_mcmc_samples_submit.sh > make_real_mcmc_samples_submit_$CASE.sh
        chmod +x make_real_mcmc_samples_submit_$CASE.sh
        ./make_real_mcmc_samples_submit_$CASE.sh
        rm make_real_mcmc_samples_submit_$CASE.sh
    fi

    # bring in spinup fluxes
    if [ $window -lt $nwindow ]
    then
        echo "changing ic..."
        if [ $analytical = TRUE ]
        then
            Rscript change_control_mf.R --window $window --case $CASE --method "analytical"
        else
            Rscript change_control_mf.R --window $window --case $CASE --method "mcmc"
        fi
    fi

done
