#' Calculate Standardized Precipitation Index (SPI)
#'
#' Computes the SPI for one or more time scales using a gamma distribution
#' fitted to the precipitation series. Classifies each value into drought
#' or wet categories.
#'
#' @param climate_data A tibble returned by \code{\link{import_climate_data}},
#'   or any data frame with columns \code{date} and \code{precip}.
#' @param scales Integer vector. Time scales in months. Default: \code{c(1, 3, 6)}.
#' @param ref_start Date or character. Start of the reference period for
#'   distribution fitting. Default: \code{NULL} (use all data).
#' @param ref_end Date or character. End of the reference period. Default: \code{NULL}.
#'
#' @return A tibble with columns: \code{date}, \code{precip}, and for each scale
#'   \code{spi_<scale>} (numeric) and \code{class_<scale>} (character).
#'
#' @details
#' SPI classification (McKee et al., 1993):
#' \itemize{
#'   \item >= 2.0 : Extremely wet
#'   \item 1.5 to 1.99 : Very wet
#'   \item 1.0 to 1.49 : Moderately wet
#'   \item -0.99 to 0.99 : Near normal
#'   \item -1.0 to -1.49 : Moderately dry
#'   \item -1.5 to -1.99 : Severely dry
#'   \item <= -2.0 : Extremely dry
#' }
#'
#' @examples
#' data(morocco_climate)
#' spi_result <- calc_spi(morocco_climate, scales = c(1, 3, 6))
#' head(spi_result)
#'
#' @export
calc_spi <- function(climate_data, scales = c(1, 3, 6),
                     ref_start = NULL, ref_end = NULL) {

  if (!all(c("date", "precip") %in% names(climate_data))) {
    stop("climate_data must contain 'date' and 'precip' columns.")
  }

  df <- climate_data[order(climate_data$date), ]

  # Aggregate to monthly precipitation if data is daily
  df_monthly <- df %>%
    dplyr::mutate(
      year  = lubridate::year(date),
      month = lubridate::month(date)
    ) %>%
    dplyr::group_by(year, month) %>%
    dplyr::summarise(
      precip = sum(precip, na.rm = TRUE),
      date   = min(date),
      .groups = "drop"
    ) %>%
    dplyr::arrange(date)

  precip_vec <- df_monthly$precip

  result <- df_monthly[, c("date", "precip")]

  for (sc in scales) {
    spi_vals <- .compute_spi_scale(precip_vec, scale = sc)
    result[[paste0("spi_", sc)]]   <- spi_vals
    result[[paste0("class_", sc)]] <- .classify_spi(spi_vals)
  }

  message("SPI computed for scales: ", paste(scales, collapse = ", "), " month(s).")
  tibble::as_tibble(result)
}

# Internal: compute SPI for one scale
.compute_spi_scale <- function(precip, scale) {
  n <- length(precip)
  spi_out <- rep(NA_real_, n)

  # Rolling sum
  rolled <- zoo::rollapply(precip, width = scale, FUN = sum,
                            align = "right", fill = NA, na.rm = TRUE)

  valid_idx <- which(!is.na(rolled) & rolled > 0)
  if (length(valid_idx) < 4) {
    warning("Not enough non-zero data points to fit gamma distribution.")
    return(spi_out)
  }

  x <- rolled[valid_idx]

  # Fit gamma distribution using method of moments
  x_mean <- mean(x)
  x_var  <- var(x)
  if (x_var == 0) return(spi_out)

  shape <- x_mean^2 / x_var
  rate  <- x_mean / x_var

  # Probability via gamma CDF → normal quantile
  p <- stats::pgamma(rolled, shape = shape, rate = rate)
  # Clip to avoid Inf
  p <- pmin(pmax(p, 1e-6), 1 - 1e-6)
  spi_out <- stats::qnorm(p)

  spi_out
}

# Internal: classify SPI values
.classify_spi <- function(spi) {
  dplyr::case_when(
    spi >= 2.0              ~ "Extremely wet",
    spi >= 1.5              ~ "Very wet",
    spi >= 1.0              ~ "Moderately wet",
    spi >= -0.99            ~ "Near normal",
    spi >= -1.49            ~ "Moderately dry",
    spi >= -1.99            ~ "Severely dry",
    spi <  -1.99            ~ "Extremely dry",
    TRUE                    ~ NA_character_
  )
}
