#!/bin/bash

# read in variables
cd ../spinup
source bash_var.sh

# submit
cd ../inversion
qsub make_real_mcmc_samples_vary_submit_cpu.sh
qsub make_real_mcmc_samples_vary_rescaled_double_submit_cpu.sh
qsub make_real_mcmc_samples_vary_rescaled_half_submit_cpu.sh
