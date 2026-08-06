# ATLAS Afforestation Project — Status & Task Tracker

**Last updated:** 2026-04-05
**Paper repo:** https://github.com/Wang-Yifan-1997/Afforestation_Atlas
**Primary working dir:** `C:/Users/wyf19/Dropbox/Afforestation_Transition/`

---

## Paper Goals (from GitHub repo)

The paper aims to evaluate the causal effects of ATLAS afforestation/reforestation programs across sub-Saharan Africa:

1. **Vegetation/forest cover gains** — Do projects generate measurable NDVI or canopy cover increases?
2. **Household welfare impacts** — Consumption, food security, employment, health near project sites (DHS data)
3. **Economic displacement / structural transformation** — Does afforestation shift labor across agriculture / manufacturing / services?
4. **Project design heterogeneity** — Which designs (species, NGO vs. government, community participation) are most effective?
5. **Cost-effectiveness** — Comparing treatment effects per dollar across projects
6. **Placement predictors** — What predicts where projects are located?

**Expected outputs:** Country fact sheets · interactive project map · replication package

---

## Data Sources

| Data | Status | Path / Notes |
|------|--------|--------------|
| MODIS NDVI (GEE extracts, `GEE_Extracts_2`) | ✅ Ready | `Data/Processed Data/Processed from GEE/GEE_Extracts_2/` — one subfolder per country |
| Landsat NDVI | ✅ In CSVs | Alternative outcome; `variable == "landsat_ndvi"` |
| World Bank sectoral data (Ag/Mfg/Services) | ✅ Used | Imported in `structural_transformation.do` |
| Global Forest Resources Assessment | ✅ Used | Merged in structural transformation file |
| DHS household surveys | ❌ Not started | Needed for welfare analysis |
| Carbon credit registries (Verra, Gold Standard) | ❌ Not started | For project characteristics heterogeneity |
| Nighttime lights (NPP-VIIRS / DMSP-OLS) | ❌ Not started | Economic activity proxy |
| Building footprints / road networks | 🔶 Partial | Used in Ghana human geography analysis only |
| FAO FAOLEX forest legislation | ❌ Not started | Policy channel analysis |

---

## Code Status

### `code_for_atlas/` directory layout

```
code_for_atlas/
├── CLAUDE.md                          ← Stata coding instructions for Claude
├── archive/                           ← Legacy / experimental (OLD GEE_Extracts)
│   ├── atlas_afforestaion_project_ethiopia_test.do
│   ├── atlas_afforestaion_project_event_study_test.do
│   ├── atlas_afforestation_ethiopia_test.do
│   ├── atlas_afforestation_gee2_all.do        ← REFERENCE: 3-step template
│   └── atlas_afforestation_malawi.do          ← Country template
├── group1/                            ← Mix of old pipeline + new analyses
│   ├── atlas_afforestaion_project_event_study_all.do   (OLD data, country loop)
│   ├── atlas_afforestaion_project_sdid_all.do          (OLD data, site loop — HAS BUG)
│   ├── atlas_afforestaion_project_structural_transformation.do
│   └── ghana_afforestaion_project_event_study.do       (most methodologically complete)
└── group2/                            ← CURRENT production code
    └── atlas_afforestation_project_group2_all.do       ← Main active file
```

### What has been done

| Task | File | Notes |
|------|------|-------|
| ✅ Load & merge all country GEE CSVs | `group2/..._group2_all.do` Step 1 | Uses `GEE_Extracts_2`; tags treated/control; appends all |
| ✅ ID construction (`group_both`, `unique_id`) | All active files | Site = treated polygon + ~100 matched controls |
| ✅ NDVI smoothing (interpolation + 4-yr rolling mean) | All active files | `ipolate` + `smooth_mean` |
| ✅ Data cleaning filters | All active files | Drop missing, early treatment (<= 2003), no treated obs |
| ✅ Country-by-country `sdid_event` event studies | `group2/..._group2_all.do` Step 2 | All countries in loop |
| ✅ Country-by-country TWFE event studies | `group2/..._group2_all.do` Step 2 | `reghdfe` + `coefplot` |
| ✅ Ethiopia site-by-site `sdid_event` | `group2/..._group2_all.do` Step 3 | Loops over `group_both` |
| ✅ Ethiopia ATT collection by site | `group2/..._group2_all.do` Step 3 | `sdid` per site, collect `e(ATT)` |
| ✅ Ethiopia cohort-level `sdid_event` | `group2/..._group2_all.do` Step 3 | Pools sites by `proj_plant_yr` |
| ✅ Malawi site/cohort analysis | `archive/atlas_afforestation_malawi.do` | Template for other countries |
| ✅ Ghana comprehensive methods | `group1/ghana_afforestaion_project_event_study.do` | Bootstrap, binned event study, human geography heterogeneity |
| ✅ Structural transformation heterogeneity | `group1/..._structural_transformation.do` | Ag/Mfg/Services composition vs. ATT |
| ⚠️ Site-loop ATT (all countries, not just Ethiopia) | `group1/..._sdid_all.do` | **HAS BUG** at line 96–97: references `country` instead of `group_both` |

### What still needs to be done

