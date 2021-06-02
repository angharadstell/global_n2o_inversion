#!/bin/bash

# load variables
source ../spinup/bash_var.sh

# iterate through each perturbed case
for YEAR in $(eval echo "{${dates[perturb_start]:0:4}..$((${dates[perturb_end]:0:4}-1))}")
do
    for MONTH in {1..12}
    do
        # construct peturbed file location
        perturb_case="$YEAR$(printf '%02d' $MONTH)"
        echo $perturb_case

        # submit
        qsub $geo_rundirs/$perturb_case/gcclassic_submit.sh
    done
done
