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

library(data.table)
library(sf)


cat("Current working directory:", getwd(), "\n\n")


#######################################################
#######################################################
################CLEAN THE RAW DATA#####################
#######################################################
#######################################################
# Define input files
input_files <- c(
  "Data/Raw Data/Global Afforestation Projects/dataverse_files/updated_LoDIA_Reforestation_Dataset_NewWorld.csv",
  "Data/Raw Data/Global Afforestation Projects/dataverse_files/updated_LoDIA_Reforestation_Dataset_Antarctica.csv",
  "Data/Raw Data/Global Afforestation Projects/dataverse_files/updated_LoDIA_Reforestation_Dataset_OldWorld_Part1.csv",
  "Data/Raw Data/Global Afforestation Projects/dataverse_files/updated_LoDIA_Reforestation_Dataset_OldWorld_Part2.csv"
)

# Define output folders
output_folder_descrip <- "Data/Processed Data/Global Afforestation Projects/Description"
output_folder_geo <- "Data/Processed Data/Global Afforestation Projects/Geography"

# Create output folders if they don't exist
dir.create(output_folder_descrip, recursive = TRUE, showWarnings = FALSE)
dir.create(output_folder_geo, recursive = TRUE, showWarnings = FALSE)

# Loop through each file
for (file in input_files) {
  cat("==================================================\n")
  cat("Processing file:", file, "\n")
  cat("==================================================\n")
  
  # Read the data
  afforestation_projects <- fread(file)
  
  cat("Total rows:", nrow(afforestation_projects), "\n")
  cat("Empty geometries:", sum(afforestation_projects$geometry == ""), "\n")
  cat("NA geometries:", sum(is.na(afforestation_projects$geometry)), "\n\n")
  
  # Get base filename without extension
  base_name <- tools::file_path_sans_ext(basename(file))
  
  # ========================================
  # Part 1: Geography data with geometry
  # ========================================
  cat("Processing geography data (with geometry)...\n")
  
  # Select columns with geometry
  afforestation_projects_geo <- afforestation_projects[, .(
    site_id_created,
    project_id_reported,
    site_id_reported,
    geometry
  )]
  
  # ========================================
  # Version 1: Save ALL data as CSV (no filtering)
  # ========================================
  cat("\nVersion 1: Saving complete geography data as CSV (no filtering)...\n")
  output_file_geo_csv <- file.path(output_folder_geo, paste0(base_name, "_geography_complete.csv"))
  fwrite(afforestation_projects_geo, output_file_geo_csv)
  cat("Saved complete geography CSV:", output_file_geo_csv, "\n")
  cat("Total rows (including empty geometries):", nrow(afforestation_projects_geo), "\n\n")
  
  # ========================================
  # Version 2: Filter and save POLYGONS ONLY as shapefile
  # ========================================
  cat("Version 2: Processing and saving POLYGONS ONLY as shapefile...\n")
  
  # Remove rows with empty or NA geometries
  afforestation_projects_geo_clean <- afforestation_projects_geo[
    !is.na(geometry) & geometry != ""
  ]
  
  cat("Rows after removing empty geometries:", nrow(afforestation_projects_geo_clean), "\n")
  
  # Check for GEOMETRYCOLLECTION
  geom_types <- substr(afforestation_projects_geo_clean$geometry, 1, 20)
  cat("GEOMETRYCOLLECTION count:", sum(grepl("GEOMETRYCOLLECT", geom_types)), "\n")
  cat("Invalid numeric entries:", sum(grepl("^[0-9]", geom_types)), "\n")
  
  # Filter to keep ONLY POLYGONS and MULTIPOLYGONS
  afforestation_projects_geo_polygon <- afforestation_projects_geo_clean[
    grepl("^(POLYGON|MULTIPOLYGON)", geometry)
  ]
  
  cat("Rows after filtering to POLYGONS only:", nrow(afforestation_projects_geo_polygon), "\n\n")
  
  # Convert to sf object
  cat("Converting polygons to sf object...\n")
  afforestation_projects_sf_polygon <- st_as_sf(afforestation_projects_geo_polygon, 
                                                wkt = "geometry", 
                                                crs = 4326)
  
  cat("Conversion successful!\n")
  cat("Geometry types:", paste(unique(st_geometry_type(afforestation_projects_sf_polygon)), collapse = ", "), "\n")
  cat("Total polygon features:", nrow(afforestation_projects_sf_polygon), "\n\n")
  
  # Save polygons as shapefile
  output_file_geo_shp <- file.path(output_folder_geo, paste0(base_name, "_geography_polygon.shp"))
  st_write(afforestation_projects_sf_polygon, output_file_geo_shp, delete_layer = TRUE, quiet = TRUE)
  cat("Saved polygon shapefile:", output_file_geo_shp, "\n")
  cat("Total rows:", nrow(afforestation_projects_sf_polygon), "\n\n")
  
  # ========================================
  # Part 2: Description data (all except geometry)
  # ========================================
  cat("Processing description data (without geometry)...\n")
  
  # Get all column names except geometry and project_description_reported
  descrip_columns <- setdiff(names(afforestation_projects), 
                             c("geometry", "project_description_reported", "site_description_reported"))
  afforestation_projects_descrip <- afforestation_projects[, ..descrip_columns]
  
  # Save as CSV
  output_file_descrip <- file.path(output_folder_descrip, paste0(base_name, "_description.csv"))
  fwrite(afforestation_projects_descrip, output_file_descrip)
  cat("Saved description file:", output_file_descrip, "\n")
  cat("Total rows:", nrow(afforestation_projects_descrip), "\n\n")
}

