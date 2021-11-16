#!/bin/bash


# Read in variables
source ../spinup/bash_var.sh


# Create base run spinup folder
cd $geo_wrapper_dir/run
# For some reason, I can only get this to work with the wrong number of 1 commands?
printf "7\n1\n1\n1\n1\n1\n$geo_rundirs\n${inversion_constants[model_err_case]}\nn\n" | ./createRunDir.sh

# copy running files from base
cp $geo_rundirs/$case/input.geos $geo_rundirs/${inversion_constants[model_err_case]}/input.geos
cp $geo_rundirs/$case/HEMCO_Config.rc $geo_rundirs/${inversion_constants[model_err_case]}/HEMCO_Config.rc
cp $geo_rundirs/$case/HEMCO_Diagn.rc $geo_rundirs/${inversion_constants[model_err_case]}/HEMCO_Diagn.rc
cp $geo_rundirs/$case/HISTORY.rc $geo_rundirs/${inversion_constants[model_err_case]}/HISTORY.rc
cp $geo_rundirs/$case/species_database.yml $geo_rundirs/${inversion_constants[model_err_case]}/species_database.yml

# move in correct restart file
ln -s $output_dir/$case/su_$(printf '%02d' $((no_spinup_years+1)))/GEOSChem.Restart.${dates[perturb_start]//-}_0000z.nc4 $geo_rundirs/${inversion_constants[model_err_case]}/GEOSChem.Restart.${dates[perturb_start]//-}_0000z.nc4

# Change date of simulation
cd $geo_rundirs/${inversion_constants[model_err_case]}
sed -i -e "s/Start YYYYMMDD, hhmmss  : .*/Start YYYYMMDD, hhmmss  : ${dates[perturb_start]//-} 000000/" -e "s/End   YYYYMMDD, hhmmss  : .*/End   YYYYMMDD, hhmmss  : ${dates[perturb_end]//-} 000000/" input.geos



# need to sample from adjusted obspack
cd $geo_rundirs/${inversion_constants[model_err_case]}
sed -i "s#obspack_n2o.YYYYMMDD.nc#${inversion_constants[model_err_case]}/obspack_n2o.YYYYMMDD.nc#g" input.geos

# outdirs
# streamline outputs
cd $output_dir
mkdir ${inversion_constants[model_err_case]}
cd $geo_rundirs/${inversion_constants[model_err_case]}
sed -i "s#$output_dir/$case#$output_dir/${inversion_constants[model_err_case]}#" input.geos
# doesnt accept the path like constant met did... no idea why, doesnt matter, dont need this bits anyway
sed -i -e "s#EXPID:  .*#EXPID:  ./GEOSChem#" -e "s#$output_dir/$case/GEOSChem.Restart.%y4%m2%d2_%h2%n2z.nc4#GEOSChem.Restart.%y4%m2%d2_%h2%n2z.nc4#" HISTORY.rc
sed -i "s#DiagnPrefix:                 $output_dir/$case/HEMCO_diagnostics#DiagnPrefix:                 $output_dir/${inversion_constants[model_err_case]}/HEMCO_diagnostics#" HEMCO_Config.rc



# Get submission script
cd $geo_rundirs/${inversion_constants[model_err_case]}
cp $location_of_this_file/templates/gcclassic_submit.sh .
sed -i "s#%exe_path%#$geo_rundirs/${inversion_constants[model_err_case]}#" gcclassic_submit.sh


# Compile
cd $geo_rundirs/${inversion_constants[model_err_case]}/build
cmake ../CodeDir -DRUNDIR=..
cmake . -DRUNDIR=..
make -j
make install