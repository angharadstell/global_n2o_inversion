# global_n2o_inversion

## How to run this code
### Make emissions
1. Make your global emissions for 1970-2020 (run n2o_inv/emissions/combine_ems.py)
2. Split into regional basis functions (run n2o_inv/emissions/ems_tagged.py)
3. Create a series of perturbed emissions for the time period of interest (run n2o_inv/emissions/perturb_ems.py)

### Make observations
1. Format the AGAGE observations to look like obspack (run n2o_inv/obs/agage_obs.py)
2. Format all the obspack observations to be fed into GEOSChem (run n2o_inv/obs/format_obspack_geoschem.py)

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


