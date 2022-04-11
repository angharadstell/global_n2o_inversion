#!/bin/bash
# This script makes the WOMBAT models, and runs the WOMBAT inversion with a rescaled prior

#SBATCH --job-name=window_sub
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=1-00:00:00
#SBATCH --mem=5G
#SBATCH --array=0-3

source ~/.bashrc
conda activate wombat

# build casename
BASE_CASE=IS-RHO0-VARYA-VARYW-NOBIAS-model-err-n2o_std
window02d=01
CASE_ARRAY=(doubleland doubleocean halfland halfocean)
CASE=${BASE_CASE}-rescaled-${CASE_ARRAY[$SLURM_ARRAY_TASK_ID]}
echo $CASE

# make models
cd ../moving_window
sed -e "s/%window02d%/$window02d/" -e "s/%CASE%/$CASE/" make_models.sh > make_models_$CASE.sh
chmod +x make_models_$CASE.sh
./make_models_$CASE.sh
rm make_models_$CASE.sh

# run inversion
sed -e "s/%window02d%/$window02d/" -e "s/%CASE%/${CASE}_window$window02d/" make_real_mcmc_samples_submit.sh > make_real_mcmc_samples_${CASE}_submit.sh
chmod +x make_real_mcmc_samples_${CASE}_submit.sh
./make_real_mcmc_samples_${CASE}_submit.sh
rm make_real_mcmc_samples_${CASE}_submit.sh
