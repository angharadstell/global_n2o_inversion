#!/bin/bash
# This script converts the spinup GEOSChem files to those needed to run the base run

# load variables
source ../spinup/bash_var.sh

# move in correct restart file
ln -s $output_dir/$case/su_$(printf '%02d' $((no_spinup_years+1)))/GEOSChem.Restart.${dates[perturb_start]//-}_0000z.nc4 $geo_rundirs/$case/GEOSChem.Restart.${dates[perturb_start]//-}_0000z.nc4

# change run dates
cd $geo_rundirs/$case
sed -i -e "s/Start YYYYMMDD, hhmmss  : .*/Start YYYYMMDD, hhmmss  : ${dates[perturb_start]//-} 000000/" -e "s/End   YYYYMMDD, hhmmss  : .*/End   YYYYMMDD, hhmmss  : ${dates[perturb_end]//-} 000000/" input.geos

# get monthly restart files
sed -i -e "s/Restart.frequency:          'End',/Restart.frequency:          00000100 000000/" -e "s/Restart.duration:           'End',/Restart.duration:           00000100 000000/" HISTORY.rc

# set new output dir
sed -i "s#/su_$(printf '%02d' $((no_spinup_years+1)))##" input.geos
sed -i "s#/su_$(printf '%02d' $((no_spinup_years+1)))##" HISTORY.rc
sed -i "s#/su_$(printf '%02d' $((no_spinup_years+1)))##" HEMCO_Config.rc

# alter submission script
cd $geo_rundirs/$case
rm gcclassic_submit.sh
cp $location_of_this_file/templates/gcclassic_submit.sh ./gcclassic_submit.sh
sed -i "s#%exe_path%#$geo_rundirs/$case#" gcclassic_submit.sh