cat("==================================================\n")
cat("All files processed successfully!\n")
cat("==================================================\n")


#######################################################
#######################################################
########READ AND CLEAR THE DESCRIPTIVE DATA############
#######################################################
#######################################################


# Remove all objects from environment
rm(list = ls())

# Free unused memory (garbage collection)
gc()

library(data.table)

# Detect current user and set appropriate path
user <- Sys.info()["user"]
if (user == "wyf19") {
  setwd("C:/Users/wyf19/Dropbox/Afforestation_Transition")
} else if (user == "wangy390") {
  setwd("D:/Dropbox/Afforestation_Transition")
} else {
  stop("Unknown user. Please add your path to the script.")
}


cat("Current working directory:", getwd(), "\n\n")

# Define input folder
input_folder_descrip <- "Data/Processed Data/Global Afforestation Projects/Description"

# Get all description CSV files
descrip_files <- list.files(input_folder_descrip, 
                            pattern = "_description\\.csv$", 
                            full.names = TRUE)

cat("Found", length(descrip_files), "description files:\n")
print(descrip_files)
cat("\n")

# Read and combine all description files
all_descrip_data <- rbindlist(lapply(descrip_files, fread), fill = TRUE)

cat("Total rows in all description files:", nrow(all_descrip_data), "\n")
cat("Total columns:", ncol(all_descrip_data), "\n\n")

# Check unique host
cat("Unique host names in dataset:\n")
print(sort(unique(all_descrip_data$host_name)))
cat("\n")

# Check unique countries
cat("Unique countries in dataset:\n")
print(sort(unique(all_descrip_data$country)))
country_name_df <- data.frame(country = unique(all_descrip_data$country))
cat("\n")

# Define African countries, WE NEED SOME RA TO GO THROUGH THIS LIST TO SEE IF IT IS CORRECT
african_countries <- c(
  "Algeria", "Angola", "Benin", "Botswana", "Burkina Faso", "Burundi",
  "Cameroon", "Central African Rep.", "Chad", "Congo", 
  "Dem. Rep. Congo", "Egypt", "Eritrea", "Ethiopia", "Gabon", "Gambia",
  "Ghana", "Guinea", "Guinea-Bissau", "Côte d'Ivoire", "Kenya", "Lesotho",
  "Liberia", "Libya", "Madagascar", "Malawi", "Mali", "Mauritania",
  "Morocco", "Mozambique", "Namibia", "Niger", "Nigeria", "Rwanda",
  "Senegal", "Sierra Leone", "Somalia", "South Africa", "S. Sudan", "Sudan",
  "Tanzania", "Togo", "Uganda", "Zambia", "Zimbabwe"
)

# Filter for African countries
africa_data <- all_descrip_data[country %in% african_countries]

cat("Total rows for African countries:", nrow(africa_data), "\n")
cat("African countries in dataset:\n")
print(sort(unique(africa_data$country)))
cat("\n")

# Summary by African country
africa_summary <- africa_data[, .N, by = country][order(-N)]
cat("Projects per African country:\n")
print(africa_summary)
cat("\n")

library(sf)
library(terra)
library(data.table)
library(dplyr)
library(tools)
library(mapview)
library(stars)
# -------------------------------------------------------------
# 1. Ghana subset from all project descriptions
# -------------------------------------------------------------
ghana_data <- all_descrip_data[country == "Ghana"]

