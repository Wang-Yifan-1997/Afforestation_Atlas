# =============================================================================
# EXTRACT COVARIATES FOR TREATED AND CONTROL POLYGONS
# =============================================================================
# Purpose: Extract forest cover, NDVI, and nighttime lights for all polygons
# Input:   - Treated polygons (ghana_projects)
#          - Control polygons (all_control_polygons.geojson)
# Output:  - Covariates for treated polygons
#          - Covariates for control polygons
# =============================================================================

# Detect current user and set appropriate path
user <- Sys.info()[["user"]]

if (user == "wangy390") {
  .libPaths(c("H:/R/library", .libPaths()))
}

if (user == "wyf19") {
  setwd("C:/Users/wyf19/Dropbox/Afforestation_Transition")
} else if (user == "wangy390") {
  setwd("D:/Dropbox/Afforestation_Transition")
} else if (user == "WANGY390") {
  setwd("C:/Users/WANGY390/Dropbox/Afforestation_Transition")
} else {
  stop("Unknown user. Please add your path to the script.")
}

library(terra)
library(sf)
library(dplyr)
library(data.table)
library(tools)

# =============================================================================
# STEP 1: LOAD POLYGONS
# =============================================================================

cat("=============================================================================\n")
cat("STEP 1: LOADING POLYGONS\n")
cat("=============================================================================\n\n")

# Load treated polygons
cat("Loading treated polygons...\n")

input_folder_descrip <- "Data/Processed Data/Global Afforestation Projects/Description"
descrip_files <- list.files(input_folder_descrip, 
                            pattern = "_description\\.csv$", 
                            full.names = TRUE)

all_descrip_data <- rbindlist(lapply(descrip_files, fread), fill = TRUE)
all_descrip_data <- all_descrip_data[is.na(planting_date_reported) | 
                                       (planting_date_reported >= 1990 & planting_date_reported <= 2030)]

ghana_data <- all_descrip_data[country == "Ghana"]

input_files <- c(
  "Data/Raw Data/Global Afforestation Projects/dataverse_files/updated_LoDIA_Reforestation_Dataset_NewWorld.csv",
  "Data/Raw Data/Global Afforestation Projects/dataverse_files/updated_LoDIA_Reforestation_Dataset_Antarctica.csv",
  "Data/Raw Data/Global Afforestation Projects/dataverse_files/updated_LoDIA_Reforestation_Dataset_OldWorld_Part1.csv",
  "Data/Raw Data/Global Afforestation Projects/dataverse_files/updated_LoDIA_Reforestation_Dataset_OldWorld_Part2.csv"
)

output_folder_geo <- "Data/Processed Data/Global Afforestation Projects/Geography"
ghana_geometry_list <- list()

for (file in input_files) {
  base_name <- tools::file_path_sans_ext(basename(file))
  shp_path <- file.path(output_folder_geo, paste0(base_name, "_geography_polygon.shp"))
  
  if (!file.exists(shp_path)) next
  
  geo_sf <- st_read(shp_path, quiet = TRUE) %>%
    mutate(
      st_d_cr = as.character(st_d_cr),
      prjct__ = as.character(prjct__),
      st_d_rp = as.character(st_d_rp)
    )
  
  merged_sf <- geo_sf %>%
    left_join(ghana_data,
              by = c("st_d_cr" = "site_id_created",
                     "prjct__" = "project_id_reported",
                     "st_d_rp" = "site_id_reported")) %>%
    filter(!is.na(country) & country == "Ghana")
  
  if (nrow(merged_sf) > 0) {
    ghana_geometry_list[[base_name]] <- merged_sf
  }
}

ghana_geometry_all <- do.call(rbind, ghana_geometry_list)
ghana_projects <- ghana_geometry_all %>% 
  select(st_d_cr, prjct__, st_d_rp, planting_date_reported)
rownames(ghana_projects) <- NULL

# Add polygon id
ghana_projects$treated_polygon_id <- 1:nrow(ghana_projects)
ghana_projects$treated <- 1

cat("Treated polygons loaded:", nrow(ghana_projects), "\n\n")

# Load control polygons
cat("Loading control polygons...\n")
all_controls <- st_read("Data/Processed Data/Control_Polygons/all_control_polygons.geojson", 
                        quiet = TRUE)

# Merge planting date from treated polygons
all_controls <- all_controls %>%
  left_join(
    ghana_projects %>% 
      st_drop_geometry() %>%
      select(treated_polygon_id, planting_date_reported),
    by = "treated_polygon_id"
  )

all_controls$treated <- 0

