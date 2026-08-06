# =============================================================================
# CLEAN MINING DATA — 50 km buffer around each treated polygon
# =============================================================================
# Two mining data sources:
#   1. Global_mining raster (30 arc-second, ~1 km):
#      global_miningarea_v1_30arcsecond.tif  [mining area in km² per pixel]
#      Source: Maus et al. (2020) doi.pangaea.de/10.1594/PANGAEA.910894
#   2. Global mining polygons:
#      global_mining_polygons_v1.gpkg  [individual mine footprints]
#
# Extraction unit: 50 km buffer around each polygon centroid.
#   Captures nearby mining activity that could degrade reforestation outcomes
#   via dust, pollution, road building, or encroachment — not just mines that
#   happen to overlap the small reforestation polygon boundary.
#
# Output: Processed Data/mining_exposure_by_polygon.csv
#   poly_id, country, plant_yr, proj_id, site_id, site_rpt,
#   mining_area_sqkm_50km,   [sum of mining area km² within 50 km buffer]
#   has_mining_50km,         [1 if any mine within 50 km buffer]
#   dist_mine_km             [km from polygon centroid to nearest mine polygon]
# =============================================================================

user <- Sys.info()[["user"]]
if (user == "wangy390") .libPaths(c("H:/R/library", .libPaths()))

library(terra)
library(sf)
library(dplyr)

sf_use_s2(FALSE)

dropdir <- switch(user,
  "wangy390" = "D:/Dropbox",
  "WANGY390" = "D:/Dropbox",
  "wyf19"    = "C:/Users/wyf19/Dropbox",
  stop("Unknown user. Please add your Dropbox path.")
)

mining_raw <- file.path(dropdir, "Afforestation_Transition/Data/Raw Data/Mining/Global_mining")
gee_upload <- file.path(dropdir, "Afforestation_Transition/Data/GEE_Upload/Africa")
output_dir <- file.path(dropdir, "Afforestation_Transition/Data/Processed Data")

# Africa Albers Equal Area Conic — accurate metre-based distances across Africa
africa_aea <- "+proj=aea +lat_1=20 +lat_2=-23 +lat_0=0 +lon_0=25 +x_0=0 +y_0=0 +datum=WGS84 +units=m"

# =============================================================================
# STEP 1: Load polygons and create 50 km buffers
# =============================================================================

cat("=============================================================================\n")
cat("STEP 1: Loading treated polygons and creating 50 km buffers\n")
cat("=============================================================================\n\n")

polygons <- st_read(file.path(gee_upload, "africa_all_treated_polygons.shp"), quiet = TRUE)
polygons <- st_transform(polygons, 4326)
polygons <- st_make_valid(polygons)
cat("Loaded", nrow(polygons), "treated polygons\n")

# Centroids in Africa AEA → 50 km buffer → back to WGS84
centroids     <- st_centroid(polygons)
centroids_aea <- st_transform(centroids, africa_aea)
buffers_wgs84 <- st_transform(st_buffer(centroids_aea, dist = 50000), 4326)
buffers_sv    <- vect(buffers_wgs84)

cat("Created 50 km buffers around", nrow(buffers_wgs84), "centroids\n\n")

# =============================================================================
# STEP 2: Extract mining area within 50 km buffers (raster, ~1 km resolution)
# =============================================================================

cat("=============================================================================\n")
cat("STEP 2: Extracting mining area within 50 km buffers\n")
cat("=============================================================================\n\n")

mining_rast <- rast(file.path(mining_raw, "global_miningarea_v1_5arcminute.tif"))

# Add margin to Africa extent to fully cover 50 km edge buffers
africa_ext  <- ext(-25, 60, -40, 45)
mining_rast <- crop(mining_rast, africa_ext)

cat("Raster resolution:", paste(res(mining_rast), collapse = " x "), "degrees\n\n")

cat("Extracting mining area within 50 km buffers...\n")
ext_sum <- extract(mining_rast, buffers_sv, fun = sum, na.rm = TRUE)
ext_max <- extract(mining_rast, buffers_sv, fun = max, na.rm = TRUE)

mining_area_sqkm_50km <- ext_sum[, 2]
has_mining_50km       <- as.integer(ext_max[, 2] > 0)
has_mining_50km[is.na(ext_max[, 2])] <- NA

cat("Buffers with any mining:", sum(has_mining_50km == 1, na.rm = TRUE), "\n\n")

# =============================================================================
# STEP 3: Distance to nearest mine polygon
# =============================================================================

cat("=============================================================================\n")
cat("STEP 3: Computing distance to nearest mining polygon\n")
cat("=============================================================================\n\n")

cat("Loading mining polygons (gpkg)...\n")
mines <- st_read(file.path(mining_raw, "global_mining_polygons_v1.gpkg"), quiet = TRUE)
mines <- st_transform(mines, 4326)
cat("Total mines globally:", nrow(mines), "\n")

africa_bbox_buf <- st_as_sfc(st_bbox(c(xmin = -25, xmax = 60,
                                        ymin = -40, ymax = 45), crs = 4326))
mines_africa <- mines[st_intersects(mines, africa_bbox_buf, sparse = FALSE)[, 1], ]
cat("Mines in Africa bounding box:", nrow(mines_africa), "\n\n")

cat("Finding nearest mine for each polygon centroid...\n")
centroids_aea2 <- st_transform(centroids,    africa_aea)
mines_aea      <- st_transform(mines_africa, africa_aea)

nearest_idx  <- st_nearest_feature(centroids_aea2, mines_aea)
dist_mine_m  <- st_distance(centroids_aea2,
                             mines_aea[nearest_idx, ],
                             by_element = TRUE)
dist_mine_km <- as.numeric(dist_mine_m) / 1000

cat("Distance to nearest mine (km):\n")
print(summary(dist_mine_km))
cat("\n")

# =============================================================================
# STEP 4: Assemble and save
# =============================================================================

cat("=============================================================================\n")
cat("STEP 4: Assembling output and saving\n")
cat("=============================================================================\n\n")

out <- st_drop_geometry(polygons) %>%
  mutate(
    mining_area_sqkm_50km = mining_area_sqkm_50km,
    has_mining_50km       = has_mining_50km,
    dist_mine_km          = dist_mine_km
  )

out_file <- file.path(output_dir, "mining_exposure_by_polygon.csv")
write.csv(out, out_file, row.names = FALSE)

cat("Saved:", out_file, "\n")
cat("Total rows:", nrow(out), "\n\n")
cat("Summary of mining exposure variables:\n")
print(summary(out[, c("mining_area_sqkm_50km", "has_mining_50km", "dist_mine_km")]))
