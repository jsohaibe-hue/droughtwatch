#' Plot Drought Time Series
#'
#' Creates an interactive time series plot of SPI/SPEI values with drought
#' classification bands and threshold lines.
#'
#' @param index_data A tibble from \code{\link{calc_spi}} or \code{\link{calc_spei}}.
#' @param index_col Character. Column name to plot. Default: auto-detected.
#' @param interactive Logical. If \code{TRUE}, returns a plotly interactive plot.
#'   Default: \code{TRUE}.
#' @param title Character. Plot title. Default: auto-generated.
#' @param show_thresholds Logical. Show drought threshold lines. Default: \code{TRUE}.
#'
#' @return A ggplot2 or plotly object.
#'
#' @examples
#' data(morocco_climate)
#' spi <- calc_spi(morocco_climate, scales = 3)
#' plot_drought_timeseries(spi, index_col = "spi_3")
#'
#' @export
plot_drought_timeseries <- function(index_data, index_col = NULL,
                                     interactive = TRUE,
                                     title = NULL,
                                     show_thresholds = TRUE) {

  if (is.null(index_col)) {
    candidates <- grep("^(spi|spei)_", names(index_data), value = TRUE)
    if (length(candidates) == 0) stop("No SPI/SPEI column found.")
    index_col <- candidates[1]
  }

  df <- index_data[!is.na(index_data[[index_col]]), ]
  df$index_val <- df[[index_col]]
  df$condition <- ifelse(df$index_val >= 0, "Wet", "Dry")

  if (is.null(title)) title <- paste0("Drought Index: ", toupper(index_col))

  p <- ggplot2::ggplot(df, ggplot2::aes(x = date, y = index_val)) +
    ggplot2::geom_bar(
      ggplot2::aes(fill = condition),
      stat = "identity", width = 20
    ) +
    ggplot2::scale_fill_manual(
      values = c("Wet" = "#2196F3", "Dry" = "#FF5722"),
      name   = "Condition"
    ) +
    ggplot2::geom_line(color = "black", linewidth = 0.4, alpha = 0.6) +
    ggplot2::labs(
      title   = title,
      x       = "Date",
      y       = toupper(index_col),
      caption = "droughtwatch package"
    ) +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(
      plot.title  = ggplot2::element_text(face = "bold"),
      legend.position = "bottom"
    )

  if (show_thresholds) {
    p <- p +
      ggplot2::geom_hline(yintercept = -1.0, linetype = "dashed",
                           color = "orange", linewidth = 0.7) +
      ggplot2::geom_hline(yintercept = -1.5, linetype = "dashed",
                           color = "red",    linewidth = 0.7) +
      ggplot2::geom_hline(yintercept = -2.0, linetype = "dashed",
                           color = "darkred", linewidth = 0.9) +
      ggplot2::annotate("text", x = min(df$date), y = -1.05,
                        label = "Moderate", hjust = 0, size = 3, color = "orange") +
      ggplot2::annotate("text", x = min(df$date), y = -1.55,
                        label = "Severe", hjust = 0, size = 3, color = "red") +
      ggplot2::annotate("text", x = min(df$date), y = -2.05,
                        label = "Extreme", hjust = 0, size = 3, color = "darkred")
  }

  if (interactive) {
    if (!requireNamespace("plotly", quietly = TRUE)) {
      warning("plotly not installed. Returning static ggplot.")
      return(p)
    }
    return(plotly::ggplotly(p))
  }

  p
}


#' Plot Drought Map
#'
#' Creates a spatial map of drought conditions from a raster (SPI or VHI).
#'
#' @param raster_data SpatRaster. A single-layer raster of drought index values.
#' @param type Character. Type of raster: \code{"spi"}, \code{"vhi"}, or
#'   \code{"risk"}. Determines color scale. Default: \code{"vhi"}.
#' @param title Character. Map title. Default: auto-generated.
#' @param output_file Character or NULL. If provided, exports the map as PNG/PDF.
#'   Default: \code{NULL} (display only).
#' @param study_area sf or NULL. Optional boundary polygon to overlay.
#'
#' @return A ggplot2 plot object.
#'
#' @examples
#' ndvi <- download_ndvi("2020-06-01", "2020-06-30", source = "synthetic")
#' vhi  <- calc_vhi(ndvi[[1]])
#' plot_drought_map(vhi[[1]], type = "vhi", title = "VHI - June 2020")
#'
#' @export
plot_drought_map <- function(raster_data, type = "vhi", title = NULL,
                              output_file = NULL, study_area = NULL) {

  if (!inherits(raster_data, "SpatRaster")) {
    stop("raster_data must be a SpatRaster (terra package).")
  }

  # Convert to data frame for ggplot
  df_rast <- as.data.frame(terra::rast(raster_data[[1]]), xy = TRUE)
  names(df_rast)[3] <- "value"
  df_rast <- df_rast[!is.na(df_rast$value), ]

  if (is.null(title)) title <- paste0(toupper(type), " Drought Map")

  # Color scale by type
  col_scale <- switch(type,
    "spi"  = ggplot2::scale_fill_gradient2(
                low = "#8B0000", mid = "white", high = "#1565C0",
                midpoint = 0, name = "SPI"
              ),
    "vhi"  = ggplot2::scale_fill_gradientn(
                colors  = c("#8B0000", "#FF5722", "#FFC107", "#8BC34A", "#1B5E20"),
                values  = scales::rescale(c(0, 10, 20, 40, 100)),
                limits  = c(0, 100),
                name    = "VHI"
              ),
    "risk" = ggplot2::scale_fill_manual(
                values = c("High" = "#B71C1C", "Medium" = "#FF9800", "Low" = "#4CAF50"),
                name   = "Risk level"
              ),
    stop("type must be 'spi', 'vhi', or 'risk'.")
  )

  p <- ggplot2::ggplot(df_rast, ggplot2::aes(x = x, y = y, fill = value)) +
    ggplot2::geom_raster() +
    col_scale +
    ggplot2::coord_equal() +
    ggplot2::labs(title = title, x = "Longitude", y = "Latitude",
                  caption = "droughtwatch package") +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(plot.title = ggplot2::element_text(face = "bold"))

  # Overlay study area boundary if provided
  if (!is.null(study_area) && inherits(study_area, "sf")) {
    p <- p + ggplot2::geom_sf(data = study_area, fill = NA,
                               color = "black", linewidth = 0.8,
                               inherit.aes = FALSE)
  }

  # Export if needed
  if (!is.null(output_file)) {
    ext <- tolower(tools::file_ext(output_file))
    ggplot2::ggsave(output_file, plot = p, width = 8, height = 6,
                    device = if (ext == "pdf") "pdf" else "png", dpi = 300)
    message("Map exported to: ", output_file)
  }

  p
}
