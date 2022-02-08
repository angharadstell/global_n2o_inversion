# global_n2o_inversion
This repository contains the code to reproduce the results in [PAPER LINK]. This paper uses the WOMBAT framework (https://arxiv.org/abs/2102.04004, https://github.com/mbertolacci/wombat-paper), which has been adapted to our use case. The primary differences between the inversion problem in the original version of WOMBAT and this work are:
1. This work solves for N<sub>2</sub>O fluxes rather than CO<sub>2</sub> fluxes
2. This work solves for 10 years of fluxes rather than 1.5 years
3. This work solely uses surface observations rather than satellite observations

These differences meant some changes to the WOMBAT package were required, namely:
1. Change molecular masses to N<sub>2</sub>O  from CO<sub>2</sub>
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
You have three options to try here:

1. [CONDA PACK]?!

2. I have tried to make an environment yaml file that you can just pass to conda:

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




3. If the above options don't work, follow the instructions in the "Installation/setting up an environment" section of https://github.com/mbertolacci/wombat-paper, with a few exceptions: 
    - I made my environment in my default conda location, but where you put it is up to you (you'll have to adapt the paths)
    - When installing the CRAN and local R packages, use the command in the environment.yml section above (includes the R packages I added)
    - Don't bother with the GEOSChem installation in the wombat-paper repo
    - I didn't install tensorflow (because I didn't use their correlated case)

    There will also be some missing packages, which you can attempt to figure out from environment.yml or just conda install as they come up.

## Getting data
- [CONDA PACK]
- GEOSChem output
- the rest of the files (e.g. intermediates, results, etc)

- emissions?
- obspack?
- other NOAA data?
- AGAGE data?

The location of these directories is specified in the config.ini file of this repo, you'll have to change the paths for your system. 


## Checking everything is working

from within the root directory "global_n2o_inversion", run these commands to check the unit tests:
```
pytest
```
```
Rscript -e "testthat::test_local()"
```

## Running GEOSChem
### Make emissions
1. Make your global emissions for 1970-2020 (run n2o_inv/emissions/combine_ems.py)
2. Split into regional basis functions (run n2o_inv/emissions/ems_tagged.py)
3. Create a series of perturbed emissions for the time period of interest (run n2o_inv/emissions/perturb_ems.py)

### Make observations
1. Format the AGAGE observations to look like obspack (run n2o_inv/obs/agage_obs.py)
2. Format all the obspack observations to be fed into GEOSChem (run n2o_inv/obs/format_obspack_geoschem.py)
3. Plot all the obs, checking for dodgy things (run n2o_inv/obs/plot_obs.py)
4. Remove dodgy things (run n2o_inv/plots/obs_baseline.py)

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

### Make model error runs
1. Create a new set of obspack files where each grid cell around a measurement is also included (model_err/adjust_obspack.py)
2. Set up the GEOSChem run (model_err/setup_model_err.sh)
3. Run the GEOSChem spinup (submit gcclassic_submit.sh in the GEOSChem rundir)
4. model_err/calc_model_err.py

## Running the inversion
Have to make intermediates for full 10 years before doing window inversion (uses intermediates to change ic)
### Make inversion intermediates
1. Make intermediates for the full 10 years (run intermediates/make_intermediates.sh)
2. Make intermediates for each of the windows (run moving_window/make_intermediates.sh)

### Do the inversion
1. Run the inversion for each window in turn (run moving_window/moving_window_inversion.sh)

### Plot the results
1. Plot the fluxes and compare posterior to the observations (run moving_window/plot_inversion_results.sh)
2. Plot the hyperparameters (run moving_window/plot_hyperparameters.R)

