# 05_build_site_chars.R
#
# Site-level version of 04_build_project_chars.R.
# For each ATLAS site (group_both / site_id), aggregates DHS cluster-level
# socioeconomic data from communities within 10 / 20 / 50 / 100 km.
#
# Only pre-treatment survey waves are used (survey_yr < site plant year).
# If a site has no pre-treatment clusters within a given radius, that cell is NA.
#
# Inputs:
#   $merged_dir/dhs_cluster_wealth.dta   cluster-level data from 03_build_dhs_panel.R
#   $dist_dir/*.csv                      raw distance CSVs (to recover nearest_site_id
#                                        if not already in dhs_cluster_wealth.dta)
#   $data_dir/atlas_ndvi_panel.dta       ATLAS panel (for site-level plant years)
#
# Output:
#   $merged_dir/dhs_site_chars.dta       one row per site (site_id)
#
# Variable naming convention:
#   n_clusters_{X}km    number of pre-treatment clusters within X km
#   n_hh_{X}km          total households represented
#   {var}_{X}km         n_hh-weighted mean of {var} across those clusters
#
# Join key to ATLAS panel: nearest_site_id (= site_id_created / st_d_cr) ↔ site_id

library(haven)
library(dplyr)
library(tidyr)
library(stringr)
library(readr)
library(purrr)

# ─── Paths ────────────────────────────────────────────────────────────────────

user <- Sys.info()[["user"]]
if (user == "WANGY390") {
  dropdir <- "C:/Users/WANGY390/Dropbox"
} else if (user == "wangy390") {
  dropdir <- "D:/Dropbox"
} else if (user == "wyf19") {
  dropdir <- "C:/Users/wyf19/Dropbox"
} else {
  stop("Unknown user — add your Dropbox path above.")
}

base       <- file.path(dropdir, "Afforestation_Transition")
data_dir   <- file.path(base, "Data/Processed Data")
dist_dir   <- file.path(data_dir, "DHS/distance")
merged_dir <- file.path(data_dir, "DHS/merged")

# ─── STEP 1: Load cluster-level DHS data ─────────────────────────────────────

cat("── STEP 1: Loading cluster data ──\n")

clusters <- read_dta(file.path(merged_dir, "dhs_cluster_wealth.dta")) |>
  mutate(nearest_proj_id = as.character(nearest_proj_id))

cat("  Clusters loaded:", nrow(clusters), "\n")
cat("  Countries:      ", n_distinct(clusters$dhscc), "\n")

# ─── STEP 2: Attach nearest_site_id (from distance CSVs if not already present)

cat("\n── STEP 2: Attaching nearest_site_id ──\n")

if ("nearest_site_id" %in% names(clusters)) {
  cat("  nearest_site_id already in cluster data — no reload needed.\n")
  clusters <- clusters |> mutate(nearest_site_id = as.character(nearest_site_id))
} else {
  cat("  nearest_site_id absent — loading from distance CSVs...\n")

  dist_files <- list.files(dist_dir, pattern = "dist_to_afforestation\\.csv$",
                           full.names = TRUE)
  dist_files <- dist_files[!str_detect(dist_files, "no_household_data")]

  site_lookup <- map_dfr(dist_files, \(f) {
    read_csv(f, col_types = cols(.default = "c"), show_col_types = FALSE) |>
      mutate(
        DHSYEAR  = as.integer(DHSYEAR),
        DHSCLUST = as.integer(DHSCLUST),
        nearest_site_id = as.character(nearest_site_id)
      ) |>
      rename(dhscc = DHSCC, survey_yr = DHSYEAR, dhsclust = DHSCLUST) |>
      distinct(dhscc, survey_yr, dhsclust, nearest_site_id)
  })

  cat("  Site lookup rows:", nrow(site_lookup), "\n")

  clusters <- left_join(clusters, site_lookup,
                        by = c("dhscc", "survey_yr", "dhsclust"))
  cat("  Clusters with nearest_site_id:",
      sum(!is.na(clusters$nearest_site_id)), "/", nrow(clusters), "\n")
}

# ─── STEP 3: Get site plant years from ATLAS panel ────────────────────────────

cat("\n── STEP 3: Loading ATLAS site plant years ──\n")

atlas_path <- file.path(data_dir, "atlas_ndvi_panel.dta")
if (!file.exists(atlas_path)) stop("atlas_ndvi_panel.dta not found at: ", atlas_path)

site_plant <- read_dta(atlas_path) |>
  filter(!is.na(plant_yr)) |>
  mutate(site_id = as.character(site_id)) |>
  group_by(site_id) |>
  summarise(plant_yr = min(plant_yr, na.rm = TRUE), .groups = "drop")

cat("  Sites with plant_yr:", nrow(site_plant), "\n\n")

# ─── STEP 4: Merge plant year onto clusters ────────────────────────────────────

cat("── STEP 4: Merging site plant year onto clusters ──\n")

