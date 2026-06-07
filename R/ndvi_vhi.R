#' Download NDVI Raster Data
#'
#' Downloads NDVI data from MODIS or uses a provided raster file.
#' For offline/example use, a synthetic NDVI raster can be generated.
#'
#' @param start_date Character or Date. Start date (YYYY-MM-DD).
#' @param end_date Character or Date. End date (YYYY-MM-DD).
#' @param region sf object or numeric vector \code{c(xmin, ymin, xmax, ymax)}.
#'   Bounding box for the study area.
#' @param source Character. Data source: \code{"modis"} or \code{"synthetic"}.
#'   Default: \code{"synthetic"} (for reproducible examples).
#' @param output_dir Character. Directory to save downloaded files.
#'   Default: \code{tempdir()}.
#'
#' @return A \code{SpatRaster} object (terra) with NDVI values (0 to 1).
#'
#' @examples
#' # Generate synthetic NDVI raster for Morocco region
#' ndvi <- download_ndvi(
#'   start_date = "2020-01-01",
#'   end_date   = "2020-12-31",
#'   region     = c(-6, 31, -4, 33),
#'   source     = "synthetic"
#' )
#' terra::plot(ndvi)
#'
#' @export
download_ndvi <- function(start_date, end_date,
                           region = c(-6, 31, -4, 33),
                           source = "synthetic",
                           output_dir = tempdir()) {

  start_date <- lubridate::as_date(start_date)
  end_date   <- lubridate::as_date(end_date)

  if (source == "synthetic") {
    message("Generating synthetic NDVI raster (source = 'synthetic').")
    ndvi_rast <- .generate_synthetic_ndvi(region, start_date, end_date)
    return(ndvi_rast)
  }

  if (source == "modis") {
    if (!requireNamespace("MODIStsp", quietly = TRUE)) {
      stop(
        "Package 'MODIStsp' is required for MODIS download.\n",
        "Install it with: install.packages('MODIStsp')\n",
        "Or use source = 'synthetic' for a demo raster."
      )
    }
    message("MODIS download via MODIStsp requires NASA Earthdata credentials.")
    message("See: https://lpdaac.usgs.gov/tools/modistsp/")
    stop("MODIS download not implemented in this version. Use source = 'synthetic'.")
  }

  stop("source must be 'modis' or 'synthetic'.")
}

# Internal: generate a synthetic NDVI raster
.generate_synthetic_ndvi <- function(region, start_date, end_date) {
  bbox <- if (is.numeric(region)) region else as.numeric(sf::st_bbox(region))

  # Create a simple raster
  r <- terra::rast(
    xmin = bbox[1], xmax = bbox[3],
    ymin = bbox[2], ymax = bbox[4],
    res  = 0.01,
    crs  = "EPSG:4326"
  )

  # Simulate seasonal NDVI variation
  set.seed(42)
  n_months <- as.integer(difftime(end_date, start_date, units = "days")) %/% 30 + 1
  n_months <- max(n_months, 1)

  layers <- lapply(seq_len(n_months), function(m) {
    base_ndvi <- 0.3 + 0.25 * sin(2 * pi * m / 12)
    vals <- rnorm(terra::ncell(r), mean = base_ndvi, sd = 0.08)
    vals <- pmin(pmax(vals, 0), 1)
    terra::setValues(r, vals)
  })

  ndvi_stack <- terra::rast(layers)
  dates <- seq(start_date, by = "month", length.out = n_months)
  names(ndvi_stack) <- as.character(dates)
  terra::time(ndvi_stack) <- dates

  ndvi_stack
}


#' Calculate Vegetation Health Index (VHI)
#'
#' Computes the Vegetation Health Index from NDVI, combining vegetation
#' condition (VCI) with an optional temperature component (TCI).
#'
#' @param ndvi SpatRaster. NDVI raster stack (values 0–1).
#' @param lst SpatRaster or NULL. Land Surface Temperature raster (optional).
#'   If \code{NULL}, VHI is computed from VCI only.
#' @param vhi_weight Numeric (0–1). Weight of VCI in VHI.
#'   VHI = vhi_weight * VCI + (1 - vhi_weight) * TCI. Default: \code{0.5}.
#'
#' @return A SpatRaster of VHI values (0–100) with classification attributes.
#'
#' @details
#' VHI classes:
#' \itemize{
#'   \item 0–10  : Extreme stress
#'   \item 10–20 : Severe stress
#'   \item 20–40 : Moderate stress
#'   \item 40–60 : Moderate health
#'   \item > 60  : Good health
#' }
#'
#' @examples
#' ndvi <- download_ndvi("2020-01-01", "2020-12-31", source = "synthetic")
#' vhi  <- calc_vhi(ndvi)
#' terra::plot(vhi)
#'
#' @export
calc_vhi <- function(ndvi, lst = NULL, vhi_weight = 0.5) {

  if (!inherits(ndvi, "SpatRaster")) {
    stop("ndvi must be a SpatRaster object (from terra package).")
  }

  # Compute VCI: (NDVI - NDVImin) / (NDVImax - NDVImin) * 100
  ndvi_min <- terra::app(ndvi, min, na.rm = TRUE)
  ndvi_max <- terra::app(ndvi, max, na.rm = TRUE)

  vci <- (ndvi - ndvi_min) / (ndvi_max - ndvi_min) * 100
  vci <- terra::clamp(vci, 0, 100)

  if (is.null(lst)) {
    message("No LST provided. VHI computed from VCI only.")
    vhi <- vci
  } else {
    if (!inherits(lst, "SpatRaster")) stop("lst must be a SpatRaster.")

    # TCI: (LSTmax - LST) / (LSTmax - LSTmin) * 100
    lst_min <- terra::app(lst, min, na.rm = TRUE)
    lst_max <- terra::app(lst, max, na.rm = TRUE)
    tci <- (lst_max - lst) / (lst_max - lst_min) * 100
    tci <- terra::clamp(tci, 0, 100)

    vhi <- vhi_weight * vci + (1 - vhi_weight) * tci
  }

  names(vhi) <- paste0("VHI_", names(ndvi))
  message("VHI computed. Values range 0 (severe stress) to 100 (good health).")
  vhi
}
