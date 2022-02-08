#!/bin/bash

# read in variables
cd ../spinup
source bash_var.sh

# all threee scripts need this
export INVERSION_BASE_PARTIAL=${paths[wombat_paper]}/3_inversion/src/partials/base.R

CASE=%CASE%
echo "model case: $CASE"

# is this a model error case?
if [[ "$CASE" =~ (model-err)([^,]*) ]]
then
    observations=model-err${BASH_REMATCH[2]}-observations
else
    observations=observations
fi
echo "Using observations file called: $observations"

# is this a rescaled case?
if [[ "$CASE" =~ (rescaled)([^,]*) ]]
then
    rescaled=-rescaled${BASH_REMATCH[2]}
else
    rescaled=""
fi
echo "Using rescaled suffix: $rescaled"


window02d=%window02d%
echo "window02d in make_models: $window02d"

#####################################################################################

# Make process model
if [ $window02d = 01 ]
then
    echo ${paths[geos_inte]}/control-mole-fraction-window${window02d}${rescaled}.fst
    Rscript ${paths[location_of_this_file]}/../intermediates/process-model.R \
    --control-emissions ${paths[geos_inte]}/control-emissions-window${window02d}${rescaled}.fst \
    --perturbations ${paths[geos_inte]}/perturbations_window${window02d}${rescaled}.fst \
    --control-mole-fraction ${paths[geos_inte]}/control-mole-fraction-window${window02d}${rescaled}.fst \
    --sensitivities ${paths[geos_inte]}/sensitivities_window${window02d}${rescaled}.fst \
    --output ${paths[moving_window_dir]}/process-model-${CASE}_window$window02d.rds
else
    echo ${paths[geos_inte]}/control-mole-fraction-${CASE}-window${window02d}${rescaled}-mcmc-rescaled.fst
    Rscript ${paths[location_of_this_file]}/../intermediates/process-model.R \
    --control-emissions ${paths[geos_inte]}/control-emissions-window${window02d}${rescaled}.fst \
    --perturbations ${paths[geos_inte]}/perturbations_window${window02d}${rescaled}.fst \
    --control-mole-fraction ${paths[geos_inte]}/control-mole-fraction-${CASE}-window${window02d}${rescaled}-mcmc-rescaled.fst \
    --sensitivities ${paths[geos_inte]}/sensitivities_window${window02d}${rescaled}.fst \
    --output ${paths[moving_window_dir]}/process-model-${CASE}_window$window02d.rds
fi 

# Make measurement model
if [[ "$CASE" == *"FIXEDGAMMA"* ]]
then
    echo "making fixed gamma measurement model..." 
    Rscript ${paths[location_of_this_file]}/../intermediates/measurement-model.R \
    --observations ${paths[geos_inte]}/${observations}_window$window02d.fst \
    --process-model ${paths[moving_window_dir]}/process-model-${CASE}_window$window02d.rds \
    --gamma-prior-shape 100000000 \
    --gamma-prior-rate 0.00000001 \
    --output ${paths[moving_window_dir]}/measurement-model-${CASE}_window$window02d.rds
else
    echo "making varying gamma measurement model..."
    Rscript ${paths[location_of_this_file]}/../intermediates/measurement-model.R \
    --observations ${paths[geos_inte]}/${observations}_window$window02d.fst \
    --process-model ${paths[moving_window_dir]}/process-model-${CASE}_window$window02d.rds \
    --gamma-prior-min 0.1 \
    --gamma-prior-max 1.0 \
    --output ${paths[moving_window_dir]}/measurement-model-${CASE}_window$window02d.rds
fi

# Make real model case
Rscript ${paths[location_of_this_file]}/../intermediates/real-model-case.R \
--case $CASE \
--measurement-model ${paths[moving_window_dir]}/measurement-model-${CASE}_window$window02d.rds \
--process-model ${paths[moving_window_dir]}/process-model-${CASE}_window$window02d.rds \
--output ${paths[moving_window_dir]}/real-model-${CASE}_window$window02d.rds
