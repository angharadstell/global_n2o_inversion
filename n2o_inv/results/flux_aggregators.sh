#!/bin/bash

# read in variables
cd ../spinup
source bash_var.sh

export INVERSION_BASE_PARTIAL=${paths[wombat_paper]}/3_inversion/src/partials/base.R
export INVERSION_TRANSCOM_UTILS_PARTIAL=${paths[wombat_paper]}/3_inversion/src/partials/transcom-utils.R

case=IS-FIXEDAO-FIXEDWO5-NOBIAS

# Create aggregated flux areas
Rscript ${paths[location_of_this_file]}/../results/flux-aggregators.R \
    --process-model ${paths[geos_inte]}/process-model.rds \
    --transcom-mask ${inversion_constants[geo_transcom_mask]} \
    --output ${paths[inversion_results]}/flux-aggregators.rds

# Aggregate MCMC samples
Rscript ${paths[wombat_paper]}/3_inversion/src/flux-aggregates-samples.R \
    --flux-aggregators $result_dir/flux-aggregators.rds \
    --model-case ${paths[geos_inte]}/real-model-$case.rds \
    --process-model ${paths[geos_inte]}/process-model.rds \
    --samples ${paths[geos_inte]}/real-mcmc-samples-$case.rds \
    --output ${paths[inversion_results]}/real-flux-aggregates-samples-$case.rds