cat("Control polygons loaded:", nrow(all_controls), "\n\n")

# =============================================================================
# STEP 2: LOAD RASTER DATA
# =============================================================================

cat("=============================================================================\n")
cat("STEP 2: LOADING RASTER DATA\n")
cat("=============================================================================\n\n")

# Hansen forest data
cat("Loading Hansen forest data...\n")
hansen_treecover2000 <- merge(
  rast("Data/Raw Data/Hansen Global Forest Change/Hansen_GFC-2024-v1.12_treecover2000_10N_000E.tif"),
  rast("Data/Raw Data/Hansen Global Forest Change/Hansen_GFC-2024-v1.12_treecover2000_10N_010W.tif")
)

hansen_lossyear <- merge(
  rast("Data/Raw Data/Hansen Global Forest Change/Hansen_GFC-2024-v1.12_lossyear_10N_000E.tif"),
  rast("Data/Raw Data/Hansen Global Forest Change/Hansen_GFC-2024-v1.12_lossyear_10N_010W.tif")
)

cat("Hansen data loaded\n\n")

# Nighttime lights files
cat("Loading nighttime lights file list...\n")
nightlight_files <- list.files(
  "Data/Processed Data/Nightlights",
  pattern = "nightlights_.*_africa\\.tif$",
  full.names = TRUE
)

# Extract years from filenames
nightlight_years <- as.numeric(gsub(".*nightlights_(\\d{4})_africa\\.tif", "\\1", 
                                    basename(nightlight_files)))

cat("Nighttime light years available:", paste(sort(nightlight_years), collapse = ", "), "\n\n")

# NDVI files
cat("Loading NDVI file list...\n")
ndvi_years <- 2000:2024
ndvi_files <- paste0("Data/Raw Data/NDVI/ndvi_ghana_", ndvi_years, 
                     "-0000000000-0000000000.tif")
ndvi_files_exist <- ndvi_files[file.exists(ndvi_files)]
cat("NDVI years available:", length(ndvi_files_exist), "files\n\n")

# =============================================================================
# STEP 3: DEFINE EXTRACTION FUNCTIONS
# =============================================================================

cat("=============================================================================\n")
cat("STEP 3: DEFINING EXTRACTION FUNCTIONS\n")
cat("=============================================================================\n\n")

# Function to extract Hansen metrics for a single polygon
extract_hansen_metrics <- function(poly, polygon_id) {
  
  # Baseline tree cover
  treecover <- terra::extract(hansen_treecover2000, poly, 
                              fun = function(x) mean(x, na.rm = TRUE))[[2]]
  
  # Loss year - mean of loss years
  mean_lossyear <- terra::extract(hansen_lossyear, poly, fun = function(x) {
    loss_vals <- x[x > 0 & !is.na(x)]
    if(length(loss_vals) == 0) return(NA)
    return(mean(loss_vals))
  })[[2]]
  
  # Percentage area with loss
  pct_loss <- terra::extract(hansen_lossyear, poly, fun = function(x) {
    x_clean <- x[!is.na(x)]
    if(length(x_clean) == 0) return(NA)
    sum(x_clean > 0) / length(x_clean) * 100
  })[[2]]
  
  return(data.frame(
    polygon_id = polygon_id,
    baseline_treecover = treecover,
    mean_lossyear = mean_lossyear,
    pct_area_with_loss = pct_loss
  ))
}

# Function to extract annual NDVI for a single polygon
extract_annual_ndvi <- function(poly, polygon_id, project_year) {
  
  results <- data.frame(
    polygon_id = polygon_id,
    year = ndvi_years,
    mean_ndvi = NA,
    median_ndvi = NA,
    sd_ndvi = NA
  )
  
  for(i in seq_along(ndvi_years)) {
    year <- ndvi_years[i]
    ndvi_file <- paste0("Data/Raw Data/NDVI/ndvi_ghana_", year, 
                        "-0000000000-0000000000.tif")
    
    if(!file.exists(ndvi_file)) next
    
    tryCatch({
      ndvi_raster <- rast(ndvi_file)
      ndvi_vals <- terra::extract(ndvi_raster, poly)[[2]]
      ndvi_vals_clean <- ndvi_vals[!is.na(ndvi_vals)]
      
      if(length(ndvi_vals_clean) > 0) {
        results$mean_ndvi[i] <- mean(ndvi_vals_clean)
        results$median_ndvi[i] <- median(ndvi_vals_clean)
        results$sd_ndvi[i] <- sd(ndvi_vals_clean)
      }
    }, error = function(e) {})
  }
  
  # Add period indicators
  results$planting_date_reported <- project_year
  results$years_since_treatment <- results$year - project_year
  results$period <- ifelse(results$year < project_year, "pre_treatment",
                           ifelse(results$year == project_year, "treatment_year",
                                  "post_treatment"))
  
  return(results)
}

