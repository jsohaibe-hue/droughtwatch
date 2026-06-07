#' Morocco Climate Example Dataset
#'
#' Monthly climate data simulated for a semi-arid region of Morocco
#' (Béni Mellal-Khénifra area, approx. latitude 32°N), covering 24 years
#' (2000–2023). Includes a synthetic severe drought period (2012–2013).
#'
#' @format A data frame with 288 rows and 4 variables:
#' \describe{
#'   \item{date}{Date. First day of each month (Date class).}
#'   \item{precip}{Numeric. Monthly precipitation total (mm).}
#'   \item{temp}{Numeric. Mean monthly temperature (°C).}
#'   \item{eto}{Numeric. Reference evapotranspiration estimate (mm/month).}
#' }
#'
#' @details
#' Precipitation follows a Mediterranean seasonal regime with wet winters
#' (October–April) and dry summers (June–September). A severe drought is
#' embedded in 2012–2013 (precipitation reduced by 70%). The dataset is
#' intended for package examples and vignettes only — it is not real
#' observational data.
#'
#' @source Synthetically generated. See \code{data-raw/morocco_climate.R}.
#'
#' @examples
#' data(morocco_climate)
#' head(morocco_climate)
#' summary(morocco_climate)
#'
#' # Quick precipitation plot
#' plot(morocco_climate$date, morocco_climate$precip, type = "l",
#'      xlab = "Date", ylab = "Precipitation (mm)",
#'      main = "Morocco - Monthly Precipitation (2000-2023)")
"morocco_climate"
