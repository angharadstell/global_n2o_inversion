#!/bin/bash

# read in variables
cd ../spinup
source bash_var.sh

# all threee scripts need this
export INVERSION_BASE_PARTIAL=${paths[wombat_paper]}/3_inversion/src/partials/base.R


#####################################################################################

# Make process model
Rscript ${paths[location_of_this_file]}/../intermediates/process-model.R \
--control-emissions ${paths[geos_inte]}/control-emissions-pseudo.fst \
--perturbations ${paths[geos_inte]}/perturbations_pseudo.fst \
--control-mole-fraction ${paths[geos_inte]}/control-mole-fraction-pseudo.fst \
--sensitivities ${paths[geos_inte]}/sensitivities_pseudo.fst \
--output ${paths[pseudodata_dir]}/process-model.rds

# run rescale_prior.R here

# # Make process model double rescaling 
# Rscript ${paths[location_of_this_file]}/../intermediates/process-model.R \
# --control-emissions ${paths[pseudodata_dir]}/control-emissions-rescaled-double.fst \
# --perturbations ${paths[pseudodata_dir]}/perturbations-rescaled-double.fst \
# --control-mole-fraction ${paths[pseudodata_dir]}/control-mole-fraction-rescaled-double.fst \
# --sensitivities ${paths[pseudodata_dir]}/sensitivities-rescaled-double.fst \
# --output ${paths[pseudodata_dir]}/process-model-rescaled-double.rds

# # Make process model half rescaling 
# Rscript ${paths[location_of_this_file]}/../intermediates/process-model.R \
# --control-emissions ${paths[pseudodata_dir]}/control-emissions-rescaled-half.fst \
# --perturbations ${paths[pseudodata_dir]}/perturbations-rescaled-half.fst \
# --control-mole-fraction ${paths[pseudodata_dir]}/control-mole-fraction-rescaled-half.fst \
# --sensitivities ${paths[pseudodata_dir]}/sensitivities-rescaled-half.fst \
# --output ${paths[pseudodata_dir]}/process-model-rescaled-half.rds
