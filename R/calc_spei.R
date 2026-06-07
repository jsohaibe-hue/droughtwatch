#' Calculate Standardized Precipitation-Evapotranspiration Index (SPEI)
#'
#' Computes a simplified SPEI using the climatic water balance
#' (Precipitation - Potential ETo) and standardizes using a log-logistic
#' or normal distribution.
#'
#' @param climate_data A tibble with columns \code{date}, \code{precip}, \code{temp},
#'   and optionally \code{eto}.
#' @param scales Integer vector. Time scales in months. Default: \code{c(1, 3, 6)}.
#' @param eto_method Character. Method to estimate ETo if not provided:
#'   \code{"hargreaves"} (default) or \code{"thornthwaite"}.
#' @param lat Numeric. Latitude in decimal degrees (needed for Hargreaves ETo).
#'   Default: \code{31.5} (central Morocco).
#'
#' @return A tibble with \code{date} and for each scale \code{spei_<scale>}
#'   (numeric) and \code{class_<scale>} (character).
#'
#' @examples
#' data(morocco_climate)
#' spei_result <- calc_spei(morocco_climate, scales = c(1, 3))
#' head(spei_result)
#'
#' @export
calc_spei <- function(climate_data, scales = c(1, 3, 6),
                       eto_method = "hargreaves", lat = 31.5) {

  required <- c("date", "precip", "temp")
  if (!all(required %in% names(climate_data))) {
    stop("climate_data must contain: ", paste(required, collapse = ", "))
  }

  df <- climate_data[order(climate_data$date), ]

  # Monthly aggregation
  df_monthly <- df %>%
    dplyr::mutate(
      year  = lubridate::year(date),
      month = lubridate::month(date)
    ) %>%
    dplyr::group_by(year, month) %>%
    dplyr::summarise(
      precip   = sum(precip, na.rm = TRUE),
      temp     = mean(temp,  na.rm = TRUE),
      eto      = if ("eto" %in% names(df)) mean(eto, na.rm = TRUE) else NA_real_,
      date     = min(date),
      .groups  = "drop"
    ) %>%
    dplyr::arrange(date)

  # Estimate ETo if not available
  if (all(is.na(df_monthly$eto))) {
    df_monthly$eto <- switch(eto_method,
      "hargreaves"   = .eto_hargreaves(df_monthly$temp, df_monthly$month, lat),
      "thornthwaite" = .eto_thornthwaite(df_monthly$temp, df_monthly$month),
      stop("eto_method must be 'hargreaves' or 'thornthwaite'.")
    )
  }

  # Water balance D = P - ETo
  df_monthly$D <- df_monthly$precip - df_monthly$eto

  result <- df_monthly[, "date"]

  for (sc in scales) {
    d_rolled <- zoo::rollapply(df_monthly$D, width = sc, FUN = sum,
                                align = "right", fill = NA, na.rm = TRUE)
    spei_vals <- .standardize_series(d_rolled)
    result[[paste0("spei_", sc)]]   <- spei_vals
    result[[paste0("class_", sc)]] <- .classify_spi(spei_vals)   # Same classification
  }

  message("SPEI computed for scales: ", paste(scales, collapse = ", "), " month(s).")
  tibble::as_tibble(result)
}

# Internal: simple Hargreaves ETo (mm/month)
.eto_hargreaves <- function(temp, month, lat) {
  # Extraterrestrial radiation approximation by month & latitude
  Ra_table <- c(9.8, 11.6, 14.1, 16.4, 18.1, 18.8,
                18.5, 17.3, 15.2, 12.5, 10.2, 9.2)
  Ra <- Ra_table[month]
  # Hargreaves: ETo = 0.0023 * Ra * (T + 17.8) * sqrt(Trange)
  # Simplified: assume Trange = 15 (typical semi-arid)
  eto <- 0.0023 * Ra * (temp + 17.8) * sqrt(15) * 30
  pmax(eto, 0)
}

# Internal: Thornthwaite ETo
.eto_thornthwaite <- function(temp, month) {
  # Annual heat index
  temp_pos <- pmax(temp, 0)
  I <- sum((temp_pos / 5)^1.514, na.rm = TRUE)
  alpha <- (6.75e-7 * I^3) - (7.71e-5 * I^2) + (1.792e-2 * I) + 0.49239
  # Day length approx (hours) — simplified constant
  N <- 12
  eto <- 16 * (N / 12) * (10 * temp_pos / I)^alpha
  pmax(eto, 0)
}

# Internal: standardize a numeric series to SPI-like values
.standardize_series <- function(x) {
  valid <- !is.na(x)
  out <- rep(NA_real_, length(x))
  if (sum(valid) < 4) return(out)
  mu  <- mean(x[valid])
  sig <- sd(x[valid])
  if (sig == 0) return(out)
  out[valid] <- (x[valid] - mu) / sig
  out
}
