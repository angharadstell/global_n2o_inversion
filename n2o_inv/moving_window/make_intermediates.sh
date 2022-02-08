#!/bin/bash

#SBATCH --job-name=int_window
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=12:00:00
#SBATCH --mem=5G

source ~/.bashrc
conda activate wombat

# read in variables
source ../spinup/bash_var.sh

cd ../intermediates

len_window=${moving_window[n_years]}
nwindow=${moving_window[n_window]}


final_year=${dates[perturb_end]:0:4}

for window in $(eval echo "{1..$nwindow}")
do
    echo "starting window $window"
    window02d=`printf %02d $window`

    first_year=$(( ${dates[perturb_start]:0:4} + window - 1 ))
    if [ $(( first_year + len_window - 1 )) -ge $final_year ]
    then
        last_year=$(( final_year - 1 ))
    else
        last_year=$(( first_year + len_window - 1 ))
    fi
    echo "covers $first_year - $last_year"

    # make control emissions
    python process_geos_ems.py $first_year $last_year "monthly_fluxes_window$window02d.nc"
    Rscript control-emissions.R  --flux-file "monthly_fluxes_window$window02d.nc" --output "control-emissions-window$window02d.fst"

    # make perturbations
    Rscript perturbations.R --flux-file "monthly_fluxes_window$window02d.nc" --control-ems "control-emissions-window$window02d.fst" --output "perturbations_window$window02d.fst"

    # make mole fraction intermediates
    start_month=$(( 12 * (window - 1) ))
    end_month=$(( 12 * (last_year - ${dates[perturb_start]:0:4} + 1) - 1))
    echo "covers months  $start_month - $end_month"
    sed -e "s/%range%/$start_month-$end_month/" -e "s/%first_year%/$first_year/" -e "s/%last_year%/$last_year/" -e "s/%window02d%/$window02d/" process_geos_output_window_template_submit.sh > process_geos_output_window_submit.sh
    sed -e "s/%first_year%/$first_year/" -e "s/%last_year%/$last_year/" -e "s/%window02d%/$window02d/" process_geos_output_window0_template_submit.sh > process_geos_output_window0_submit.sh
    sbatch process_geos_output_window_submit.sh
    sbatch process_geos_output_window0_submit.sh
done

# wait for job to finish
njob=38
while [ $njob -gt 0 ]
do
    sleep 1m
    # calculate the number of jobs running
    njob=$(sacct --format="JobID,State,JobName%30" | grep "RUNNING \| PENDING" | grep "geo_out.*" | wc -l)

    echo "There are $njob jobs to go"
done
echo "Exiting loop..."


for window in $(eval echo "{1..$nwindow}")
do
    echo "starting window $window, phase 2"
    window02d=`printf %02d $window`

    # make control_mf
    Rscript control-mole-fraction.R --case $case --mf-file "combined_mf_window$window02d" --output "control-mole-fraction-window$window02d"

    # make sensitivities
    Rscript sensitivities.R --mf-file "combined_mf_window$window02d.nc" --control-mf "control-mole-fraction-window$window02d.fst" --output "sensitivities_window$window02d.fst"

    # make observations with different model errors
    Rscript observations.R --mf-file "combined_mf_window$window02d.nc" --model-err "n2o_std" --output "model-err-n2o_std-observations_window$window02d.fst"
    Rscript observations.R --mf-file "combined_mf_window$window02d.nc" --model-err "arbitrary" --output "model-err-arbitrary-observations_window$window02d.fst"
done
