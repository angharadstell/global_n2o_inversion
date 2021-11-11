#!/bin/bash

# read in variables
cd ../spinup
source bash_var.sh

# all threee scripts need this
export INVERSION_BASE_PARTIAL=${paths[wombat_paper]}/3_inversion/src/partials/base.R



window02d=03
echo "window02d in make_models: $window02d"

#####################################################################################

# Make process model
if [ $window02d = 01 ]
then
    echo ${paths[geos_inte]}/control-mole-fraction-window$window02d.fst
    Rscript ${paths[location_of_this_file]}/../intermediates/process-model.R \
    --control-emissions ${paths[geos_inte]}/control-emissions-window$window02d.fst \
    --perturbations ${paths[geos_inte]}/perturbations_window$window02d.fst \
    --control-mole-fraction ${paths[geos_inte]}/control-mole-fraction-window$window02d.fst \
    --sensitivities ${paths[geos_inte]}/sensitivities_window$window02d.fst \
    --output ${paths[moving_window_dir]}/process-model_window$window02d.rds
else
    echo ${paths[geos_inte]}/control-mole-fraction-window$window02d-mcmc-rescaled.fst
    Rscript ${paths[location_of_this_file]}/../intermediates/process-model.R \
    --control-emissions ${paths[geos_inte]}/control-emissions-window$window02d.fst \
    --perturbations ${paths[geos_inte]}/perturbations_window$window02d.fst \
    --control-mole-fraction ${paths[geos_inte]}/control-mole-fraction-window$window02d-mcmc-rescaled.fst \
    --sensitivities ${paths[geos_inte]}/sensitivities_window$window02d.fst \
    --output ${paths[moving_window_dir]}/process-model_window$window02d.rds
fi 
# Make measurement model
Rscript ${paths[location_of_this_file]}/../intermediates/measurement-model.R \
--observations ${paths[geos_inte]}/observations_window$window02d.fst \
--process-model ${paths[moving_window_dir]}/process-model_window$window02d.rds \
--gamma-prior-min 0.1 \
--gamma-prior-max 1.9 \
--output ${paths[moving_window_dir]}/measurement-model_window$window02d.rds

# Make real model case - all areas equally varying
Rscript ${paths[location_of_this_file]}/../intermediates/real-model-case.R \
--case ${inversion_constants[land_ocean_equal_model_case]} \
--measurement-model ${paths[moving_window_dir]}/measurement-model_window$window02d.rds \
--process-model ${paths[moving_window_dir]}/process-model_window$window02d.rds \
--output ${paths[moving_window_dir]}/real-model-${inversion_constants[land_ocean_equal_model_case]}_window$window02d.rds
