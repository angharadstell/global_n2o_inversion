#!/bin/bash

#PBS -l select=1:ncpus=12:mem=10gb
#PBS -l walltime=72:00:00
#PBS -j oe

###############################################################################
### Sample GEOS-Chem run script for SLURM
### You can increase the number of cores with -c and memory with --mem,
### particularly if you are running at very fine resolution (e.g. nested-grid)
###############################################################################

ulimit -s unlimited
export OMP_STACKSIZE=500m

# Set the proper # of threads for OpenMP
# SLURM_CPUS_PER_TASK ensures this matches the number you set with -c above
export OMP_NUM_THREADS=12

# Run GEOS_Chem.  The "time" command will return CPU and wall times.
# Stdout and stderr will be directed to the "GC.log" log file
# (you can change the log file name below if you wish)
cd %exe_path%
./gcclassic >> GC.log

