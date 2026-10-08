# Infant Mortality and Household Wealth in Nigeria

An R analysis of Nigeria Demographic and Health Survey (DHS) birth history data. It reshapes woman-level records into a child-level panel of 19,639 births across 239 survey clusters, then:

1. Builds an infant mortality indicator, filling the 12 missing ages at death with DHS-style hot-deck imputation.
2. Estimates the link between household wealth and infant death (IMR of 102.6 per 1,000; β = −0.025, p < 0.001).
3. Maps cluster-level mortality across Nigeria.
4. Links cluster GPS coordinates to WorldClim June temperatures and finds higher infant mortality in hotter areas.

The write-up is in [04-writeup/R_WorkSample_Singla.pdf](04-writeup/R_WorkSample_Singla.pdf).

## Project structure

```
├── 01-code/
│   └── Singla_code.R            ← Run this file; reproduces every number and figure
├── 02-data/
│   ├── WomanData.csv            ← Nigeria DHS women's birth history (6,344 women)
│   ├── Locations.csv            ← GPS coordinates for the 239 survey clusters
│   └── wc2.1_10m_tavg_06.tif    ← WorldClim 2.1 June temperature, 10-minute resolution
├── 03-output/                   ← Figures produced by the script
└── 04-writeup/
    └── R_WorkSample_Singla.pdf  ← Written analysis
```

## How to run

Set the working directory to `01-code/` and run the script:

```r
setwd("path/to/r-coding-sample/01-code")
source("Singla_code.R")
```

Or from a terminal, inside `01-code/`: `Rscript Singla_code.R`

The script reads from `02-data/`, prints summary statistics to the console, and saves `figure1.pdf`, `figure2.pdf` and `figure3.pdf` to `03-output/`.

## Requirements

R 4.0 or later, with:

```r
install.packages(c("tidyverse", "zoo", "sf", "terra", "rnaturalearth", "rnaturalearthdata"))
```

## Data sources

- Nigeria DHS birth history and cluster locations: [The DHS Program](https://dhsprogram.com/)
- WorldClim 2.1 climate data: [worldclim.org](https://www.worldclim.org/data/worldclim21.html)
