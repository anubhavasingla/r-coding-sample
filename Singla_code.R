# ==============================================================================
# Infant Mortality and Household Wealth in Nigeria
# Analysis of DHS Birth History Data
#
# Author: Anubhava Singla
# Date: April 2026
#
# This script accompanies the written analysis. It reads from the current
# directory and produces three figures as PDF files.
#
# Required packages: tidyverse, ggplot2, zoo, sf, terra, rnaturalearth,
#                    rnaturalearthdata
# Required data files (place in current directory):
#   - WomanData.csv (Nigeria DHS women's birth history)
#   - Locations.csv (GPS coordinates for survey clusters)
#   - wc2.1_10m_tavg_06.tif (WorldClim June temperature raster)
# ==============================================================================

library(tidyverse)

# ==============================================================================
# 1. Load and reshape birth history data
# ==============================================================================

women <- read_csv("WomanData.csv", show_col_types = FALSE)
cat("Women in original data:", nrow(women), "\n")

# The birth history is in wide format: each variable (b5, b7, bord, etc.)
# is repeated _01 through _20 for up to 20 births per woman.
# We reshape so each row is one child.

birth_cols <- names(women)[grepl("^(bidx|bord|b[0-9]+)_\\d{2}$", names(women))]

# Some columns are read as character, others as numeric, which breaks
# pivot_longer. Force everything to character first, convert back after.
women <- women %>%
  mutate(across(all_of(birth_cols), as.character))

births_long <- women %>%
  pivot_longer(
    cols = all_of(birth_cols),
    names_to = c(".value", "child_idx"),
    names_pattern = "^(.+)_(\\d{2})$"
  ) %>%
  mutate(across(c(bidx, bord, b0, b1, b2, b3, b7, b8, b11, b12, b15, b16), as.numeric))

cat("Rows after reshape:", nrow(births_long), "\n")

# Keep only actual births (bidx not missing).
# Empty slots (e.g., child index 8-20 for a woman with 7 births) are dropped.
births <- births_long %>%
  filter(!is.na(bidx))

cat("Valid births:", nrow(births), "\n")
cat("Alive:", sum(births$b5 == "yes", na.rm = TRUE), "\n")
cat("Dead:", sum(births$b5 == "no", na.rm = TRUE), "\n")

# ==============================================================================
# 2. Construct infant mortality indicator
# ==============================================================================

# Infant death = died at or before 12 completed months (b5 = "no" and b7 <= 12)

# 12 dead children have missing b7. The DHS Recode6 manual says missing ages
# at death are imputed via hot-deck: take the age at death of the last child
# with the same birth order. We replicate this for the remaining 12.

dead_missing <- sum(births$b5 == "no" & is.na(births$b7), na.rm = TRUE)
cat("\nDead children with missing b7:", dead_missing, "\n")

if (dead_missing > 0) {
  births <- births %>%
    arrange(bord) %>%
    group_by(bord) %>%
    mutate(
      b7 = if_else(
        b5 == "no" & is.na(b7),
        zoo::na.locf(if_else(b5 == "no" & !is.na(b7), b7, NA_real_), na.rm = FALSE),
        b7
      )
    ) %>%
    ungroup()

  # Verify imputation worked
  still_missing <- sum(births$b5 == "no" & is.na(births$b7), na.rm = TRUE)
  cat("Missing b7 after imputation:", still_missing, "\n")
}

births <- births %>%
  mutate(infant_death = as.integer(b5 == "no" & b7 <= 12))

n_births <- nrow(births)
n_deaths <- sum(births$infant_death)
imr <- (n_deaths / n_births) * 1000

cat("\nBirths:", n_births, "\n")
cat("Infant deaths:", n_deaths, "\n")
cat("IMR per 1,000:", round(imr, 1), "\n")

# ==============================================================================
# 3. Regression: infant mortality on household wealth
# ==============================================================================

# v191 is the DHS wealth index (PCA score, standardized to mean 0, SD 1)
births <- births %>%
  rename(wealth_index = v191)

reg <- lm(infant_death ~ wealth_index, data = births)
summary(reg)

cat("\nWealth coefficient:", round(coef(reg)["wealth_index"], 4), "\n")
cat("Effect per 1,000 births:", round(coef(reg)["wealth_index"] * 1000, 1), "\n")

# ==============================================================================
# 4. Village-level aggregation and scatter plot (Figure 1)
# ==============================================================================

# Collapse to cluster level
clusters <- births %>%
  group_by(v001) %>%
  summarise(
    avg_wealth = mean(wealth_index, na.rm = TRUE),
    avg_imr = mean(infant_death, na.rm = TRUE),
    n_births = n(),
    .groups = "drop"
  )

cat("\nClusters:", nrow(clusters), "\n")

library(ggplot2)

pdf("figure1.pdf", width = 7, height = 5)
ggplot(clusters, aes(x = avg_wealth, y = avg_imr)) +
  geom_point(alpha = 0.5, size = 1.5) +
  labs(
    title = "Village-Average Wealth vs. Infant Mortality",
    x = "Village-Average Wealth Score (Standardized)",
    y = "Village-Average Probability of Infant Death"
  ) +
  theme_minimal()
dev.off()

# ==============================================================================
# 5. Map of cluster locations colored by IMR (Figure 2)
# ==============================================================================

library(sf)
library(rnaturalearth)

locations <- read_csv("Locations.csv", show_col_types = FALSE)

cluster_map <- clusters %>%
  inner_join(locations, by = "v001")

nigeria <- ne_countries(scale = "medium", country = "Nigeria", returnclass = "sf")
cluster_sf <- st_as_sf(cluster_map, coords = c("lon", "lat"), crs = 4326)

pdf("figure2.pdf", width = 7, height = 5)
ggplot() +
  geom_sf(data = nigeria, fill = "grey95", color = "black") +
  geom_sf(data = cluster_sf, aes(color = avg_imr), size = 1.5, alpha = 0.7) +
  scale_color_viridis_c(name = "Infant\nMortality\nRate", option = "plasma") +
  labs(title = "Cluster Locations Colored by Infant Mortality Rate") +
  theme_minimal()
dev.off()

cat("\nMin cluster IMR:", round(min(cluster_map$avg_imr), 3), "\n")
cat("Max cluster IMR:", round(max(cluster_map$avg_imr), 3), "\n")

# ==============================================================================
# 6. Temperature and mortality (Figure 3)
# ==============================================================================

library(terra)

# WorldClim 10-minute average temperature, June layer.
# Download from https://www.worldclim.org/data/worldclim21.html
# and place the .tif file in the current directory.
june_temp <- rast("wc2.1_10m_tavg_06.tif")

# Convert cluster coordinates to spatial vector and extract temperature
cluster_points <- vect(cluster_map, geom = c("lon", "lat"), crs = "EPSG:4326")
cluster_map$june_temp <- extract(june_temp, cluster_points)[, 2]

temp_data <- cluster_map %>% filter(!is.na(june_temp))
cat("\nClusters with temperature data:", nrow(temp_data), "\n")

temp_reg <- lm(avg_imr ~ june_temp, data = temp_data)
summary(temp_reg)

pdf("figure3.pdf", width = 7, height = 5)
ggplot(temp_data, aes(x = june_temp, y = avg_imr)) +
  geom_point(alpha = 0.5, size = 1.5) +
  geom_smooth(method = "lm", se = TRUE, color = "blue") +
  labs(
    title = "Average June Temperature vs. Village Mortality Rate",
    x = "Average June Temperature (°C)",
    y = "Village-Average Infant Mortality Rate"
  ) +
  theme_minimal()
dev.off()
