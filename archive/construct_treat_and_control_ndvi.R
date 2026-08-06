# Detect current user and set appropriate path
user <- Sys.info()[["user"]]

# Set custom library path only for wangy390
if (user == "wangy390") {
  .libPaths(c("H:/R/library", .libPaths()))
}

if (user == "wyf19") {
  setwd("C:/Users/wyf19/Dropbox/Afforestation_Transition")
} else if (user == "wangy390") {
  setwd("D:/Dropbox/Afforestation_Transition")
} else {
  stop("Unknown user. Please add your path to the script.")
}

# Load required libraries
library(terra)
library(sf)
library(dplyr)
library(tidyr)
library(ggplot2)
library(data.table)
library(tools)
library(mapview)
library(geosphere)  # For geographic calculations

# =============================================================================
# LOAD GHANA AFFORESTATION PROJECT DATA
# =============================================================================


# Load description data
input_folder_descrip <- "Data/Processed Data/Global Afforestation Projects/Description"
descrip_files <- list.files(input_folder_descrip, 
                            pattern = "_description\\.csv$", 
                            full.names = TRUE)

all_descrip_data <- rbindlist(lapply(descrip_files, fread), fill = TRUE)
# Keep NAs but filter out invalid years
all_descrip_data <- all_descrip_data[is.na(planting_date_reported) | 
                                       (planting_date_reported >= 1990 & planting_date_reported <= 2030)]

# Filter for Ghana
ghana_data <- all_descrip_data[country == "Ghana"]

cat("Ghana projects loaded:", nrow(ghana_data), "\n")

input_files <- c(
  "Data/Raw Data/Global Afforestation Projects/dataverse_files/updated_LoDIA_Reforestation_Dataset_NewWorld.csv",
  "Data/Raw Data/Global Afforestation Projects/dataverse_files/updated_LoDIA_Reforestation_Dataset_Antarctica.csv",
  "Data/Raw Data/Global Afforestation Projects/dataverse_files/updated_LoDIA_Reforestation_Dataset_OldWorld_Part1.csv",
  "Data/Raw Data/Global Afforestation Projects/dataverse_files/updated_LoDIA_Reforestation_Dataset_OldWorld_Part2.csv"
)

output_folder_geo <- "Data/Processed Data/Global Afforestation Projects/Geography"

ghana_geometry_list <- list()

for (file in input_files) {
  
  # Base name without extension
  base_name <- file_path_sans_ext(basename(file))
  
  # Corresponding shapefile previously created
  shp_path <- file.path(output_folder_geo, paste0(base_name, "_geography_polygon.shp"))
  
  if (!file.exists(shp_path)) {
    cat("❌ Missing shapefile:", shp_path, "\n")
    next
  }
  
  cat("→ Reading:", shp_path, "\n")
  geo_sf <- st_read(shp_path, quiet = TRUE)
  
  # ---- Prepare geo_sf for joining ----
  geo_sf <- geo_sf %>%
    mutate(
      st_d_cr = as.character(st_d_cr),   # convert to character
      prjct__ = as.character(prjct__),   # convert to character
      st_d_rp = as.character(st_d_rp)    # often needed too
    )
  
  # ---- Merge with Ghana metadata ----
  merged_sf <- geo_sf %>%
    left_join(
      ghana_data,
      by = c("st_d_cr" = "site_id_created",
             "prjct__" = "project_id_reported",
             "st_d_rp" = "site_id_reported")
    ) %>%
    filter(!is.na(country) & country == "Ghana")   # keep only Ghana rows
  
  if (nrow(merged_sf) > 0) {
    ghana_geometry_list[[base_name]] <- merged_sf
    cat("   ✓ Added", nrow(merged_sf), "Ghana records.\n")
  } else {
    cat("   ⚠ No Ghana matches in this file.\n")
  }
}


# Combine all geometries
ghana_geometry_all <- do.call(rbind, ghana_geometry_list)
ghana_geometry_clean <- ghana_geometry_all %>% select(st_d_cr, prjct__, st_d_rp, planting_date_reported)
rownames(ghana_geometry_clean) <- NULL

# =============================================================================
# 1. LOAD AND PREPARE DATA
# =============================================================================

# Load and combine Hansen forest data tiles
# Tree cover 2000
hansen_treecover2000_tile1 <- rast("Data/Raw Data/Hansen Global Forest Change/Hansen_GFC-2024-v1.12_treecover2000_10N_000E.tif")
hansen_treecover2000_tile2 <- rast("Data/Raw Data/Hansen Global Forest Change/Hansen_GFC-2024-v1.12_treecover2000_10N_010W.tif")

