#!/bin/bash
# This script creates the required WOMBAT intermediates for running the full 10 year inversion

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

# make control emissions intermediate
python process_geos_ems.py 2010 2020 "monthly_fluxes.nc"
Rscript control-emissions.R --flux-file "monthly_fluxes.nc" --output "control-emissions.fst"

# make perturbations intermediate
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

# make sensitivities intermediates
Rscript sensitivities.R --mf-file "combined_mf.nc" --control-mf "control-mole-fraction.fst" --output "sensitivities.fst"

# make three observation intermediates: one with no model error, one with the model error set by the spatial variability of N2O,
# one with a constant "arbitrary" model error
Rscript observations.R --mf-file "combined_mf.nc" --model-err "" --output "observations.fst"
Rscript observations.R --mf-file "combined_mf.nc" --model-err "n2o_std" --output "model-err-n2o_std-observations.fst"
Rscript observations.R --mf-file "combined_mf.nc" --model-err "arbitrary" --output "model-err-arbitrary-observations.fst"