# Function to extract annual nighttime lights for a single polygon
extract_annual_nightlights <- function(poly, polygon_id, project_year) {
  
  results <- data.frame(
    polygon_id = polygon_id,
    year = nightlight_years,
    mean_nl = NA,
    median_nl = NA,
    sd_nl = NA
  )
  
  for(i in seq_along(nightlight_files)) {
    year <- nightlight_years[i]
    
    tryCatch({
      nl_raster <- rast(nightlight_files[i])
      
      # Transform polygon to nightlight CRS if needed
      poly_transformed <- st_transform(poly, crs(nl_raster))
      
      nl_vals <- terra::extract(nl_raster, poly_transformed)[[2]]
      nl_vals_clean <- nl_vals[!is.na(nl_vals) & nl_vals >= 0]
      
      if(length(nl_vals_clean) > 0) {
        results$mean_nl[i] <- mean(nl_vals_clean)
        results$median_nl[i] <- median(nl_vals_clean)
        results$sd_nl[i] <- sd(nl_vals_clean)
      }
    }, error = function(e) {})
  }
  
  # Add period indicators
  results$planting_date_reported <- project_year
  results$years_since_treatment <- results$year - project_year
  results$period <- ifelse(results$year < project_year, "pre_treatment",
                           ifelse(results$year == project_year, "treatment_year",
                                  "post_treatment"))
  
  return(results)
}

# =============================================================================
# STEP 4: EXTRACT FOR TREATED POLYGONS
# =============================================================================

cat("=============================================================================\n")
cat("STEP 4: EXTRACTING COVARIATES FOR TREATED POLYGONS\n")
cat("=============================================================================\n\n")

# Transform CRS
ghana_projects_t <- st_transform(ghana_projects, crs(hansen_treecover2000))

start_time <- Sys.time()

hansen_treated_list <- list()
ndvi_treated_list <- list()
nl_treated_list <- list()

for(i in 1:nrow(ghana_projects_t)) {
  
  if(i %% 100 == 0) {
    elapsed <- difftime(Sys.time(), start_time, units = "mins")
    rate <- i / as.numeric(elapsed)
    remaining <- (nrow(ghana_projects_t) - i) / rate
    cat("Treated polygon", i, "of", nrow(ghana_projects_t),
        sprintf("(%.1f%%) - Est. remaining: %.1f min\n", 
                i/nrow(ghana_projects_t)*100, remaining))
  }
  
  poly <- ghana_projects_t[i, ]
  project_year <- as.numeric(poly[["planting_date_reported"]])
  polygon_id <- poly$treated_polygon_id
  
  if(is.na(project_year)) next
  
  # Extract Hansen metrics
  tryCatch({
    hansen_treated_list[[i]] <- extract_hansen_metrics(poly, polygon_id)
  }, error = function(e) {})
  
  # Extract NDVI
  tryCatch({
    ndvi_treated_list[[i]] <- extract_annual_ndvi(poly, polygon_id, project_year)
  }, error = function(e) {})
  
  # Extract Nighttime lights
  tryCatch({
    nl_treated_list[[i]] <- extract_annual_nightlights(poly, polygon_id, project_year)
  }, error = function(e) {})
}

# Combine treated results
hansen_treated <- bind_rows(hansen_treated_list)
ndvi_treated <- bind_rows(ndvi_treated_list)
nl_treated <- bind_rows(nl_treated_list)

cat("\nTreated extraction complete!\n")
cat("Hansen metrics:", nrow(hansen_treated), "rows\n")
cat("NDVI time series:", nrow(ndvi_treated), "rows\n")
cat("Nighttime lights:", nrow(nl_treated), "rows\n\n")

# =============================================================================
# STEP 5: EXTRACT FOR CONTROL POLYGONS
# =============================================================================

cat("=============================================================================\n")
cat("STEP 5: EXTRACTING COVARIATES FOR CONTROL POLYGONS\n")
cat("=============================================================================\n\n")

# Transform CRS
all_controls_t <- st_transform(all_controls, crs(hansen_treecover2000))

start_time <- Sys.time()

hansen_control_list <- list()
ndvi_control_list <- list()
nl_control_list <- list()