# Merge tiles
hansen_treecover2000 <- merge(hansen_treecover2000_tile1, hansen_treecover2000_tile2)

# Loss year
hansen_lossyear_tile1 <- rast("Data/Raw Data/Hansen Global Forest Change/Hansen_GFC-2024-v1.12_lossyear_10N_000E.tif")
hansen_lossyear_tile2 <- rast("Data/Raw Data/Hansen Global Forest Change/Hansen_GFC-2024-v1.12_lossyear_10N_010W.tif")

# Merge tiles
hansen_lossyear <- merge(hansen_lossyear_tile1, hansen_lossyear_tile2)

cat("Tree cover 2000 extent:", as.vector(ext(hansen_treecover2000)), "\n")
cat("Loss year extent:", as.vector(ext(hansen_lossyear)), "\n")
# Load afforestation project polygons (assumes you have this loaded as ghana_geometry_all)
# ghana_geometry_all should have columns: geometry, planting_date_reported (or treatment_year)

# Check the structure
cat("Afforestation data structure:\n")
print(head(ghana_geometry_all))
cat("\nNumber of projects:", nrow(ghana_geometry_all), "\n")

# Transform to Hansen CRS
ghana_projects <- st_transform(ghana_geometry_clean, crs(hansen_treecover2000))

# =============================================================================
# 2. EXTRACT HANSEN DATA FOR EACH PROJECT POLYGON
# =============================================================================

cat("\nExtracting Hansen data for each project polygon...\n")

# Function to extract forest metrics for a single polygon
extract_forest_metrics <- function(polygon_idx) {
  
  poly <- ghana_projects[polygon_idx, ]
  
  # Extract tree cover 2000 (baseline)
  treecover <- terra::extract(hansen_treecover2000, poly, fun = function(x) {
    mean(x, na.rm = TRUE)
  })
  
  # Extract loss year
  loss <- terra::extract(hansen_lossyear, poly, fun = function(x) {
    # Get distribution of loss years
    loss_vals <- x[x > 0 & !is.na(x)]
    if(length(loss_vals) == 0) return(NA)
    return(mean(loss_vals))
  })
  
  # Calculate area with loss (percentage)
  loss_area <- terra::extract(hansen_lossyear, poly, fun = function(x) {
    x_clean <- x[!is.na(x)]
    if(length(x_clean) == 0) return(NA)
    sum(x_clean > 0) / length(x_clean) * 100
  })
  
  return(data.frame(
    polygon_id = polygon_idx,
    baseline_treecover = treecover[[2]],
    mean_lossyear = loss[[2]],
    pct_area_with_loss = loss_area[[2]]
  ))
}

# Extract for all polygons (with progress tracking)
forest_metrics_list <- lapply(1:nrow(ghana_projects), function(i) {
  if(i %% 100 == 0) cat("Processing polygon", i, "of", nrow(ghana_projects), "\n")
  extract_forest_metrics(i)
})

# Combine results
forest_metrics <- bind_rows(forest_metrics_list)

# Merge with original data
ghana_analysis <- ghana_projects %>%
  st_drop_geometry() %>%
  bind_cols(forest_metrics) %>%
  select(-polygon_id)

# =============================================================================
# 3. CALCULATE ANNUAL FOREST COVER FOR EACH POLYGON
# =============================================================================

# =============================================================================
# CALCULATE NDVI STATISTICS FOR ALL POLYGONS
# =============================================================================

cat("Calculating NDVI statistics for all polygons...\n")
cat("Total polygons:", nrow(ghana_projects), "\n\n")

# Define years
years <- 2000:2024

# Initialize list to store results
all_ndvi_results <- list()

