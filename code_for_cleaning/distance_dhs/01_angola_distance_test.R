# Calculate distance from each Angola DHS cluster to the nearest Angola afforestation polygon.
# Requires: run 00_split_afforestation_by_country.R first.
# DHS source : Data/DHS data/4.19/Angola/2006-07/AOGE52FL.shp
# Aff source : Data/Processed Data/Global Afforestation Projects/by_country/Angola.gpkg

user <- Sys.info()[["user"]]
if (user == "wangy390") {
  .libPaths(c("H:/R/library", .libPaths()))
  setwd("D:/Dropbox/Afforestation_Transition")
} else if (user == "wyf19") {
  setwd("C:/Users/wyf19/Dropbox/Afforestation_Transition")
} else {
  stop("Unknown user — add your path here.")
}

library(sf)
library(dplyr)

cat("Working directory:", getwd(), "\n\n")

# ─────────────────────────────────────────────────────────────
# 1. Load Angola afforestation polygons
# ─────────────────────────────────────────────────────────────
aff_path <- "Data/Processed Data/Global Afforestation Projects/by_country/Angola.gpkg"

if (!file.exists(aff_path)) {
  stop("Angola.gpkg not found. Run 00_split_afforestation_by_country.R first.")
}

angola_aff <- st_read(aff_path, quiet = TRUE)
cat("Angola afforestation polygons loaded:", nrow(angola_aff), "\n")
cat("CRS:", st_crs(angola_aff)$input, "\n\n")

# ─────────────────────────────────────────────────────────────
# 2. Load Angola DHS cluster shapefile
# ─────────────────────────────────────────────────────────────
dhs_path <- "Data/DHS data/4.19/Angola/2006-07/AOGE52FL.shp"
dhs <- st_read(dhs_path, quiet = TRUE)

cat("DHS clusters loaded:", nrow(dhs), "\n")

# Drop clusters with missing coordinates (SOURCE == "MIS" → lat/lon = 0,0)
n_before <- nrow(dhs)
dhs <- dhs %>% filter(LATNUM != 0 | LONGNUM != 0)
cat("Dropped", n_before - nrow(dhs), "clusters with missing coords\n")
cat("Clusters used:", nrow(dhs), "\n\n")

# Align CRS
angola_aff <- st_transform(angola_aff, st_crs(dhs))

# ─────────────────────────────────────────────────────────────
# 3. Distance from each cluster to nearest afforestation polygon
# ─────────────────────────────────────────────────────────────
cat("Computing nearest-feature distances...\n")

nearest_idx  <- st_nearest_feature(dhs, angola_aff)
dist_m       <- st_distance(dhs, angola_aff[nearest_idx, ], by_element = TRUE)

dhs$dist_aff_km     <- as.numeric(dist_m) / 1000
dhs$nearest_site_id <- angola_aff$st_d_cr[nearest_idx]
dhs$nearest_proj_id <- angola_aff$prjct__[nearest_idx]
dhs$nearest_country <- angola_aff$country[nearest_idx]

# ─────────────────────────────────────────────────────────────
# 4. Save result
# ─────────────────────────────────────────────────────────────
out_dir <- "Data/Processed Data/DHS/distance"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
out_path <- file.path(out_dir, "Angola_2006_07_dist_to_afforestation.csv")

dhs %>%
  st_drop_geometry() %>%
  select(DHSID, DHSCC, DHSYEAR, DHSCLUST, URBAN_RURA, LATNUM, LONGNUM,
         dist_aff_km, nearest_site_id, nearest_proj_id) %>%
  write.csv(out_path, row.names = FALSE)

cat("Saved:", out_path, "\n\n")

# ─────────────────────────────────────────────────────────────
# 5. Summary
# ─────────────────────────────────────────────────────────────
cat("=== Distance to nearest afforestation project (km) ===\n")
print(summary(dhs$dist_aff_km))

cat("\nSample (10 clusters):\n")
dhs %>%
  st_drop_geometry() %>%
  select(DHSID, DHSCLUST, URBAN_RURA, dist_aff_km, nearest_site_id, nearest_proj_id) %>%
  head(10) %>%
  print()
