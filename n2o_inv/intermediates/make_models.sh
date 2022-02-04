#!/bin/bash

# read in variables
cd ../spinup
source bash_var.sh

# all threee scripts need this
export INVERSION_BASE_PARTIAL=${paths[wombat_paper]}/3_inversion/src/partials/base.R

#####################################################################################

# Make process model
Rscript ${paths[location_of_this_file]}/../intermediates/process-model.R \
--control-emissions ${paths[geos_inte]}/control-emissions.fst \
--perturbations ${paths[geos_inte]}/perturbations.fst \
--control-mole-fraction ${paths[geos_inte]}/control-mole-fraction.fst \
--sensitivities ${paths[geos_inte]}/sensitivities.fst \
--output ${paths[geos_inte]}/process-model.rds

# Make process model double rescaling 
Rscript ${paths[location_of_this_file]}/../intermediates/process-model.R \
--control-emissions ${paths[geos_inte]}/control-emissions-rescaled-double.fst \
--perturbations ${paths[geos_inte]}/perturbations-rescaled-double.fst \
--control-mole-fraction ${paths[geos_inte]}/control-mole-fraction-rescaled-double.fst \
--sensitivities ${paths[geos_inte]}/sensitivities-rescaled-double.fst \
--output ${paths[geos_inte]}/process-model-rescaled-double.rds

# Make process model half rescaling 
Rscript ${paths[location_of_this_file]}/../intermediates/process-model.R \
--control-emissions ${paths[geos_inte]}/control-emissions-rescaled-half.fst \
--perturbations ${paths[geos_inte]}/perturbations-rescaled-half.fst \
--control-mole-fraction ${paths[geos_inte]}/control-mole-fraction-rescaled-half.fst \
--sensitivities ${paths[geos_inte]}/sensitivities-rescaled-half.fst \
--output ${paths[geos_inte]}/process-model-rescaled-half.rds

#####################################################################################

# Make measurement model
Rscript ${paths[location_of_this_file]}/../intermediates/measurement-model.R \
--observations ${paths[geos_inte]}/observations.fst \
--process-model ${paths[geos_inte]}/process-model.rds \
--gamma-prior-min 0.1 \
--gamma-prior-max 1.0 \
--output ${paths[geos_inte]}/measurement-model.rds

# Make measurement model with fixed gamma
Rscript ${paths[location_of_this_file]}/../intermediates/measurement-model.R \
--observations ${paths[geos_inte]}/observations.fst \
--process-model ${paths[geos_inte]}/process-model.rds \
--gamma-prior-shape 100000000 \
--gamma-prior-rate 0.00000001 \
--output ${paths[geos_inte]}/measurement-model-FIXEDGAMMA.rds

# Make measurement model with added error
Rscript ${paths[location_of_this_file]}/../intermediates/measurement-model.R \
--observations ${paths[geos_inte]}/model-err-observations.fst \
--process-model ${paths[geos_inte]}/process-model.rds \
--gamma-prior-min 0.1 \
--gamma-prior-max 1.0 \
--output ${paths[geos_inte]}/measurement-model-model-err.rds

# Make measurement model double rescaling
Rscript ${paths[location_of_this_file]}/../intermediates/measurement-model.R \
--observations ${paths[geos_inte]}/observations.fst \
--process-model ${paths[geos_inte]}/process-model-rescaled-double.rds \
--gamma-prior-min 0.1 \
--gamma-prior-max 1.0 \
--output ${paths[geos_inte]}/measurement-model-rescaled-double.rds

# Make measurement model half rescaling
Rscript ${paths[location_of_this_file]}/../intermediates/measurement-model.R \
--observations ${paths[geos_inte]}/observations.fst \
--process-model ${paths[geos_inte]}/process-model-rescaled-half.rds \
--gamma-prior-min 0.1 \
--gamma-prior-max 1.0 \
--output ${paths[geos_inte]}/measurement-model-rescaled-half.rds

#####################################################################################

# Make real model case - like WOMBAT original
Rscript ${paths[location_of_this_file]}/../intermediates/real-model-case.R \
--case ${inversion_constants[model_case]} \
--measurement-model ${paths[geos_inte]}/measurement-model.rds \
--process-model ${paths[geos_inte]}/process-model.rds \
--output ${paths[geos_inte]}/real-model-${inversion_constants[model_case]}.rds

