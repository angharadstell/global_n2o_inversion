#!/bin/bash

#SBATCH --job-name=window_sub
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=11-00:00:00
#SBATCH --mem=5G

source ~/.bashrc
conda activate wombat

# read in variables
source ../spinup/bash_var.sh

./make_intermediates.sh

nwindow=${moving_window[n_window]}
analytical=FALSE

for window in $(eval echo "{1..$nwindow}")
do
    echo "starting window $window"
    window02d=`printf %02d $window`

    sed -i -e "s/window02d=.*/window02d=$window02d/" make_models.sh
    ./make_models.sh

    echo "Doing inversion..."
    if [ $analytical = TRUE ]
    then
        Rscript analytical_inversion.R --window $window

    else
        sed -i -e "s/window02d=.*/window02d=$window02d/" make_real_mcmc_samples_vary_submit.sh
        ./make_real_mcmc_samples_vary_submit.sh
    fi

    # bring in spinup fluxes
    if [ $window -lt $nwindow ]
    then
        echo "changing ic..."
        if [ $analytical = TRUE ]
        then
            Rscript change_control_mf.R --window $window --method "analytical"
        else
            Rscript change_control_mf.R --window $window --method "mcmc"
        fi
    fi

done
