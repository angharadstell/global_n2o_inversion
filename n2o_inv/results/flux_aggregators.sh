#!/bin/bash

# read in variables
cd ../spinup
source bash_var.sh

export INVERSION_BASE_PARTIAL=${paths[wombat_paper]}/3_inversion/src/partials/base.R
export INVERSION_TRANSCOM_UTILS_PARTIAL=${paths[wombat_paper]}/3_inversion/src/partials/transcom-utils.R

echo "first bash arg (model case):"
echo $1
echo "second bash arg (process model):"
echo $2

# Create aggregated flux areas
Rscript ${paths[location_of_this_file]}/../results/flux-aggregators.R \
    --process-model ${paths[geos_inte]}/$2.rds \
    --transcom-mask ${inversion_constants[geo_transcom_mask]} \
    --output ${paths[inversion_results]}/flux-aggregators-$1.rds

# Aggregate MCMC samples
Rscript ${paths[location_of_this_file]}/../results/flux-aggregates-samples.R \
    --flux-aggregators ${paths[inversion_results]}/flux-aggregators-$1.rds \
    --model-case ${paths[geos_inte]}/real-model-$1.rds \
    --process-model ${paths[geos_inte]}/$2.rds \
    --samples ${paths[geos_inte]}/real-mcmc-samples-$1.rds \
    --output ${paths[inversion_results]}/real-flux-aggregates-samples-$1.rds
