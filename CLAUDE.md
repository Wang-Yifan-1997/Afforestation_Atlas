# ATLAS Afforestation Project — Stata Analysis Context

## Project overview
Evaluating the impact of ATLAS afforestation projects on vegetation (NDVI) across multiple African countries, using satellite data extracted from Google Earth Engine (GEE).

## Directory layout
```
Afforestation_Transition/
  Code/
    code_for_atlas/          ← main do files (this folder)
      archive/               ← older/country-specific experimental do files
  Data/
    Processed Data/
      Processed from GEE/
        GEE_Extracts_2/      ← NEW data source (use this, not GEE_Extracts)
          Ethiopia/          ← one subfolder per country
          malawi/
          morocco/
          ...                ← each country has batch CSVs + geojsons
  Output/
    Figure/atlas/
      project/               ← site-level plots go here
```

## Data structure
Each country subfolder contains batched CSV files:
- `*_treated_covariates.csv` — treated polygons. Columns: `poly_id, ctry_id, proj_id, site_id, site_rpt, year, variable, mean, median, sd, country, plant_yr`
- `*_control_covariates.csv` — control polygons. Columns: `control_id, treated_polygon_id, ctry_id, proj_id, site_id, site_rpt, year, variable, mean, median, sd, country, plant_yr`

Key data facts:
- `proj_id` can be a **string** (e.g., `proj_9ShooMmxbB3thnsKZ1rSAXEw`) or numeric — always `tostring proj_id site_rpt` on load
- `plant_yr` can be **missing** for some treated polygons — always `drop if plant_yr == .`
- One folder (`south sudan & togo`) contains two countries — path has spaces and `&`, use compound quotes `` `" "' ``
- Outcome variable: `modis_ndvi` (primary), `landsat_ndvi` (alternative)
- Panel covers years ~2000–2023 (~25 obs per unit)

## Regression unit: **site-level** (NOT polygon-level, NOT project-level)
```stata
* Site identifier (5-key):
egen group_both = group(treated_polygon_id ctry_id proj_id site_id site_rpt)

* Project-level treatment year per site (min across polygons in same site):
bys group_both: egen proj_plant_yr = min(plant_yr)

* Panel unit (treated polygon OR one of its ~100 matched controls):
egen unique_id = group(treated_polygon_id ctry_id proj_id site_id site_rpt control_id treatment)

* Treatment indicator:
gen treat_absorbing = (control_id == 0 & year >= proj_plant_yr)
```

Each **site** (`group_both`) = 1 treated polygon + **~100 matched control polygons**.
Control polygons are matched at the GEE stage — each control has a `treated_polygon_id` linking it to its treated polygon.

## Outcome construction
```stata
* Linear interpolation to fill missing years, then 4-yr rolling mean:
sort unique_id year
by unique_id: ipolate mean year, gen(mean_ipo) epolate
by unique_id: gen smooth_mean = (mean_ipo[_n-3] + mean_ipo[_n-2] + mean_ipo[_n-1] + mean_ipo[_n]) / 4
```

## Analysis hierarchy
Three levels, run in this order (Ethiopia first):

| Level | Code | Command |
|-------|------|---------|
| Site-by-site | loop over `group_both` | `sdid_event` per site |
| Cohort | loop over `proj_plant_yr` | `sdid_event` pooling all sites in same cohort |
| Country pooled | full country sample | `sdid_event` or `reghdfe` staggered TWFE |

## Active do files
| File | Purpose |
|------|---------|
| `atlas_afforestation_gee2_all.do` | **Main file** — Step 1 load all, Step 2 country-by-country, Step 3 Ethiopia site/cohort |
| `archive/atlas_afforestation_malawi.do` | Malawi-specific (same structure, reference for other countries) |
| `archive/atlas_afforestaion_project_ethiopia_test.do` | Ethiopia experimental/scratch |
| `atlas_afforestaion_project_event_study_all.do` | Old version (GEE_Extracts, flat folder) — keep for reference |

## Key Stata commands used
- `sdid_event` — synthetic DID event study (main estimator)
- `sdid` — synthetic DID ATT with `vce(placebo) reps(100)`
- `reghdfe` — TWFE robustness check (`absorb(unique_id year) vce(cluster unique_id)`)
- `ipolate ... epolate` — linear interpolation with extrapolation

## Common pitfalls
- Always `drop if missing_total == 25` (units with all 25 years missing)
- Always `drop if max_treat == 0` (sites with no treated observations — drops purely control groups)
- `sdid_event` matrix extraction: `e(H)[2..`=total+1', 1..5]` — rows = periods, cols = coef/lb/ub/...
- Plot id construction: `id = _n - 1` for post periods, `id = post - _n` for pre periods (after svmat)
- Always `drop res1 res2 res3 res4 res5 id` at end of each loop iteration before `restore`
- `cap mkdir "$fig_dir/project"` before any site-level graph export
