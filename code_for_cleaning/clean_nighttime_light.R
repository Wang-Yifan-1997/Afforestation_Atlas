# =============================================================================
# PROCESS NIGHTTIME LIGHTS DATA - CROP TO AFRICA AND SAVE
# =============================================================================

# Detect current user and set appropriate path
user <- Sys.info()[["user"]]

# Set custom library path only for wangy390
if (user == "wangy390") {
  .libPaths(c("H:/R/library", .libPaths()))
}

# Load required libraries
library(terra)
library(sf)

# =============================================================================
# SET PATHS
# =============================================================================

# Base path for nightlights
nightlight_path <- switch(user,
                          "wangy390" = "D:/Dropbox/Afforestation_Transition/Data/Raw Data/Global Nighttime Light",
                          "WANGY390" = "D:/Dropbox/Afforestation_Transition/Data/Raw Data/Global Nighttime Light",
                          "wyf19"    = "C:/Users/wyf19/Dropbox/Afforestation_Transition/Data/Raw Data/Global Nighttime Light",
                          stop("Unknown user. Please add your path to the script.")
)

# Output path
output_nightlight_path <- switch(user,
                                 "wangy390" = "D:/Dropbox/Afforestation_Transition/Data/Processed Data/Nightlights",
                                 "WANGY390" = "D:/Dropbox/Afforestation_Transition/Data/Processed Data/Nightlights",
                                 "wyf19"    = "C:/Users/wyf19/Dropbox/Afforestation_Transition/Data/Processed Data/Nightlights",
                                 stop("Unknown user. Please add your path to the script.")
)

# Create output directory if doesn't exist
dir.create(output_nightlight_path, recursive = TRUE, showWarnings = FALSE)

# =============================================================================
# FIND ALL NIGHTLIGHT FILES
# =============================================================================

# Get all .gz files
gz_files <- list.files(nightlight_path, 
                       pattern = "\\.tif\\.gz$", 
                       full.names = TRUE)

cat("Found", length(gz_files), "nightlight files:\n")
print(basename(gz_files))
cat("\n")

# =============================================================================
# DEFINE AFRICA EXTENT
# =============================================================================

africa_extent <- ext(-20, 55, -35, 40)  # (xmin, xmax, ymin, ymax)

# =============================================================================
# PROCESS EACH FILE
# =============================================================================

cat("Starting processing...\n")
cat("=============================================================================\n\n")

for(i in seq_along(gz_files)) {
  
  gz_file <- gz_files[i]
  
  # Extract year from filename
  year <- gsub(".*_(\\d{4})_.*", "\\1", basename(gz_file))
  
  cat("Processing file", i, "of", length(gz_files), "- Year:", year, "\n")
  cat("Input file:", basename(gz_file), "\n")
  
  # Read nightlights using GDAL virtual file system (no unzipping needed)
  tryCatch({
    
    nightlights <- rast(paste0("/vsigzip/", gz_file))
    cat("  Loaded raster: ", dim(nightlights)[1], "x", dim(nightlights)[2], "pixels\n")
    
    # Crop to Africa
    nightlights_africa <- crop(nightlights, africa_extent)
    cat("  Cropped to Africa: ", dim(nightlights_africa)[1], "x", dim(nightlights_africa)[2], "pixels\n")
    
    # Define output file
    output_file <- file.path(output_nightlight_path, 
                             paste0("nightlights_", year, "_africa.tif"))
    
    # Save to TIF file
    writeRaster(nightlights_africa, 
                output_file, 
                overwrite = TRUE,
                gdal = c("COMPRESS=LZW"))
    
    # Report results
    file_size_mb <- round(file.info(output_file)$size / 1e6, 2)
    cat("  Saved to:", basename(output_file), "\n")
    cat("  File size:", file_size_mb, "MB\n")
    cat("  Status: SUCCESS\n\n")
    
  }, error = function(e) {
    cat("  ERROR processing", basename(gz_file), ":", e$message, "\n\n")
  })
}

# =============================================================================
# SUMMARY
# =============================================================================

cat("=============================================================================\n")
cat("PROCESSING COMPLETE\n")
cat("=============================================================================\n\n")

# List all processed files
processed_files <- list.files(output_nightlight_path, 
                              pattern = "nightlights_.*_africa\\.tif$", 
                              full.names = TRUE)

cat("Total files processed:", length(processed_files), "\n")
cat("Output directory:", output_nightlight_path, "\n")
cat("Total output size:", 
    round(sum(file.info(processed_files)$size) / 1e6, 2), "MB\n\n")

cat("Processed years:\n")
years <- gsub(".*nightlights_(\\d{4})_africa\\.tif", "\\1", basename(processed_files))
print(sort(years))

cat("\nAll nightlight files successfully processed!\n")