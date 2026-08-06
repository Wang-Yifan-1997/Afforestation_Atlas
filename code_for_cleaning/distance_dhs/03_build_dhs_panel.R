# 03_build_dhs_panel.R
#
# Merges DHS household data with cluster distances to afforestation projects.
# Produces two Stata-ready datasets:
#
#   dhs_household_wealth.dta  — one row per household
#   dhs_cluster_wealth.dta    — one row per cluster × survey wave
#
# Variables in output (all derived from DHS HR files):
#
#   IDENTIFIERS
#     dhscc, survey_yr, dhsclust      country code, year, cluster number
#
#   WEALTH
#     hv271              Wealth factor score (continuous)
#     wealth_quintile    Wealth quintile (1–5)
#
#   HOUSEHOLD BASICS
#     hhsize             Household size (hv009)
#     sample_weight      DHS sample weight (hv005; divide by 1e6 for Stata pweight)
#
#   ASSETS  (0 = no, 1 = yes; missing coded as NA)
#     electricity        hv206
#     radio              hv207
#     television         hv208
#     refrigerator       hv209
#     bicycle            hv210
#     motorcycle         hv211
#     car                hv212
#     telephone          hv221
#
#   HOUSING / SANITATION
#     tap_water          1 if main drinking water source is piped/tap (hv201 ∈ 10–13)
#     flush_toilet       1 if toilet is flush type (hv205 ∈ 10–15)
#     constr_floor       1 if floor material is constructed/non-earth (hv213 ≥ 20)
#     ln_rooms_pp        log(sleeping rooms / household size) (hv216 / hv009)
#
#   AGRICULTURE & LIVESTOCK
#     own_agri_land      1 if owns agricultural land (hv244)
#     agri_land_ha       Hectares of agricultural land (hv245 raw; see note below)
#     own_livestock      1 if owns any livestock (hv246)
#     cattle             Number of cattle (hv246a)
#     cows_bulls         Number of cows/bulls (hv246b)
#     horses_donkeys_camels  hv246c
#     goats              hv246e
#     sheep              hv246f
#     chickens           hv246g
#     other_livestock    hv246h
#
#   Note on agri_land_ha: stored as the raw DHS hv245 integer code. In older DHS
#   rounds this has an implied decimal (code 10 = 1.0 ha); in newer rounds it is
#   whole hectares. Values ≥ 9998 are treated as missing. Divide by 10 to convert
#   older-round codes to hectares if needed.
#
#   DISTANCE / TREATMENT (from distance CSVs)
#     dist_aff_km        Centroid-to-boundary distance to nearest ATLAS polygon
#     treated            1 if dist_aff_km ≤ 100
#     nearest_proj_id    ATLAS project ID of the nearest polygon
#     nearest_site_id    ATLAS site ID (site_id_created / st_d_cr) of nearest polygon
#     urban_rura         "U" = urban, "R" = rural
#     latnum / longnum   Cluster GPS coordinates

library(haven)
library(dplyr)
library(readr)
library(purrr)
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

base      <- file.path(dropdir, "Afforestation_Transition")
data_dir  <- file.path(base, "Data/Processed Data")
dhs19_dir <- file.path(base, "Data/DHS data/4.19")
dhs20_dir <- file.path(base, "Data/DHS data/4.20")
dist_dir  <- file.path(data_dir, "DHS/distance")
out_dir   <- file.path(data_dir, "DHS/merged")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# ─── Variables to load from each HR DTA file ─────────────────────────────────

hr_vars_want <- c(
  "hv001",                                           # cluster (join key)
  "hv271", "hv270",                                  # wealth score, quintile
  "hv005", "hv009",                                  # sample weight, hhsize
  "hv206", "hv207", "hv208", "hv209",               # electricity, radio, tv, fridge
  "hv210", "hv211", "hv212", "hv221",               # bicycle, motorcycle, car, phone
  "hv201", "hv205", "hv213", "hv216",               # water, toilet, floor, rooms
  "hv244", "hv245", "hv246",                        # own land, land ha, own livestock
  "hv246a", "hv246b", "hv246c",                     # cattle, cows/bulls, horses/donkeys
  "hv246e", "hv246f", "hv246g", "hv246h"            # goats, sheep, chickens, other
)

