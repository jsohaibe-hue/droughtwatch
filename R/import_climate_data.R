#' Import Climate Data
#'
#' Imports climate data (precipitation, temperature, optional ETo) from
#' CSV or Excel files, handles date parsing and missing values.
#'
#' @param file Character. Path to the input file (CSV or Excel).
#' @param format Character. File format: \code{"csv"} or \code{"excel"}.
#'   If \code{NULL} (default), the format is inferred from the file extension.
#' @param date_col Character. Name of the date column. Default: \code{"date"}.
#' @param precip_col Character. Name of the precipitation column. Default: \code{"precip"}.
#' @param temp_col Character. Name of the temperature column. Default: \code{"temp"}.
#' @param eto_col Character or NULL. Name of the ETo column. Default: \code{NULL} (optional).
#' @param fill_missing Character. Method to fill missing values: \code{"interpolate"},
#'   \code{"mean"}, or \code{"none"}. Default: \code{"interpolate"}.
#' @param sheet Integer or character. For Excel files, the sheet to read. Default: \code{1}.
#'
#' @return A tibble with columns: \code{date} (Date), \code{precip} (numeric),
#'   \code{temp} (numeric), and optionally \code{eto} (numeric).
#'
#' @examples
#' # Using the built-in example dataset path
#' data_path <- system.file("extdata", "climate_example.csv", package = "droughtwatch")
#' if (file.exists(data_path)) {
#'   climate <- import_climate_data(data_path)
#'   head(climate)
#' }
#'
#' # Simulate data directly
#' climate <- import_climate_data(data = morocco_climate)
#' head(climate)
#'
#' @export
import_climate_data <- function(file = NULL,
                                 format = NULL,
                                 date_col = "date",
                                 precip_col = "precip",
                                 temp_col = "temp",
                                 eto_col = NULL,
                                 fill_missing = "interpolate",
                                 sheet = 1,
                                 data = NULL) {

  # Allow passing a dataframe directly (for testing / examples)
  if (!is.null(data)) {
    df <- data
  } else {
    if (is.null(file)) stop("Provide either 'file' or 'data'.")

    # Infer format from extension
    if (is.null(format)) {
      ext <- tolower(tools::file_ext(file))
      format <- if (ext %in% c("xlsx", "xls")) "excel" else "csv"
    }

    df <- if (format == "excel") {
      readxl::read_excel(file, sheet = sheet)
    } else {
      readr::read_csv(file, show_col_types = FALSE)
    }
  }

  # Rename columns to standard names
  col_map <- c(date_col, precip_col, temp_col)
  names(col_map) <- c("date", "precip", "temp")

  missing_cols <- setdiff(c(date_col, precip_col, temp_col), names(df))
  if (length(missing_cols) > 0) {
    stop("Missing columns in data: ", paste(missing_cols, collapse = ", "))
  }

  result <- df[, c(date_col, precip_col, temp_col), drop = FALSE]
  names(result) <- c("date", "precip", "temp")

  # Add ETo if provided
  if (!is.null(eto_col) && eto_col %in% names(df)) {
    result$eto <- df[[eto_col]]
  }

  # Parse dates
  result$date <- tryCatch(
    lubridate::as_date(result$date),
    error = function(e) stop("Cannot parse date column. Check date format.")
  )

  # Ensure numeric
  result$precip <- suppressWarnings(as.numeric(result$precip))
  result$temp   <- suppressWarnings(as.numeric(result$temp))

  # Handle missing values
  result <- switch(fill_missing,
    "interpolate" = {
      result$precip <- zoo::na.approx(result$precip, na.rm = FALSE)
      result$temp   <- zoo::na.approx(result$temp,   na.rm = FALSE)
      result
    },
    "mean" = {
      result$precip[is.na(result$precip)] <- mean(result$precip, na.rm = TRUE)
      result$temp[is.na(result$temp)]     <- mean(result$temp,   na.rm = TRUE)
      result
    },
    "none" = result,
    stop("fill_missing must be 'interpolate', 'mean', or 'none'.")
  )

  # Sort by date
  result <- result[order(result$date), ]

  n_missing <- sum(is.na(result$precip)) + sum(is.na(result$temp))
  if (n_missing > 0) {
    warning(n_missing, " missing values remain after filling.")
  }

  message("Climate data imported: ", nrow(result), " observations from ",
          min(result$date), " to ", max(result$date), ".")

  tibble::as_tibble(result)
}
