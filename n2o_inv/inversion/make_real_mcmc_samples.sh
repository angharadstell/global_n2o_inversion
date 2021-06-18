#!/bin/bash

# read in variables
cd ../spinup
source bash_var.sh

export INVERSION_BASE_PARTIAL=${paths[wombat_paper]}/3_inversion/src/partials/base.R
export CASE=${inversion_constants[model_case]}
export INTERMEDIATE_DIR=${paths[geos_inte]}


# Do MCMC sampling
Rscript ${paths[location_of_this_file]}/../inversion/mcmc-samples.R \
--process-model ${paths[geos_inte]}/process-model.rds \
--model-case ${paths[geos_inte]}/real-model-${inversion_constants[model_case]}.rds \
--output ${paths[geos_inte]}/real-mcmc-samples-${inversion_constants[model_case]}.rds