# Loop through all polygons
for(polygon_idx in 1:nrow(ghana_projects)) {
  
  # Progress indicator
  if(polygon_idx %% 100 == 0) {
    cat("Processing polygon", polygon_idx, "of", nrow(ghana_projects), "\n")
  }
  
  # Extract the polygon
  poly <- ghana_projects[polygon_idx, ]
  project_year <- as.numeric(poly[["planting_date_reported"]])
  
  # Skip if project year is missing
  if(is.na(project_year)) {
    next
  }
  
  # Initialize results dataframe for this polygon
  ndvi_results <- data.frame(
    polygon_id = polygon_idx,
    planting_date_reported = project_year,
    year = years,
    mean_ndvi = NA,
    median_ndvi = NA,
    min_ndvi = NA,
    max_ndvi = NA,
    p25_ndvi = NA,
    p75_ndvi = NA,
    sd_ndvi = NA,
    n_pixels = NA
  )
  
  # Loop through each year and extract NDVI
  for(i in seq_along(years)) {
    year <- years[i]
    
    # Construct filename
    ndvi_file <- paste0("Data/Raw Data/NDVI/ndvi_ghana_", year, "-0000000000-0000000000.tif")
    
    # Check if file exists
    if(!file.exists(ndvi_file)) {
      next
    }
    
    # Load NDVI raster for this year
    tryCatch({
      ndvi_raster <- rast(ndvi_file)
      
      # Extract NDVI values for the polygon
      ndvi_extract <- terra::extract(ndvi_raster, poly)
      ndvi_vals <- ndvi_extract[[2]]
      
      # Remove NAs
      ndvi_vals_clean <- ndvi_vals[!is.na(ndvi_vals)]
      
      # Calculate statistics
      if(length(ndvi_vals_clean) > 0) {
        ndvi_results$mean_ndvi[i] <- mean(ndvi_vals_clean)
        ndvi_results$median_ndvi[i] <- median(ndvi_vals_clean)
        ndvi_results$min_ndvi[i] <- min(ndvi_vals_clean)
        ndvi_results$max_ndvi[i] <- max(ndvi_vals_clean)
        ndvi_results$p25_ndvi[i] <- quantile(ndvi_vals_clean, 0.25)
        ndvi_results$p75_ndvi[i] <- quantile(ndvi_vals_clean, 0.75)
        ndvi_results$sd_ndvi[i] <- sd(ndvi_vals_clean)
        ndvi_results$n_pixels[i] <- length(ndvi_vals_clean)
      }
      
    }, error = function(e) {
      cat("Error processing polygon", polygon_idx, "year", year, ":", e$message, "\n")
    })
  }
  
  # Add period indicators
  ndvi_results$period <- ifelse(ndvi_results$year < project_year, "pre_treatment",
                                ifelse(ndvi_results$year == project_year, "treatment_year",
                                       "post_treatment"))
  ndvi_results$years_since_treatment <- ndvi_results$year - project_year
  
  # Store results
  all_ndvi_results[[polygon_idx]] <- ndvi_results
}

# Combine all results into one dataframe
cat("\nCombining results...\n")
all_ndvi_data <- bind_rows(all_ndvi_results)

cat("Total rows in combined data:", nrow(all_ndvi_data), "\n")
cat("Unique polygons processed:", length(unique(all_ndvi_data$polygon_id)), "\n\n")

# After creating all_ndvi_data, save it
cat("Saving treated polygon NDVI time series...\n")
dir.create("Data/Processed Data/Treated_Polygons", recursive = TRUE, showWarnings = FALSE)

write.csv(all_ndvi_data, 
          "Data/Processed Data/Treated_Polygons/treated_ndvi_timeseries.csv", 
          row.names = FALSE)

cat("Treated NDVI data saved to: Data/Processed Data/Treated_Polygons/treated_ndvi_timeseries.csv\n")

# =============================================================================
# CALCULATE SUMMARY STATISTICS
# =============================================================================

cat("=== SUMMARY STATISTICS ===\n\n")

# Overall NDVI change summary
summary_by_polygon <- all_ndvi_data %>%
  group_by(polygon_id, planting_date_reported) %>%
  summarize(
    # Pre-treatment statistics
    pre_mean_ndvi = mean(mean_ndvi[period == "pre_treatment"], na.rm = TRUE),
    pre_median_ndvi = median(median_ndvi[period == "pre_treatment"], na.rm = TRUE),
    
    # Post-treatment statistics
    post_mean_ndvi = mean(mean_ndvi[period == "post_treatment"], na.rm = TRUE),
    post_median_ndvi = median(median_ndvi[period == "post_treatment"], na.rm = TRUE),
    
    # Changes
    change_mean_ndvi = post_mean_ndvi - pre_mean_ndvi,
    change_median_ndvi = post_median_ndvi - pre_median_ndvi,
    
    # Sample sizes
    n_pre_years = sum(period == "pre_treatment" & !is.na(mean_ndvi)),
    n_post_years = sum(period == "post_treatment" & !is.na(mean_ndvi)),
    
    .groups = "drop"
  )

cat("Overall treatment effects:\n")
cat("Mean NDVI change:", mean(summary_by_polygon$change_mean_ndvi, na.rm = TRUE), "\n")
cat("Median NDVI change:", median(summary_by_polygon$change_mean_ndvi, na.rm = TRUE), "\n")
cat("% of polygons with positive change:", 
    sum(summary_by_polygon$change_mean_ndvi > 0, na.rm = TRUE) / nrow(summary_by_polygon) * 100, "%\n\n")

# =============================================================================
# CREATE SUMMARY VISUALIZATIONS
# =============================================================================

