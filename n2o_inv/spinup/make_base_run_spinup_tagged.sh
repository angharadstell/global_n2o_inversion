#!/bin/bash
# This script sorts out tagged tracers to be regional transcom basis functions

# Check git setup right
cd $geo_wrapper_dir/src/GEOS-Chem
git branch
git checkout -b n2o
git reset --hard HEAD


# Create base run spinup folder
cd $geo_wrapper_dir/run
# For some reason, I can only get this to work with the wrong number of 1 commands?
printf "7\n1\n1\n1\n1\n1\n$geo_rundirs\n$case\nn\n" | ./createRunDir.sh


#################
# Edit GEOSChem config/ input files

# Change date of simulation
cd $geo_rundirs/$case
sed -i -e "s/Start YYYYMMDD, hhmmss  : .*/Start YYYYMMDD, hhmmss  : ${dates[spinup_start]//-} 000000/" -e "s/End   YYYYMMDD, hhmmss  : .*/End   YYYYMMDD, hhmmss  : ${dates[perturb_start]//-} 000000/" input.geos

# Copy HEMCO_Config_template across
cp ${paths[root_code_dir]}/spinup/templates/HEMCO_Config_template.rc ./HEMCO_Config.rc

# Remove species names
sed -i '/Species name            : CH4.*/d' input.geos

sed -i '/EMIS_CH4_.* CH4    0.*/d' HEMCO_Diagn.rc
sed -i 's#molec/cm2/s#kg/m2/s#' HEMCO_Diagn.rc

## Add species names
for REGION in $(eval echo "{$no_regions..0}")
do
    # in input.geos
    sed -i "/^%%% ADVECTED SPECIES MENU %%%:/a Species name            : CH4_R$(printf '%02d' $REGION)" input.geos
    # in species_database.yml
    ems_frac=$(ncdump -v emi_R$(printf '%02d' $REGION) $ems_dir/ems_frac.nc |  grep "emi_R$(printf '%02d' $REGION) = " | sed -e "s/.*= //;s/ .*//")
    sed -i "/  FullName: Methane$/a CH4_R$(printf '%02d' $REGION):\n  << : *CH4properties\n  Background_VV: $ems_frac\n  FullName: Methane from TRANSCOM Region $REGION" species_database.yml
    # in HEMCO_Diagn.rc
    if [[ $REGION -lt 9 ]]
    then
        sed -i "/^EMIS_CH4_TOTAL/a EMIS_CH4_R$(printf '%02d' $REGION)         CH4    0      $((REGION+1))   -1   2   kg\/m2\/s" HEMCO_Diagn.rc
    else
        sed -i "/^EMIS_CH4_TOTAL/a EMIS_CH4_R$(printf '%02d' $REGION)         CH4    0      $((REGION+1))  -1   2   kg\/m2\/s" HEMCO_Diagn.rc
    fi
    # in HEMCO_Config.rc
    sed -i -e "/^(((STELL/a 0 STELL_CH4_R$(printf '%02d' $REGION)_T   $ems_dir/$ems_file emi_R$(printf '%02d' $REGION) 1970-2020/1-12/1/0 C xy kg/m2/s CH4_R$(printf '%02d' $REGION) - $((REGION+1)) 1" \
           -e "/^(((STELL/a 0 STELL_CH4_R$(printf '%02d' $REGION)     $ems_dir/$ems_file emi_R$(printf '%02d' $REGION) 1970-2020/1-12/1/0 C xy kg/m2/s CH4     - $((REGION+1)) 1"  HEMCO_Config.rc
done

# Add CH4 back to input.geos
sed -i "/^%%% ADVECTED SPECIES MENU %%%:/a Species name            : CH4" input.geos

#################
# Modify global_ch4_mod
cd $geo_rundirs/$case/CodeDir/src/GEOS-Chem/GeosCore
cp ${paths[root_code_dir]}/spinup/templates/global_ch4_mod_tagged_template.txt .

# delete print statements
sed -i "/^       WRITE(\*,\*) 'Oil          : ', SUM(CH4_EMIS(:,:,2))/,/^       WRITE(\*,\*) 'Soil absorb  : ', SUM(CH4_EMIS(:,:,15))/d" global_ch4_mod.F90
# delete default tracers
sed -i "/\!-------------------$/,/    Ptr2D => NULL()$/d" global_ch4_mod.F90
# remove subtraction of soil loss
sed -i "s/    CH4_EMIS(:,:,1) = SUM(CH4_EMIS, 3) - (2 \* CH4_EMIS(:,:,15))/    CH4_EMIS(:,:,1) = SUM(CH4_EMIS, 3)/" global_ch4_mod.F90 
# make CH4_EMIS array correct size
sed -i "s/ALLOCATE( CH4_EMIS( State_Grid%NX, State_Grid%NY, 15 ), STAT=RC )/ALLOCATE( CH4_EMIS( State_Grid%NX, State_Grid%NY, $((no_regions+2)) ), STAT=RC )/" global_ch4_mod.F90


for REGION in $(eval echo "{$no_regions..0}")
do
    sed -i "/       WRITE(\*,\*) 'Total        : ', SUM(CH4_EMIS(:,:,1))/a \ \ \ \ \ \ \ WRITE(\*,\*) 'R$(printf '%02d' $REGION)          : ', SUM(CH4_EMIS(:,:,$((REGION+2))))" global_ch4_mod.F90

    sed -i "/CH4_EMIS(:,:,:) = 0e+0_fp$/r global_ch4_mod_tagged_template.txt" global_ch4_mod.F90
    sed -i "s/%name%/R$(printf '%02d' $REGION)/g" global_ch4_mod.F90
    sed -i "s/%number%/$((REGION+2))/g" global_ch4_mod.F90
done

rm global_ch4_mod_tagged_template.txt

#################
# Modify hcoi_gc_diagn_mod
cp ${paths[root_code_dir]}/spinup/templates/hcoi_gc_diagn_mod_template.txt .

## delete old tracers
sed -i '/! %%%%% CH4 from /,+28d' hcoi_gc_diagn_mod.F90

for REGION in $(eval echo "{0..$no_regions}")
do
    sed -n -i -e "/END SUBROUTINE Diagn_CH4/r hcoi_gc_diagn_mod_template.txt" -e 1x -e '2,${x;p}' -e '${x;p}' hcoi_gc_diagn_mod.F90
    sed -i "s/%name%/CH4_R$(printf '%02d' $REGION)/g" hcoi_gc_diagn_mod.F90
    sed -i "s/%number%/$((REGION+1))/g" hcoi_gc_diagn_mod.F90
done

rm hcoi_gc_diagn_mod_template.txt
