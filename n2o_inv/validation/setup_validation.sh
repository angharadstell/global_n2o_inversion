#!/bin/bash
# This script creates all the files required for the GEOSChem valiidation run

# Read in variables
source ../spinup/bash_var.sh


# Create base run spinup folder
cd $geo_wrapper_dir/run
# For some reason, I can only get this to work with the wrong number of 1 commands?
printf "7\n1\n1\n1\n1\n1\n$geo_rundirs\n${inversion_constants[validation_case]}\nn\n" | ./createRunDir.sh

# copy running files from base
cp $geo_rundirs/$case/input.geos $geo_rundirs/${inversion_constants[validation_case]}/input.geos
cp $geo_rundirs/$case/HEMCO_Config.rc $geo_rundirs/${inversion_constants[validation_case]}/HEMCO_Config.rc
cp $geo_rundirs/$case/HEMCO_Diagn.rc $geo_rundirs/${inversion_constants[validation_case]}/HEMCO_Diagn.rc
cp $geo_rundirs/$case/HISTORY.rc $geo_rundirs/${inversion_constants[validation_case]}/HISTORY.rc
cp $geo_rundirs/$case/species_database.yml $geo_rundirs/${inversion_constants[validation_case]}/species_database.yml

# move in correct restart file
ln -s $output_dir/$case/su_10/GEOSChem.Restart.${dates[perturb_start]//-}_0000z.nc4 $geo_rundirs/${inversion_constants[validation_case]}/GEOSChem.Restart.${dates[perturb_start]//-}_0000z.nc4

# Change date of simulation
cd $geo_rundirs/${inversion_constants[validation_case]}
sed -i -e "s/Start YYYYMMDD, hhmmss  : .*/Start YYYYMMDD, hhmmss  : ${dates[perturb_start]//-} 000000/" -e "s/End   YYYYMMDD, hhmmss  : .*/End   YYYYMMDD, hhmmss  : ${dates[perturb_end]//-} 000000/" input.geos

#after I made the orginal runs, but before I made this, /work/as16992 became /user/work/as16992 and the shared directory move to /group/chemistry/acrg
#sed -i -e "s#/work/as16992/#/user/work/as16992/#" -e "s#/work/chxmr/shared/#/group/chemistry/acrg/#" HEMCO_Config.rc
#sed -i -e "s#/work/as16992/#/user/work/as16992/#" -e "s#/work/chxmr/shared/#/group/chemistry/acrg/#" input.geos
#sed -i "s#/work/as16992/#/user/work/as16992/#" HISTORY.rc

# outdirs
# streamline outputs
cd $output_dir
mkdir ${inversion_constants[validation_case]}
cd $geo_rundirs/${inversion_constants[validation_case]}
sed -i "s#$output_dir/$case#$output_dir/${inversion_constants[validation_case]}#" input.geos
sed -i -e "s#EXPID:  .*#EXPID:  $output_dir/${inversion_constants[validation_case]}/GEOSChem#" -e "s#$output_dir/$case/GEOSChem.Restart.%y4%m2%d2_%h2%n2z.nc4#$output_dir/${inversion_constants[validation_case]}/GEOSChem.Restart.%y4%m2%d2_%h2%n2z.nc4#" HISTORY.rc
sed -i "s#DiagnPrefix:                 $output_dir/$case/HEMCO_diagnostics#DiagnPrefix:                 $output_dir/${inversion_constants[validation_case]}/HEMCO_diagnostics#" HEMCO_Config.rc

# change emissions
sed -i "s#base_emissions_tagged.nc#ems_posterior.nc#" HEMCO_Config.rc

# Get submission script
cd $geo_rundirs/${inversion_constants[validation_case]}
cp ${paths[root_code_dir]}/spinup/templates/gcclassic_submit.sh .
sed -i -e "s#%exe_path%#$geo_rundirs/${inversion_constants[validation_case]}#" -e "s/72:00:00/120:00:00/" gcclassic_submit.sh

# Compile
cd $geo_rundirs/${inversion_constants[validation_case]}/build
cmake ../CodeDir -DRUNDIR=..
cmake . -DRUNDIR=..
make -j
make install