for(i in 1:nrow(all_controls_t)) {
  
  if(i %% 100 == 0) {
    elapsed <- difftime(Sys.time(), start_time, units = "mins")
    rate <- i / as.numeric(elapsed)
    remaining <- (nrow(all_controls_t) - i) / rate
    cat("Control polygon", i, "of", nrow(all_controls_t),
        sprintf("(%.1f%%) - Est. remaining: %.1f min\n", 
                i/nrow(all_controls_t)*100, remaining))
  }
  
  poly <- all_controls_t[i, ]
  project_year <- as.numeric(poly[["planting_date_reported"]])
  polygon_id <- poly$control_id
  treated_id <- poly$treated_polygon_id
  
  if(is.na(project_year)) next
  
  # Extract Hansen metrics
  tryCatch({
    hansen_row <- extract_hansen_metrics(poly, polygon_id)
    hansen_row$treated_polygon_id <- treated_id
    hansen_control_list[[i]] <- hansen_row
  }, error = function(e) {})
  
  # Extract NDVI
  tryCatch({
    ndvi_row <- extract_annual_ndvi(poly, polygon_id, project_year)
    ndvi_row$treated_polygon_id <- treated_id
    ndvi_control_list[[i]] <- ndvi_row
  }, error = function(e) {})
  
  # Extract Nighttime lights
  tryCatch({
    nl_row <- extract_annual_nightlights(poly, polygon_id, project_year)
    nl_row$treated_polygon_id <- treated_id
    nl_control_list[[i]] <- nl_row
  }, error = function(e) {})
}

# Combine control results
hansen_control <- bind_rows(hansen_control_list)
ndvi_control <- bind_rows(ndvi_control_list)
nl_control <- bind_rows(nl_control_list)

cat("\nControl extraction complete!\n")
cat("Hansen metrics:", nrow(hansen_control), "rows\n")
cat("NDVI time series:", nrow(ndvi_control), "rows\n")
cat("Nighttime lights:", nrow(nl_control), "rows\n\n")

# =============================================================================
# STEP 6: SAVE ALL RESULTS
# =============================================================================

cat("=============================================================================\n")
cat("STEP 6: SAVING RESULTS\n")
cat("=============================================================================\n\n")

# Create output directories
dir.create("Data/Processed Data/Treated_Polygons", recursive = TRUE, showWarnings = FALSE)
dir.create("Data/Processed Data/Control_Polygons", recursive = TRUE, showWarnings = FALSE)

# Save treated polygon results
write.csv(hansen_treated, 
          "Data/Processed Data/Treated_Polygons/treated_hansen_metrics.csv", 
          row.names = FALSE)

write.csv(ndvi_treated, 
          "Data/Processed Data/Treated_Polygons/treated_ndvi_timeseries.csv", 
          row.names = FALSE)

write.csv(nl_treated, 
          "Data/Processed Data/Treated_Polygons/treated_nightlights_timeseries.csv", 
          row.names = FALSE)

cat("Treated polygon files saved:\n")
cat("  - treated_hansen_metrics.csv\n")
cat("  - treated_ndvi_timeseries.csv\n")
cat("  - treated_nightlights_timeseries.csv\n\n")

# Save control polygon results
write.csv(hansen_control, 
          "Data/Processed Data/Control_Polygons/control_hansen_metrics.csv", 
          row.names = FALSE)

write.csv(ndvi_control, 
          "Data/Processed Data/Control_Polygons/control_ndvi_timeseries.csv", 
          row.names = FALSE)

write.csv(nl_control, 
          "Data/Processed Data/Control_Polygons/control_nightlights_timeseries.csv", 
          row.names = FALSE)

cat("Control polygon files saved:\n")
cat("  - control_hansen_metrics.csv\n")
cat("  - control_ndvi_timeseries.csv\n")
cat("  - control_nightlights_timeseries.csv\n\n")

cat("=============================================================================\n")
cat("ALL EXTRACTIONS COMPLETE!\n")
cat("=============================================================================\n\n")

cat("Summary of output files:\n")
cat("Treated polygons:\n")
cat("  Hansen metrics:", nrow(hansen_treated), "polygons\n")
cat("  NDVI time series:", nrow(ndvi_treated), "polygon-year observations\n")
cat("  Nighttime lights:", nrow(nl_treated), "polygon-year observations\n\n")
cat("Control polygons:\n")
cat("  Hansen metrics:", nrow(hansen_control), "polygons\n")
cat("  NDVI time series:", nrow(ndvi_control), "polygon-year observations\n")
cat("  Nighttime lights:", nrow(nl_control), "polygon-year observations\n\n")