# ─── STEP 1: Stack all distance CSVs ─────────────────────────────────────────

cat("── STEP 1: Loading distance CSVs ──\n")

dist_files <- list.files(dist_dir, pattern = "dist_to_afforestation\\.csv$",
                         full.names = TRUE)
dist_files <- dist_files[!str_detect(dist_files, "no_household_data")]
cat("  CSVs found:", length(dist_files), "\n")

dist_all <- map_dfr(dist_files, \(f) {
  read_csv(f, col_types = cols(.default = "c"), show_col_types = FALSE) |>
    mutate(
      dist_aff_km = as.numeric(dist_aff_km),
      DHSYEAR     = as.integer(DHSYEAR),
      DHSCLUST    = as.integer(DHSCLUST)
    )
}) |>
  rename(survey_yr = DHSYEAR) |>
  mutate(treated = as.integer(dist_aff_km <= 100 & !is.na(dist_aff_km)))

cat("  Rows stacked:", nrow(dist_all), "\n")
cat("  Countries:   ", n_distinct(dist_all$DHSCC), "\n\n")

# ─── STEP 2: Discover HR DTA files → crosswalk (DHSCC, year, path) ───────────

cat("── STEP 2: Building HR file crosswalk ──\n")

hr_files <- c(
  list.files(dhs19_dir, pattern = "HR.*FL\\.DTA$", recursive = TRUE,
             full.names = TRUE, ignore.case = TRUE),
  list.files(dhs20_dir, pattern = "HR.*FL\\.DTA$", recursive = TRUE,
             full.names = TRUE, ignore.case = TRUE)
)
cat("  HR DTA files found:", length(hr_files), "\n")

hr_crosswalk <- tibble(hr_path = hr_files) |>
  mutate(
    bname  = basename(hr_path),
    dhscc  = str_sub(bname, 1, 2) |> str_to_upper(),
    yr_fld = basename(dirname(hr_path)),
    hr_yr  = as.integer(str_sub(yr_fld, 1, 4))
  ) |>
  filter(!is.na(hr_yr), str_detect(bname, regex("^..HR", ignore_case = TRUE))) |>
  select(dhscc, hr_yr, hr_path)

cat("  Crosswalk rows:", nrow(hr_crosswalk), "\n\n")

# ─── STEP 3: Match distance pairs with HR crosswalk ──────────────────────────

cat("── STEP 3: Matching country-year pairs ──\n")

dist_pairs <- dist_all |>
  distinct(DHSCC, survey_yr) |>
  rename(dhscc = DHSCC, hr_yr = survey_yr)

matched <- inner_join(dist_pairs, hr_crosswalk, by = c("dhscc", "hr_yr"))

cat("  Matched pairs:", nrow(matched), "\n")
print(matched |> select(dhscc, hr_yr) |> arrange(dhscc, hr_yr), n = Inf)
cat("\n")

# ─── STEP 4: Load each HR file, recode, and merge with distance data ──────────

cat("── STEP 4: Loading household data and merging ──\n")

hh_list <- vector("list", nrow(matched))

