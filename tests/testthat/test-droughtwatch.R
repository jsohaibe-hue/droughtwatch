library(testthat)
library(droughtwatch)

# ---- Helper: build a minimal climate tibble ----
make_climate <- function(n_months = 60) {
  set.seed(42)
  dates   <- seq(as.Date("2000-01-01"), by = "month", length.out = n_months)
  months  <- as.integer(format(dates, "%m"))
  precip  <- pmax(rnorm(n_months,
                        c(45,40,35,28,18,5,2,3,12,28,38,48)[months],
                        sd = 10), 0)
  temp    <- rnorm(n_months,
                   c(9,11,14,17,22,27,31,30,25,20,14,10)[months], sd = 2)
  eto     <- pmax(rnorm(n_months,
                        c(40,50,70,90,120,160,185,170,130,90,55,40)[months],
                        sd = 10), 5)
  data.frame(date = dates, precip = round(precip, 1),
             temp = round(temp, 1), eto = round(eto, 1))
}

# ===========================================================
# TEST: import_climate_data
# ===========================================================
test_that("import_climate_data works with a data frame", {
  df  <- make_climate()
  out <- import_climate_data(data = df)
  expect_s3_class(out, "tbl_df")
  expect_true(all(c("date", "precip", "temp") %in% names(out)))
  expect_s3_class(out$date, "Date")
  expect_type(out$precip, "double")
  expect_type(out$temp,   "double")
})

test_that("import_climate_data errors on missing columns", {
  bad_df <- data.frame(date = Sys.Date(), x = 1)
  expect_error(import_climate_data(data = bad_df), "Missing columns")
})

test_that("import_climate_data handles fill_missing options", {
  df           <- make_climate(24)
  df$precip[3] <- NA
  out_interp   <- import_climate_data(data = df, fill_missing = "interpolate")
  expect_false(any(is.na(out_interp$precip)))

  out_mean <- import_climate_data(data = df, fill_missing = "mean")
  expect_false(any(is.na(out_mean$precip)))
})

# ===========================================================
# TEST: calc_spi
# ===========================================================
test_that("calc_spi returns correct structure", {
  climate <- import_climate_data(data = make_climate(72))
  spi     <- calc_spi(climate, scales = c(1, 3))

  expect_s3_class(spi, "tbl_df")
  expect_true("spi_1"   %in% names(spi))
  expect_true("spi_3"   %in% names(spi))
  expect_true("class_1" %in% names(spi))
  expect_true("class_3" %in% names(spi))
})

test_that("calc_spi values are roughly standardised", {
  climate <- import_climate_data(data = make_climate(120))
  spi     <- calc_spi(climate, scales = 3)
  vals    <- spi$spi_3[!is.na(spi$spi_3)]
  expect_lt(abs(mean(vals)), 0.5)   # approx zero mean
  expect_lt(abs(sd(vals) - 1), 0.5) # approx unit variance
})

test_that("calc_spi errors without precip column", {
  bad <- data.frame(date = Sys.Date(), temp = 20)
  expect_error(calc_spi(bad), "precip")
})

# ===========================================================
# TEST: calc_spei
# ===========================================================
test_that("calc_spei returns spei columns", {
  climate <- import_climate_data(data = make_climate(72))
  spei    <- calc_spei(climate, scales = c(1, 3))
  expect_true("spei_1" %in% names(spei))
  expect_true("spei_3" %in% names(spei))
})

# ===========================================================
# TEST: detect_drought
# ===========================================================
test_that("detect_drought returns list with series and episodes", {
  climate <- import_climate_data(data = make_climate(120))
  spi     <- calc_spi(climate, scales = 3)
  result  <- detect_drought(spi, index_col = "spi_3")

  expect_type(result, "list")
  expect_true(all(c("series", "episodes") %in% names(result)))
  expect_s3_class(result$series,   "tbl_df")
  expect_s3_class(result$episodes, "tbl_df")
})

test_that("detect_drought flags drought months correctly", {
  climate <- import_climate_data(data = make_climate(120))
  spi     <- calc_spi(climate, scales = 3)
  result  <- detect_drought(spi, threshold = -1.0)
  drought_rows <- result$series[result$series$drought == TRUE, ]
  idx_col <- "spi_3"
  if (idx_col %in% names(result$series) && nrow(drought_rows) > 0) {
    expect_true(all(drought_rows[[idx_col]] <= -1.0, na.rm = TRUE))
  }
})

# ===========================================================
# TEST: forecast_drought
# ===========================================================
test_that("forecast_drought returns correct horizon", {
  climate <- import_climate_data(data = make_climate(120))
  spi     <- calc_spi(climate, scales = 3)
  fc      <- forecast_drought(spi, index_col = "spi_3",
                               method = "moving_average", horizon = 3)
  expect_equal(nrow(fc), 3)
  expect_true("forecast" %in% names(fc))
})

# ===========================================================
# TEST: analyze_frequency
# ===========================================================
test_that("analyze_frequency returns valid summary", {
  climate <- import_climate_data(data = make_climate(120))
  spi     <- calc_spi(climate, scales = 3)
  dr      <- detect_drought(spi)
  stats   <- analyze_frequency(dr)

  expect_type(stats, "list")
  expect_true(all(c("summary", "by_period", "severity_table") %in% names(stats)))
})

# ===========================================================
# TEST: generate_alerts
# ===========================================================
test_that("generate_alerts returns message column", {
  climate <- import_climate_data(data = make_climate(120))
  spi     <- calc_spi(climate, scales = 3)
  dr      <- detect_drought(spi)
  alerts  <- generate_alerts(dr, region = "Test Region")

  expect_s3_class(alerts, "tbl_df")
  expect_true("message"     %in% names(alerts))
  expect_true("alert_level" %in% names(alerts))
})

# ===========================================================
# TEST: download_ndvi (synthetic only)
# ===========================================================
test_that("download_ndvi synthetic returns SpatRaster", {
  skip_if_not_installed("terra")
  ndvi <- download_ndvi("2020-01-01", "2020-03-01",
                         region = c(-6, 31, -4, 33), source = "synthetic")
  expect_s4_class(ndvi, "SpatRaster")
  expect_gte(terra::nlyr(ndvi), 1)
})

# ===========================================================
# TEST: plot_drought_timeseries
# ===========================================================
test_that("plot_drought_timeseries returns a plot", {
  climate <- import_climate_data(data = make_climate(72))
  spi     <- calc_spi(climate, scales = 3)
  p       <- plot_drought_timeseries(spi, interactive = FALSE)
  expect_s3_class(p, "ggplot")
})
