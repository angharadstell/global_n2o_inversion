#!/bin/bash

# read in variables
cd ../spinup
source bash_var.sh

export INVERSION_BASE_PARTIAL=${paths[wombat_paper]}/3_inversion/src/partials/base.R
export INVERSION_TRANSCOM_UTILS_PARTIAL=${paths[wombat_paper]}/3_inversion/src/partials/transcom-utils.R

# Create aggregated flux areas
Rscript ${paths[location_of_this_file]}/../results/flux-aggregators.R \
    --process-model ${paths[geos_inte]}/process-model.rds \
    --transcom-mask ${inversion_constants[geo_transcom_mask]} \
    --output ${paths[inversion_results]}/flux-aggregators.rds

# Aggregate MCMC samples
Rscript ${paths[location_of_this_file]}/../results/flux-aggregates-samples.R \
    --flux-aggregators ${paths[inversion_results]}/flux-aggregators.rds \
    --model-case ${paths[geos_inte]}/real-model-${inversion_constants[model_case]}.rds \
    --process-model ${paths[geos_inte]}/process-model.rds \
    --samples ${paths[geos_inte]}/real-mcmc-samples-${inversion_constants[model_case]}.rds \
    --output ${paths[inversion_results]}/real-flux-aggregates-samples-${inversion_constants[model_case]}.rds
