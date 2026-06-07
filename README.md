# droughtwatch <img src="man/figures/logo.png" align="right" height="120" alt="droughtwatch logo"/>

<!-- badges: start -->
[![R-CMD-check](https://github.com/SohaibJabrane/droughtwatch/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/SohaibJabrane/droughtwatch/actions/workflows/R-CMD-check.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

> **Agricultural Drought Monitoring and Early Warning System**

`droughtwatch` is a comprehensive R package for monitoring agricultural drought
conditions and generating early warning alerts. It computes standard drought
indices (SPI, SPEI, VHI), detects drought episodes, analyses vegetation health
using NDVI data, and produces automated bulletins and an interactive dashboard.

---

## Features

| Function | Description |
|---|---|
| `import_climate_data()` | Import CSV/Excel climate data with automatic date parsing |
| `calc_spi()` | Standardized Precipitation Index (scales: 1, 3, 6 months) |
| `calc_spei()` | Standardized Precipitation-Evapotranspiration Index |
| `download_ndvi()` | Download / generate NDVI raster data |
| `calc_vhi()` | Vegetation Health Index from NDVI |
| `detect_drought()` | Detect and classify drought episodes |
| `forecast_drought()` | Short-term forecast (ARIMA / moving average) |
| `analyze_frequency()` | Drought frequency, duration, intensity statistics |
| `generate_alerts()` | Automatic multi-level drought alerts |
| `plot_drought_timeseries()` | Interactive time series visualisation |
| `plot_drought_map()` | Spatial drought risk maps |
| `generate_monthly_bulletin()` | Automated HTML/PDF monthly bulletin |
| `shiny_dashboard()` | Interactive Shiny dashboard |

---

## Installation

```r
# Install from GitHub
# install.packages("devtools")
devtools::install_github("SohaibJabrane/droughtwatch")
```

---

## Quick Start

```r
library(droughtwatch)

# 1. Load example data
data(morocco_climate)

# 2. Compute SPI at 3-month scale
spi <- calc_spi(morocco_climate, scales = c(1, 3, 6))

# 3. Detect drought episodes
drought <- detect_drought(spi, index_col = "spi_3")
drought$episodes

# 4. Generate alerts
alerts <- generate_alerts(drought, region = "Beni Mellal-Khenifra")

# 5. Plot
plot_drought_timeseries(spi, index_col = "spi_3")

# 6. Launch dashboard
shiny_dashboard(data = morocco_climate)
```

---

## Example Outputs

### SPI Time Series
The time series plot shows monthly SPI values with drought classification
bands (moderate / severe / extreme).

```
Drought Index: SPI_3
------------------------------------------------------------
Date       | SPI  | Classification
-----------|------|---------------------------
2012-06-01 | -2.3 | Extremely dry   ⚠️ EXTREME
2012-07-01 | -2.1 | Extremely dry   ⚠️ EXTREME
2012-08-01 | -1.8 | Severely dry    🔴 SEVERE
```

### Drought Episodes Summary

```
Episodes detected: 4
┌─────────────┬─────────────┬──────────┬──────────────┬─────────────┐
│ Start       │ End         │ Duration │ Mean Index   │ Alert Level │
├─────────────┼─────────────┼──────────┼──────────────┼─────────────┤
│ 2012-05-01  │ 2013-04-01  │ 12 months│ -1.85        │ EXTREME     │
│ 2004-08-01  │ 2004-10-01  │ 3 months │ -1.12        │ MODERATE    │
└─────────────┴─────────────┴──────────┴──────────────┴─────────────┘
```

---

## Data Requirements

### Climate Data (CSV or Excel)

| Column | Description | Unit |
|---|---|---|
| `date` | Date (YYYY-MM-DD) | — |
| `precip` | Monthly precipitation | mm |
| `temp` | Mean temperature | °C |
| `eto` | Evapotranspiration (optional) | mm/month |

---

## SPI Classification (McKee et al., 1993)

| SPI value | Class |
|---|---|
| ≥ 2.0 | Extremely wet |
| 1.5 – 1.99 | Very wet |
| 1.0 – 1.49 | Moderately wet |
| −0.99 – 0.99 | Near normal |
| −1.0 – −1.49 | Moderately dry |
| −1.5 – −1.99 | Severely dry |
| ≤ −2.0 | Extremely dry |

---

## Package Structure

```
droughtwatch/
├── R/
│   ├── droughtwatch-package.R   # Package documentation
│   ├── import_climate_data.R    # Data import
│   ├── calc_spi.R               # SPI computation
│   ├── calc_spei.R              # SPEI computation
│   ├── ndvi_vhi.R               # NDVI download & VHI
│   ├── detect_forecast.R        # Episode detection & forecast
│   ├── analyze_alerts.R         # Frequency analysis & alerts
│   ├── plot_functions.R         # Visualisations
│   ├── bulletin.R               # Monthly bulletin
│   ├── shiny_dashboard.R        # Interactive dashboard
│   └── data.R                   # Dataset documentation
├── data/
│   └── morocco_climate.rda      # Example dataset
├── data-raw/
│   └── morocco_climate.R        # Dataset generation script
├── tests/
│   └── testthat/
│       └── test-droughtwatch.R  # Unit tests
├── vignettes/
│   └── introduction.Rmd         # Package vignette
├── DESCRIPTION
├── NAMESPACE
├── LICENSE
└── README.md
```

---

## References

- McKee et al. (1993). *Proceedings of the 8th Conference on Applied Climatology.*
- Vicente-Serrano et al. (2010). *Journal of Climate*, 23(7), 1696–1718.
- Kogan (1995). *Advances in Space Research*, 15(11), 91–100.

---

## Author

**Sohaib Jabrane**  
Programme 2CI IDSA — Statistiques & Informatique Appliquée  

> *Built with ❤️ for agricultural resilience in Morocco.*
