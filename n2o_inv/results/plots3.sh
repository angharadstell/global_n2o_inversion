#!/bin/bash
# This script plots the fluxes and observed mole fractions for both the analytical and hierarchical results

# read in variables
cd ../spinup
source bash_var.sh

export RESULTS_BASE_PARTIAL=${paths[wombat_paper]}/4_results/src/partials/base.R
export RESULTS_TABLES_PARTIAL=${paths[root_code_dir]}/results/partials/tables.R
export RESULTS_DISPLAY_PARTIAL=${paths[wombat_paper]}/4_results/src/partials/display.R
export RESULTS_FLUX_AGGREGATES_PARTIAL=${paths[root_code_dir]}/results/partials/flux-aggregates3.R

echo "hierarchical model case:"
hierarchical_case=IS-RHO0-FIXEDA-VARYW-NOBIAS-model-err-n2o_std_windowall
echo $hierarchical_case

echo "analytical model case:"
analytical_case=analytical-IS-FIXEDGAMMA-NOBIAS-model-err-n2o_std
echo $analytical_case

# GLOBAL PLOTS
echo "flux-aggregates.R zonal"
Rscript ${paths[root_code_dir]}/results/flux-aggregates3.R \
    --region 'N extratropics (23.5 - 90)' 'N tropics (0 - 23.5)' 'S tropics (-23.5 - 0)' 'S extratropics (-90 - -23.5)' \
    --flux-samples ${paths[inversion_results]}/real-flux-aggregates-samples-$hierarchical_case.rds \
    --anal-samples ${paths[inversion_results]}/real-flux-aggregates-samples-$analytical_case.rds \
    --height 18 \
    --small-y-axes \
    --start-date ${dates[analyse_start]} \
    --end-date ${dates[perturb_end]} \
    --output ${paths[inversion_results]}/flux-aggregates3-zonal-$hierarchical_case.pdf

echo "flux-aggregates.R zonal 30"
Rscript ${paths[root_code_dir]}/results/flux-aggregates3.R \
    --region 'N extratropics (30 - 90)' 'N tropics (0 - 30)' 'S tropics (-30 - 0)' 'S extratropics (-90 - -30)' \
    --flux-samples ${paths[inversion_results]}/real-flux-aggregates-samples-$hierarchical_case.rds \
    --anal-samples ${paths[inversion_results]}/real-flux-aggregates-samples-$analytical_case.rds \
    --height 18 \
    --small-y-axes \
    --start-date ${dates[analyse_start]} \
    --end-date ${dates[perturb_end]} \
    --output ${paths[inversion_results]}/flux-aggregates3-zonal30-$hierarchical_case.pdf

echo "flux-aggregates.R global"
Rscript ${paths[root_code_dir]}/results/flux-aggregates3.R \
		--region "Global" "Global land" "Global oceans" \
		--flux-samples ${paths[inversion_results]}/real-flux-aggregates-samples-$hierarchical_case.rds \
        --anal-samples ${paths[inversion_results]}/real-flux-aggregates-samples-$analytical_case.rds \
		--height 16.5 \
        --start-date ${dates[analyse_start]} \
        --end-date ${dates[perturb_end]} \
		--output ${paths[inversion_results]}/flux-aggregates3-globals-$hierarchical_case.pdf

echo "flux-aggregates.R zonal priorunc"
Rscript ${paths[root_code_dir]}/results/flux-aggregates3.R \
    --region 'N extratropics (23.5 - 90)' 'N tropics (0 - 23.5)' 'S tropics (-23.5 - 0)' 'S extratropics (-90 - -23.5)' \
    --flux-samples ${paths[inversion_results]}/real-flux-aggregates-samples-$hierarchical_case.rds \
    --anal-samples ${paths[inversion_results]}/real-flux-aggregates-samples-$analytical_case.rds \
    --show-prior-uncertainty \
    --height 18 \
    --small-y-axes \
    --start-date ${dates[analyse_start]} \
    --end-date ${dates[perturb_end]} \
    --output ${paths[inversion_results]}/flux-aggregates3-zonal_priorunc-$hierarchical_case.pdf

echo "flux-aggregates.R global priorunc"
Rscript ${paths[root_code_dir]}/results/flux-aggregates3.R \
		--region Global "Global land" "Global oceans" \
		--flux-samples ${paths[inversion_results]}/real-flux-aggregates-samples-$hierarchical_case.rds \
        --anal-samples ${paths[inversion_results]}/real-flux-aggregates-samples-$analytical_case.rds \
        --show-prior-uncertainty \
		--height 16.5 \
        --start-date ${dates[analyse_start]} \
        --end-date ${dates[perturb_end]} \
		--output ${paths[inversion_results]}/flux-aggregates3-globals_priorunc-$hierarchical_case.pdf

