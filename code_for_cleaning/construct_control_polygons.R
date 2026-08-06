# =============================================================================
# GENERATE CONTROL POLYGONS FOR GHANA AFFORESTATION PROJECTS
# =============================================================================
# Purpose: Create random control polygons matched to treated polygons
# Output: Saves all control polygons (100 per treated) to GeoJSON
# =============================================================================

# Detect current user and set appropriate path
user <- Sys.info()[["user"]]

# Set custom library path only for wangy390
if (user == "wangy390") {
  .libPaths(c("H:/R/library", .libPaths()))
}

# Set working directory
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
library(data.table)

cat("\n=============================================================================\n")
cat("STEP 1: LOAD GHANA PROJECT POLYGONS\n")
cat("=============================================================================\n\n")

# Load description data
input_folder_descrip <- "Data/Processed Data/Global Afforestation Projects/Description"
descrip_files <- list.files(input_folder_descrip, 
                            pattern = "_description\\.csv$", 
                            full.names = TRUE)

all_descrip_data <- rbindlist(lapply(descrip_files, fread), fill = TRUE)
all_descrip_data <- all_descrip_data[is.na(planting_date_reported) | 
                                       (planting_date_reported >= 1990 & planting_date_reported <= 2030)]

ghana_data <- all_descrip_data[country == "Ghana"]
cat("Ghana projects loaded:", nrow(ghana_data), "\n\n")

# Load geometries
input_files <- c(
  "Data/Raw Data/Global Afforestation Projects/dataverse_files/updated_LoDIA_Reforestation_Dataset_NewWorld.csv",
  "Data/Raw Data/Global Afforestation Projects/dataverse_files/updated_LoDIA_Reforestation_Dataset_Antarctica.csv",
  "Data/Raw Data/Global Afforestation Projects/dataverse_files/updated_LoDIA_Reforestation_Dataset_OldWorld_Part1.csv",
  "Data/Raw Data/Global Afforestation Projects/dataverse_files/updated_LoDIA_Reforestation_Dataset_OldWorld_Part2.csv"
)

output_folder_geo <- "Data/Processed Data/Global Afforestation Projects/Geography"
ghana_geometry_list <- list()

for (file in input_files) {
 
  base_name <- sub("\\.csv$", "", basename(file))
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

cat("Total Ghana polygons:", nrow(ghana_projects), "\n\n")

# =============================================================================
# STEP 2: LOAD GHANA BOUNDARY AND CREATE EXCLUSION ZONE
# =============================================================================

cat("=============================================================================\n")
cat("STEP 2: PREPARE CONTROL AREA\n")
cat("=============================================================================\n\n")

# Load Ghana boundary
ghana_boundary <- st_read("Data/Raw Data/Ghana Shp File/gha_admin0.shp", quiet = TRUE) %>% 
  select("iso3") %>%
  st_union() %>%
  st_make_valid()

cat("Ghana boundary loaded\n")

# Create treatment exclusion zone
treated_union <- ghana_projects %>%
  st_union() %>%
  st_collection_extract("POLYGON") %>%
  st_make_valid()

buffer_distance <- 0.01  # ~1km
treated_exclusion <- st_buffer(treated_union, dist = buffer_distance)

# Create eligible control area
eligible_control_area <- st_difference(ghana_boundary, treated_exclusion)

cat("Treated area:", as.numeric(st_area(treated_union) / 1e6), "km²\n")
cat("Eligible control area:", as.numeric(st_area(eligible_control_area) / 1e6), "km²\n\n")

# =============================================================================
# STEP 3: GENERATE CONTROL POLYGONS
# =============================================================================

cat("=============================================================================\n")
cat("STEP 3: GENERATING CONTROL POLYGONS\n")
cat("=============================================================================\n\n")

n_candidates <- 100  # Generate 100 controls per treated polygon

cat("Generating", n_candidates, "control candidates per treated polygon\n")
cat("Total treated polygons:", nrow(ghana_projects), "\n\n")

# Create progress tracking
dir.create("Log", showWarnings = FALSE)
progress_file <- "Log/progress_generate_controls.txt"
write("", file = progress_file)

start_time <- Sys.time()
all_controls_list <- list()

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
  
  # Log progress
  write(paste(Sys.time(), "- Polygon", i, "started"), 
        file = progress_file, append = TRUE)
  
  treated_poly <- ghana_projects[i, ]
  treated_area <- st_area(treated_poly)
  
  # Generate control candidates
  control_candidates <- list()
  attempt <- 0
  max_attempts <- n_candidates * 10
  
  while(length(control_candidates) < n_candidates && attempt < max_attempts) {
    attempt <- attempt + 1
    
    tryCatch({
      # Sample random point
      random_point <- st_sample(eligible_control_area, size = 1)
      if(length(random_point) == 0) next
      
      # Create polygon of same size
      radius <- sqrt(as.numeric(treated_area) / pi)
      control_poly_geom <- st_buffer(random_point, dist = radius)
      control_poly <- st_sf(geometry = control_poly_geom)
      
      # Check overlap with treated areas
      overlaps <- st_intersects(control_poly, treated_exclusion, sparse = FALSE)
      
      if(!any(overlaps)) {
        # Valid control - store it
        control_sf <- st_sf(
          control_id = length(control_candidates) + 1,
          treated_polygon_id = i,
          geometry = st_geometry(control_poly)
        )
        
        control_candidates[[length(control_candidates) + 1]] <- control_sf
      }
    }, error = function(e) NULL)
  }
  
  if(length(control_candidates) > 0) {
    controls_df <- do.call(rbind, control_candidates)
    all_controls_list[[i]] <- controls_df
    
    write(paste(Sys.time(), "- Polygon", i, "completed -", 
                nrow(controls_df), "controls generated"), 
          file = progress_file, append = TRUE)
  } else {
    cat("Warning: No controls found for polygon", i, "\n")
    write(paste(Sys.time(), "- Polygon", i, "FAILED"), 
          file = progress_file, append = TRUE)
  }
}

end_time <- Sys.time()
elapsed_time <- difftime(end_time, start_time, units = "mins")

cat("\n=============================================================================\n")
cat("CONTROL GENERATION COMPLETE\n")
cat("=============================================================================\n")
cat("Total time:", round(elapsed_time, 2), "minutes\n\n")

# =============================================================================
# STEP 4: COMBINE AND SAVE CONTROL POLYGONS
# =============================================================================

cat("=============================================================================\n")
cat("STEP 4: SAVING CONTROL POLYGONS\n")
cat("=============================================================================\n\n")

# Combine all controls
all_controls_list <- all_controls_list[!sapply(all_controls_list, is.null)]
all_controls <- bind_rows(all_controls_list)

cat("Total control polygons generated:", nrow(all_controls), "\n")
cat("Controls per treated polygon:", 
    round(nrow(all_controls) / nrow(ghana_projects), 1), "\n\n")

# Create output directory
dir.create("Data/Processed Data/Control_Polygons", recursive = TRUE, showWarnings = FALSE)

# Save as GeoJSON
output_file <- "Data/Processed Data/Control_Polygons/all_control_polygons.geojson"
st_write(all_controls, output_file, delete_dsn = TRUE, quiet = TRUE)

cat("Saved to:", output_file, "\n")
cat("File size:", round(file.info(output_file)$size / 1e6, 2), "MB\n\n")

cat("=============================================================================\n")
cat("CONTROL POLYGON GENERATION COMPLETE!\n")
cat("=============================================================================\n")
