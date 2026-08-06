# =============================================================================
# PREPARE TREATED POLYGONS FOR GEE UPLOAD (AFRICAN COUNTRIES ONLY)
# =============================================================================
# Purpose: Export treated polygons from African countries as GEE-ready shapefiles
# Output:  - One shapefile per African country in Data/GEE_Upload/Africa/
#          - One combined shapefile for all of Africa
#          - Summary statistics for each country
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

library(sf)
library(dplyr)
library(data.table)
library(tools)

# =============================================================================
# DEFINE AFRICAN COUNTRIES
# =============================================================================

african_countries <- c(
  "Algeria", "Angola", "Benin", "Botswana", "Burkina Faso", "Burundi",
  "Cameroon", "Central African Rep.", "Chad", "Congo", 
  "Dem. Rep. Congo", "Egypt", "Eritrea", "Ethiopia", "Gabon", "Gambia",
  "Ghana", "Guinea", "Guinea-Bissau", "Côte d'Ivoire", "Ivory Coast", "Kenya", "Lesotho",
  "Liberia", "Libya", "Madagascar", "Malawi", "Mali", "Mauritania",
  "Morocco", "Mozambique", "Namibia", "Niger", "Nigeria", "Rwanda",
  "Senegal", "Sierra Leone", "Somalia", "South Africa", "S. Sudan", "Sudan",
  "Tanzania", "Togo", "Tunisia", "Uganda", "Zambia", "Zimbabwe",
  "Equatorial Guinea", "Swaziland", "Eswatini"
)

# =============================================================================
# STEP 1: LOAD ALL DESCRIPTION DATA
# =============================================================================

cat("=============================================================================\n")
cat("STEP 1: LOADING DESCRIPTION DATA\n")
cat("=============================================================================\n\n")

input_folder_descrip <- "Data/Processed Data/Global Afforestation Projects/Description"
descrip_files <- list.files(input_folder_descrip, 
                            pattern = "_description\\.csv$", 
                            full.names = TRUE)

all_descrip_data <- rbindlist(lapply(descrip_files, fread), fill = TRUE)

# Filter valid planting years
all_descrip_data <- all_descrip_data[is.na(planting_date_reported) | 
                                       (planting_date_reported >= 1990 & 
                                          planting_date_reported <= 2030)]

cat("Total projects loaded:", nrow(all_descrip_data), "\n")

# Filter for African countries
africa_descrip_data <- all_descrip_data[country %in% african_countries]

cat("African projects:", nrow(africa_descrip_data), "\n")
cat("African countries found:", length(unique(africa_descrip_data$country)), "\n\n")

# =============================================================================
# STEP 2: LOAD ALL GEOGRAPHY DATA
# =============================================================================

cat("=============================================================================\n")
cat("STEP 2: LOADING GEOGRAPHY DATA\n")
cat("=============================================================================\n\n")

input_files <- c(
  "Data/Raw Data/Global Afforestation Projects/dataverse_files/updated_LoDIA_Reforestation_Dataset_NewWorld.csv",
  "Data/Raw Data/Global Afforestation Projects/dataverse_files/updated_LoDIA_Reforestation_Dataset_Antarctica.csv",
  "Data/Raw Data/Global Afforestation Projects/dataverse_files/updated_LoDIA_Reforestation_Dataset_OldWorld_Part1.csv",
  "Data/Raw Data/Global Afforestation Projects/dataverse_files/updated_LoDIA_Reforestation_Dataset_OldWorld_Part2.csv"
)

output_folder_geo <- "Data/Processed Data/Global Afforestation Projects/Geography"
africa_geometry_list <- list()

for (file in input_files) {
  base_name <- tools::file_path_sans_ext(basename(file))
  shp_path <- file.path(output_folder_geo, paste0(base_name, "_geography_polygon.shp"))
  
  if (!file.exists(shp_path)) {
    cat("Warning: Shapefile not found:", shp_path, "\n")
    next
  }
  
  cat("Loading:", basename(shp_path), "\n")
  
  geo_sf <- st_read(shp_path, quiet = TRUE) %>%
    mutate(
      st_d_cr = as.character(st_d_cr),
      prjct__ = as.character(prjct__),
      st_d_rp = as.character(st_d_rp)
    )
  
  # Merge with African description data only
  merged_sf <- geo_sf %>%
    left_join(africa_descrip_data,
              by = c("st_d_cr" = "site_id_created",
                     "prjct__" = "project_id_reported",
                     "st_d_rp" = "site_id_reported")) %>%
    filter(!is.na(country) & country %in% african_countries)
  
  if (nrow(merged_sf) > 0) {
    africa_geometry_list[[base_name]] <- merged_sf
    cat("  Found", nrow(merged_sf), "African polygons\n")
  }
}

# Combine all geometry data
africa_projects <- do.call(rbind, africa_geometry_list)
rownames(africa_projects) <- NULL

cat("\nTotal African projects with geometry:", nrow(africa_projects), "\n\n")

# =============================================================================
# STEP 3: PREPARE DATA FOR GEE
# =============================================================================

cat("=============================================================================\n")
cat("STEP 3: PREPARING DATA FOR GEE\n")
cat("=============================================================================\n\n")

