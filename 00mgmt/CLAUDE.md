# Afforestation Atlas — Master Project Guide for Claude Code

**Paper repo:** https://github.com/Wang-Yifan-1997/Afforestation_Atlas
**Working directory:** `C:/Users/wyf19/Dropbox/Afforestation_Transition/`
**Primary language:** Stata (do files), with GEE (JavaScript) for data extraction

Read this file first before writing any code or making any decisions on this project.

---

## What This Project Is

A large-scale causal impact study of **45,628+ georeferenced afforestation and reforestation projects** across Africa (and globally), combining:

- **Satellite remote sensing** (MODIS, Landsat, Sentinel-2, Hansen forest cover)
- **Causal inference** (Synthetic DiD, staggered event studies)
- **Policy analysis** (~300 country-year forest policy documents, LLM-coded)
- **Household welfare** (DHS surveys spatially linked to project sites)

The paper is organized around four research questions:

1. Do afforestation projects actually increase vegetation and forest cover?
2. Why does effectiveness vary so dramatically across programs?
3. Do nearby households benefit — or bear costs?
4. How do national policies shape program design and outcomes?

**Main result target:** Average +5 percentage point NDVI gain within 5 years of planting, with substantial heterogeneity.

---

## Directory Layout

```
Afforestation_Transition/
├── Code/
│   ├── 00mgmt/                        ← YOU ARE HERE (management docs)
│   │   ├── CLAUDE.md                  ← this file
│   │   └── project_status.md          ← detailed task tracker
│   └── code_for_atlas/                ← all Stata do files
│       ├── CLAUDE.md                  ← Stata coding patterns (read this too)
│       ├── archive/                   ← legacy / experimental
│       ├── group1/                    ← older pipeline + Ghana / structural analyses
│       └── group2/                    ← CURRENT production code
│           └── atlas_afforestation_project_group2_all.do   ← MAIN file
├── Data/
│   └── Processed Data/
│       └── Processed from GEE/
│           └── GEE_Extracts_2/        ← USE THIS (not GEE_Extracts)
│               ├── Ethiopia/          ← one subfolder per country
│               ├── malawi/
│               ├── morocco/
│               └── ...                ← CSVs + GeoJSONs per country
└── Output/
    └── Figure/atlas/
        └── project/                   ← site-level event study plots
```

---

## Stata Coding Rules

See [stata.md](stata.md) for all Stata-specific rules — path setup, forbidden patterns,
estimator conventions, plot style, and required packages.

**Most important rules (full details in stata.md):**
- Path setup: `local user = c(username)` then `if "`user'" == ...` (no braces)
- No semicolons as command separators — one command per line always
- Never nest `foreach`/`forvalues` inside a compound `if { }` block in a do file
- Always compute `pre`/`post`/`total` dynamically before `sdid_event`
- Always `drop res1 res2 res3 res4 res5 id` after each `sdid_event` loop iteration

---

## Effectiveness Analysis: `01_effectiveness/01_ndvi/`

Four analysis files, run independently after `00_data_prep.do`:

| File | Unit | N regressions | Methods |
|------|------|---------------|---------|
| `01_site.do` | site (`group_both`) | most | TWFE, SDID, SC, EB+TWFE |
| `02_project.do` | project (`ctry_id × proj_id`) | fewer | TWFE, SDID, SC, EB+TWFE |
| `03_cohort.do` | country × cohort year | fewer still | TWFE, SDID, SC, EB+TWFE |
| `04_country.do` | country | fewest | TWFE, SDID, EB+TWFE, csdid |

