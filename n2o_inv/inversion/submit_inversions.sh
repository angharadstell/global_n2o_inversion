#!/bin/bash

# read in variables
cd ../spinup
source bash_var.sh

# submit
cd ../inversion
sbatch make_real_mcmc_samples_vary_submit_cpu.sh
sbatch make_real_mcmc_samples_vary_rescaled_double_submit_cpu.sh
sbatch make_real_mcmc_samples_vary_rescaled_half_submit_cpu.sh