# REGIONAL LAND PLOTS
echo "flux-aggregates.R americas"
Rscript ${paths[root_code_dir]}/results/flux-aggregates3.R \
    --region 'T01' 'T02' 'T03' 'T04' \
    --flux-samples ${paths[inversion_results]}/real-flux-aggregates-samples-$hierarchical_case.rds \
    --anal-samples ${paths[inversion_results]}/real-flux-aggregates-samples-$analytical_case.rds \
    --height 18 \
    --small-y-axes \
    --start-date ${dates[analyse_start]} \
    --end-date ${dates[perturb_end]} \
    --output ${paths[inversion_results]}/flux-aggregates3-americas-$hierarchical_case.pdf

echo "flux-aggregates.R eurasia"
Rscript ${paths[root_code_dir]}/results/flux-aggregates3.R \
    --region 'T11' 'T07' 'T08' 'T09' \
    --flux-samples ${paths[inversion_results]}/real-flux-aggregates-samples-$hierarchical_case.rds \
    --anal-samples ${paths[inversion_results]}/real-flux-aggregates-samples-$analytical_case.rds \
    --height 18 \
    --small-y-axes \
    --start-date ${dates[analyse_start]} \
    --end-date ${dates[perturb_end]} \
    --output ${paths[inversion_results]}/flux-aggregates3-eurasia-$hierarchical_case.pdf

echo "flux-aggregates.R remainder land"
Rscript ${paths[root_code_dir]}/results/flux-aggregates3.R \
    --region 'T00' 'T05' 'T06' 'T10' \
    --flux-samples ${paths[inversion_results]}/real-flux-aggregates-samples-$hierarchical_case.rds \
    --anal-samples ${paths[inversion_results]}/real-flux-aggregates-samples-$analytical_case.rds \
    --height 18 \
    --small-y-axes \
    --start-date ${dates[analyse_start]} \
    --end-date ${dates[perturb_end]} \
    --output ${paths[inversion_results]}/flux-aggregates3-remainderland-$hierarchical_case.pdf

# REGIONAL OCEAN PLOTS
echo "flux-aggregates.R Pacific"
Rscript ${paths[root_code_dir]}/results/flux-aggregates3.R \
    --region 'T12' 'T13' 'T14' 'T15' \
    --flux-samples ${paths[inversion_results]}/real-flux-aggregates-samples-$hierarchical_case.rds \
    --anal-samples ${paths[inversion_results]}/real-flux-aggregates-samples-$analytical_case.rds \
    --height 18 \
    --small-y-axes \
    --start-date ${dates[analyse_start]} \
    --end-date ${dates[perturb_end]} \
    --output ${paths[inversion_results]}/flux-aggregates3-pacific-$hierarchical_case.pdf

echo "flux-aggregates.R Atlantic"
Rscript ${paths[root_code_dir]}/results/flux-aggregates3.R \
    --region 'T17' 'T18' 'T19' \
    --flux-samples ${paths[inversion_results]}/real-flux-aggregates-samples-$hierarchical_case.rds \
    --anal-samples ${paths[inversion_results]}/real-flux-aggregates-samples-$analytical_case.rds \
    --height 18 \
    --small-y-axes \
    --start-date ${dates[analyse_start]} \
    --end-date ${dates[perturb_end]} \
    --output ${paths[inversion_results]}/flux-aggregates3-atlantic-$hierarchical_case.pdf

echo "flux-aggregates.R remainder ocean"
Rscript ${paths[root_code_dir]}/results/flux-aggregates3.R \
    --region 'T16' 'T20' 'T21' 'T22' \
    --flux-samples ${paths[inversion_results]}/real-flux-aggregates-samples-$hierarchical_case.rds \
    --anal-samples ${paths[inversion_results]}/real-flux-aggregates-samples-$analytical_case.rds \
    --height 18 \
    --small-y-axes \
    --start-date ${dates[analyse_start]} \
    --end-date ${dates[perturb_end]} \
    --output ${paths[inversion_results]}/flux-aggregates3-remainderocean-$hierarchical_case.pdf

# plot observation time series
echo "plot_mf.R"
Rscript ${paths[root_code_dir]}/results/plot_mf3.R \
    --obs-samples ${paths[inversion_results]}/obs_matched_samples-$hierarchical_case.rds \
    --anal-samples ${paths[inversion_results]}/obs_matched_samples-$analytical_case.rds \
    --output ${paths[inversion_results]}/obs_time_series3-$hierarchical_case.pdf
