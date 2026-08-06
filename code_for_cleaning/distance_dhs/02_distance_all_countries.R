# Calculate distance from each DHS cluster to the nearest afforestation polygon
# in the same country, for every country-year in both 4.19 and 4.20.
#
# Requires: 00_split_afforestation_by_country.R must have been run first.
# Output  : Data/Processed Data/DHS/distance/<Country>_<Year>_dist_to_afforestation.csv

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

# Disable s2 spherical engine: some afforestation polygons have near-duplicate
# edges that s2 rejects. We project to a metric CRS before distance calc anyway,
# so planar GEOS gives identical results without needing lwgeom.
sf_use_s2(FALSE)

cat("Working directory:", getwd(), "\n\n")

# ─────────────────────────────────────────────────────────────
# 1. Configuration
# ─────────────────────────────────────────────────────────────

dhs_roots <- c(
  "Data/DHS data/4.19",
  "Data/DHS data/4.20"
)

aff_dir <- "Data/Processed Data/Global Afforestation Projects/by_country"
out_dir <- "Data/Processed Data/DHS/distance"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Maps DHS folder country name → gpkg file stem (only where names differ)
country_crosswalk <- c(
  "Congo Democratic Republic" = "Dem_Rep_Congo",
  "Cote d'Ivoire"             = "C_te_d_Ivoire",
  "Central African Republic"  = "Central_African_Rep"
)

# Convert any string to the same safe filename stem used in 00_split script
to_safe <- function(x) {
  x <- gsub("[^a-zA-Z0-9]", "_", x)
  x <- gsub("_+", "_", x)
  gsub("^_|_$", "", x)
}

# ─────────────────────────────────────────────────────────────
# 2. Discover all DHS GPS shapefiles
# ─────────────────────────────────────────────────────────────

all_shp <- unlist(lapply(dhs_roots, function(root) {
  list.files(root, pattern = "\\.shp$", recursive = TRUE, full.names = TRUE)
}))

cat("Total DHS shapefiles found:", length(all_shp), "\n\n")

# Parse country and year from path relative to the known root.
# This handles extra nesting (e.g. Burkina Faso/1998-99/BFGE32FL/BFGE32FL.shp)
# by anchoring on the root rather than counting from the filename end.
parse_path <- function(path, roots) {
  path_norm <- normalizePath(path, winslash = "/", mustWork = FALSE)
  for (root in roots) {
    root_norm <- normalizePath(root, winslash = "/", mustWork = FALSE)
    if (startsWith(path_norm, root_norm)) {
      rel   <- substring(path_norm, nchar(root_norm) + 2)   # strip root + "/"
      parts <- strsplit(rel, "/")[[1]]
      return(list(country = parts[1], year = parts[2]))
    }
  }
  stop("Path not under any known root: ", path)
}

meta <- lapply(all_shp, function(p) {
  m <- parse_path(p, dhs_roots)
  data.frame(shp = p, country = m$country, year = m$year,
             stringsAsFactors = FALSE)
})
meta_df <- do.call(rbind, meta)

cat("Country-year combinations:\n")
print(table(meta_df$country))
cat("\n")

# ─────────────────────────────────────────────────────────────
# 3. Loop: country → load afforestation once, then all years
# ─────────────────────────────────────────────────────────────

skipped  <- character(0)
processed <- 0

for (ctry in sort(unique(meta_df$country))) {

  # Resolve afforestation gpkg path
  if (ctry %in% names(country_crosswalk)) {
    gpkg_stem <- country_crosswalk[[ctry]]
  } else {
    gpkg_stem <- to_safe(ctry)
  }
  gpkg_path <- file.path(aff_dir, paste0(gpkg_stem, ".gpkg"))

  if (!file.exists(gpkg_path)) {
    msg <- sprintf("%-35s — no afforestation data (skipped)", ctry)
    cat("  [SKIP]", msg, "\n")
    skipped <- c(skipped, ctry)
    next
  }

  cat("──", ctry, "\n")
  aff <- st_read(gpkg_path, quiet = TRUE)
  aff <- st_make_valid(aff)
  cat("  Afforestation polygons:", nrow(aff), "\n")

  # All years for this country
  rows <- meta_df[meta_df$country == ctry, ]

  for (i in seq_len(nrow(rows))) {
    shp_path <- rows$shp[i]
    year_lbl <- rows$year[i]

    cat("  →", year_lbl, "...")

    # Load DHS clusters
    dhs <- tryCatch(
      st_read(shp_path, quiet = TRUE),
      error = function(e) {
        cat(" ERROR reading shapefile:", conditionMessage(e), "\n")
        return(NULL)
      }
    )
    if (is.null(dhs)) next

    # Drop clusters with missing coordinates (SOURCE == "MIS" → lat/lon = 0,0)
    n_before <- nrow(dhs)
    dhs <- dhs %>% filter(LATNUM != 0 | LONGNUM != 0)
    n_dropped <- n_before - nrow(dhs)

    if (nrow(dhs) == 0) {
      cat(" no valid clusters after dropping MIS — skipped\n")
      next
    }

    # Project both layers to a metric CRS so st_distance uses planar GEOS
    # (avoids s2 and lwgeom; EPSG:4087 is equidistant cylindrical in metres)
    dhs_m       <- st_transform(dhs, 4087)
    aff_m       <- st_transform(aff, 4087)

    nearest_idx <- st_nearest_feature(dhs_m, aff_m)
    dist_m      <- st_distance(dhs_m, aff_m[nearest_idx, ], by_element = TRUE)

    dhs$dist_aff_km     <- as.numeric(dist_m) / 1000
    dhs$nearest_site_id <- aff$st_d_cr[nearest_idx]
    dhs$nearest_proj_id <- aff$prjct__[nearest_idx]

    # Save — select only columns that exist (SR shapefiles have different schemas)
    safe_ctry <- to_safe(ctry)
    safe_year <- to_safe(year_lbl)
    out_path  <- file.path(out_dir, paste0(safe_ctry, "_", safe_year, "_dist_to_afforestation.csv"))

    want_cols <- c("DHSID", "DHSCC", "DHSYEAR", "DHSCLUST", "URBAN_RURA",
                   "LATNUM", "LONGNUM", "dist_aff_km", "nearest_site_id", "nearest_proj_id")
    out_df <- st_drop_geometry(dhs)
    out_df  <- out_df[, intersect(want_cols, names(out_df)), drop = FALSE]
    write.csv(out_df, out_path, row.names = FALSE)

    cat(sprintf(" %d clusters (dropped %d MIS) → %s\n",
                nrow(dhs), n_dropped, basename(out_path)))
    processed <- processed + 1
  }
}

# ─────────────────────────────────────────────────────────────
# 4. Summary
# ─────────────────────────────────────────────────────────────
cat("\n══════════════════════════════════════════\n")
cat("Done.\n")
cat("CSVs written     :", processed, "\n")
cat("Countries skipped:", length(skipped),
    if (length(skipped) > 0) paste0("(", paste(skipped, collapse = ", "), ")") else "", "\n")
cat("Output folder    :", out_dir, "\n")
