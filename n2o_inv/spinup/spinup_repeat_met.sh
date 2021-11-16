# read in variables
source ../spinup/bash_var.sh

module load apps/nco-toolkit/4.9.2-gcc

for YEAR in $(eval echo "{1..$no_spinup_years}")
do
    # make output dir for next spinup year output
    cd $output_dir/$case
    mkdir su_$(printf '%02d' $((YEAR+1)))

    # copy last year's ic to run directory 
    cd $geo_rundirs/$case
    rm GEOSChem.Restart.${dates[spinup_start]//-}_0000z.nc4
    cp $output_dir/$case/su_$(printf '%02d' $YEAR)/GEOSChem.Restart.${dates[perturb_start]//-}_0000z.nc4 ./GEOSChem.Restart.${dates[spinup_start]//-}_0000z.nc4

    # change date in ic file
    ncatted -O -a units,time,o,c,"minutes since ${dates[spinup_start]} 00:00:00" GEOSChem.Restart.${dates[spinup_start]//-}_0000z.nc4

    # put output in diff output dir
    sed -i "s#su_$(printf '%02d' $YEAR)#su_$(printf '%02d' $((YEAR+1)))#" input.geos
    sed -i "s#su_$(printf '%02d' $YEAR)#su_$(printf '%02d' $((YEAR+1)))#" HISTORY.rc
    sed -i "s#su_$(printf '%02d' $YEAR)#su_$(printf '%02d' $((YEAR+1)))#" HEMCO_Config.rc

    # run again
    ./gcclassic >> GC_su_$(printf '%02d' $((YEAR+1))).log
   
done
