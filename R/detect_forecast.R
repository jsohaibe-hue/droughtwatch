#' Detect Drought Episodes
#'
#' Identifies drought episodes in a time series using SPI/SPEI thresholds
#' and optionally NDVI anomalies. Returns a summary of each drought period
#' with alert levels.
#'
#' @param index_data A tibble returned by \code{\link{calc_spi}} or
#'   \code{\link{calc_spei}}, containing at least \code{date} and one
#'   index column (e.g., \code{spi_3}).
#' @param index_col Character. Name of the index column to use. Default: first
#'   column starting with \code{"spi_"} or \code{"spei_"}.
#' @param threshold Numeric. SPI/SPEI value below which drought is declared.
#'   Default: \code{-1.0} (moderate drought).
#' @param min_duration Integer. Minimum consecutive months to qualify as an
#'   episode. Default: \code{2}.
#'
#' @return A list with two elements:
#' \describe{
#'   \item{series}{Tibble with original series plus \code{drought} flag and
#'     \code{alert_level} column.}
#'   \item{episodes}{Tibble summarising each episode: start, end, duration,
#'     mean intensity, min index, and alert level.}
#' }
#'
#' @examples
#' data(morocco_climate)
#' spi  <- calc_spi(morocco_climate, scales = 3)
#' result <- detect_drought(spi, index_col = "spi_3")
#' result$episodes
#'
#' @export
detect_drought <- function(index_data, index_col = NULL,
                            threshold = -1.0, min_duration = 2) {

  # Auto-select index column
  if (is.null(index_col)) {
    candidates <- grep("^(spi|spei)_", names(index_data), value = TRUE)
    if (length(candidates) == 0) stop("No SPI/SPEI column found in index_data.")
    index_col <- candidates[1]
    message("Using index column: ", index_col)
  }

  if (!index_col %in% names(index_data)) {
    stop("Column '", index_col, "' not found in index_data.")
  }

  df <- index_data[order(index_data$date), ]
  idx <- df[[index_col]]

  # Flag drought months
  df$drought <- !is.na(idx) & idx <= threshold

  # Alert level
  df$alert_level <- dplyr::case_when(
    is.na(idx)   ~ "No data",
    idx <= -2.0  ~ "Extreme",
    idx <= -1.5  ~ "Severe",
    idx <= -1.0  ~ "Moderate",
    TRUE         ~ "None"
  )

  # Identify episodes (consecutive drought months)
  episodes <- list()
  in_episode <- FALSE
  ep_start <- NULL
  ep_idx   <- c()

  for (i in seq_len(nrow(df))) {
    if (df$drought[i]) {
      if (!in_episode) {
        in_episode <- TRUE
        ep_start <- df$date[i]
        ep_idx   <- idx[i]
      } else {
        ep_idx <- c(ep_idx, idx[i])
      }
    } else {
      if (in_episode) {
        duration <- length(ep_idx)
        if (duration >= min_duration) {
          episodes[[length(episodes) + 1]] <- tibble::tibble(
            start       = ep_start,
            end         = df$date[i - 1],
            duration_months = duration,
            mean_index  = mean(ep_idx, na.rm = TRUE),
            min_index   = min(ep_idx,  na.rm = TRUE),
            alert_level = dplyr::case_when(
              min(ep_idx) <= -2.0 ~ "Extreme",
              min(ep_idx) <= -1.5 ~ "Severe",
              TRUE                 ~ "Moderate"
            )
          )
        }
        in_episode <- FALSE
        ep_idx <- c()
      }
    }
  }

  # Close open episode at end of series
  if (in_episode && length(ep_idx) >= min_duration) {
    episodes[[length(episodes) + 1]] <- tibble::tibble(
      start           = ep_start,
      end             = df$date[nrow(df)],
      duration_months = length(ep_idx),
      mean_index      = mean(ep_idx, na.rm = TRUE),
      min_index       = min(ep_idx,  na.rm = TRUE),
      alert_level     = dplyr::case_when(
        min(ep_idx) <= -2.0 ~ "Extreme",
        min(ep_idx) <= -1.5 ~ "Severe",
        TRUE                 ~ "Moderate"
      )
    )
  }

  ep_df <- if (length(episodes) > 0) dplyr::bind_rows(episodes) else
    tibble::tibble(start = as.Date(NA), end = as.Date(NA),
                   duration_months = integer(0), mean_index = numeric(0),
                   min_index = numeric(0), alert_level = character(0))

  message(nrow(ep_df), " drought episode(s) detected (threshold = ", threshold, ").")
  list(series = tibble::as_tibble(df), episodes = ep_df)
}


#' Forecast Drought Conditions
#'
#' Generates short-term forecasts of SPI/SPEI using ARIMA or moving average.
#'
#' @param index_data A tibble with \code{date} and an index column.
#' @param index_col Character. Index column to forecast. Default: auto-detected.
#' @param method Character. Forecasting method: \code{"arima"} or
#'   \code{"moving_average"}. Default: \code{"arima"}.
#' @param horizon Integer. Forecast horizon in months. Default: \code{3}.
#' @param ma_window Integer. Window size for moving average. Default: \code{3}.
#'
#' @return A tibble with columns \code{date}, \code{forecast}, \code{lower_80},
#'   \code{upper_80} (confidence intervals, ARIMA only).
#'
#' @examples
#' data(morocco_climate)
#' spi    <- calc_spi(morocco_climate, scales = 3)
#' fc     <- forecast_drought(spi, index_col = "spi_3", horizon = 3)
#' fc
#'
#' @export
forecast_drought <- function(index_data, index_col = NULL,
                              method = "arima", horizon = 3,
                              ma_window = 3) {

  if (is.null(index_col)) {
    candidates <- grep("^(spi|spei)_", names(index_data), value = TRUE)
    if (length(candidates) == 0) stop("No SPI/SPEI column found.")
    index_col <- candidates[1]
  }

  df  <- index_data[order(index_data$date), ]
  idx <- df[[index_col]]
  idx <- idx[!is.na(idx)]

  last_date <- max(df$date[!is.na(df[[index_col]])])
  future_dates <- seq(last_date, by = "month", length.out = horizon + 1)[-1]

  if (method == "arima") {
    if (!requireNamespace("forecast", quietly = TRUE)) {
      stop("Package 'forecast' needed. Install with: install.packages('forecast')")
    }
    ts_obj <- stats::ts(idx, frequency = 12)
    fit    <- forecast::auto.arima(ts_obj, seasonal = TRUE)
    fc     <- forecast::forecast(fit, h = horizon, level = 80)

    result <- tibble::tibble(
      date      = future_dates,
      forecast  = as.numeric(fc$mean),
      lower_80  = as.numeric(fc$lower[, 1]),
      upper_80  = as.numeric(fc$upper[, 1]),
      method    = "ARIMA"
    )

  } else if (method == "moving_average") {
    ma_val <- mean(utils::tail(idx, ma_window), na.rm = TRUE)
    result <- tibble::tibble(
      date     = future_dates,
      forecast = rep(ma_val, horizon),
      lower_80 = rep(NA_real_, horizon),
      upper_80 = rep(NA_real_, horizon),
      method   = paste0("MA(", ma_window, ")")
    )

  } else {
    stop("method must be 'arima' or 'moving_average'.")
  }

  # Add drought classification
  result$class <- .classify_spi(result$forecast)

  message("Forecast for ", horizon, " month(s) using ", method, ".")
  result
}
