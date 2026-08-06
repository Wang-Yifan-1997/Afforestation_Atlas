# =============================================================================
# CLEAN CROPLAND PRESSURE DATA — 50 km buffer around each treated polygon
# =============================================================================
# Two cropland data sources:
#   1. ExpansionAreas (0.5° ≈ 55 km resolution):
#      - AreaExpPressure_30_{CON,EXP}scenario.bil  [km² under expansion pressure]
#      - ProfitabilityRanking_1to30_{CON,EXP}scenario.bil [1–30 rank; lower = more pressure]
#   2. Global_cropland_2011 (30m resolution): GLAD cropland cover (4-quadrant tiles)
#
# Extraction unit: 50 km buffer around each polygon centroid.
#   The buffer captures the surrounding landscape context — the competitive
#   land-use pressure in the area, not just within the small reforestation polygon.
#
# Output: Processed Data/cropland_pressure_by_polygon.csv
#   poly_id, country, plant_yr, proj_id, site_id, site_rpt,
#   area_exp_pressure_con,   [mean km² under pressure within 50 km buffer, CON]
#   area_exp_pressure_exp,   [mean km² under pressure within 50 km buffer, EXP]
#   profit_rank_con,         [mean profitability rank 1–30 within 50 km buffer, CON]
#   profit_rank_exp,         [mean profitability rank 1–30 within 50 km buffer, EXP]
#   cropland_pct_2011        [mean % cropland within 50 km buffer, 30m]
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

cropland_raw <- file.path(dropdir, "Afforestation_Transition/Data/Raw Data/Cropland")
gee_upload   <- file.path(dropdir, "Afforestation_Transition/Data/GEE_Upload/Africa")
output_dir   <- file.path(dropdir, "Afforestation_Transition/Data/Processed Data")

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

# Centroids — used for coarse 0.5° raster extraction (point lookup)
centroids_wgs84 <- st_centroid(polygons)
centroids_sv    <- vect(centroids_wgs84)

# Centroids in Africa AEA → 50 km buffer → back to WGS84 — used for 30m cropland
centroids_aea <- st_transform(centroids_wgs84, africa_aea)
buffers_wgs84 <- st_transform(st_buffer(centroids_aea, dist = 50000), 4326)
buffers_sv    <- vect(buffers_wgs84)

cat("Created 50 km buffers around", nrow(buffers_wgs84), "centroids\n\n")

# =============================================================================
# STEP 2: Extract ExpansionArea pressure rasters (0.5° resolution)
# =============================================================================
# Mean within the 50 km buffer: captures average expansion pressure in the
# landscape surrounding the reforestation site.
# =============================================================================

cat("=============================================================================\n")
cat("STEP 2: Extracting cropland expansion pressure within 50 km buffers\n")
cat("=============================================================================\n\n")

exp_dir <- file.path(cropland_raw, "ExpansionAreas")

area_con   <- rast(file.path(exp_dir, "AreaExpPressure_30_CONscenario.bil"))
area_exp   <- rast(file.path(exp_dir, "AreaExpPressure_30_EXPscenario.bil"))
profit_con <- rast(file.path(exp_dir, "ProfitabilityRanking_1to30_CONscenario.bil"))
profit_exp <- rast(file.path(exp_dir, "ProfitabilityRanking_1to30_EXPscenario.bil"))

# Point extraction is appropriate here: at 0.5° (~55 km per cell) the centroid
# already identifies the relevant pixel — polygon mean would give the same value.
area_exp_pressure_con <- extract(area_con,   centroids_sv)[, 2]
area_exp_pressure_exp <- extract(area_exp,   centroids_sv)[, 2]
profit_rank_con       <- extract(profit_con, centroids_sv)[, 2]
profit_rank_exp       <- extract(profit_exp, centroids_sv)[, 2]

cat("Non-missing area_exp_pressure_con:", sum(!is.na(area_exp_pressure_con)), "\n")
cat("Non-missing profit_rank_con:      ", sum(!is.na(profit_rank_con)), "\n\n")

# =============================================================================
# STEP 3: Extract Global Cropland cover within 50 km buffers (30m tiles)
# =============================================================================

cat("=============================================================================\n")
cat("STEP 3: Extracting Global Cropland cover within 50 km buffers (30m tiles)\n")
cat("=============================================================================\n\n")

gc_dir <- file.path(cropland_raw, "Global_cropland")

# Add 1° margin beyond Africa bounding box to fully cover 50 km edge buffers
africa_ext <- ext(-22, 57, -37, 42)

cat("Cropping tiles to Africa extent and aggregating to ~3 km...\n")
tiles <- Filter(Negate(is.null), lapply(c("NE", "NW", "SE", "SW"), function(q) {
  tryCatch({
    r <- crop(rast(file.path(gc_dir, paste0("Global_cropland_", q, "_2011.tif"))), africa_ext)
    aggregate(r, fact = 100, fun = mean)
  }, error = function(e) NULL)   # skip tiles that don't overlap Africa
}))

cat("Mosaicking cropland tiles...\n")
cropland_africa <- mosaic(sprc(tiles))

cat("Extracting mean cropland cover within 50 km buffers...\n")
cropland_pct_2011 <- extract(cropland_africa, buffers_sv, fun = mean, na.rm = TRUE)[, 2]

cat("Non-missing cropland_pct_2011:", sum(!is.na(cropland_pct_2011)), "\n\n")

# =============================================================================
# STEP 4: Assemble and save
# =============================================================================

cat("=============================================================================\n")
cat("STEP 4: Assembling output and saving\n")
cat("=============================================================================\n\n")

out <- st_drop_geometry(polygons) %>%
  mutate(
    area_exp_pressure_con = area_exp_pressure_con,
    area_exp_pressure_exp = area_exp_pressure_exp,
    profit_rank_con       = profit_rank_con,
    profit_rank_exp       = profit_rank_exp,
    cropland_pct_2011     = cropland_pct_2011
  )

out_file <- file.path(output_dir, "cropland_pressure_by_polygon.csv")
write.csv(out, out_file, row.names = FALSE)

cat("Saved:", out_file, "\n")
cat("Total rows:", nrow(out), "\n\n")
cat("Summary of cropland pressure variables (50 km buffer):\n")
print(summary(out[, c("area_exp_pressure_con", "area_exp_pressure_exp",
                       "profit_rank_con",       "profit_rank_exp",
                       "cropland_pct_2011")]))