# Make real model case - all areas equally varying
Rscript ${paths[location_of_this_file]}/../intermediates/real-model-case.R \
--case ${inversion_constants[land_ocean_equal_model_case]} \
--measurement-model ${paths[geos_inte]}/measurement-model.rds \
--process-model ${paths[geos_inte]}/process-model.rds \
--output ${paths[geos_inte]}/real-model-${inversion_constants[land_ocean_equal_model_case]}.rds

# Make real model case - bogstandard inversion
Rscript ${paths[location_of_this_file]}/../intermediates/real-model-case.R \
--case ${inversion_constants[bogstandard_model_case]} \
--measurement-model ${paths[geos_inte]}/measurement-model-FIXEDGAMMA.rds \
--process-model ${paths[geos_inte]}/process-model.rds \
--output ${paths[geos_inte]}/real-model-${inversion_constants[bogstandard_model_case]}.rds

# Make real model case - fix_alpha_distrib inversion
Rscript ${paths[location_of_this_file]}/../intermediates/real-model-case.R \
--case ${inversion_constants[fix_alpha_distrib_model_case]} \
--measurement-model ${paths[geos_inte]}/measurement-model.rds \
--process-model ${paths[geos_inte]}/process-model.rds \
--output ${paths[geos_inte]}/real-model-${inversion_constants[fix_alpha_distrib_model_case]}.rds

# Make real model case - fix_gamma inversion
Rscript ${paths[location_of_this_file]}/../intermediates/real-model-case.R \
--case ${inversion_constants[fix_gamma_model_case]} \
--measurement-model ${paths[geos_inte]}/measurement-model-FIXEDGAMMA.rds \
--process-model ${paths[geos_inte]}/process-model.rds \
--output ${paths[geos_inte]}/real-model-${inversion_constants[fix_gamma_model_case]}.rds

# Make real model case - double rescaling
Rscript ${paths[location_of_this_file]}/../intermediates/real-model-case.R \
--case ${inversion_constants[model_case]} \
--measurement-model ${paths[geos_inte]}/measurement-model-rescaled-double.rds \
--process-model ${paths[geos_inte]}/process-model-rescaled-double.rds \
--output ${paths[geos_inte]}/real-model-${inversion_constants[model_case]}-rescaled-double.rds

# Make real model case - half rescaling
Rscript ${paths[location_of_this_file]}/../intermediates/real-model-case.R \
--case ${inversion_constants[model_case]} \
--measurement-model ${paths[geos_inte]}/measurement-model-rescaled-half.rds \
--process-model ${paths[geos_inte]}/process-model-rescaled-half.rds \
--output ${paths[geos_inte]}/real-model-${inversion_constants[model_case]}-rescaled-half.rds

# Make real model case - varying double rescaling
Rscript ${paths[location_of_this_file]}/../intermediates/real-model-case.R \
--case ${inversion_constants[land_ocean_equal_model_case]} \
--measurement-model ${paths[geos_inte]}/measurement-model-rescaled-double.rds \
--process-model ${paths[geos_inte]}/process-model-rescaled-double.rds \
--output ${paths[geos_inte]}/real-model-${inversion_constants[land_ocean_equal_model_case]}-rescaled-double.rds

# Make real model case - varying half rescaling
Rscript ${paths[location_of_this_file]}/../intermediates/real-model-case.R \
--case ${inversion_constants[land_ocean_equal_model_case]} \
--measurement-model ${paths[geos_inte]}/measurement-model-rescaled-half.rds \
--process-model ${paths[geos_inte]}/process-model-rescaled-half.rds \
--output ${paths[geos_inte]}/real-model-${inversion_constants[land_ocean_equal_model_case]}-rescaled-half.rds

# Make real model case - model err
Rscript ${paths[location_of_this_file]}/../intermediates/real-model-case.R \
--case ${inversion_constants[land_ocean_equal_model_case]} \
--measurement-model ${paths[geos_inte]}/measurement-model-model-err.rds \
--process-model ${paths[geos_inte]}/process-model.rds \
--output ${paths[geos_inte]}/real-model-${inversion_constants[land_ocean_equal_model_case]}-model-err.rds