for (i in seq_len(nrow(matched))) {
  cc   <- matched$dhscc[i]
  yr   <- matched$hr_yr[i]
  path <- matched$hr_path[i]

  cat(sprintf("  [%d/%d] %s %d  %s\n", i, nrow(matched), cc, yr,
              basename(path)))

  # Distance data for this country-year (cluster-level, one row per cluster)
  dsub <- dist_all |>
    filter(DHSCC == cc, survey_yr == yr) |>
    rename(dhscc = DHSCC)

  # Load HR — only columns that exist in this file (any_of handles gaps)
  hh <- tryCatch(
    read_dta(path, col_select = any_of(hr_vars_want)),
    error = function(e) {
      cat("    SKIP — could not load:", conditionMessage(e), "\n")
      NULL
    }
  )
  if (is.null(hh)) next

  # ── Core identifiers ────────────────────────────────────────────────────────
  hh <- hh |>
    rename(dhsclust = hv001) |>
    mutate(
      dhsclust  = as.integer(dhsclust),
      dhscc     = cc,
      survey_yr = yr
    )

  # ── Wealth score (hv271 absent in early DHS rounds before Phase 5) ──────────
  if ("hv271" %in% names(hh)) {
    hh <- hh |> mutate(
      hv271 = if_else(as.numeric(hv271) >= 900000, NA_real_, as.numeric(hv271))
    )
  }

  # ── Wealth quintile ──────────────────────────────────────────────────────────
  if ("hv270" %in% names(hh)) {
    hh <- hh |> mutate(
      wealth_quintile = if_else(as.integer(hv270) %in% 1:5,
                                as.integer(hv270), NA_integer_)
    ) |> select(-hv270)
  }

  # ── Household basics ─────────────────────────────────────────────────────────
  if ("hv005" %in% names(hh)) {
    hh <- hh |> mutate(sample_weight = as.numeric(hv005)) |> select(-hv005)
  }
  if ("hv009" %in% names(hh)) {
    hh <- hh |> mutate(
      hhsize = if_else(as.integer(hv009) < 98L, as.integer(hv009), NA_integer_)
    )
    # Keep hv009 temporarily for ln_rooms_pp calculation below
  }

  # ── Asset dummies (0 = no, 1 = yes; all other codes → NA) ───────────────────
  asset_raw <- c("hv206","hv207","hv208","hv209","hv210","hv211","hv212","hv221")
  asset_out <- c("electricity","radio","television","refrigerator",
                 "bicycle","motorcycle","car","telephone")
  for (j in seq_along(asset_raw)) {
    v <- asset_raw[j]
    if (v %in% names(hh)) {
      hh[[asset_out[j]]] <- { x <- as.integer(hh[[v]]); if_else(x %in% 0:1, x, NA_integer_) }
      hh <- select(hh, -all_of(v))
    }
  }

  # ── Housing / sanitation ─────────────────────────────────────────────────────
  if ("hv201" %in% names(hh)) {
    hh <- hh |> mutate(
      tap_water = as.integer(as.integer(hv201) %in% 10:13)
    ) |> select(-hv201)
  }
  if ("hv205" %in% names(hh)) {
    hh <- hh |> mutate(
      flush_toilet = as.integer(as.integer(hv205) %in% 10:15)
    ) |> select(-hv205)
  }
  if ("hv213" %in% names(hh)) {
    hh <- hh |> mutate(
      constr_floor = { v <- as.integer(hv213); as.integer(v >= 20L & v < 90L) }
    ) |> select(-hv213)
  }
  if (all(c("hv216", "hv009") %in% names(hh))) {
    hh <- hh |> mutate(
      hv216_v = if_else(as.numeric(hv216) >= 98 | as.numeric(hv216) <= 0,
                        NA_real_, as.numeric(hv216)),
      hv009_v = if_else(as.integer(hv009) >= 98L | as.integer(hv009) <= 0L,
                        NA_real_, as.numeric(hv009)),
      ln_rooms_pp = if_else(!is.na(hv216_v) & !is.na(hv009_v),
                            log(hv216_v / hv009_v), NA_real_)
    ) |> select(-hv216, -hv216_v, -hv009_v)
  } else if ("hv216" %in% names(hh)) {
    hh <- hh |> select(-hv216)
  }
  # Drop hv009 raw column now that hhsize and ln_rooms_pp are done
  if ("hv009" %in% names(hh)) hh <- select(hh, -hv009)

  # ── Agricultural land ────────────────────────────────────────────────────────
  if ("hv244" %in% names(hh)) {
    hh <- hh |> mutate(
      own_agri_land = if_else(as.integer(hv244) %in% 0:1,
                              as.integer(hv244 == 1L), NA_integer_)
    ) |> select(-hv244)
  }
  if ("hv245" %in% names(hh)) {
    hh <- hh |> mutate(
      # Raw DHS code; see header note on implied decimal in older surveys
      agri_land_ha = if_else(as.numeric(hv245) >= 9998 | as.numeric(hv245) < 0,
                             NA_real_, as.numeric(hv245))
    ) |> select(-hv245)
  }

  # ── Livestock ────────────────────────────────────────────────────────────────
  if ("hv246" %in% names(hh)) {
    hh <- hh |> mutate(
      own_livestock = if_else(as.integer(hv246) %in% 0:1,
                              as.integer(hv246 == 1L), NA_integer_)
    ) |> select(-hv246)
  }
  livestock_raw <- c("hv246a","hv246b","hv246c","hv246e","hv246f","hv246g","hv246h")
  livestock_out <- c("cattle","cows_bulls","horses_donkeys_camels",
                     "goats","sheep","chickens","other_livestock")
  for (j in seq_along(livestock_raw)) {
    v <- livestock_raw[j]
    if (v %in% names(hh)) {
      hh[[livestock_out[j]]] <- { x <- as.integer(hh[[v]]); if_else(x < 95L, x, NA_integer_) }
      hh <- select(hh, -all_of(v))
    }
  }

  # ── Join with cluster distance/location data ─────────────────────────────────
  merged <- left_join(hh, dsub, by = c("dhsclust" = "DHSCLUST", "dhscc", "survey_yr"))

  cat(sprintf("    %d households, %d clusters, %.0f%% matched to distance\n",
              nrow(merged),
              n_distinct(merged$dhsclust),
              100 * mean(!is.na(merged$dist_aff_km))))

  hh_list[[i]] <- merged
}

