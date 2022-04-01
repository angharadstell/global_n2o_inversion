# global_n2o_inversion
This repository contains the code to reproduce the results in [PAPER LINK]. This paper uses the WOMBAT framework (https://doi.org/10.5194/gmd-15-45-2022, https://github.com/mbertolacci/wombat-paper), which has been adapted to our use case. The primary differences between the inversion problem in the original version of WOMBAT and this work are:
1. This work solves for N<sub>2</sub>O fluxes rather than CO<sub>2</sub> fluxes
2. This work solves for 10 years of fluxes rather than 1.5 years
3. This work solely uses surface observations rather than satellite observations

These differences meant some changes to the WOMBAT package were required, namely:
1. Change molecular masses to N<sub>2</sub>O from CO<sub>2</sub>
2. A truncated normal distribution is used for the scaling factor to prevent negative fluxes over the TRANSCOM regions
The adapted N<sub>2</sub>O  repository can be found at https://github.com/angharadstell/wombat.

## Getting code
1. Clone this repo
2. Clone https://github.com/mbertolacci/wombat-paper (needed for fast sparse and a few random scripts I should move into mine)
3. Clone https://github.com/angharadstell/wombat
4. Clone [ACRG REPO] (annoying...)
5. If you want to run GEOSChem, you will have to install it, full instructions are available through the GEOSChem guide (https://geos-chem.seas.harvard.edu/). I used version 13.0.0.

The location of these directories is specified in the config.ini file of this repo, you'll have to change the paths for your system. 

## Setting up an environment
You have two options to try here:

1. I have tried to make an environment yaml file that you can just pass to conda:

    ```
    conda env create -f environment.yml
    ```

    This doesn't set the cran mirror (you might need to change the path to where you put the conda environment, and choose your preferred CRAN mirror):
    ```
    cat > ~/.conda/envs/wombat/lib/R/etc/Rprofile.site <<- EOF
    local({
    r <- getOption('repos')
    r['CRAN'] <- 'https://www.stats.bris.ac.uk/R/'
    options(repos = r)
    })
    EOF
    ```

    This also doesn't include the desired R packages from CRAN:
    ```
    Rscript -e "install.packages(c(
    'devtools', 'raster', 'argparser', 'codetools', 'ncdf4', 'fst', 'matrixStats',
    'readr', 'argparse', 'scoringRules', 'patchwork', 'lifecycle', 'sf',
    'ggplot2', 'dplyr', 'tidyr', 'RcppEigen', 'rnaturalearth',
    'rnaturalearthdata', 'rgeos', 'ini', 'here'
    ))"
    ```

    Or the local R packages:
    - cd into the "wombat-paper" directory where you cloned https://github.com/mbertolacci/wombat-paper
        ```
        Rscript -e "devtools::install('fastsparse')"
        ```
    - cd into the folder above where you cloned https://github.com/angharadstell/wombat
        ```
        Rscript -e "devtools::install('wombat')"
        ```




2. If the above options don't work, follow the instructions in the "Installation/setting up an environment" section of https://github.com/mbertolacci/wombat-paper, with a few exceptions: 
    - I made my environment in my default conda location, but where you put it is up to you (you'll have to adapt the paths)
    - When installing the CRAN and local R packages, use the command in the environment.yml section above (includes the R packages I added)
    - Don't bother with the GEOSChem installation in the wombat-paper repo
    - I didn't install tensorflow (because I didn't use their correlated case)

    There will also be some missing packages, which you can attempt to figure out from environment.yml or just conda install as they come up.

## Getting data
- The intermediates and results of this work is available at [OSF LINK]. This does not include: the emissions (except the intermediate used in the inversion), observations (except the intermediate used in the inversion), GEOSChem output, GEOSChem running directories, and pseudodata because this is a lage amount of data that is not required to reproduce the main results of the paper. This data is available if you contact me.
The following data is only needed if you want to recreate the geoschem runs:
- The emissions used can be downloaded from: EDGAR (https://edgar.jrc.ec.europa.eu/dataset_ghg50), Saikawa 2013 (either cotact the authors https://doi.org/10.1002/gbc.20087 or me), GFED (https://www.globalfiredata.org/data.html), Manizza 2012 (either contact the authors https://doi.org/10.3402/tellusb.v64i0.18429 or me)
- The obspacks used (obspack_multi-species_1_CCGGSurfaceFlask_v2.0_2021-02-09 and obspack_multi-species_1_CCGGAircraftFlask_v2.0_2021-02-09) can be downloaded from https://gml.noaa.gov/ccgg/obspack/data.php
- The obspack didn't include 2020 when I did this work, so I downloaded the separate NOAA N2O surface data from https://gml.noaa.gov/dv/data.html
- [AGAGE DATA]

The location of these directories is specified in the config.ini file of this repo (and in emissions/combine_ems.py for emissions - sorry), you'll have to change the paths for your system. 


## Checking everything is working

from within the root directory "global_n2o_inversion", run this commands to check the python unit tests:
```
pytest
```
from within the directory "global_n2o_inversion/tests/testthat", run this commands to check the R unit tests:
```
Rscript -e "testthat::test_local()"
```

If you have downloaded the intermediates/ results (see section above) and correctly changed the config.ini to have the correct paths, all the tests should pass.

## Getting started
A good place to start might be tutorials/wombat_intermediates.ipynb which goes through how I create all the WOMBAT intermediates from the GEOSChem runs. To run all of this tutorial, you will either need your own set of GEOSChem runs or contacted me to get my set. However, the tutorial intermediates are included in the easily downloadable intermediates/ results data, so you can still examine the intermediates. Even without the raw GEOSChem runs this is useful script to look at, because it contains descriptions of all the variables in the WOMBAT intermediates.



## Running GEOSChem
You won't be able to run any of this without the emissions / observations / raw GEOSChem output.
### Make emissions
1. Make your global emissions for 1970-2020 (run n2o_inv/emissions/combine_ems.py)
2. Split into regional basis functions (run n2o_inv/emissions/ems_tagged.py)
3. Create a series of perturbed emissions for the time period of interest (run n2o_inv/emissions/perturb_ems.py)
4. Work out the starting mole fractions for different regions based on the ratio of the emissions in the spinup (run n2o_inv/emissions/ems_ratio.py)

### Make observations
1. Format the AGAGE observations to look like obspack (run n2o_inv/obs/agage_obs.py)
2. Read in the 2020 NOAA data which isn't in the obspack (run n2o_inv/obs/noaa_2020_obs.py)
3. Format all the obspack observations to be fed into GEOSChem (run n2o_inv/obs/format_obspack_geoschem.py)
4. Plot all the obs, checking for dodgy things (run n2o_inv/obs/plot_obs.py)
5. Remove dodgy things (run n2o_inv/obs/obs_baseline.py)
6. Work out how to rescale AGAGE observations to match NOAA observations (run n2o_inv/obs/agage_noaa_ratio.py)

### Make initial conditions
1. Set up GEOSChem spinup for the base run (run n2o_inv/spinup/configure_base_run_spinup.sh)
2. Run the GEOSChem spinup (submit gcclassic_submit.sh in the GEOSChem rundir)
3. Check the output looks sensible (run n2o_inv/plots/plot_output.py for the spinup)

### Make base run
1. Convert the spinup to the base run (run n2o_inv/base_run/convert_spinup.sh)
2. Run the GEOSChem base run (submit gcclassic_submit.sh in the GEOSChem rundir)

### Make perturbed runs
1. Create the perturbed run directories (run n2o_inv/perturbed_runs/setup_perturbed.sh)
2. Run the GEOSChem perturbed runs (run n2o_inv/perturbed_runs/submit_perturbed.sh)
3. Check that all the perturbed runs finished successfully (run n2o_inv/perturbed_runs/check_success.sh)

### Make model error runs
1. Create a new set of obspack files where each grid cell around a measurement is also included (run model_err/adjust_obspack.py)
2. Set up the GEOSChem run (run model_err/setup_model_err.sh)
3. Run the GEOSChem spinup (submit gcclassic_submit.sh in the GEOSChem rundir)
4. Calculate the standard deviation of the grid cells around the measurements (run model_err/calc_model_err.py)



## Checking the inversion using pseudodata
You won't be able to run any of this without the emissions / observations / raw GEOSChem output.
Run analytical and WOMBAT inversions for the first window using pseudodata and compare the performance. It makes more sense to run this with the WOMBAT alpha truncation turned off to make it more comparable.
### Make pseudodata and do inversions
1. Creates the pseduo scaling factors, generates pseudo observations, and perform the WOMBAT inversions (run pseudodata/pseudodata_generate.sh)
2. Carry out analytical inversions for the pseudodata (run pseudodata/analytical_inversion.R)

### Compare the inversions
4. Compare how the analytical and WOMBAT inversions do (run pseudodata/analyse_mcmc_samples.R)



## Running the inversion
You won't be able to run any of the "Making inversion intermediates" without the emissions / observations / raw GEOSChem output.
Have to make intermediates for full 10 years before doing window inversion (uses intermediates to change ic)
### Make inversion intermediates
1. Make intermediates for the full 10 years (run intermediates/make_intermediates.sh)
2. Make intermediates for each of the windows (run moving_window/make_intermediates.sh)

### Do the inversion
1. Run the inversion for each window in turn (run moving_window/moving_window_inversion.sh)

### Check the inversion
1. Check the control_mf is being adjusted correctly (run moving_window/check_change_control_mf.R)
2. Do a moving window analytical inversion (run moving_window/moving_window_inversion.sh)
3. Check the moving window inversion is working adequately (run moving_window/compare_to_full_analytical.R)

### Plot the results
1. Plot the fluxes and compare posterior to the observations (run moving_window/plot_inversion_results.sh)
2. Plot the hyperparameters (run moving_window/plot_hyperparameters.R)



## Compare moving window inversion to analytical inversion
You can check the performance of the moving window inversion, vs the whole time series, by: 
1. Running the moving window inversion analytically (set the method in moving_window/moving_window_inversion.sh to "analytical")
2. Comparing to the whole time series analytical inversion (set the method in moving_window/compare_to_full_analytical.R to "analytical")

You can compare the WOMBAT moving window inversion to the whole time series analytical inversion by:
1. Compare the two sets of alphas (run moving_window/compare_to_full_analytical.R)
2. Plot the analytical results like the WOMBAT moving window (run moving_window/plot_analytical_results.sh)



## Looking at the effect of rescaling the prior
Have to make intermediates for the first window inversion to do this (uses intermediates to rescale)
### Make intermediates
1. Make rescaled intermediates(run scaled_prior/rescale_prior.R)

### Do the inversion
1. Run the inversion for the rescaled cases (run scaled_prior/rescale_prior_inversion.sh)



## Validation of inversion results
You won't be able to run any of this without the emissions / observations / raw GEOSChem output.
1. Extract alphas from inversion (run validation/extract_alphas.R)
2. Make optimised emissions (run validation/make_ems.py)
3. Create the validation run files (run validation/setup_validation.sh)
4. Run the GEOSChem spinup (submit gcclassic_submit.sh in the GEOSChem rundir)
5. Plot and analyse (run validation/validating.py)
