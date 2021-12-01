#!/bin/bash

#SBATCH --job-name=make_int
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=5:00:00
#SBATCH --mem=5G

source ~/.bashrc
conda activate wombat

# read in variables
cd ../spinup
source bash_var.sh

cd ../intermediates

# make control emissions
python process_geos_ems.py 2010 2020 "monthly_fluxes.nc"
Rscript control-emissions.R --flux-file "monthly_fluxes.nc" --output "control-emissions.fst"

# make perturbations
Rscript perturbations.R --flux-file "monthly_fluxes.nc" --control-ems "control-emissions.fst" --output "perturbations.fst"

# make mole fraction intermediates
sbatch process_geos_output_submit.sh
# wait for job to finish
njob=1
while [ $njob -gt 0 ]
do
    sleep 1m
    njob=$(sacct --format="JobID,State,JobName%30" | grep "RUNNING \| PENDING" | grep "geo_out.*" | wc -l)

    echo "There are $njob jobs to go"
done
echo "Exiting loop..."

Rscript control-mole-fraction.R --case $case --mf-file "combined_mf" --output "control-mole-fraction"

Rscript sensitivities.R --mf-file "combined_mf.nc" --control-mf "control-mole-fraction.fst" --output "sensitivities.fst"
Rscript observations.R --mf-file "combined_mf.nc" --output "observations.fst"
