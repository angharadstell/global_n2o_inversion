#!/bin/bash

# This script lets you extend the inversion. You'll need to manually redo the observations, or use the "final_end" in the config.ini as the final date you want and then adjust
# "perturb_end" to only run to that date, until you're ready to commit to the full run to "final_end".

# load variables
source ../spinup/bash_var.sh

part_done_perturb_start=2013-02-01

old_end=2015-01-01
new_end=2021-01-01

new_walltime=24

# EMISSIONS
python ../emissions/perturb_ems.py

BASE RUN
move in correct restart file
ln -s $output_dir/$case/GEOSChem.Restart.${old_end//-}_0000z.nc4 $geo_rundirs/$case/.
change run dates
cd $geo_rundirs/$case
sed -i -e "s/Start YYYYMMDD, hhmmss  : .*/Start YYYYMMDD, hhmmss  : ${old_end//-} 000000/" -e "s/End   YYYYMMDD, hhmmss  : .*/End   YYYYMMDD, hhmmss  : ${new_end//-} 000000/" input.geos
change runtime
sed -i "s/#SBATCH --time=.*/#SBATCH --time=$new_walltime:00:00/" gcclassic_submit.sh
# download any missing data
./gcclassic --dryrun > log.dryrun
./download_data.py log.dryrun --cc
# submit 
qsub gcclassic_submit.sh

OLD PERTURBED RUNS
for YEAR in $(eval echo "{${part_done_perturb_start:0:4}..$((${old_end:0:4}-1))}")
do
    for MONTH in {1..12}
    do
        perturb_case="$YEAR$(printf '%02d' $MONTH)"
        echo $perturb_case

        cd $geo_rundirs/$perturb_case
        # move in correct restart file
        ln -s $output_dir/$perturb_case/GEOSChem.Restart.${old_end//-}_0000z.nc4 $geo_rundirs/$perturb_case/.
        # change run dates
        # for 2 year sensitivity
        end_date_year=$((YEAR+2))
        end_date_month=$MONTH
        # check doesn't go beyond end date
        if [ $((end_date_year)) -ge ${new_end:0:4} ]
        then
            end_date_year=${new_end:0:4}
            end_date_month=1
        fi
        end_date="$end_date_year$(printf '%02d' $end_date_month)"   
        sed -i -e "s/Start YYYYMMDD, hhmmss  : .*/Start YYYYMMDD, hhmmss  : ${old_end//-} 000000/" -e "s/End   YYYYMMDD, hhmmss  : .*/End   YYYYMMDD, hhmmss  : ${end_date}01 000000/" input.geos
        # change runtime
        sed -i "s/#SBATCH --time=.*/#SBATCH --time=$new_walltime:00:00/" gcclassic_submit.sh
        # submit 
        qsub gcclassic_submit.sh
    done
done

# # NEW PERTURBED RUNS
# # HAVE TO WAIT FOR BASE RUN TO FINISH
# cd ${paths[root_code_dir]}/perturbed_runs
# # only replace first match of date as want to keep second which specifies correct ic file location
# sed -e "0,/\${dates\[perturb_start\]:0:4}/{s/\${dates\[perturb_start\]:0:4}/${old_end:0:4}/}" -e "s/10:00:00/$new_walltime:00:00/" setup_perturbed.sh > extend_setup_perturbed.sh
# chmod +x extend_setup_perturbed.sh
# ./extend_setup_perturbed.sh
# rm extend_setup_perturbed.sh
# submit
# sed -e "s/\${dates\[perturb_start\]:0:4}/${old_end:0:4}/g" submit_perturbed.sh > extend_submit_perturbed.sh
# chmod +x extend_submit_perturbed.sh
# ./extend_submit_perturbed.sh
# rm extend_submit_perturbed.sh