hh_all <- bind_rows(hh_list)
cat("\nTotal households stacked:", nrow(hh_all), "\n")
cat("Countries:", n_distinct(hh_all$dhscc), "\n\n")

# ─── STEP 5: Save output datasets ─────────────────────────────────────────────

cat("── STEP 5: Saving datasets ──\n")

hh_out <- hh_all |>
  rename_with(str_to_lower) |>
  select(
    dhscc, survey_yr, dhsclust,
    # Wealth
    hv271,
    any_of("wealth_quintile"),
    # Household
    any_of(c("hhsize", "sample_weight")),
    # Assets
    any_of(c("electricity","radio","television","refrigerator",
             "bicycle","motorcycle","car","telephone")),
    # Housing / sanitation
    any_of(c("tap_water","flush_toilet","constr_floor","ln_rooms_pp")),
    # Agriculture & livestock
    any_of(c("own_agri_land","agri_land_ha","own_livestock",
             "cattle","cows_bulls","horses_donkeys_camels",
             "goats","sheep","chickens","other_livestock")),
    # Distance / treatment
    dist_aff_km, treated, nearest_proj_id,
    urban_rura, latnum, longnum,
    any_of(c("dhsid", "nearest_site_id"))
  )

write_dta(hh_out, file.path(out_dir, "dhs_household_wealth.dta"))
cat("  Saved: dhs_household_wealth.dta  (", nrow(hh_out), "rows,",
    ncol(hh_out), "columns)\n")

# Cluster-level means (one row per cluster × survey wave)
# hv271 renamed to hv271_mean for backward compatibility with Stata scripts
outcome_and_index_vars <- c(
  "hv271", "wealth_quintile", "hhsize", "sample_weight"
)
asset_vars <- c(
  "electricity", "radio", "television", "refrigerator",
  "bicycle", "motorcycle", "car", "telephone"
)
housing_vars <- c(
  "tap_water", "flush_toilet", "constr_floor", "ln_rooms_pp"
)
agri_vars <- c(
  "own_agri_land", "agri_land_ha", "own_livestock",
  "cattle", "cows_bulls", "horses_donkeys_camels",
  "goats", "sheep", "chickens", "other_livestock"
)
all_agg_vars <- c(outcome_and_index_vars, asset_vars, housing_vars, agri_vars)
agg_vars_present <- intersect(all_agg_vars, names(hh_out))

cluster_out <- hh_out |>
  group_by(dhscc, survey_yr, dhsclust) |>
  summarise(
    n_hh = n(),
    across(all_of(agg_vars_present),
           \(x) mean(x, na.rm = TRUE)),
    across(c(dist_aff_km, treated, nearest_proj_id,
             urban_rura, latnum, longnum,
             any_of("nearest_site_id")), first),
    .groups = "drop"
  ) |>
  rename(hv271_mean = hv271)   # backward-compatible name for Stata regression

write_dta(cluster_out, file.path(out_dir, "dhs_cluster_wealth.dta"))
cat("  Saved: dhs_cluster_wealth.dta  (", nrow(cluster_out), "rows,",
    ncol(cluster_out), "columns)\n")

cat("\n── Done ──\n")
cat("Output folder:", out_dir, "\n")