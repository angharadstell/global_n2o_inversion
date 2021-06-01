#!/bin/bash


# Read in variables
source bash_var.sh

# Sort out tagged tracers to be regional transcom basis functions
source make_base_run_spinup_tagged.sh

# Change CH4 to N2O
cd $location_of_this_file
source make_base_run_spinup_n2o.sh


# Try to get CH4 collection to check losses
cd $geo_rundirs/$case
cp $geo_wrapper_dir/run/HISTORY.rc.templates/HISTORY.rc.CH4 ./HISTORY.rc
sed -i -e "s/{FREQUENCY}/00000100 000000/g" -e "s/{DURATION}/00000100 000000/g" HISTORY.rc


# streamline outputs
cd $output_dir
mkdir $case
mkdir $case/su_01
cd $geo_rundirs/$case
sed -i -e "s#EXPID:  ./OutputDir/GEOSChem#EXPID:  $output_dir/$case/su_01/GEOSChem#" -e "s#./GEOSChem.Restart.%y4%m2%d2_%h2%n2z.nc4#$output_dir/$case/su_01/GEOSChem.Restart.%y4%m2%d2_%h2%n2z.nc4#" HISTORY.rc
sed -i "s#DiagnPrefix:                 ./OutputDir/HEMCO_diagnostics#DiagnPrefix:                 $output_dir/$case/su_01/HEMCO_diagnostics#" HEMCO_Config.rc

# Match obs
sed -i -e "s#Turn on ObsPack diag?   : F#Turn on ObsPack diag?   : T#" -e "s#Quiet logfile output    : F#Quiet logfile output    : T#" -e "s#./obspack_co2_1_OCO2MIP_2018-11-28.YYYYMMDD.nc#$obspack_dir/obspack_n2o.YYYYMMDD.nc#" -e "s#./OutputDir/GEOSChem.ObsPack.YYYYMMDD_hhmmz.nc4#$output_dir/$case/su_01/GEOSChem.ObsPack.YYYYMMDD_hhmmz.nc4#" -e "s#ObsPack output species  : NO CO O3#ObsPack output species  : ?ADV?#" input.geos



# Compile
cd $geo_rundirs/$case/build
cmake ../CodeDir -DRUNDIR=..
cmake . -DRUNDIR=..
make -j
make install


# Get submission script
cd $geo_rundirs/$case
cp $location_of_this_file/templates/gcclassic_submit.sh .
sed -i -e "s#%exe_path%#$geo_rundirs/$case#" -e "s#GC.log#GC_su_01.log#" gcclassic_submit.sh

cp $location_of_this_file/bash_var.sh .
cat $location_of_this_file/spinup_repeat_met.sh >> gcclassic_submit.sh

./gcclassic --dryrun > log.dryrun
./download_data.py log.dryrun --cc