cat("Creating visualizations...\n")

# Plot 1: Average NDVI trajectory across all polygons
avg_trajectory <- all_ndvi_data %>%
  group_by(years_since_treatment) %>%
  summarize(
    mean_ndvi = mean(mean_ndvi, na.rm = TRUE),
    median_ndvi = median(median_ndvi, na.rm = TRUE),
    se_ndvi = sd(mean_ndvi, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  ) %>%
  filter(years_since_treatment >= -5 & years_since_treatment <= 5)

p1 <- ggplot(avg_trajectory, aes(x = years_since_treatment, y = mean_ndvi)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "red", linewidth = 1) +
  geom_ribbon(aes(ymin = mean_ndvi - 1.96*se_ndvi, 
                  ymax = mean_ndvi + 1.96*se_ndvi),
              alpha = 0.2, fill = "darkgreen") +
  geom_line(linewidth = 1, color = "darkgreen") +
  geom_point(size = 2, color = "darkgreen") +
  labs(
    title = "Average NDVI Trajectory Around Afforestation Treatment",
    subtitle = "Vertical line indicates treatment year",
    x = "Years Since Treatment",
    y = "Mean NDVI",
    caption = "Error bands show 95% confidence intervals"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    axis.title = element_text(face = "bold")
  )

print(p1)
ggsave("Output/Figure/ghana_ndvi_average_trajectory.png", p1, width = 10, height = 6, dpi = 300)

# Plot 2: Distribution of NDVI changes
p2 <- ggplot(summary_by_polygon, aes(x = change_mean_ndvi)) +
  geom_histogram(bins = 50, fill = "darkgreen", alpha = 0.7, color = "black") +
  geom_vline(xintercept = 0, color = "red", linetype = "dashed", linewidth = 1) +
  geom_vline(xintercept = median(summary_by_polygon$change_mean_ndvi, na.rm = TRUE), 
             color = "blue", linetype = "dashed", linewidth = 1) +
  labs(
    title = "Distribution of NDVI Changes After Afforestation",
    x = "Change in Mean NDVI (Post - Pre)",
    y = "Number of Polygons",
    caption = "Red line = 0 (no change), Blue line = median change"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    axis.title = element_text(face = "bold")
  )

print(p2)
ggsave("Output/Figure/ghana_ndvi_change_distribution.png", p2, width = 10, height = 6, dpi = 300)

# Plot 3: NDVI change by project year
p3 <- summary_by_polygon %>%
  ggplot(aes(x = factor(planting_date_reported), y = change_mean_ndvi)) +
  geom_boxplot(fill = "lightgreen", alpha = 0.7) +
  geom_hline(yintercept = 0, color = "red", linetype = "dashed") +
  labs(
    title = "NDVI Changes by Project Year",
    x = "Planting Year",
    y = "Change in Mean NDVI"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    axis.title = element_text(face = "bold"),
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

print(p3)
ggsave("Output/Figure/ghana_ndvi_change_by_year.png", p3, width = 10, height = 6, dpi = 300)

cat("\nVisualizations saved:\n")
cat("  - outputs/ndvi_average_trajectory.png\n")
cat("  - outputs/ndvi_change_distribution.png\n")
cat("  - outputs/ndvi_change_by_year.png\n")

cat("\n=============================================================================\n")
cat("ANALYSIS COMPLETE!\n")
cat("=============================================================================\n")


# =============================================================================
# 4. CREATE CONTROL GROUP THROUGH MATCHING
# =============================================================================

cat("\n=============================================================================\n")
cat("CREATING CONTROL GROUP\n")
cat("=============================================================================\n\n")

# -----------------------------------------------------------------------------
# Step 1: Load Ghana Boundary
# -----------------------------------------------------------------------------

cat("Step 1: Loading Ghana boundary...\n")

# Option A: If you have a Ghana boundary shapefile
ghana_boundary <- st_read("Data/Raw Data/Ghana Shp File/gha_admin0.shp") %>% select("iso3")

cat("Ghana boundary area:", st_area(ghana_boundary) / 1e6, "km²\n\n")

# -----------------------------------------------------------------------------
# Step 2: Create Treatment Exclusion Zone
# -----------------------------------------------------------------------------

cat("Step 2: Creating treatment exclusion zone...\n")

# Union all treated polygons
treated_union <- ghana_projects %>%
  st_union() %>%
  st_collection_extract("POLYGON") %>%
  st_make_valid()

# Add buffer around treated areas (optional, to avoid spillover)
buffer_distance <- 0.01  # degrees (~1km)
treated_exclusion <- st_buffer(treated_union, dist = buffer_distance)

# Now create eligible control area
eligible_control_area <- st_difference(ghana_boundary_single, treated_exclusion)

cat("Treated area:", st_area(treated_union) / 1e6, "km²\n")
cat("Eligible control area:", st_area(eligible_control_area) / 1e6, "km²\n\n")


# =============================================================================
# SAVE CHECKPOINT BEFORE CONTROL GROUP GENERATION
# =============================================================================


cat("\n=============================================================================\n")
cat("SAVING CHECKPOINT DATA\n")
cat("=============================================================================\n\n")

# Create checkpoint directory
dir.create("Data/Processed Data/R_checkpoints", recursive = TRUE, showWarnings = FALSE)

cat("Saving entire workspace...\n")

# Save all objects in the environment
save.image(file = "Data/Processed Data/R_checkpoints/construct_treat_and_control_ndvi_checkpoint.RData")

cat("\nCheckpoint saved successfully!\n")
cat("Location: Data/Processed Data/R_checkpoints/construct_treat_and_control_ndvi_checkpoint.RData\n\n")


# =============================================================================
# RESUME FROM CHECKPOINT
# =============================================================================

cat("\n=============================================================================\n")
cat("LOADING CHECKPOINT DATA\n")
cat("=============================================================================\n\n")

# Detect current user and set appropriate path
user <- Sys.info()[["user"]]

# Set custom library path only for wangy390
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

# Load required libraries
library(terra)
library(sf)
library(dplyr)
library(tidyr)
library(ggplot2)
library(data.table)
library(tools)
library(mapview)
library(geosphere)  # For geographic calculations

# Load checkpoint
cat("Loading workspace from checkpoint...\n")
load("Data/Processed Data/R_checkpoints/construct_treat_and_control_ndvi_checkpoint.RData")

cat("\nCheckpoint loaded successfully!\n")
cat("Objects restored:", length(ls()), "\n\n")

cat("=============================================================================\n")
cat("READY TO CONTINUE\n")
cat("=============================================================================\n\n")

# Load and combine Hansen forest data tiles
# Tree cover 2000
hansen_treecover2000_tile1 <- rast("Data/Raw Data/Hansen Global Forest Change/Hansen_GFC-2024-v1.12_treecover2000_10N_000E.tif")
hansen_treecover2000_tile2 <- rast("Data/Raw Data/Hansen Global Forest Change/Hansen_GFC-2024-v1.12_treecover2000_10N_010W.tif")

# Merge tiles
hansen_treecover2000 <- merge(hansen_treecover2000_tile1, hansen_treecover2000_tile2)

# -----------------------------------------------------------------------------
# Step 3: Define Similarity Calculation Function
# -----------------------------------------------------------------------------
# Yifan's comments: here we are only comparing the mean distance. we might try L2 norm with/without normalization, or Cosine similarity 

cat("Step 3: Defining similarity metrics...\n")

# Function to calculate similarity between treated and control polygon
calculate_similarity <- function(treated_poly, control_poly, 
                                 hansen_treecover, ndvi_baseline_raster) {
  
  # Ensure both are sf objects (not just sfc geometry)
  if(!inherits(treated_poly, "sf")) {
    treated_poly <- st_sf(geometry = treated_poly)
  }
  if(!inherits(control_poly, "sf")) {
    control_poly <- st_sf(geometry = control_poly)
  }
  
  # Extract baseline characteristics for treated polygon
  treated_treecover <- terra::extract(hansen_treecover, treated_poly, 
                                      fun = function(x) mean(x, na.rm = TRUE))[[2]]
  treated_ndvi <- terra::extract(ndvi_baseline_raster, treated_poly,
                                 fun = function(x) mean(x, na.rm = TRUE))[[2]]
  
  # Extract baseline characteristics for control polygon
  control_treecover <- terra::extract(hansen_treecover, control_poly,
                                      fun = function(x) mean(x, na.rm = TRUE))[[2]]
  control_ndvi <- terra::extract(ndvi_baseline_raster, control_poly,
                                 fun = function(x) mean(x, na.rm = TRUE))[[2]]
  
  # Handle NA values
  if(is.na(treated_treecover)) treated_treecover <- 0
  if(is.na(treated_ndvi)) treated_ndvi <- 0
  if(is.na(control_treecover)) control_treecover <- 0
  if(is.na(control_ndvi)) control_ndvi <- 0
  
  # Calculate Euclidean distance (normalized)
  treecover_dist <- abs(treated_treecover - control_treecover) / 100
  ndvi_dist <- abs(treated_ndvi - control_ndvi) / 1
  
  # Combined distance (lower = more similar)
  similarity_distance <- sqrt(treecover_dist^2 + ndvi_dist^2)
  
  return(list(
    distance = similarity_distance,
    treated_treecover = treated_treecover,
    treated_ndvi = treated_ndvi,
    control_treecover = control_treecover,
    control_ndvi = control_ndvi
  ))
}


# -----------------------------------------------------------------------------
# Step 4: Generate Control Pool for Each Treated Polygon
# -----------------------------------------------------------------------------

cat("\nStep 4: Generating control candidates...\n")

# Load baseline NDVI (average of pre-treatment years, e.g., 2000-2003)
cat("Loading baseline NDVI rasters...\n")
baseline_years <- 2000:2003
ndvi_baseline_list <- list()

for(year in baseline_years) {
  ndvi_file <- paste0("Data/Raw Data/NDVI/ndvi_ghana_", year, "-0000000000-0000000000.tif")
  if(file.exists(ndvi_file)) {
    ndvi_baseline_list[[as.character(year)]] <- rast(ndvi_file)
    cat("  Loaded NDVI for", year, "\n")
  } else {
    cat("  Warning: NDVI file not found for", year, "\n")
  }
}

# Calculate mean baseline NDVI
if(length(ndvi_baseline_list) > 0) {
  ndvi_baseline_raster <- mean(rast(ndvi_baseline_list))
  cat("Baseline NDVI computed from", length(ndvi_baseline_list), "years\n\n")
} else {
  stop("No baseline NDVI files found!")
}

# Parameters
n_candidates <- 100  # Number of random control candidates per treated polygon
top_percent <- 0.10  # Keep top 10%
n_keep <- ceiling(n_candidates * top_percent)

cat("Generating", n_candidates, "candidates per polygon, keeping top", n_keep, "\n\n")

# =============================================================================
# SEQUENTIAL PROCESSING WITH PROGRESS TRACKING
# =============================================================================

cat("Starting sequential control generation...\n")
cat("This will process", nrow(ghana_projects), "polygons\n\n")

# Create progress tracking
dir.create("Log", showWarnings = FALSE)
progress_file <- "Log/progress_construct_treat_and_control_ndvi.txt"
write("", file = progress_file)  # Create empty file

start_time <- Sys.time()

# Initialize list to store control pools
control_pools <- list()

# Loop through each treated polygon
for(i in 1:nrow(ghana_projects)) {
  
  # Progress indicator
  if(i %% 10 == 0) {
    elapsed <- difftime(Sys.time(), start_time, units = "mins")
    rate <- i / as.numeric(elapsed)
    remaining <- (nrow(ghana_projects) - i) / rate
    
    cat("Processing polygon", i, "of", nrow(ghana_projects), 
        sprintf("(%.1f%%)", i/nrow(ghana_projects)*100),
        "- Est. remaining:", sprintf("%.1f min", remaining), "\n")
  }
  
  # Log to file
  tryCatch({
    progress_line <- paste(Sys.time(), "- Polygon", i, "started")
    write(progress_line, file = progress_file, append = TRUE)
  }, error = function(e) {})
  
  treated_poly <- ghana_projects[i, ]
  treated_area <- st_area(treated_poly)
  
  # Generate control candidates
  control_candidates <- list()
  attempt <- 0
  max_attempts <- n_candidates * 10
  
  while(length(control_candidates) < n_candidates && attempt < max_attempts) {
    attempt <- attempt + 1
    
    tryCatch({
      random_point <- st_sample(eligible_control_area, size = 1)
      
      if(length(random_point) == 0) next
      
      radius <- sqrt(as.numeric(treated_area) / pi)
      control_poly_geom <- st_buffer(random_point, dist = radius)
      control_poly <- st_sf(geometry = control_poly_geom)
      
      overlaps <- st_intersects(control_poly, treated_exclusion, sparse = FALSE)
      
      if(!any(overlaps)) {
        similarity <- calculate_similarity(treated_poly, control_poly,
                                           hansen_treecover2000, ndvi_baseline_raster)
        
        # Check if similarity calculation returned valid values
        if(!is.na(similarity$distance)) {
          control_sf <- st_sf(
            control_id = length(control_candidates) + 1,
            treated_polygon_id = i,
            similarity_distance = similarity$distance,
            treated_treecover = similarity$treated_treecover,
            treated_ndvi = similarity$treated_ndvi,
            control_treecover = similarity$control_treecover,
            control_ndvi = similarity$control_ndvi,
            geometry = st_geometry(control_poly)
          )
          
          control_candidates[[length(control_candidates) + 1]] <- control_sf
        }
      }
      
    }, error = function(e) {
      NULL
    })
  }
  
  if(length(control_candidates) == 0) {
    cat("Warning: No valid control candidates found for polygon", i, "\n")
    # Log failure
    write(paste(Sys.time(), "- Polygon", i, "FAILED - no controls"), 
          file = progress_file, append = TRUE)
    next
  }
  
  # Combine all candidates for this treated polygon
  candidates_df <- do.call(rbind, control_candidates)
  
  # Rank by similarity and keep top 10%
  candidates_df <- candidates_df %>%
    arrange(similarity_distance) %>%
    slice_head(n = n_keep)
  
  # Store in control pool
  control_pools[[i]] <- candidates_df
  
  # Log completion
  write(paste(Sys.time(), "- Polygon", i, "completed -", 
              nrow(candidates_df), "controls generated"), 
        file = progress_file, append = TRUE)
}

end_time <- Sys.time()
elapsed_time <- difftime(end_time, start_time, units = "mins")

cat("\n=============================================================================\n")
cat("SEQUENTIAL PROCESSING COMPLETE\n")
cat("=============================================================================\n")
cat("Total time:", round(elapsed_time, 2), "minutes\n")
cat("Average time per polygon:", round(elapsed_time / nrow(ghana_projects) * 60, 2), "seconds\n\n")

# Remove NULL entries
control_pools_valid <- control_pools[!sapply(control_pools, is.null)]

cat("Results:\n")
cat("  Successfully processed:", length(control_pools_valid), "polygons\n")
cat("  Failed:", nrow(ghana_projects) - length(control_pools_valid), "polygons\n")

# Check which polygons failed
if(length(control_pools_valid) < nrow(ghana_projects)) {
  failed_indices <- which(sapply(control_pools, is.null))
  cat("  Failed polygon indices:", head(failed_indices, 20), 
      if(length(failed_indices) > 20) "..." else "", "\n")
}

# Combine all control pools
if(length(control_pools_valid) > 0) {
  all_controls <- bind_rows(control_pools_valid)
  
  cat("\nControl pool summary:\n")
  cat("  Total control polygons:", nrow(all_controls), "\n")
  cat("  Average controls per treated polygon:", 
      round(nrow(all_controls) / length(control_pools_valid), 1), "\n")
  cat("  Min similarity distance:", round(min(all_controls$similarity_distance, na.rm = TRUE), 4), "\n")
  cat("  Max similarity distance:", round(max(all_controls$similarity_distance, na.rm = TRUE), 4), "\n")
  cat("  Mean similarity distance:", round(mean(all_controls$similarity_distance, na.rm = TRUE), 4), "\n\n")
} else {
  stop("ERROR: No valid control polygons generated!")
}

cat("=============================================================================\n\n")

# Save progress log (don't delete it in sequential version so you can review)
cat("Progress log saved to:", progress_file, "\n")

cat("\n=============================================================================\n")
cat("SAVING CONTROL POLYGONS\n")
cat("=============================================================================\n\n")

# Create output directory
dir.create("Data/Processed Data/Control_Polygons", recursive = TRUE, showWarnings = FALSE)

# Save as GeoJSON (preserves geometry and is human-readable)
cat("Saving control polygons as GeoJSON...\n")
st_write(all_controls, 
         "Data/Processed Data/Control_Polygons/control_polygons.geojson", 
         delete_dsn = TRUE, 
         quiet = TRUE)

# -----------------------------------------------------------------------------
# Step 5: Extract NDVI Time Series for Control Polygons
# -----------------------------------------------------------------------------

cat("Step 5: Extracting NDVI time series for control polygons...\n")

# Similar to treated polygon extraction
years <- 2000:2024
all_control_ndvi <- list()

for(control_idx in 1:nrow(all_controls)) {
  
  if(control_idx %% 100 == 0) {
    cat("Processing control", control_idx, "of", nrow(all_controls), "\n")
  }
  
  control_poly <- all_controls[control_idx, ]
  treated_id <- control_poly$treated_polygon_id
  
  # Get project year from corresponding treated polygon
  project_year <- ghana_projects[treated_id, ][["planting_date_reported"]]
  
  # Convert integer64 to regular numeric/integer
  project_year <- as.numeric(project_year)
  
  # Initialize results
  ndvi_results <- data.frame(
    control_id = control_idx,
    treated_polygon_id = treated_id,
    planting_date_reported = project_year,
    year = years,
    mean_ndvi = NA,
    median_ndvi = NA,
    sd_ndvi = NA
  )
  
  # Extract NDVI for each year
  for(i in seq_along(years)) {
    year <- years[i]
    ndvi_file <- paste0("Data/Raw Data/NDVI/ndvi_ghana_", year, "-0000000000-0000000000.tif")
    
    if(file.exists(ndvi_file)) {
      tryCatch({
        ndvi_raster <- rast(ndvi_file)
        ndvi_extract <- terra::extract(ndvi_raster, control_poly)
        ndvi_vals <- ndvi_extract[[2]][!is.na(ndvi_extract[[2]])]
        
        if(length(ndvi_vals) > 0) {
          ndvi_results$mean_ndvi[i] <- mean(ndvi_vals)
          ndvi_results$median_ndvi[i] <- median(ndvi_vals)
          ndvi_results$sd_ndvi[i] <- sd(ndvi_vals)
        }
      }, error = function(e) {})
    }
  }
  
  # Add period indicators
  ndvi_results$period <- ifelse(ndvi_results$year < project_year, "pre_treatment",
                                ifelse(ndvi_results$year == project_year, "treatment_year",
                                       "post_treatment"))
  ndvi_results$years_since_treatment <- ndvi_results$year - project_year
  
  all_control_ndvi[[control_idx]] <- ndvi_results
}

# Combine all control NDVI data
control_ndvi_data <- bind_rows(all_control_ndvi)

cat("Control NDVI data extracted:", nrow(control_ndvi_data), "rows\n\n")

# Save as GeoJSON (preserves geometry and is human-readable)
cat("Saving control polygons as GeoJSON...\n")
st_write(control_ndvi_data, 
         "Data/Processed Data/Control_Polygons/control_polygons_ndvi.geojson", 
         delete_dsn = TRUE, 
         quiet = TRUE)

# -----------------------------------------------------------------------------
# Step 6: Calculate Treatment Effects with Matched Controls
# -----------------------------------------------------------------------------

cat("Step 6: Calculating treatment effects...\n")

# Calculate pre/post for controls
control_effects <- control_ndvi_data %>%
  group_by(control_id, treated_polygon_id) %>%
  summarize(
    pre_mean_ndvi = mean(mean_ndvi[period == "pre_treatment"], na.rm = TRUE),
    post_mean_ndvi = mean(mean_ndvi[period == "post_treatment"], na.rm = TRUE),
    control_change = post_mean_ndvi - pre_mean_ndvi,
    .groups = "drop"
  )

# Average control changes for each treated polygon
control_avg <- control_effects %>%
  group_by(treated_polygon_id) %>%
  summarize(
    avg_control_change = mean(control_change, na.rm = TRUE),
    se_control_change = sd(control_change, na.rm = TRUE) / sqrt(n()),
    n_controls = n(),
    .groups = "drop"
  )

# Merge with treated effects (from earlier analysis)
treatment_effects_matched <- summary_by_polygon %>%
  left_join(control_avg, by = c("polygon_id" = "treated_polygon_id")) %>%
  mutate(
    # Difference-in-differences estimate
    did_effect = change_mean_ndvi - avg_control_change,
    
    # Adjusted p-value (simple t-test approximation)
    t_stat = did_effect / se_control_change,
    significant = abs(t_stat) > 1.96  # 95% confidence
  )

cat("\n=== TREATMENT EFFECTS WITH MATCHED CONTROLS ===\n")
cat("Mean DiD effect:", mean(treatment_effects_matched$did_effect, na.rm = TRUE), "\n")
cat("Median DiD effect:", median(treatment_effects_matched$did_effect, na.rm = TRUE), "\n")
cat("% significant (p<0.05):", 
    sum(treatment_effects_matched$significant, na.rm = TRUE) / nrow(treatment_effects_matched) * 100, "%\n\n")

# -----------------------------------------------------------------------------
# Step 7: Save Results
# -----------------------------------------------------------------------------

cat("Step 7: Saving results...\n")

# Save control pool geometries
st_write(all_controls, "Data/Processed Data/Control_Polygons/control_pool_polygons.geojson", delete_dsn = TRUE)

# Save control NDVI time series
write.csv(control_ndvi_data, "Data/Processed Data/Control_Polygons/control_ndvi_timeseries.csv", row.names = FALSE)

# Save treatment effects with controls
write.csv(treatment_effects_matched, "Data/Processed Data/Control_Polygons/treatment_effects_with_controls.csv", row.names = FALSE)

cat("\nResults saved:\n")
cat("  - outputs/control_pool_polygons.geojson\n")
cat("  - outputs/control_ndvi_timeseries.csv\n")
cat("  - outputs/treatment_effects_with_controls.csv\n\n")

cat("=============================================================================\n")
cat("CONTROL GROUP CREATION COMPLETE!\n")
cat("=============================================================================\n")