clusters <- left_join(clusters, site_plant,
                      by = c("nearest_site_id" = "site_id"))

n_matched <- sum(!is.na(clusters$plant_yr))
cat(sprintf("  Clusters with plant_yr matched: %d / %d (%.1f%%)\n\n",
            n_matched, nrow(clusters), 100 * n_matched / nrow(clusters)))

if (n_matched / nrow(clusters) < 0.10) {
  cat("  WARNING: fewer than 10% of clusters matched a plant year.\n")
  cat("  nearest_site_id sample: ",
      paste(head(unique(clusters$nearest_site_id), 5), collapse = ", "), "\n")
  cat("  site_id sample (ATLAS): ",
      paste(head(unique(site_plant$site_id), 5), collapse = ", "), "\n\n")
}

# ─── STEP 5: Keep pre-treatment survey waves ──────────────────────────────────

cat("── STEP 5: Filtering to pre-treatment waves ──\n")

clusters_pre <- clusters |>
  filter(!is.na(plant_yr), survey_yr < plant_yr)

cat(sprintf("  Pre-treatment clusters: %d / %d\n\n",
            nrow(clusters_pre), nrow(clusters)))

if (nrow(clusters_pre) == 0) {
  stop("No pre-treatment clusters found. ",
       "Check that survey years and plant years overlap.")
}

# ─── STEP 6: Define variables to aggregate ────────────────────────────────────

non_agg <- c("dhscc", "survey_yr", "dhsclust", "nearest_proj_id",
             "nearest_site_id", "plant_yr", "dist_aff_km", "treated",
             "latnum", "longnum", "n_hh", "urban_rura")

agg_vars <- clusters_pre |>
  select(where(is.numeric)) |>
  select(-any_of(non_agg)) |>
  names()

cat("── STEP 6: Variables to aggregate ──\n")
cat("  ", paste(agg_vars, collapse = ", "), "\n\n")

# ─── Helper: n_hh-weighted mean ───────────────────────────────────────────────

weighted_site_means <- function(df, vars) {
  result <- df |>
    group_by(nearest_site_id) |>
    summarise(
      n_clusters = n(),
      n_hh_total = sum(n_hh, na.rm = TRUE),
      .groups = "drop"
    )

  for (v in vars) {
    if (!v %in% names(df)) next
    wm <- df |>
      group_by(nearest_site_id) |>
      summarise(
        !!v := {
          x     <- .data[[v]]
          w     <- n_hh
          valid <- !is.na(x)
          if (sum(valid) == 0) NA_real_
          else sum(x[valid] * w[valid], na.rm = TRUE) / sum(w[valid], na.rm = TRUE)
        },
        .groups = "drop"
      )
    result <- left_join(result, wm, by = "nearest_site_id")
  }
  result
}

# ─── STEP 7: Aggregate by site × distance threshold ───────────────────────────

cat("── STEP 7: Aggregating by site × distance threshold ──\n")

thresholds <- c(10, 20, 50, 100)

agg_list <- lapply(thresholds, function(thresh) {
  nearby <- clusters_pre |> filter(dist_aff_km <= thresh)
  cat(sprintf("  %3d km — %d clusters, %d sites\n",
              thresh, nrow(nearby), n_distinct(nearby$nearest_site_id)))
  if (nrow(nearby) == 0) return(NULL)
  weighted_site_means(nearby, agg_vars) |>
    mutate(threshold_km = thresh)
})

# ─── STEP 8: Pivot to wide format (one row per site) ──────────────────────────

cat("\n── STEP 8: Pivoting to wide format ──\n")

agg_long <- bind_rows(agg_list)

value_cols <- setdiff(names(agg_long), c("nearest_site_id", "threshold_km"))

site_wide <- agg_long |>
  pivot_wider(
    id_cols     = nearest_site_id,
    names_from  = threshold_km,
    values_from = all_of(value_cols),
    names_glue  = "{.value}_{threshold_km}km"
  )

cat("  Sites in output:", nrow(site_wide), "\n")
cat("  Columns in output: ", ncol(site_wide), "\n\n")

for (thresh in thresholds) {
  col <- paste0("n_clusters_", thresh, "km")
  if (col %in% names(site_wide)) {
    n_sites <- sum(!is.na(site_wide[[col]]))
    med_cl  <- median(site_wide[[col]], na.rm = TRUE)
    cat(sprintf("  %3d km: %d sites have data (median %.0f clusters)\n",
                thresh, n_sites, med_cl))
  }
}

# ─── STEP 9: Save ─────────────────────────────────────────────────────────────

cat("\n── STEP 9: Saving ──\n")

out_path <- file.path(merged_dir, "dhs_site_chars.dta")
write_dta(site_wide, out_path)
cat("  Saved:", out_path, "\n")
cat("  Rows:", nrow(site_wide), "  Columns:", ncol(site_wide), "\n")
cat("\n── Done ──\n")
cat("  Merge key for ATLAS panel: nearest_site_id ↔ site_id\n")