# -------------------------------------------------------------
# 2. List of geometry CSV input files
# -------------------------------------------------------------
input_files <- c(
  "Data/Raw Data/Global Afforestation Projects/dataverse_files/updated_LoDIA_Reforestation_Dataset_NewWorld.csv",
  "Data/Raw Data/Global Afforestation Projects/dataverse_files/updated_LoDIA_Reforestation_Dataset_Antarctica.csv",
  "Data/Raw Data/Global Afforestation Projects/dataverse_files/updated_LoDIA_Reforestation_Dataset_OldWorld_Part1.csv",
  "Data/Raw Data/Global Afforestation Projects/dataverse_files/updated_LoDIA_Reforestation_Dataset_OldWorld_Part2.csv"
)

output_folder_geo <- "Data/Processed Data/Global Afforestation Projects/Geography"

# -------------------------------------------------------------
# 3. Loop: read shapefile for each dataset & merge with Ghana
# -------------------------------------------------------------

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

# -------------------------------------------------------------
# 4. Combine all matched Ghana geometries into one sf object
# -------------------------------------------------------------
ghana_geometry_all <- do.call(rbind, ghana_geometry_list)
mapview(ghana_geometry_all)
ghana_geometry_sample <- ghana_geometry_all %>% 
  filter(st_d_cr == "897667")
mapview(ghana_geometry_sample)

# Drop geometry and save as CSV
ghana_geometry_sample_csv <- ghana_geometry_sample %>%
  st_drop_geometry()

# Save to CSV
write.csv(
  ghana_geometry_sample_csv,
  "Data/Temp Data/ghana_geometry_sample.csv",
  row.names = FALSE
)

ghana_single_mp <- ghana_geometry_all %>%
  st_union() %>%        # merge all geometries
  st_make_valid()       # fix possible geometry issues
plot(ghana_single_mp)

st_write(
  ghana_single_mp,
  "Data/Processed Data/Global Afforestation Projects/Geography/ghana_afforestation_polygons.kml",
  driver = "KML",
  delete_dsn = TRUE
)


###############################################################################
###############################################################################
############ Additional Cleaning Step to Remove Overlapping Areas  ############
###############################################################################
###############################################################################

# Remove all objects from environment
rm(list = ls())

# Free unused memory (garbage collection)
gc()

library(data.table)

# Detect current user and set appropriate path
current_user <- Sys.info()["user"]
if (current_user == "wyf19") {
  setwd("C:/Users/wyf19/Dropbox/Afforestation_Transition")
} else {
  stop("Unknown user. Please add your path to the script.")
}

cat("Current working directory:", getwd(), "\n\n")

# Define input folder
input_folder_descrip <- "Data/Processed Data/Global Afforestation Projects/Description"

# Get all description CSV files
descrip_files <- list.files(input_folder_descrip, 
                            pattern = "_description\\.csv$", 
                            full.names = TRUE)

cat("Found", length(descrip_files), "description files:\n")
print(descrip_files)
cat("\n")

# Read and combine all description files
all_descrip_data <- rbindlist(lapply(descrip_files, fread), fill = TRUE)

cat("Total rows in all description files:", nrow(all_descrip_data), "\n")
cat("Total columns:", ncol(all_descrip_data), "\n\n")

# Check unique host
cat("Unique host names in dataset:\n")
print(sort(unique(all_descrip_data$host_name)))
cat("\n")

# Check unique countries
cat("Unique countries in dataset:\n")
print(sort(unique(all_descrip_data$country)))

library(sf)
library(data.table)
library(dplyr)
library(tools)
library(mapview)

# -------------------------------------------------------------
# 2. List of geometry CSV input files
# -------------------------------------------------------------

input_files <- c(
  "Data/Raw Data/Global Afforestation Projects/dataverse_files/updated_LoDIA_Reforestation_Dataset_NewWorld.csv",
  "Data/Raw Data/Global Afforestation Projects/dataverse_files/updated_LoDIA_Reforestation_Dataset_Antarctica.csv",
  "Data/Raw Data/Global Afforestation Projects/dataverse_files/updated_LoDIA_Reforestation_Dataset_OldWorld_Part1.csv",
  "Data/Raw Data/Global Afforestation Projects/dataverse_files/updated_LoDIA_Reforestation_Dataset_OldWorld_Part2.csv"
)

output_folder_geo <- "Data/Processed Data/Global Afforestation Projects/Geography"

# Read all shapefiles into a list
geo_list <- lapply(input_files, function(file) {
  base_name <- file_path_sans_ext(basename(file))
  shp_path  <- file.path(output_folder_geo, paste0(base_name, "_geography_polygon.shp"))
  
  cat("→ Reading:", shp_path, "\n")
  sf_obj <- st_read(shp_path, quiet = TRUE)
  
  # (Optional) keep track of source file
  sf_obj$source_file <- base_name
  
  sf_obj
})

# Bind them into one sf object
geo_all <- do.call(rbind, geo_list)


