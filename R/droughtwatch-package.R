#' droughtwatch: Agricultural Drought Monitoring and Early Warning System
#'
#' A comprehensive R package for monitoring agricultural drought and generating
#' early warning alerts. It provides tools to calculate standard drought indices
#' (SPI, SPEI, VHI), analyze NDVI vegetation data, detect drought episodes,
#' produce risk maps, and generate automated monthly bulletins.
#'
#' @section Main functions:
#' \itemize{
#'   \item \code{\link{import_climate_data}} - Import climate data (CSV/Excel)
#'   \item \code{\link{calc_spi}} - Calculate Standardized Precipitation Index
#'   \item \code{\link{calc_spei}} - Calculate Standardized Precipitation-Evapotranspiration Index
#'   \item \code{\link{download_ndvi}} - Download NDVI raster data
#'   \item \code{\link{calc_vhi}} - Calculate Vegetation Health Index
#'   \item \code{\link{detect_drought}} - Detect drought episodes
#'   \item \code{\link{forecast_drought}} - Forecast future drought conditions
#'   \item \code{\link{analyze_frequency}} - Analyze drought frequency statistics
#'   \item \code{\link{generate_alerts}} - Generate automatic drought alerts
#'   \item \code{\link{plot_drought_timeseries}} - Plot drought time series
#'   \item \code{\link{plot_drought_map}} - Map drought spatial distribution
#'   \item \code{\link{generate_monthly_bulletin}} - Generate monthly HTML/PDF bulletin
#'   \item \code{\link{shiny_dashboard}} - Launch interactive Shiny dashboard
#' }
#'
#' @docType package
#' @name droughtwatch
"_PACKAGE"

## usethis namespace: start
#' @importFrom dplyr filter mutate select arrange group_by summarise left_join %>%
#' @importFrom ggplot2 ggplot aes geom_line geom_bar geom_ribbon scale_fill_manual
#'   scale_color_manual labs theme theme_minimal element_text geom_hline
#' @importFrom lubridate year month ymd as_date
#' @importFrom readr read_csv
#' @importFrom readxl read_excel
#' @importFrom tidyr pivot_longer pivot_wider
#' @importFrom zoo rollapply na.approx
#' @importFrom stats qnorm pnorm sd median arima predict
#' @importFrom tibble tibble as_tibble
## usethis namespace: end
NULL
