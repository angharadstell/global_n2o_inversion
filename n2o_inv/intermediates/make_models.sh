#!/bin/bash

# read in variables
cd ../spinup
source bash_var.sh

# all threee scripts need this
export INVERSION_BASE_PARTIAL=${paths[wombat_paper]}/3_inversion/src/partials/base.R

# Make process model
Rscript ${paths[location_of_this_file]}/../intermediates/process-model.R \
--control-emissions ${paths[geos_inte]}/control-emissions.fst \
--perturbations ${paths[geos_inte]}/perturbations.fst \
--control-mole-fraction ${paths[geos_inte]}/control-mole-fraction.fst \
--sensitivities ${paths[geos_inte]}/sensitivities.fst \
--output ${paths[geos_inte]}/process-model.rds

# Make measurement model
Rscript ${paths[wombat_paper]}/3_inversion/src/measurement-model.R \
--observations ${paths[geos_inte]}/observations.fst \
--process-model ${paths[geos_inte]}/process-model.rds \
--output ${paths[geos_inte]}/measurement-model.rds

# Make real model case
Rscript ${paths[location_of_this_file]}/../intermediates/real-model-case.R \
--case ${inversion_constants[model_case]} \
--measurement-model ${paths[geos_inte]}/measurement-model.rds \
--process-model ${paths[geos_inte]}/process-model.rds \
--output ${paths[geos_inte]}/real-model-${inversion_constants[model_case]}.rds
