# data-raw/morocco_climate.R
# Script to generate the example dataset included in the package

set.seed(2024)

# Simulate 20 years of monthly climate data for a semi-arid Moroccan region
# (Beni Mellal-Khenifra area, approx. lat 32°N)

dates <- seq(as.Date("2000-01-01"), as.Date("2023-12-01"), by = "month")
n     <- length(dates)
months <- as.integer(format(dates, "%m"))

# Precipitation: seasonal pattern (wet winters, dry summers)
precip_mean <- c(45, 40, 35, 28, 18, 5, 2, 3, 12, 28, 38, 48)[months]
precip_sd   <- precip_mean * 0.5 + 3
precip      <- pmax(rnorm(n, precip_mean, precip_sd), 0)

# Temperature: hot summers, mild winters
temp_mean <- c(9, 11, 14, 17, 22, 27, 31, 30, 25, 20, 14, 10)[months]
temp      <- rnorm(n, temp_mean, sd = 2)

# ETo (Penman-Monteith approx.)
eto_mean <- c(40, 50, 70, 90, 120, 160, 185, 170, 130, 90, 55, 40)[months]
eto      <- pmax(rnorm(n, eto_mean, sd = 10), 5)

# Introduce a severe drought period (2012-2013)
drought_idx <- which(dates >= as.Date("2012-05-01") & dates <= as.Date("2013-04-01"))
precip[drought_idx] <- precip[drought_idx] * 0.3
eto[drought_idx]    <- eto[drought_idx] * 1.15

morocco_climate <- data.frame(
  date   = dates,
  precip = round(precip, 1),
  temp   = round(temp, 1),
  eto    = round(eto, 1)
)

usethis::use_data(morocco_climate, overwrite = TRUE)

