#!/bin/bash
# This script makes the WOMBAT models to plot the analytical inversion results in the same way as WOMBAT

# read in variables
cd ../spinup
source bash_var.sh

# all threee scripts need this
export INVERSION_BASE_PARTIAL=${paths[wombat_paper]}/3_inversion/src/partials/base.R

CASE=!CASE!
echo "model case: $CASE"

# is this a model error case?
if [[ "$CASE" =~ (model-err)([^,]*)(-rescaled) ]]
then
    observations=model-err${BASH_REMATCH[2]}-observations
elif [[ "$CASE" =~ (model-err)([^,]*) ]]
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


#####################################################################################

# Make process model
echo "making process model..."
Rscript ${paths[root_code_dir]}/intermediates/process-model.R \
    --control-emissions ${paths[geos_inte]}/control-emissions${rescaled}.fst \
    --perturbations ${paths[geos_inte]}/perturbations${rescaled}.fst \
    --control-mole-fraction ${paths[geos_inte]}/control-mole-fraction.fst \
    --sensitivities ${paths[geos_inte]}/sensitivities${rescaled}.fst \
    --output ${paths[geos_inte]}/process-model-${CASE}.rds

# Make measurement model
echo "making fixed gamma measurement model..." 
Rscript ${paths[root_code_dir]}/intermediates/measurement-model.R \
--observations ${paths[geos_inte]}/${observations}.fst \
--process-model ${paths[geos_inte]}/process-model-${CASE}.rds \
--gamma-prior-shape 100000000 \
--gamma-prior-rate 0.00000001 \
--output ${paths[geos_inte]}/measurement-model-${CASE}.rds

# Make real model case
echo "making real model..."
Rscript ${paths[root_code_dir]}/intermediates/real-model-case.R \
--case $CASE \
--measurement-model ${paths[geos_inte]}/measurement-model-${CASE}.rds \
--process-model ${paths[geos_inte]}/process-model-${CASE}.rds \
--output ${paths[geos_inte]}/real-model-${CASE}.rds
