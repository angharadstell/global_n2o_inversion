library(ncdf4)

# used in sensitivities and perturbations
read_nc_file <- function(nc_file) {
  # return the variables in the netcdf
  base_nc <- ncdf4::nc_open(nc_file)
  v_base <- function(...) ncdf4::ncvar_get(base_nc, ...)
  v_base
}