**Why no SC at country level:** SC requires a single (or few) treated units with many controls to form a synthetic counterfactual. At the country level, all treated polygons are pooled with no clean donor pool — `csdid` (Callaway-Sant'Anna) is the correct staggered-DID alternative.

**Output structure:**
```
Output/Figure/atlas/01_effectiveness/01_ndvi/
├── site/{twfe|sdid|sc|eb}/         ← one JPG/PDF per site per method
├── project/{twfe|sdid|sc|eb}/      ← one per project
├── cohort/{twfe|sdid|sc|eb}/       ← one per country-cohort
└── country/{twfe|sdid|eb|csdid}/   ← one per country

Data/Processed Data/results/01_effectiveness/01_ndvi/
├── 01_site_results.dta             ← one row per site, 4×(ATT+SE) columns
├── 02_project_results.dta
├── 03_cohort_results.dta
└── 04_country_results.dta
```

**EB implementation:** reshape panel to wide (one column per pre-treatment year),
drop any year with missing values, run `ebalance treated_unit smooth_mean{year}...`,
then apply weights to weighted TWFE. Year-by-year balancing (not just mean) matches
the approach in `archive/atlas_afforestation_ethiopia_test.do`.

**SC implementation:** `sdid method(sc)` — produces ATT with placebo CI and a
trend graph (treated vs. synthetic). Not a formal event study; used as ATT robustness.

---

## Current Code Status

### Done
- Full data load pipeline (`group2/atlas_afforestation_project_group2_all.do`)
- Country-by-country `sdid_event` + TWFE for all countries
- Ethiopia site-by-site + cohort-level ATT collection
- Malawi site/cohort template (`archive/atlas_afforestation_malawi.do`)
- Ghana comprehensive methods with bootstrap + human geography heterogeneity
- Structural transformation heterogeneity (ATT vs Ag/Mfg/Services sector shares)

### Not done yet (in priority order)
1. Site-by-site + cohort loops extended to **all countries** (not just Ethiopia)
2. Fix bug in `group1/atlas_afforestaion_project_sdid_all.do` line 96–97 (`country` → `group_both`)
3. Landsat NDVI robustness run
4. Forest cover outcome (Hansen data — check if in `GEE_Extracts_2`)
5. **DHS household welfare analysis** (spatial matching → staggered DiD on consumption/employment)
6. Project metadata table (Verra/Gold Standard → org type, species, community participation)
7. Rainfall confound controls
8. Spatial leakage / spillover tests
9. Country fact sheets
10. Interactive project map (GeoJSONs already in `GEE_Extracts_2/*/`)
11. LLM policy coding pipeline (~300 country-year documents via FAOLEX)

---

## Current Priorities (as of 2026-04-05)

From `Priority_TODO_tasks.md` in the GitHub repo:

1. **Non-Africa small countries** — process remaining countries outside Africa for NDVI extraction
2. **Summary statistics update** — refresh descriptive tables after adding new countries
3. **LLM policy coding** — extract key message, forest relevance, regulation strength from FAOLEX documents; output must be machine-readable and comparable across countries
4. **DHS household analysis** — document available variables; calculate distance from DHS clusters to nearest project boundary/centroid
5. **Within-project heterogeneity** — test whether Google building footprints / road density correlates with reduced NDVI effectiveness

---

## Project Conventions

5. **Use `GEE_Extracts_2`**, not the old `GEE_Extracts` folder.
6. **Always `tostring proj_id site_rpt`** on load — `proj_id` can have leading zeros.
7. **Compound quotes** for paths with spaces or `&` (South Sudan & Togo subfolder).
8. **Do not rename existing files** — the typo "afforestaion" in filenames is cosmetic; fix only at final cleanup.
9. **Primary outcome is `modis_ndvi`.** Run `landsat_ndvi` as robustness only.
10. **Ethiopia first** — always develop/test new code on Ethiopia before scaling to all countries.

---

## Known Gotchas

| Issue | Where | Fix |
|-------|-------|-----|
| Bug: loop references `country` instead of `group_both` | `group1/..._sdid_all.do` line 96–97 | Fix before using |
| `sdid` SE extraction formula is a placeholder | `group2_all.do` | Verify `e(ATT) + e(se)` formula |
| South Sudan & Togo folder has spaces + `&` in path | `GEE_Extracts_2/` | Use `` `"$gee_dir/`d'"' `` compound quotes |
| `sdid_event` matrix row range must match dynamic window | All loops | `e(H)[2..`=total+1', 1..5]` |
| `drop if max_treat == 0` must be done at the right level | Cleaning step | Run `bys country:` not `bys group_both:` |
