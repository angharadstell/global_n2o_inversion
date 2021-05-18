# global_n2o_inversion

## How to run this code
### Make emissions
1. Make your global emissions for 1970-2020 (run n20_inv/emissions/combine_ems.py)
2. Split into regional basis functions (run n2o_inv/emissions/ems_tagged.py)
3. Create a series of perturbed emissions for the time period of interest (run n2o_inv/emissions/perturb_ems.py)

### Make initial conditions
1. Set up GEOSChem spinup for the bae run (run n2o_inv/spinup/configure_base_run_spinup.sh)
2. Run the GEOSChem spinup (submit gcclassic_submit.sh in the GEOSChem rundir)
