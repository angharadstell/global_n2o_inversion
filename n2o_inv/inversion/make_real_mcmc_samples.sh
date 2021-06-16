#!/bin/bash

# read in variables
cd ../spinup
source bash_var.sh

case=IS-FIXEDAO-FIXEDWO5-NOBIAS

export INVERSION_BASE_PARTIAL=${paths[wombat_paper]}/3_inversion/src/partials/base.R
export CASE=$case
export INTERMEDIATE_DIR=${paths[geos_inte]}


# Do MCMC sampling
Rscript ${paths[location_of_this_file]}/../inversion/mcmc-samples.R \
--process-model ${paths[geos_inte]}/process-model.rds \
--model-case ${paths[geos_inte]}/real-model-$case.rds \
--output ${paths[geos_inte]}/real-mcmc-samples-$case.rds
