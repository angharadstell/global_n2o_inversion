#!/bin/bash
# This script plots the full time series analytical inversion results

CASE=analytical-IS-FIXEDGAMMA-NOBIAS-model-err-n2o_std
echo $CASE

source ~/.bashrc
conda activate wombat

# read in variables
cd ../spinup
source bash_var.sh



# is this a model error case?
if [[ "$CASE" =~ (model-err)([^,]*) ]]
then
    observations=model-err${BASH_REMATCH[2]}-observations
else
    observations=observations
fi
echo "Using observations file called: $observations"



# make models
echo "making models..."
cd ../moving_window

sed "s#!CASE!#${CASE}#" make_models_analytical.sh > make_models_analytical_$CASE.sh
chmod +x make_models_analytical_$CASE.sh
./make_models_analytical_$CASE.sh
rm make_models_analytical_$CASE.sh


# traceplot
echo "traceplots.R"
Rscript ${paths[root_code_dir]}/inversion/traceplots.R --casename $CASE --sampledir ${paths[geos_inte]}

# flux aggregate
cd ../results
./flux_aggregators.sh $CASE process-model-$CASE ${paths[geos_inte]}

echo "obs_matched_samples.R"
Rscript ${paths[root_code_dir]}/results/obs_matched_samples.R \
    --model-case ${paths[geos_inte]}/real-model-${CASE}.rds \
    --process-model ${paths[geos_inte]}/process-model-${CASE}.rds \
    --samples ${paths[geos_inte]}/real-mcmc-samples-${CASE}.rds \
    --observations ${paths[geos_inte]}/${observations}.fst \
    --output ${paths[inversion_results]}/obs_matched_samples-${CASE}.rds

# plot
echo "plots.sh"
cd ../results
./plots.sh $CASE

echo "plot_annual_ems.R"
Rscript plot_annual_ems.R --casename $CASE
