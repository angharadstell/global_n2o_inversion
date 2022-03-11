library(dplyr)
library(ini)
library(logger)
library(raster)
library(ncdf4)

options(dplyr.summarise.inform = FALSE)

###############################################################################
# FUNCTIONS
###############################################################################

process_transcom_regions <- function(transcome_mask_file) {
  log_info('Loading Transcom mask')
  transcom_mask <- raster(transcome_mask_file, stopIfNotEqualSpaced = FALSE)

}

###############################################################################
# EXECUTION
###############################################################################

main <- function() {
  source(Sys.getenv('INVERSION_BASE_PARTIAL'))

  args <- arg_parser('', hide.opts = TRUE) %>%
    add_argument('--process-model', '') %>%
    add_argument('--transcom-mask', '') %>%
    add_argument('--output', '') %>%
    parse_args()

  #############################################################################

  log_info('Loading process model')
  process_model <- readRDS(args$process_model)

  # process transcom regions
  transcom_mask <- process_transcom_regions(args$transcom_mask)

  log_info('Calculating')
  process_model$control_emissions <- process_model$control_emissions %>%
    mutate(
      transcom_region = extract(transcom_mask, cbind(longitude, latitude))
    ) %>%
    mutate(
      transcom_region = if_else(is.na(transcom_region), 0, transcom_region)
    )

  emission_groups <- c(list(
    list(
      name = 'Global',
      expr = quote(type %in% c('land', 'ocean') & latitude > -Inf)
    ),
    list(
      name = 'Global land',
      expr = quote(type == 'land')
    ),
    list(
      name = 'Global oceans',
      expr = quote(type == 'ocean')
    ),
    list(
      name = 'N extratropics (23.5 - 90)',
      expr = quote(type %in% c('land', 'ocean') & latitude > 23.5)
    ),
    list(
      name = 'S extratropics (-90 - -23.5)',
      expr = quote(type %in% c('land', 'ocean') & latitude < -23.5)
    ),
    list(
      name = 'N tropics (0 - 23.5)',
      expr = quote(type %in% c('land', 'ocean') & between(latitude, 0, 23.5))
    ),
    list(
      name = 'S tropics (-23.5 - 0)',
      expr = quote(type %in% c('land', 'ocean') & between(latitude, -23.5, 0))
    ),
    list(
      name = 'N extratropics (30 - 90)',
      expr = quote(type %in% c('land', 'ocean') & latitude > 30)
    ),
    list(
      name = 'S extratropics (-90 - -30)',
      expr = quote(type %in% c('land', 'ocean') & latitude < -30)
    ),
    list(
      name = 'N tropics (0 - 30)',
      expr = quote(type %in% c('land', 'ocean') & between(latitude, 0, 30))
    ),
    list(
      name = 'S tropics (-30 - 0)',
      expr = quote(type %in% c('land', 'ocean') & between(latitude, -30, 0))
    )
  ), lapply(process_model$regions, function(region) {
    list(
      name = sprintf('T%02d', region),
      expr = parse(text = sprintf("type %%in%% c('land', 'ocean') & transcom_region == %d", region))[[1]]
    )
  }))

  log_debug('Computing aggregators')
  aggregators <- lapply(emission_groups, function(emission_group) {
    log_trace('Processing {emission_group$name}')
    emission_group$aggregator <- flux_aggregator(
      process_model,
      !! emission_group$expr
    )
    emission_group
  })

  log_info('Saving')
  saveRDS(aggregators, args$output)

  log_info('Done')
}

if (getOption('run.main', default=TRUE)) {
   main()
}
