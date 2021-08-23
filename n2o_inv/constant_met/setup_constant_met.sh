#!/bin/bash


# Read in variables
source /home/as16992/global_n2o_inversion/n2o_inv/spinup/bash_var.sh


# Create base run spinup folder
cd $geo_wrapper_dir/run
# For some reason, I can only get this to work with the wrong number of 1 commands?
printf "7\n1\n1\n1\n1\n1\n$geo_rundirs\n${inversion_constants[constant_case]}\nn\n" | ./createRunDir.sh

# copy running files from base
cp $geo_rundirs/$case/input.geos $geo_rundirs/${inversion_constants[constant_case]}/input.geos
cp $geo_rundirs/$case/HEMCO_Config.rc $geo_rundirs/${inversion_constants[constant_case]}/HEMCO_Config.rc
cp $geo_rundirs/$case/HEMCO_Diagn.rc $geo_rundirs/${inversion_constants[constant_case]}/HEMCO_Diagn.rc
cp $geo_rundirs/$case/HISTORY.rc $geo_rundirs/${inversion_constants[constant_case]}/HISTORY.rc
cp $geo_rundirs/$case/species_database.yml $geo_rundirs/${inversion_constants[constant_case]}/species_database.yml

# move in correct restart file
ln -s $output_dir/$case/GEOSChem.Restart.${dates[constant_end]//-}_0000z.nc4 $geo_rundirs/${inversion_constants[constant_case]}/GEOSChem.Restart.${dates[constant_start]//-}_0000z.nc4
cd $geo_rundirs/${inversion_constants[constant_case]}
ncatted -O -a units,time,o,c,"minutes since ${dates[constant_start]} 00:00:00" GEOSChem.Restart.${dates[constant_start]//-}_0000z.nc4

# Change date of simulation
cd $geo_rundirs/${inversion_constants[constant_case]}
sed -i -e "s/Start YYYYMMDD, hhmmss  : .*/Start YYYYMMDD, hhmmss  : ${dates[constant_start]//-} 000000/" -e "s/End   YYYYMMDD, hhmmss  : .*/End   YYYYMMDD, hhmmss  : ${dates[constant_end]//-} 000000/" input.geos



# need to sample from adjusted obspack
cd $geo_rundirs/${inversion_constants[constant_case]}
sed -i "s#obspack_n2o.YYYYMMDD.nc#${inversion_constants[constant_case]}/su_01/obspack_n2o.YYYYMMDD.nc#g" input.geos

# outdirs
# streamline outputs
cd $output_dir
mkdir ${inversion_constants[constant_case]}
mkdir ${inversion_constants[constant_case]}/su_01
cd $geo_rundirs/${inversion_constants[constant_case]}
sed -i "s#$output_dir/$case#$output_dir/${inversion_constants[constant_case]}/su_01#" input.geos
sed -i -e "s#EXPID:  .*#EXPID:  $output_dir/${inversion_constants[constant_case]}/su_01/GEOSChem#" -e "s#$output_dir/$case/GEOSChem.Restart.%y4%m2%d2_%h2%n2z.nc4#$output_dir/${inversion_constants[constant_case]}/su_01/GEOSChem.Restart.%y4%m2%d2_%h2%n2z.nc4#" HISTORY.rc
sed -i "s#DiagnPrefix:                 $output_dir/$case/HEMCO_diagnostics#DiagnPrefix:                 $output_dir/${inversion_constants[constant_case]}/su_01/HEMCO_diagnostics#" HEMCO_Config.rc



# Get submission script
cd $geo_rundirs/${inversion_constants[constant_case]}
cp $location_of_this_file/templates/gcclassic_submit.sh .
sed -i -e "s#%exe_path%#$geo_rundirs/${inversion_constants[constant_case]}#" -e "s#GC.log#GC_su_01.log#" -e "s/72:00:00/48:00:00/" gcclassic_submit.sh

cp $location_of_this_file/bash_var.sh .
# NEEEDS TO BE ADAPTED
cp $location_of_this_file/spinup_repeat_met.sh $geo_rundirs/${inversion_constants[constant_case]}/.
sed -i -e "s/no_spinup_years/{inversion_constants[no_constant_years]}/g" -e "s/case/{inversion_constants[constant_case]}/g" -e "s/perturb_start/constant_end/g" -e "s/spinup_start/constant_start/g" $geo_rundirs/${inversion_constants[constant_case]}/spinup_repeat_met.sh
cat $geo_rundirs/${inversion_constants[constant_case]}/spinup_repeat_met.sh >> gcclassic_submit.sh

# Compile
cd $geo_rundirs/${inversion_constants[constant_case]}/build
cmake ../CodeDir -DRUNDIR=..
cmake . -DRUNDIR=..
make -j
make install