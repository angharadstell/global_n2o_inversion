#!/bin/bash

#PBS -l select=1:ncpus=1:mem=5gb
#PBS -l walltime=3:00:00
#PBS -j oe

source ~/.bashrc
conda activate wombat

cd "${PBS_O_WORKDIR}"

# read in variables
cd ../spinup
source bash_var.sh

cd ../intermediates

# make control emissions
python process_geos_ems.py 2010 2012 "monthly_fluxes_pseudo.nc"
Rscript control-emissions.R  --flux-file "monthly_fluxes_pseudo.nc" --output "control-emissions-pseudo.fst"

# make perturbations
Rscript perturbations.R --flux-file "monthly_fluxes_pseudo.nc" --control-ems "control-emissions-pseudo.fst" --output "perturbations_pseudo.fst"


# make mole fraction intermediates
qsub process_geos_output_pseudo_submit.sh
# wait for job to finish
njob=1
while [ $njob -gt 0 ]
do
    sleep 1m
    njob=$(qstat -tf | grep "Job_Name\s=\sprocess_geos_output_pseudo_submit.sh" | wc -l)

    echo "There are $njob jobs to go"
done
echo "Exiting loop..."
Rscript control-mole-fraction.R  --case $case --mf-file "combined_mf_pseudo" --output "control-mole-fraction-pseudo"

Rscript sensitivities.R --mf-file "combined_mf_pseudo.nc" --control-mf "control-mole-fraction-pseudo.fst" --output "sensitivities_pseudo.fst"
Rscript observations.R --mf-file "combined_mf_pseudo.nc" --output "observations_pseudo.fst"
