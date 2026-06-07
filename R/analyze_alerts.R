#' Analyze Drought Frequency Statistics
#'
#' Computes summary statistics on detected drought episodes: frequency,
#' mean duration, mean intensity, and seasonal distribution.
#'
#' @param drought_result List returned by \code{\link{detect_drought}}.
#' @param by Character. Grouping for seasonal analysis: \code{"month"},
#'   \code{"season"}, or \code{"year"}. Default: \code{"year"}.
#'
#' @return A list with:
#' \describe{
#'   \item{summary}{Overall statistics table.}
#'   \item{by_period}{Drought occurrence by the chosen time period.}
#'   \item{severity_table}{Count of episodes by alert level.}
#' }
#'
#' @examples
#' data(morocco_climate)
#' spi    <- calc_spi(morocco_climate, scales = 3)
#' dr     <- detect_drought(spi)
#' stats  <- analyze_frequency(dr)
#' stats$summary
#'
#' @export
analyze_frequency <- function(drought_result, by = "year") {

  if (!is.list(drought_result) || !all(c("series", "episodes") %in% names(drought_result))) {
    stop("drought_result must be the output of detect_drought().")
  }

  episodes <- drought_result$episodes
  series   <- drought_result$series

  if (nrow(episodes) == 0) {
    message("No drought episodes detected. Returning empty statistics.")
    return(list(
      summary       = tibble::tibble(),
      by_period     = tibble::tibble(),
      severity_table = tibble::tibble()
    ))
  }

  # Overall summary
  n_years  <- as.numeric(difftime(max(series$date), min(series$date), units = "days")) / 365.25
  summary_tbl <- tibble::tibble(
    total_episodes      = nrow(episodes),
    frequency_per_year  = round(nrow(episodes) / max(n_years, 1), 2),
    mean_duration_months = round(mean(episodes$duration_months), 1),
    median_duration     = median(episodes$duration_months),
    mean_intensity      = round(mean(episodes$mean_index), 3),
    min_intensity       = round(min(episodes$min_index), 3),
    record_start        = min(episodes$start),
    record_end          = max(episodes$end)
  )

  # By period
  series_copy <- series
  series_copy$drought_month <- series_copy$drought & !is.na(series_copy$drought)

  series_copy <- series_copy %>%
    dplyr::mutate(
      year   = lubridate::year(date),
      month  = lubridate::month(date),
      season = dplyr::case_when(
        month %in% c(12, 1, 2) ~ "Winter",
        month %in% c(3, 4, 5)  ~ "Spring",
        month %in% c(6, 7, 8)  ~ "Summer",
        TRUE                    ~ "Autumn"
      )
    )

  by_period <- switch(by,
    "year"   = series_copy %>%
                 dplyr::group_by(year) %>%
                 dplyr::summarise(drought_months = sum(drought_month, na.rm = TRUE),
                                   .groups = "drop"),
    "month"  = series_copy %>%
                 dplyr::group_by(month) %>%
                 dplyr::summarise(drought_months = sum(drought_month, na.rm = TRUE),
                                   .groups = "drop"),
    "season" = series_copy %>%
                 dplyr::group_by(season) %>%
                 dplyr::summarise(drought_months = sum(drought_month, na.rm = TRUE),
                                   .groups = "drop"),
    stop("by must be 'year', 'month', or 'season'.")
  )

  severity_table <- episodes %>%
    dplyr::count(alert_level, name = "count") %>%
    dplyr::arrange(dplyr::desc(count))

  list(
    summary        = summary_tbl,
    by_period      = by_period,
    severity_table = severity_table
  )
}


#' Generate Drought Alerts
#'
#' Generates a structured table of current and recent drought alerts based
#' on the latest index values and detected episodes.
#'
#' @param drought_result List returned by \code{\link{detect_drought}}.
#' @param index_col Character. Name of the index column in the series.
#'   Default: auto-detected.
#' @param thresholds Named numeric vector. Alert thresholds for each level.
#'   Default: \code{c(moderate = -1.0, severe = -1.5, extreme = -2.0)}.
#' @param region Character. Name of the region for the alert message.
#'   Default: \code{"Study area"}.
#'
#' @return A tibble with columns: \code{date}, \code{index_value},
#'   \code{alert_level}, \code{message}.
#'
#' @examples
#' data(morocco_climate)
#' spi  <- calc_spi(morocco_climate, scales = 3)
#' dr   <- detect_drought(spi)
#' alerts <- generate_alerts(dr, region = "Beni Mellal-Khenifra")
#' print(alerts)
#'
#' @export
generate_alerts <- function(drought_result,
                             index_col = NULL,
                             thresholds = c(moderate = -1.0, severe = -1.5, extreme = -2.0),
                             region = "Study area") {

  series <- drought_result$series

  if (is.null(index_col)) {
    candidates <- grep("^(spi|spei)_", names(series), value = TRUE)
    if (length(candidates) == 0) stop("No index column found in series.")
    index_col <- candidates[1]
  }

  alert_series <- series %>%
    dplyr::filter(!is.na(.data[[index_col]])) %>%
    dplyr::mutate(
      index_value = .data[[index_col]],
      alert_level = dplyr::case_when(
        index_value <= thresholds["extreme"]  ~ "EXTREME",
        index_value <= thresholds["severe"]   ~ "SEVERE",
        index_value <= thresholds["moderate"] ~ "MODERATE",
        TRUE                                   ~ "NONE"
      ),
      message = dplyr::case_when(
        alert_level == "EXTREME"  ~
          paste0("[", date, "] EXTREME DROUGHT in ", region,
                 ". Index = ", round(index_value, 2),
                 ". Immediate agricultural intervention required."),
        alert_level == "SEVERE"   ~
          paste0("[", date, "] SEVERE DROUGHT in ", region,
                 ". Index = ", round(index_value, 2),
                 ". Water resource management advised."),
        alert_level == "MODERATE" ~
          paste0("[", date, "] MODERATE DROUGHT in ", region,
                 ". Index = ", round(index_value, 2),
                 ". Monitor crop water stress."),
        TRUE ~
          paste0("[", date, "] Normal conditions in ", region,
                 ". Index = ", round(index_value, 2), ".")
      )
    ) %>%
    dplyr::select(date, index_value, alert_level, message)

  active_alerts <- alert_series %>%
    dplyr::filter(alert_level != "NONE")

  message(nrow(active_alerts), " alert(s) generated for ", region, ".")
  tibble::as_tibble(alert_series)
}
