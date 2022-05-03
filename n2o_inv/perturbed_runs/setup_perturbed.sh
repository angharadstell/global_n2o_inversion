#!/bin/bash
# This script creates the files needed for the perturbed GEOSChem runs

# load variables
source ../spinup/bash_var.sh

for YEAR in $(eval echo "{${dates[perturb_start]:0:4}..$((${dates[perturb_end]:0:4}-1))}")
do
    for MONTH in {1..12}
    do
        perturb_case="$YEAR$(printf '%02d' $MONTH)"
        echo $perturb_case
        # For some reason, I can only get this to work with the wrong number of 1 commands?
        cd $geo_wrapper_dir/run
        printf "7\n1\n1\n1\n1\n1\n$geo_rundirs\n$perturb_case\nn\n" | ./createRunDir.sh
    
        # copy running files from base
        cp $geo_rundirs/$case/input.geos $geo_rundirs/$perturb_case/input.geos
        cp $geo_rundirs/$case/HEMCO_Config.rc $geo_rundirs/$perturb_case/HEMCO_Config.rc
        cp $geo_rundirs/$case/HEMCO_Diagn.rc $geo_rundirs/$perturb_case/HEMCO_Diagn.rc
        cp $geo_rundirs/$case/HISTORY.rc $geo_rundirs/$perturb_case/HISTORY.rc
        cp $geo_rundirs/$case/species_database.yml $geo_rundirs/$perturb_case/species_database.yml

        # Change run date so only run from perturbed month, for 2 years
        cd $geo_rundirs/$perturb_case

        # for 2 year sensitivity
        end_date_year=$((YEAR+2))
        end_date_month=$MONTH

       # check doesn't go beyond end date
       if [ $((end_date_year)) -ge ${dates[perturb_end]:0:4} ]
       then
           end_date_year=${dates[perturb_end]:0:4}
           end_date_month=1
       fi
       end_date="$end_date_year$(printf '%02d' $end_date_month)"         

        sed -i -e "s/Start YYYYMMDD, hhmmss  : .*/Start YYYYMMDD, hhmmss  : ${perturb_case}01 000000/" -e "s/End   YYYYMMDD, hhmmss  : .*/End   YYYYMMDD, hhmmss  : ${end_date}01 000000/" input.geos

        # Change emissions file
        sed -i "s/base_emissions_tagged.nc/ems_${perturb_case}.nc/" HEMCO_Config.rc        

        # Change output dir
        mkdir $output_dir/$perturb_case
        sed -i "s#/$case/#/$perturb_case/#" input.geos
        sed -i "s#/$case/#/$perturb_case/#" HISTORY.rc
        sed -i "s#/$case/#/$perturb_case/#" HEMCO_Config.rc

        # If its a leap year and Mar-Dec and an integer no. of years being run, comment out collections that get stored at "End" (geoschem bug makes it think the date is out of range)
        sed -i "s/'Metrics',/#'Metrics',/" HISTORY.rc

        # Remove default ic file
        rm $geo_rundirs/$perturb_case/GEOSChem.Restart.20190101_0000z.nc4
        # Get ic file
        if [ "$perturb_case" = "${dates[perturb_start]:0:4}01" ]
        then
            ln -s $output_dir/$case/su_$(printf '%02d' $((no_spinup_years+1)))/GEOSChem.Restart.${perturb_case}01_0000z.nc4 $geo_rundirs/$perturb_case/GEOSChem.Restart.${perturb_case}01_0000z.nc4
        else
            ln -s $output_dir/$case/GEOSChem.Restart.${perturb_case}01_0000z.nc4 $geo_rundirs/$perturb_case/GEOSChem.Restart.${perturb_case}01_0000z.nc4
        fi

        # Run script
        cp ${paths[root_code_dir]}/spinup/templates/gcclassic_submit.sh $geo_rundirs/$perturb_case/gcclassic_submit.sh
        sed -i -e "s#%exe_path%#$geo_rundirs/$perturb_case#" -e "s/72:00:00/24:00:00/" gcclassic_submit.sh

        # Compile
        cd $geo_rundirs/$perturb_case/build
        cmake ../CodeDir -DRUNDIR=..
        cmake . -DRUNDIR=..
        make -j
        make install
    done
done
