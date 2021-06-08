
options(dplyr.summarise.inform = FALSE)

###############################################################################
# GLOBAL CONSTANTS
###############################################################################

fileloc <- (function() {
  attr(body(sys.function()), "srcfile")
})()$filename

config <- read.ini(paste0(gsub("n2o_inv/inversion.*", "", fileloc), "config.ini"))


intermediate_dir <- config$paths$geos_inte

###############################################################################
# EXECUTION
###############################################################################

log_info('Loading process model')
process_model <- readRDS(paste0(intermediate_dir, "/process-model.rds"))

log_info('Loading Transcom mask')
fn <- ncdf4::nc_open(config$inversion_constants$geo_transcom_mask)
v <- function(...) ncdf4::ncvar_get(fn, ...)
transcom_mask <- raster(nrows=72,
                        ncols=46,
                        vals=v('regions'))

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
    name = 'N polar (65 - 90)',
    expr = quote(type %in% c('land', 'ocean') & latitude > 65)
  ),
  list(
    name = 'N mid (23.5 - 65)',
    expr = quote(type %in% c('land', 'ocean') & between(latitude, 23.5, 65))
  ),
  list(
    name = 'N tropics (0 - 23.5)',
    expr = quote(type %in% c('land', 'ocean') & between(latitude, 0, 23.4))
  ),
  list(
    name = 'S tropics (-23.5 - 0)',
    expr = quote(type %in% c('land', 'ocean') & between(latitude, -23.5, 0))
  ),
  list(
    name = 'S mid (-65 - -23.5)',
    expr = quote(type %in% c('land', 'ocean') & between(latitude, -65, -23.5))
  ),
  list(
    name = 'S polar (-90 - -65)',
    expr = quote(type %in% c('land', 'ocean') & latitude < -65)
  ),
  list(
    name = 'N upper (45 - 90)',
    expr = quote(type %in% c('land', 'ocean') & latitude > 45)
  ),
  list(
    name = 'N lower (0 - 45)',
    expr = quote(type %in% c('land', 'ocean') & between(latitude, 0, 45))
  ),
  list(
    name = 'S upper (-45 - 0)',
    expr = quote(type %in% c('land', 'ocean') & between(latitude, -45, 0))
  ),
  list(
    name = 'S lower (-90 - -45)',
    expr = quote(type %in% c('land', 'ocean') & latitude < -45)
  ),
  list(
    name = 'N polar land (65 - 90)',
    expr = quote(type == 'land' & latitude > 65)
  ),
  list(
    name = 'N mid land (23.5 - 65)',
    expr = quote(type == 'land' & between(latitude, 23.5, 65))
  ),
  list(
    name = 'N tropics land (0 - 23.5)',
    expr = quote(type == 'land' & between(latitude, 0, 23.4))
  ),
  list(
    name = 'S tropics land (-23.5 - 0)',
    expr = quote(type == 'land' & between(latitude, -23.5, 0))
  ),
  list(
    name = 'S mid land (-65 - -23.5)',
    expr = quote(type == 'land' & between(latitude, -65, -23.5))
  ),
  list(
    name = 'S polar land (-90 - -65)',
    expr = quote(type == 'land' & latitude < -65)
  ),
  list(
    name = 'N polar oceans (65 - 90)',
    expr = quote(type == 'ocean' & latitude > 65)
  ),
  list(
    name = 'N mid oceans (23.5 - 65)',
    expr = quote(type == 'ocean' & between(latitude, 23.5, 65))
  ),
  list(
    name = 'N tropics oceans (0 - 23.5)',
    expr = quote(type == 'ocean' & between(latitude, 0, 23.4))
  ),
  list(
    name = 'S tropics oceans (-23.5 - 0)',
    expr = quote(type == 'ocean' & between(latitude, -23.5, 0))
  ),
  list(
    name = 'S mid oceans (-65 - -23.5)',
    expr = quote(type == 'ocean' & between(latitude, -65, -23.5))
  ),
  list(
    name = 'S polar oceans (-90 - -65)',
    expr = quote(type == 'ocean' & latitude < -65)
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
saveRDS(aggregators, paste0(intermediate_dir, "/flux-aggregators.rds"))

log_info('Done')
