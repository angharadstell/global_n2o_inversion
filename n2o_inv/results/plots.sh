#!/bin/bash

# read in variables
cd ../spinup
source bash_var.sh

export RESULTS_BASE_PARTIAL=${paths[wombat_paper]}/4_results/src/partials/base.R
export RESULTS_TABLES_PARTIAL=${paths[wombat_paper]}/4_results/src/partials/tables.R
export RESULTS_DISPLAY_PARTIAL=${paths[wombat_paper]}/4_results/src/partials/display.R
export RESULTS_FLUX_AGGREGATES_PARTIAL=${paths[location_of_this_file]}/../results/partials/flux-aggregates.R

case=IS-FIXEDAO-FIXEDWO5-NOBIAS

Rscript ${paths[location_of_this_file]}/../results/flux-aggregates-table.R \
    --flux-samples ${paths[inversion_results]}/real-flux-aggregates-samples-$case.rds \
    --output ${paths[inversion_results]}/flux-aggregates-table.txt

Rscript ${paths[location_of_this_file]}/../results/flux-aggregates.R \
    --region 'N extratropics (23.5 - 90)' 'N tropics (0 - 23.5)' 'S tropics (-23.5 - 0)' 'S extratropics (-90 - -23.5)' \
    --flux-samples ${paths[inversion_results]}/real-flux-aggregates-samples-$case.rds \
    --height 18 \
    --small-y-axes \
    --output ${paths[inversion_results]}/flux-aggregates-zonal.pdf

Rscript ${paths[location_of_this_file]}/../results/flux-aggregates.R \
		--region Global "Global land" "Global oceans" \
		--flux-samples ${paths[inversion_results]}/real-flux-aggregates-samples-$case.rds \
		--height 16.5 \
		--output ${paths[inversion_results]}/flux-aggregates-globals.pdf

Rscript ${paths[location_of_this_file]}/../results/obs_matched_samples.R
Rscript ${paths[location_of_this_file]}/../results/plot_mf.R