# Add global polygon ID
africa_projects$polygon_id <- 1:nrow(africa_projects)

# Select key fields for GEE
africa_projects_clean <- africa_projects %>%
  select(
    polygon_id,
    country,
    planting_date_reported,
    st_d_cr,
    prjct__,
    st_d_rp,
    geometry
  ) %>%
  rename(
    poly_id = polygon_id,
    plant_yr = planting_date_reported,
    site_id = st_d_cr,
    proj_id = prjct__,
    site_rpt = st_d_rp
  )

# Transform to WGS84 (required for GEE)
africa_projects_wgs84 <- st_transform(africa_projects_clean, 4326)

cat("Data prepared for GEE export\n")
cat("CRS:", st_crs(africa_projects_wgs84)$input, "\n\n")

# =============================================================================
# STEP 4: EXPORT BY COUNTRY
# =============================================================================

cat("=============================================================================\n")
cat("STEP 4: EXPORTING SHAPEFILES BY AFRICAN COUNTRY\n")
cat("=============================================================================\n\n")

# Create output directory
output_dir <- "Data/GEE_Upload/Africa"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Get unique African countries
countries <- africa_projects_wgs84 %>%
  st_drop_geometry() %>%
  group_by(country) %>%
  summarise(
    n_polygons = n(),
    min_year = min(plant_yr, na.rm = TRUE),
    max_year = max(plant_yr, na.rm = TRUE),
    mean_year = round(mean(plant_yr, na.rm = TRUE), 1)
  ) %>%
  arrange(desc(n_polygons))

# Print country summary
cat("African countries to export:\n")
print(countries, n = Inf)
cat("\n")

# Export each country
export_summary <- data.frame()

for (i in 1:nrow(countries)) {
  country_name <- countries$country[i]
  n_poly <- countries$n_polygons[i]
  
  cat(sprintf("Exporting %s (%d polygons)...", country_name, n_poly))
  
  # Filter country data
  country_data <- africa_projects_wgs84 %>%
    filter(country == country_name)
  
  # Add country-specific polygon ID
  country_data <- country_data %>%
    arrange(poly_id) %>%
    mutate(ctry_id = row_number())
  
  # Create clean filename
  country_clean <- gsub("[^A-Za-z0-9]", "_", country_name)
  country_clean <- gsub("_+", "_", country_clean)
  country_clean <- tolower(country_clean)
  
  output_file <- file.path(output_dir, paste0(country_clean, "_treated_polygons.shp"))
  
  # Export shapefile
  tryCatch({
    st_write(country_data, output_file, delete_dsn = TRUE, quiet = TRUE)
    cat(" ✓\n")
    
    export_summary <- rbind(export_summary, data.frame(
      country = country_name,
      filename = basename(output_file),
      n_polygons = n_poly,
      exported = TRUE,
      stringsAsFactors = FALSE
    ))
  }, error = function(e) {
    cat(" ✗ ERROR:", e$message, "\n")
    
    export_summary <- rbind(export_summary, data.frame(
      country = country_name,
      filename = NA,
      n_polygons = n_poly,
      exported = FALSE,
      stringsAsFactors = FALSE
    ))
  })
}

cat("\n")

# =============================================================================
# STEP 5: EXPORT ONE COMBINED AFRICA SHAPEFILE
# =============================================================================

cat("=============================================================================\n")
cat("STEP 5: EXPORTING COMBINED AFRICA SHAPEFILE\n")
cat("=============================================================================\n\n")

# Export all African countries in one file
combined_file <- file.path(output_dir, "africa_all_treated_polygons.shp")

st_write(africa_projects_wgs84, combined_file, delete_dsn = TRUE, quiet = TRUE)

cat("Combined Africa shapefile saved:", basename(combined_file), "\n")
cat("Total polygons:", nrow(africa_projects_wgs84), "\n\n")

# =============================================================================
# STEP 6: SAVE SUMMARY AND COUNTRY LIST
# =============================================================================

cat("=============================================================================\n")
cat("STEP 6: SAVING SUMMARY FILES\n")
cat("=============================================================================\n\n")

# Save export summary
write.csv(export_summary, 
          file.path(output_dir, "africa_export_summary.csv"), 
          row.names = FALSE)

# Save country statistics
write.csv(countries, 
          file.path(output_dir, "africa_country_statistics.csv"), 
          row.names = FALSE)

# Create a simple text file with country names
country_list <- countries %>%
  arrange(country) %>%
  pull(country)

writeLines(country_list, 
           file.path(output_dir, "africa_country_list.txt"))

cat("Summary files saved:\n")
cat("  - africa_export_summary.csv\n")
cat("  - africa_country_statistics.csv\n")
cat("  - africa_country_list.txt\n")
cat("  - africa_all_treated_polygons.shp (combined)\n\n")

cat("=============================================================================\n")
cat("EXPORT COMPLETE!\n")
cat("=============================================================================\n\n")

cat("Summary:\n")
cat("  African countries:", nrow(countries), "\n")
cat("  Total polygons:", nrow(africa_projects_wgs84), "\n")
cat("  Output directory:", output_dir, "\n")