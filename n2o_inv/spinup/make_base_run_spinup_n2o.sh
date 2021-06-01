#!/bin/bash




cd $geo_rundirs/$case


# edit species_database.yml
echo "editing species_database.yml"
# Is_photolysis is only used for diagnostics - don't need to add this to fake CH4
sed -i -e "s/MW_g: 16.05/MW_g: $mw_gas/g" -e "s/Background_VV: 1.8e-6/Background_VV: $background_conc/g" species_database.yml


# change strat loss to mine in HEMCO_Config.rc
echo "editing HEMCO_Config.rc"
sed -i "s#\* CH4_LOSS   \$ROOT/CH4/v2014-09/4x5/gmi.ch4loss.geos5_47L.4x5.nc     CH4loss      1985/1-12/1/0 C xyz s-1   \* - 1 1#\* CH4_LOSS   $loss_file    loss      2005/1-12/1/0 C xyz s-1   \* - 1 1#" HEMCO_Config.rc


# edit global_ch4_mod.F90
echo "editing global_ch4_mod.F90"
cd CodeDir/src/GEOS-Chem/GeosCore
# correct molecular weight
sed -i "s/16d-3/$mw_gas/g" global_ch4_mod.F90
# turn off tropospheric losses
sed -i "/    CALL CH4_DECAY( Input_Opt,  State_Chm, State_Diag, &/,+1 s/^/\!/" global_ch4_mod.F90

