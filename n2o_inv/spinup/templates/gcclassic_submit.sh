#!/bin/bash

#SBATCH --job-name=geoschem_run
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=12
#SBATCH --time=72:00:00
#SBATCH --mem=5G

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

