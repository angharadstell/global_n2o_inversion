#!/bin/bash
# This script checks if all the perturbed runs finish normally
# Expected output for each successful run:
# **************   E N D   O F   G E O S -- C H E M   **************
# anything else suggests a problem! GO check it

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

        tail -1 ${paths[geo_rundirs]}/$perturb_case/GC.log
    done
done
