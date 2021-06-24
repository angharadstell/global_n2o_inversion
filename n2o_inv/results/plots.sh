#!/bin/bash

# read in variables
cd ../spinup
source bash_var.sh

export RESULTS_BASE_PARTIAL=${paths[wombat_paper]}/4_results/src/partials/base.R
export RESULTS_TABLES_PARTIAL=${paths[wombat_paper]}/4_results/src/partials/tables.R
export RESULTS_DISPLAY_PARTIAL=${paths[wombat_paper]}/4_results/src/partials/display.R
export RESULTS_FLUX_AGGREGATES_PARTIAL=${paths[location_of_this_file]}/../results/partials/flux-aggregates.R

echo "flux-aggregates-table.R"
Rscript ${paths[location_of_this_file]}/../results/flux-aggregates-table.R \
    --flux-samples ${paths[inversion_results]}/real-flux-aggregates-samples-${inversion_constants[model_case]}.rds \
    --start-date ${dates[perturb_start]} \
    --end-date ${dates[perturb_end]} \
    --output ${paths[inversion_results]}/flux-aggregates-table.txt

echo "flux-aggregates.R zonal"
Rscript ${paths[location_of_this_file]}/../results/flux-aggregates.R \
    --region 'N extratropics (23.5 - 90)' 'N tropics (0 - 23.5)' 'S tropics (-23.5 - 0)' 'S extratropics (-90 - -23.5)' \
    --flux-samples ${paths[inversion_results]}/real-flux-aggregates-samples-${inversion_constants[model_case]}.rds \
    --height 18 \
    --small-y-axes \
    --start-date ${dates[perturb_start]} \
    --end-date ${dates[perturb_end]} \
    --output ${paths[inversion_results]}/flux-aggregates-zonal.pdf

echo "flux-aggregates.R global"
Rscript ${paths[location_of_this_file]}/../results/flux-aggregates.R \
		--region Global "Global land" "Global oceans" \
		--flux-samples ${paths[inversion_results]}/real-flux-aggregates-samples-${inversion_constants[model_case]}.rds \
		--height 16.5 \
        --start-date ${dates[perturb_start]} \
        --end-date ${dates[perturb_end]} \
		--output ${paths[inversion_results]}/flux-aggregates-globals.pdf

echo "flux-aggregates.R zonal priorunc"
Rscript ${paths[location_of_this_file]}/../results/flux-aggregates.R \
    --region 'N extratropics (23.5 - 90)' 'N tropics (0 - 23.5)' 'S tropics (-23.5 - 0)' 'S extratropics (-90 - -23.5)' \
    --flux-samples ${paths[inversion_results]}/real-flux-aggregates-samples-${inversion_constants[model_case]}.rds \
    --show-prior-uncertainty \
    --height 18 \
    --small-y-axes \
    --start-date ${dates[perturb_start]} \
    --end-date ${dates[perturb_end]} \
    --output ${paths[inversion_results]}/flux-aggregates-zonal_priorunc.pdf

echo "flux-aggregates.R global priorunc"
Rscript ${paths[location_of_this_file]}/../results/flux-aggregates.R \
		--region Global "Global land" "Global oceans" \
		--flux-samples ${paths[inversion_results]}/real-flux-aggregates-samples-${inversion_constants[model_case]}.rds \
        --show-prior-uncertainty \
		--height 16.5 \
        --start-date ${dates[perturb_start]} \
        --end-date ${dates[perturb_end]} \
		--output ${paths[inversion_results]}/flux-aggregates-globals_priorunc.pdf

echo "obs_matched_samples.R"
Rscript ${paths[location_of_this_file]}/../results/obs_matched_samples.R \
    --model-case ${paths[geos_inte]}/real-model-${inversion_constants[model_case]}.rds \
    --process-model ${paths[geos_inte]}/process-model.rds \
    --samples ${paths[geos_inte]}/real-mcmc-samples-${inversion_constants[model_case]}.rds \
    --observations ${paths[geos_inte]}/observations.fst \
    --output ${paths[inversion_results]}/obs_matched_samples.rds

echo "plot_mf.R"
Rscript ${paths[location_of_this_file]}/../results/plot_mf.R \
    --obs-samples ${paths[inversion_results]}/obs_matched_samples.rds \
    --output ${paths[inversion_results]}/obs_time_series.pdf