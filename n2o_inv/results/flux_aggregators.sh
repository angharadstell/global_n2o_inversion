#!/bin/bash

# read in variables
cd ../spinup
source bash_var.sh

export INVERSION_BASE_PARTIAL=${paths[wombat_paper]}/3_inversion/src/partials/base.R

echo "first bash arg (model case):"
echo $1
echo "second bash arg (process model):"
echo $2
echo "third bash arg (intermediate dir):"
echo $3

# Create aggregated flux areas
Rscript ${paths[root_code_dir]}/results/flux-aggregators.R \
    --process-model $3/$2.rds \
    --transcom-mask ${inversion_constants[geo_transcom_mask]} \
    --output ${paths[inversion_results]}/flux-aggregators-$1.rds

# Aggregate MCMC samples
Rscript ${paths[root_code_dir]}/results/flux-aggregates-samples.R \
    --flux-aggregators ${paths[inversion_results]}/flux-aggregators-$1.rds \
    --model-case $3/real-model-$1.rds \
    --process-model $3/$2.rds \
    --samples $3/real-mcmc-samples-$1.rds \
    --output ${paths[inversion_results]}/real-flux-aggregates-samples-$1.rds
