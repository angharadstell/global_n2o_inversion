source(Sys.getenv('INVERSION_BASE_PARTIAL'))
library(here)
library(ini)
library(Matrix)
library(WoodburyMatrix)

set.seed(20200706)

###############################################################################
# FUNCTIONS
###############################################################################

log_info_case <- function(str, ...) {
  log_info(paste0(
    sprintf('[%s] ', args$case),
    str
  ), ...)
}

###############################################################################
# EXECUTION
###############################################################################

args <- arg_parser('', hide.opts = TRUE) %>%
  add_argument('--case', '') %>%
  add_argument('--measurement-model', '') %>%
  add_argument('--process-model', '') %>%
  add_argument('--output', '') %>%
  parse_args()

log_info_case('Loading measurement model')
measurement_model <- readRDS(args$measurement_model)

log_info_case('Loading process model')
process_model <- readRDS(args$process_model)

log_info_case('Constructing case')
case_parts <- as.vector(stringr::str_split(
  args$case,
  '-',
  simplify = TRUE
))

measurement_model <- measurement_model %>%
  filter(overall_observation_mode %in% case_parts)


n_groups <- nlevels(measurement_model$attenuation_factor)

config <- read.ini(paste0(here(), "/config.ini"))
n_regions <- as.numeric(config$inversion_constants$no_regions) + 1
n_land_regions <- as.numeric(config$inversion_constants$no_land_regions)
n_ocean_regions <- n_regions - n_land_regions

if ('RHO0' %in% case_parts) {
  measurement_model[['rho']] <- rep(0, n_groups)
  measurement_model[['ell']] <- rep(1, n_groups)
}

if ('FIXEDA' %in% case_parts) {
  process_model[['a']] <- rep(0, n_regions)
}

if ('FIXEDAO' %in% case_parts) {
  process_model[['a']] <- c(rep(NA, n_land_regions), rep(0, n_ocean_regions))
}

if ('FIXEDW' %in% case_parts) {
  process_model[['w']] <- rep(4, n_regions)
}

if ('FIXEDWO5' %in% case_parts) {
  process_model[['w']] <- c(rep(NA, n_land_regions), rep(4, n_ocean_regions))
}

process_model$eta_prior_mean <- rep(0, ncol(process_model$Psi))
process_model$eta_prior_precision <- Diagonal(x = 1 / 25, n = ncol(process_model$Psi))

if ('NOBIAS' %in% case_parts) {
  measurement_model$A <- matrix(0, nrow = nrow(measurement_model$A), ncol = 0)
  measurement_model$beta_prior_mean <- rep(0, 0)
  measurement_model$beta_prior_precision <- Matrix::Diagonal(n = 0)
}

# HACK(mgnb): later code is configured to load these if missing
process_model$sensitivities <- NULL
process_model$H <- NULL

output <- list(process_model = process_model,
               measurement_model = measurement_model
              )

log_info_case('Saving')
saveRDS_gz1(output, args$output)

log_info_case('Done')
