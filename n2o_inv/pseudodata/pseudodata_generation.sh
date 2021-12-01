# read in variables
cd ../spinup
source bash_var.sh

cd ../pseudodata

case=( m1_ac0_ar1 m4_ac0_ar1 m2_ac0_ar1 m05_ac0_ar1 m1_ac05_ar1 m1_ac1_ar1 m1_ac0_ar2 m1_ac0_ar05 )
#case=( m1_ac0_ar1 m1_ac05_ar1 m1_ac1_ar1 )

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


./make_process_models.sh

for i in "${case[@]}"
do 
    echo $i
    sed -i "s#case=.*#case='$i'#" make_models.sh
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

for i in "${case[@]}"
do
    sed "s#%case%#$i#" make_real_mcmc_samples_bogstandard_submit.sh > make_real_mcmc_samples_bogstandard_${i}_submit.sh
    sbatch make_real_mcmc_samples_bogstandard_${i}_submit.sh

    sed "s#%case%#$i#" make_real_mcmc_samples_vary_submit.sh > make_real_mcmc_samples_vary_${i}_submit.sh
    sbatch make_real_mcmc_samples_vary_${i}_submit.sh

    sed "s#%case%#$i#" make_real_mcmc_samples_varya_submit.sh > make_real_mcmc_samples_varya_${i}_submit.sh
    sbatch make_real_mcmc_samples_varya_${i}_submit.sh

    sed "s#%case%#$i#" make_real_mcmc_samples_fixedalpha_submit.sh > make_real_mcmc_samples_fixedalpha_${i}_submit.sh
    sbatch make_real_mcmc_samples_fixedalpha_${i}_submit.sh

    sed "s#%case%#$i#" make_real_mcmc_samples_varyw_submit.sh > make_real_mcmc_samples_varyw_${i}_submit.sh
    sbatch make_real_mcmc_samples_varyw_${i}_submit.sh

done


