#!/bin/bash

#PBS -l select=1:ncpus=1:mem=10gb
#PBS -l walltime=1:00:00
#PBS -j oe
#PBS -J 1-100

source ~/.bashrc
conda activate wombat

cd "${PBS_O_WORKDIR}"

# read in variables
cd ../spinup
source bash_var.sh

# all threee scripts need this
export INVERSION_BASE_PARTIAL=${paths[wombat_paper]}/3_inversion/src/partials/base.R

case='m1_ac0_ar05'

#####################################################################################

# Make measurement model
Rscript ${paths[location_of_this_file]}/../intermediates/measurement-model.R \
--observations ${paths[pseudodata_dir]}/observations_${case}_`printf %04d $PBS_ARRAY_INDEX`.fst \
--process-model ${paths[pseudodata_dir]}/process-model.rds \
--gamma-prior-min 0.1 \
--gamma-prior-max 1.9 \
--output ${paths[pseudodata_dir]}/measurement-model_${case}_`printf %04d $PBS_ARRAY_INDEX`.rds

# Make measurement model with fixed gamma
Rscript ${paths[location_of_this_file]}/../intermediates/measurement-model.R \
--observations ${paths[pseudodata_dir]}/observations_${case}_`printf %04d $PBS_ARRAY_INDEX`.fst \
--process-model ${paths[pseudodata_dir]}/process-model.rds \
--gamma-prior-shape 100000000 \
--gamma-prior-rate 0.00000001 \
--output ${paths[pseudodata_dir]}/measurement-model-FIXEDGAMMA_${case}_`printf %04d $PBS_ARRAY_INDEX`.rds


#####################################################################################

# Make real model case - all areas equally varying
Rscript ${paths[location_of_this_file]}/../intermediates/real-model-case.R \
--case ${inversion_constants[land_ocean_equal_model_case]} \
--measurement-model ${paths[pseudodata_dir]}/measurement-model_${case}_`printf %04d $PBS_ARRAY_INDEX`.rds \
--process-model ${paths[pseudodata_dir]}/process-model.rds \
--output ${paths[pseudodata_dir]}/real-model-${inversion_constants[land_ocean_equal_model_case]}_${case}_`printf %04d $PBS_ARRAY_INDEX`.rds

# vary a
Rscript ${paths[location_of_this_file]}/../intermediates/real-model-case.R \
--case IS-RHO0-FIXEDGAMMA-VARYA-FIXEDW-NOBIAS \
--measurement-model ${paths[pseudodata_dir]}/measurement-model-FIXEDGAMMA_${case}_`printf %04d $PBS_ARRAY_INDEX`.rds \
--process-model ${paths[pseudodata_dir]}/process-model.rds \
--output ${paths[pseudodata_dir]}/real-model-IS-RHO0-FIXEDGAMMA-VARYA-FIXEDW-NOBIAS_${case}_`printf %04d $PBS_ARRAY_INDEX`.rds

# vary w
Rscript ${paths[location_of_this_file]}/../intermediates/real-model-case.R \
--case IS-RHO0-FIXEDGAMMA-FIXEDA-VARYW-NOBIAS \
--measurement-model ${paths[pseudodata_dir]}/measurement-model-FIXEDGAMMA_${case}_`printf %04d $PBS_ARRAY_INDEX`.rds \
--process-model ${paths[pseudodata_dir]}/process-model.rds \
--output ${paths[pseudodata_dir]}/real-model-IS-RHO0-FIXEDGAMMA-FIXEDA-VARYW-NOBIAS_${case}_`printf %04d $PBS_ARRAY_INDEX`.rds

# vary gamma
Rscript ${paths[location_of_this_file]}/../intermediates/real-model-case.R \
--case ${inversion_constants[fix_alpha_distrib_model_case]} \
--measurement-model ${paths[pseudodata_dir]}/measurement-model_${case}_`printf %04d $PBS_ARRAY_INDEX`.rds \
--process-model ${paths[pseudodata_dir]}/process-model.rds \
--output ${paths[pseudodata_dir]}/real-model-${inversion_constants[fix_alpha_distrib_model_case]}_${case}_`printf %04d $PBS_ARRAY_INDEX`.rds

# Make real model case - bogstandard inversion
Rscript ${paths[location_of_this_file]}/../intermediates/real-model-case.R \
--case ${inversion_constants[bogstandard_model_case]} \
--measurement-model ${paths[pseudodata_dir]}/measurement-model-FIXEDGAMMA_${case}_`printf %04d $PBS_ARRAY_INDEX`.rds \
--process-model ${paths[pseudodata_dir]}/process-model.rds \
--output ${paths[pseudodata_dir]}/real-model-${inversion_constants[bogstandard_model_case]}_${case}_`printf %04d $PBS_ARRAY_INDEX`.rds