#### A. Vegetation analysis (extend existing pipeline)

- [ ] **Run site-by-site analysis for all countries** (not just Ethiopia)
  Extend Step 3 of `group2_all.do` to loop over all countries
  Save ATT results to `sdid_results_by_site.dta` with country identifier

- [ ] **Fix bug in `group1/atlas_afforestaion_project_sdid_all.do`** (~line 96–97)
  Change `if country == "`c'"` → `if group_both == `g``
  Or retire this file and replicate clean logic in group2

- [ ] **Cohort-level analysis for all countries** (currently only Ethiopia)
  Add `foreach c of local countries { ... cohort loop ... }` block

- [ ] **Alternative outcome: Landsat NDVI**
  Re-run with `variable == "landsat_ndvi"` filter
  Separate output folder: `$fig_dir/landsat/`

- [ ] **Forest cover outcome** (Hansen Global Forest Change)
  May require separate GEE extraction step; check if data exists in `GEE_Extracts_2`

#### B. Welfare / household analysis

- [ ] **Download and harmonize DHS data** for countries with ATLAS projects
  Match project polygons to DHS cluster locations (within X km buffer)
  Outcome variables: consumption, food security, employment, health indicators

- [ ] **Spatial matching of DHS clusters to afforestation sites**
  Need GIS step (likely in Python/R or GEE) to assign DHS cluster → nearest ATLAS project
  Create `dhs_treated` indicator (cluster within treatment area or buffer)

- [ ] **Staggered DiD on DHS outcomes** (same sdid_event framework)
  Panel unit = DHS cluster; treatment = project planting year in area

#### C. Project characteristics heterogeneity

- [ ] **Build project metadata dataset**
  Sources: Verra, Gold Standard, ATLAS project registries
  Variables: implementing org type (NGO/govt/private), species, community participation, budget

- [ ] **Merge ATT results with project metadata**
  Join on `proj_id`

- [ ] **Heterogeneity regressions**: `ATT ~ org_type + species + community_part + budget`

#### D. Cost-effectiveness

- [ ] **Collect project budget / cost data** per site
- [ ] **Compute cost per unit of NDVI gain**: `budget / (ATT × site_area × post_years)`
- [ ] **Compare across countries and project types**

#### E. Outputs / paper

- [ ] **Country fact sheets** (one per country)
  Template: N projects, treatment years, median ATT, best/worst performing sites, map

- [ ] **Interactive project map**
  Likely Leaflet (R/Python) or QGIS; uses GeoJSON files already in `GEE_Extracts_2/*/`

- [ ] **Replication package**
  Clean ordered do files (Step 1 → Step N), README, intermediate data on OSF/Dataverse

---

## Recommended Next Steps (priority order)

1. **Fix the site-loop ATT bug** and re-run site-by-site for all countries → produces master ATT table
2. **Extend Step 3 (site + cohort loops) to all countries** in `group2_all.do`
3. **Run Landsat NDVI robustness** (modify `keep if variable ==` filter)
4. **Compile country fact sheets** from existing sdid_event figures
5. **Start DHS data acquisition** for welfare analysis (takes time, plan early)
6. **Build project metadata table** from Verra/Gold Standard registries

---

## Key File Paths

```stata
* Path setup (add to top of all new do files)
if c(username) == "wyf19"    { global dropdir "C:/Users/wyf19/Dropbox" }
if c(username) == "wangy390"  { global dropdir "D:/Dropbox" }
if c(username) == "WANGY390"  { global dropdir "C:/Users/WANGY390/Dropbox" }

global gee_dir  "$dropdir/Afforestation_Transition/Data/Processed Data/Processed from GEE/GEE_Extracts_2"
global fig_dir  "$dropdir/Afforestation_Transition/Output/Figure/atlas"
global data_dir "$dropdir/Afforestation_Transition/Data/Processed Data"
global code_dir "$dropdir/Afforestation_Transition/Code/code_for_atlas"
```

---

## Known Issues / Gotchas

| Issue | Location | Fix |
|-------|----------|-----|
| Bug: site-loop references `country` instead of `group_both` | `group1/..._sdid_all.do` line 96–97 | Correct variable name |
| Typo "afforestaion" in filenames | Many files | Cosmetic; don't rename until final cleanup |
| South Sudan & Togo: path has spaces + `&` | `GEE_Extracts_2/` subfolder | Use compound quotes `` `"path"' `` |
| `proj_id` comes as numeric → needs `tostring` | All load steps | Already handled in group2_all.do |
| `sdid_event` fails on small samples → always `capture` | All estimation loops | Already handled in group2_all.do |
| `drop res1 res2 res3 res4 res5 id` must be inside loop | All sdid_event loops | Easy to forget; causes overwrite errors |
| `sdid` ATT extraction: `replace se = e(ATT) + e(se)` is a placeholder | `group2_all.do` | Verify correct SE formula before using |

---

## Required Stata Packages

```stata
ssc install sdid_event
ssc install sdid
ssc install reghdfe
ssc install coefplot
ssc install csdid
ssc install drdid
ssc install eventstudyinteract
ssc install avar
ssc install did_multiplegt_dyn
```
