# read in variables
cd ../spinup
source bash_var.sh

cd ../pseudodata

# set up the cases and which parameters need to vary in WOMBAT for these
case=( m1_ac0_ar1 m4_ac0_ar1 m2_ac0_ar1 m05_ac0_ar1 m1_ac05_ar1 m1_ac1_ar1 m1_ac0_ar2 m1_ac0_ar05 )
gamma=( TRUE TRUE TRUE TRUE FALSE FALSE FALSE FALSE )
a=( TRUE FALSE FALSE FALSE TRUE TRUE FALSE FALSE )
w=( TRUE FALSE FALSE FALSE FALSE FALSE TRUE TRUE )

# run base case
Rscript pseudodata.R --measurement-noise 1 --acorr 0 --alpha-range 1 --output-suffix "m1_ac0_ar1"

# # change measurement noise
Rscript pseudodata.R --measurement-noise 4 --acorr 0 --alpha-range 1 --output-suffix "m4_ac0_ar1"
Rscript pseudodata.R --measurement-noise 2 --acorr 0 --alpha-range 1 --output-suffix "m2_ac0_ar1"
Rscript pseudodata.R --measurement-noise 0.5 --acorr 0 --alpha-range 1 --output-suffix "m05_ac0_ar1"

# # change alpha correlation
Rscript pseudodata.R --measurement-noise 1 --acorr 0.5 --alpha-range 1 --output-suffix "m1_ac05_ar1"
Rscript pseudodata.R --measurement-noise 1 --acorr 0.99 --alpha-range 1 --output-suffix "m1_ac1_ar1"

# # change alpha range
Rscript pseudodata.R --measurement-noise 1 --acorr 0 --alpha-range 2 --output-suffix "m1_ac0_ar2"
Rscript pseudodata.R --measurement-noise 1 --acorr 0 --alpha-range 0.5 --output-suffix "m1_ac0_ar05"

# only need one process model, but need loads of measurement / real case models, so make separately
export INVERSION_BASE_PARTIAL=${paths[wombat_paper]}/3_inversion/src/partials/base.R
# Make process model
Rscript ${paths[location_of_this_file]}/../intermediates/process-model.R \
--control-emissions ${paths[geos_inte]}/control-emissions-window01.fst \
--perturbations ${paths[geos_inte]}/perturbations_window01.fst \
--control-mole-fraction ${paths[geos_inte]}/control-mole-fraction-window01.fst \
--sensitivities ${paths[geos_inte]}/sensitivities_window01.fst \
--output ${paths[pseudodata_dir]}/process-model.rds

# make measurement and real case models
len=${#case[@]}
for (( i=0; i<$len; i++ ));
do 
    echo "${case[$i]}"
    echo "${gamma[$i]}"
    echo "${a[$i]}"
    echo "${w[$i]}"
    sed -i -e "s#case=.*#case='${case[$i]}'#" -e "s#param_gamma=.*#param_gamma=${gamma[$i]}#" -e "s#param_a=.*#param_a=${a[$i]}#" -e "s#param_w=.*#param_w=${w[$i]}#" make_models.sh
    sbatch make_models.sh
done

# wait for job to finish
njob=1
while [ $njob -gt 0 ]
do
    sleep 10s
    njob=$(sacct --format="JobID,State,JobName%30" | grep "RUNNING \| PENDING" | grep "models_pseudo.*" | wc -l)

    echo "There are $njob jobs to go"
done
echo "Exiting loop..."


# submit inversions
for (( i=0; i<$len; i++ ));
do
    echo "${case[$i]}"
    if [[ "${gamma[$i]}" = TRUE ]]
    then
        echo "submitting varying gamma..."
        sed "s#%case%#${case[$i]}#" make_real_mcmc_samples_varygamma_submit.sh > make_real_mcmc_samples_varygamma_${case[$i]}_submit.sh
        sbatch make_real_mcmc_samples_varygamma_${case[$i]}_submit.sh
    fi
    if [[ "${a[$i]}" = TRUE ]]
    then
        echo "submitting varying a..."
        sed "s#%case%#${case[$i]}#" make_real_mcmc_samples_varya_submit.sh > make_real_mcmc_samples_varya_${case[$i]}_submit.sh
        sbatch make_real_mcmc_samples_varya_${case[$i]}_submit.sh
    fi
    if [[ "${w[$i]}" = TRUE ]]
    then
        echo "submitting varying w..."
        sed "s#%case%#${case[$i]}#" make_real_mcmc_samples_varyw_submit.sh > make_real_mcmc_samples_varyw_${case[$i]}_submit.sh
        sbatch make_real_mcmc_samples_varyw_${case[$i]}_submit.sh
    fi
done
