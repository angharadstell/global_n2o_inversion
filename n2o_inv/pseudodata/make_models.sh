#!/bin/bash
# This script makes the WOMBAT models required for running the pseudodata WOMBAT inversions

#SBATCH --job-name=models_pseudo
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=1:00:00
#SBATCH --mem=10G
#SBATCH --array=1-50

source ~/.bashrc
conda activate wombat

# read in variables
cd ../spinup
source bash_var.sh

# all threee scripts need this
export INVERSION_BASE_PARTIAL=${paths[wombat_paper]}/3_inversion/src/partials/base.R

case='m1_ac0_ar05'
param_gamma=FALSE
param_a=FALSE
param_w=TRUE

#####################################################################################

# Make measurement model
if [[ $param_gamma = TRUE ]]
then
    Rscript ${paths[root_code_dir]}/intermediates/measurement-model.R \
    --observations ${paths[pseudodata_dir]}/observations_${case}_`printf %04d $SLURM_ARRAY_TASK_ID`.fst \
    --process-model ${paths[pseudodata_dir]}/process-model.rds \
    --gamma-prior-min 0.1 \
    --gamma-prior-max 1.0 \
    --output ${paths[pseudodata_dir]}/measurement-model_${case}_`printf %04d $SLURM_ARRAY_TASK_ID`.rds
fi
if [[ $param_a = TRUE ]] || [[ $param_w = TRUE ]]
then
    # Make measurement model with fixed gamma
    Rscript ${paths[root_code_dir]}/intermediates/measurement-model.R \
    --observations ${paths[pseudodata_dir]}/observations_${case}_`printf %04d $SLURM_ARRAY_TASK_ID`.fst \
    --process-model ${paths[pseudodata_dir]}/process-model.rds \
    --gamma-prior-shape 100000000 \
    --gamma-prior-rate 0.00000001 \
    --output ${paths[pseudodata_dir]}/measurement-model-FIXEDGAMMA_${case}_`printf %04d $SLURM_ARRAY_TASK_ID`.rds
fi

#####################################################################################

# vary a
if [[ $param_a = TRUE ]]
then
    Rscript ${paths[root_code_dir]}/intermediates/real-model-case.R \
    --case IS-RHO0-FIXEDGAMMA-VARYA-FIXEDW-NOBIAS \
    --measurement-model ${paths[pseudodata_dir]}/measurement-model-FIXEDGAMMA_${case}_`printf %04d $SLURM_ARRAY_TASK_ID`.rds \
    --process-model ${paths[pseudodata_dir]}/process-model.rds \
    --output ${paths[pseudodata_dir]}/real-model-IS-RHO0-FIXEDGAMMA-VARYA-FIXEDW-NOBIAS_${case}_`printf %04d $SLURM_ARRAY_TASK_ID`.rds
fi

# vary w
if [[ $param_w = TRUE ]]
then
    Rscript ${paths[root_code_dir]}/intermediates/real-model-case.R \
    --case IS-RHO0-FIXEDGAMMA-FIXEDA-VARYW-NOBIAS \
    --measurement-model ${paths[pseudodata_dir]}/measurement-model-FIXEDGAMMA_${case}_`printf %04d $SLURM_ARRAY_TASK_ID`.rds \
    --process-model ${paths[pseudodata_dir]}/process-model.rds \
    --output ${paths[pseudodata_dir]}/real-model-IS-RHO0-FIXEDGAMMA-FIXEDA-VARYW-NOBIAS_${case}_`printf %04d $SLURM_ARRAY_TASK_ID`.rds
fi

# vary gamma
if [[ $param_gamma = TRUE ]]
then
    Rscript ${paths[root_code_dir]}/intermediates/real-model-case.R \
    --case IS-RHO0-FIXEDA-FIXEDW-NOBIAS \
    --measurement-model ${paths[pseudodata_dir]}/measurement-model_${case}_`printf %04d $SLURM_ARRAY_TASK_ID`.rds \
    --process-model ${paths[pseudodata_dir]}/process-model.rds \
    --output ${paths[pseudodata_dir]}/real-model-IS-RHO0-FIXEDA-FIXEDW-NOBIAS_${case}_`printf %04d $SLURM_ARRAY_TASK_ID`.rds
fi
