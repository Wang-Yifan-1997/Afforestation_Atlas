# 04_build_project_chars.R
#
# For each ATLAS reforestation project, aggregates DHS cluster-level
# socioeconomic data from communities within 10 / 20 / 50 / 100 km.
#
# Only pre-treatment survey waves are used (survey_yr < project plant year)
# so the output captures baseline community characteristics before planting.
# If a project has no pre-treatment clusters within a given radius, that cell
# is NA.
#
# Inputs:
#   $merged_dir/dhs_cluster_wealth.dta   cluster-level data from 03_build_dhs_panel.R
#   $data_dir/atlas_ndvi_panel.dta       ATLAS panel (for project plant years)
#
# Output:
#   $merged_dir/dhs_project_chars.dta    one row per project
#
# Variable naming convention:
#   n_clusters_{X}km    number of pre-treatment clusters within X km
#   n_hh_{X}km          total households represented
#   {var}_{X}km         n_hh-weighted mean of {var} across those clusters
#
# Aggregation weight: n_hh (household count per cluster), so larger clusters
# contribute proportionally more to each project-level mean.

library(haven)
library(dplyr)
library(tidyr)
library(stringr)

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
merged_dir <- file.path(data_dir, "DHS/merged")

# ─── STEP 1: Load cluster-level DHS data ─────────────────────────────────────

cat("── STEP 1: Loading cluster data ──\n")

clusters <- read_dta(file.path(merged_dir, "dhs_cluster_wealth.dta")) |>
  mutate(nearest_proj_id = as.character(nearest_proj_id))

cat("  Clusters loaded:", nrow(clusters), "\n")
cat("  Countries:      ", n_distinct(clusters$dhscc), "\n")
cat("  Survey years:   ", paste(sort(unique(clusters$survey_yr)), collapse = ", "), "\n\n")

# ─── STEP 2: Get project plant years from ATLAS panel ─────────────────────────

cat("── STEP 2: Loading ATLAS plant years ──\n")

atlas_path <- file.path(data_dir, "atlas_ndvi_panel.dta")
if (!file.exists(atlas_path)) stop("atlas_ndvi_panel.dta not found at: ", atlas_path)

proj_plant <- read_dta(atlas_path) |>
  filter(!is.na(plant_yr)) |>
  mutate(proj_id = as.character(proj_id)) |>
  group_by(proj_id) |>
  summarise(plant_yr = min(plant_yr, na.rm = TRUE), .groups = "drop")

cat("  Projects with plant_yr:", nrow(proj_plant), "\n\n")

# ─── STEP 3: Merge plant year onto clusters ────────────────────────────────────

cat("── STEP 3: Merging plant year onto clusters ──\n")

clusters <- left_join(clusters, proj_plant,
                      by = c("nearest_proj_id" = "proj_id"))

n_matched <- sum(!is.na(clusters$plant_yr))
cat(sprintf("  Clusters with plant_yr matched: %d / %d (%.1f%%)\n\n",
            n_matched, nrow(clusters), 100 * n_matched / nrow(clusters)))

if (n_matched / nrow(clusters) < 0.10) {
  cat("  WARNING: fewer than 10% of clusters matched a plant year.\n")
  cat("  nearest_proj_id sample (clusters): ",
      paste(head(unique(clusters$nearest_proj_id), 5), collapse = ", "), "\n")
  cat("  proj_id sample (ATLAS):            ",
      paste(head(unique(proj_plant$proj_id), 5), collapse = ", "), "\n")
  cat("  IDs may differ in format (numeric vs. string prefix).\n\n")
}

# ─── STEP 4: Keep pre-treatment survey waves ──────────────────────────────────

cat("── STEP 4: Filtering to pre-treatment waves ──\n")

clusters_pre <- clusters |>
  filter(!is.na(plant_yr), survey_yr < plant_yr)

cat(sprintf("  Pre-treatment clusters: %d / %d\n\n",
            nrow(clusters_pre), nrow(clusters)))

if (nrow(clusters_pre) == 0) {
  stop("No pre-treatment clusters found. ",
       "Check that survey years and plant years overlap.")
}

# ─── STEP 5: Define variables to aggregate ────────────────────────────────────

# All numeric variables except identifiers / constants
non_agg <- c("dhscc", "survey_yr", "dhsclust", "nearest_proj_id", "plant_yr",
             "dist_aff_km", "treated", "latnum", "longnum", "n_hh")

agg_vars <- clusters_pre |>
  select(where(is.numeric)) |>
  select(-any_of(non_agg)) |>
  names()

cat("── STEP 5: Variables to aggregate ──\n")
cat("  ", paste(agg_vars, collapse = ", "), "\n\n")

# ─── Helper: n_hh-weighted mean within one grouped data frame ─────────────────

weighted_project_means <- function(df, vars) {
  result <- df |>
    group_by(nearest_proj_id) |>
    summarise(
      n_clusters = n(),
      n_hh_total = sum(n_hh, na.rm = TRUE),
      .groups = "drop"
    )

  for (v in vars) {
    if (!v %in% names(df)) next
    wm <- df |>
      group_by(nearest_proj_id) |>
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
    result <- left_join(result, wm, by = "nearest_proj_id")
  }
  result
}

# ─── STEP 6: Aggregate by project × distance threshold ────────────────────────

cat("── STEP 6: Aggregating by project × distance threshold ──\n")

thresholds <- c(10, 20, 50, 100)

agg_list <- lapply(thresholds, function(thresh) {
  nearby <- clusters_pre |> filter(dist_aff_km <= thresh)
  cat(sprintf("  %3d km — %d clusters, %d projects\n",
              thresh, nrow(nearby), n_distinct(nearby$nearest_proj_id)))
  if (nrow(nearby) == 0) return(NULL)
  weighted_project_means(nearby, agg_vars) |>
    mutate(threshold_km = thresh)
})

# ─── STEP 7: Pivot to wide format (one row per project) ───────────────────────

cat("\n── STEP 7: Pivoting to wide format ──\n")

agg_long <- bind_rows(agg_list)

value_cols <- setdiff(names(agg_long), c("nearest_proj_id", "threshold_km"))

project_wide <- agg_long |>
  pivot_wider(
    id_cols     = nearest_proj_id,
    names_from  = threshold_km,
    values_from = all_of(value_cols),
    names_glue  = "{.value}_{threshold_km}km"
  )

cat("  Projects in output:", nrow(project_wide), "\n")
cat("  Columns in output: ", ncol(project_wide), "\n\n")

for (thresh in thresholds) {
  col <- paste0("n_clusters_", thresh, "km")
  if (col %in% names(project_wide)) {
    n_proj <- sum(!is.na(project_wide[[col]]))
    med_cl <- median(project_wide[[col]], na.rm = TRUE)
    cat(sprintf("  %3d km: %d projects have data (median %.0f clusters)\n",
                thresh, n_proj, med_cl))
  }
}

# ─── STEP 8: Save ─────────────────────────────────────────────────────────────

cat("\n── STEP 8: Saving ──\n")

out_path <- file.path(merged_dir, "dhs_project_chars.dta")
write_dta(project_wide, out_path)
cat("  Saved:", out_path, "\n")
cat("  Rows:", nrow(project_wide), "  Columns:", ncol(project_wide), "\n")
cat("\n── Done ──\n")
