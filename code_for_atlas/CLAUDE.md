# Event Study DID — General Instruction File

This file instructs Claude on how to structure and run staggered DiD / event study regressions.
It is written for the **ATLAS afforestation project** but documents the general patterns so the same
logic can be adapted to other projects (e.g. PEDL energy / hexagon).

---

## Dropbox Path Setup

Always include this block at the top of any new .do file:

```stata
if c(username) == "wyf19"    { global dropdir "C:/Users/wyf19/Dropbox" }
if c(username) == "wangy390"  { global dropdir "D:/Dropbox" }
if c(username) == "WANGY390"  { global dropdir "C:/Users/WANGY390/Dropbox" }
```

---

## PROJECT: ATLAS Afforestation

### Context

- **Unit of observation**: Afforestation site = treated polygon + ~100 matched control polygons
- **Data source**: GEE (Google Earth Engine) NDVI extracts — CSV files in country subfolders
- **Outcome**: `smooth_mean` (4-yr rolling mean of interpolated MODIS NDVI)
- **Treatment**: `treat_absorbing = 1` if treated unit AND `year >= proj_plant_yr`
- **Main estimators**: `sdid_event`, `sdid`, TWFE (`reghdfe` + `coefplot`)
- **Loop levels**: country-by-country → site-by-site (`group_both`) → cohort-by-cohort

### Global Paths

```stata
global gee_dir  "$dropdir/Afforestation_Transition/Data/Processed Data/Processed from GEE/GEE_Extracts_2"
global fig_dir  "$dropdir/Afforestation_Transition/Output/Figure/atlas"
global data_dir "$dropdir/Afforestation_Transition/Data/Processed Data"
cap mkdir "$fig_dir/project"
```

### Step 1: Load and Merge GEE CSVs

```stata
local first = 1
local dirs : dir `"$gee_dir"' dirs "*"

foreach d of local dirs {
    local files : dir `"$gee_dir/`d'"' files "*_covariates.csv"
    foreach f of local files {
        import delimited `"$gee_dir/`d'/`f'"', clear
        tostring proj_id site_rpt, replace force

        local is_control = strpos("`f'", "control") > 0
        if `is_control' { gen treatment = 0 }
        else {
            gen treatment = 1
            rename poly_id treated_polygon_id
        }

        if `first' { tempfile combined; save "`combined'"; local first = 0 }
        else { append using "`combined'", force; save "`combined'", replace }
    }
}

use "`combined'", clear
replace country = "Cote dIvoire"        if strpos(country, "Ivoire") > 0
replace country = "Central African Rep" if country == "Central African Rep."
save `"$gee_dir/all_covariates_combined_2.dta"', replace
```

### Step 2: ID Construction and Panel Setup

```stata
keep if variable == "modis_ndvi"
duplicates drop
drop if plant_yr == .

replace control_id = 0 if mi(control_id)

* Site ID (5-key): one row per treated/control polygon within a site
egen group_both  = group(treated_polygon_id ctry_id proj_id site_id site_rpt)
bys group_both: egen proj_plant_yr = min(plant_yr)   // single treatment yr per site

* Panel unit (includes control_id and treatment to distinguish polygons)
egen unique_id = group(treated_polygon_id ctry_id proj_id site_id site_rpt control_id treatment)
```

### Step 3: Treatment Indicator

```stata
gen treat_absorbing = (control_id == 0 & year >= proj_plant_yr)
```

### Step 4: NDVI Smoothing

```stata
sort unique_id year
by unique_id: ipolate mean year, gen(mean_ipo) epolate   // interpolate missing years
by unique_id: gen smooth_mean = (mean_ipo[_n-3] + mean_ipo[_n-2] + mean_ipo[_n-1] + mean_ipo[_n]) / 4
```

### Step 5: Data Cleaning

```stata
gen missing = mi(smooth_mean)
by unique_id: egen missing_total = sum(missing)
drop if missing_total == 25          // drop units with all-missing NDVI

gen treatment_year = year if treat_absorbing == 1
by unique_id: egen first_year = min(treatment_year)
drop if first_year <= 2003           // exclude very early treatments (pre-MODIS era)

bys country: egen max_treat = max(treat_absorbing)
drop if max_treat == 0               // drop countries with no treated units
```

### Step 6: Dynamic Window Calculation

**Always compute pre/post window from data before calling sdid_event.** The matrix size depends on it.

```stata
quietly {
    su year if year > 2002, meanonly
    local year_min  = r(min)
    local year_max  = r(max)
    su year if treat_absorbing == 1 & year > 2002, meanonly
    local treat_year = r(min)
}
local pre   = `treat_year' - `year_min'
local post  = `year_max'   - `treat_year' + 1
local total = `pre' + `post'
display "pre: `pre'  post: `post'  total: `total'"
```

---

## ATLAS Estimators

### A — SDID Event Study: `sdid_event` (main method)

Always wrap in `capture`. The matrix row range `[2..total+1]` must match the dynamic window.

```stata
capture sdid_event smooth_mean unique_id year treat_absorbing if year > 2002, ///
    vce(placebo) placebo(all)
if _rc != 0 {
    display "WARNING: sdid_event failed, skipping"
    * [restore / continue as appropriate]
}
else {
    mat res = e(H)[2..`=`total'+1', 1..5]
    * res cols: 1=coef, 2=se, 3=ci_lower, 4=ci_upper, 5=p-value
    svmat res
    gen id = _n - 1 if !missing(res1)
    replace id = `post' - _n if _n > `post' & !missing(res1)
    sort id
    twoway (rarea res3 res4 id, lc(gs10) fc(gs11%50)) ///
           (scatter res1 id, mc(blue) ms(d)), ///
           legend(off) title("[Label] sdid_event") ///
           xtitle(Relative time to treatment change) ytitle(Smooth NDVI) ///
           yline(0, lc(red) lp(-)) xline(0, lc(black) lp(solid))
    graph export `"$fig_dir/sdid_event_[label]_modis_ndvi.jpg"', replace
    drop res1 res2 res3 res4 res5 id
}
```

### B — SDID ATT: `sdid` (point estimate per unit)

```stata
* First test with noinference to check feasibility:
capture sdid smooth_mean unique_id year treat_absorbing if year > 2002, vce(noinference)
if _rc != 0 {
    display "WARNING: sdid failed, skipping"
}
else {
    sdid smooth_mean unique_id year treat_absorbing if year > 2002, ///
        vce(placebo) reps(100) graph ///
        graph_export("$fig_dir/[label]_modis_ndvi", .pdf)
    * Optionally also run SC:
    sdid smooth_mean unique_id year treat_absorbing if year > 2002, ///
        vce(placebo) graph method(sc) ///
        graph_export("$fig_dir/sc_[label]_modis_ndvi", .pdf)
    * Extract:
    replace coef = e(ATT)         if [condition]
    replace se   = e(ATT) + e(se) if [condition]   // NOTE: placeholder — check formula
}
```

### C — TWFE Event Study: `reghdfe` + `coefplot`

```stata
gen rel_time = year - first_year

capture reghdfe smooth_mean ib(-1).rel_time, ///
    absorb(unique_id year) vce(cluster unique_id) nocons
if _rc == 0 {
    coefplot, keep(*.rel_time) omitted baselevels vertical recast(connected) ///
        ciopts(recast(rarea) fc(gs11%50) lc(gs10)) ///
        yline(0, lc(red) lp(-)) xline(-0.5, lc(black) lp(solid)) ///
        title("[Label] TWFE event study") ///
        xtitle(Relative time to treatment) ytitle(Smooth NDVI) legend(off)
    graph export `"$fig_dir/twfe_event_[label]_modis_ndvi.jpg"', replace
}
else { display "WARNING: TWFE failed, skipping" }
```

---

## ATLAS Loop Patterns

### Country-by-country

```stata
levelsof country, local(countries)
foreach c of local countries {
    display "`c'"
    * [compute dynamic window for country `c']
    * [run sdid_event / sdid / TWFE with if country == "`c'" & year > 2002]
    * [export figures with country label]
}
```

### Site-by-site (group_both)

```stata
su group_both, meanonly
local n_sites = r(max)

forvalues g = 1/`n_sites' {
    display "===== Site `g' / `n_sites' ====="
    preserve
    keep if group_both == `g'

    * Skip if no treated obs after 2002
    quietly su year if treat_absorbing == 1 & year > 2002, meanonly
    if r(N) == 0 { display "  Skipping site `g': no treated obs"; restore; continue }

    * [compute dynamic window]
    * [run sdid_event with capture]
    * [export with site label: site`g']
    drop res1 res2 res3 res4 res5 id   // must drop before next iteration
    restore
}
```

### Cohort-by-cohort (proj_plant_yr)

```stata
gen cohort = proj_plant_yr
levelsof cohort, local(cohorts)

foreach cohort_yr of local cohorts {
    display "===== Cohort `cohort_yr' ====="
    preserve
    keep if cohort == `cohort_yr' | treatment == 0   // treated cohort + all controls

    quietly su year if treat_absorbing == 1 & year > 2002, meanonly
    if r(N) == 0 { display "  Skipping cohort `cohort_yr'"; restore; continue }

    * [compute dynamic window]
    * [run sdid_event with capture]
    * [export with cohort label: cohort`cohort_yr']
    restore
}
```

### Collect ATT across sites/countries

```stata
gen coef = .
gen se   = .

forvalues g = 1/`n_sites' {
    capture sdid smooth_mean unique_id year treat_absorbing ///
        if group_both == `g' & year > 2002, vce(noinference)
    if _rc != 0 { display "WARNING: sdid ATT failed for site `g'"; continue }
    sdid smooth_mean unique_id year treat_absorbing ///
        if group_both == `g' & year > 2002, vce(placebo) reps(100)
    replace coef = e(ATT)         if group_both == `g'
    replace se   = e(ATT) + e(se) if group_both == `g'
}

keep coef se proj_id site_id site_rpt group_both country proj_plant_yr
duplicates drop group_both, force
save `"$data_dir/sdid_results_by_site.dta"', replace
```

---

## ATLAS Key Variables Reference

| Variable | Description |
|---|---|
| `group_both` | 5-key site ID: `group(treated_polygon_id ctry_id proj_id site_id site_rpt)` |
| `unique_id` | Panel unit: `group(... control_id treatment)` |
| `proj_plant_yr` | `min(plant_yr)` within site — single treatment year per site |
| `treat_absorbing` | 1 if `control_id == 0 & year >= proj_plant_yr` |
| `treatment` | 1 = treated polygon, 0 = control polygon |
| `control_id` | 0 for treated polygons; >0 for control polygons |
| `mean` | Raw MODIS NDVI from GEE |
| `mean_ipo` | Interpolated NDVI (`ipolate ... epolate`) |
| `smooth_mean` | 4-yr rolling mean of `mean_ipo` (main outcome) |
| `first_year` | First year `treat_absorbing == 1` for the unit |
| `cohort` | = `proj_plant_yr` (treatment cohort year) |
| `rel_time` | `year - first_year` (for TWFE) |
| `missing_total` | Count of missing `smooth_mean` per unit |

---

## ATLAS Plot Style Convention

- CI band (from sdid_event directly): `rarea res3 res4 id, lc(gs10) fc(gs11%50)`
- Point estimates: `scatter res1 id, mc(blue) ms(d)`
- Zero line: `yline(0, lc(red) lp(-))`
- Treatment line: `xline(0, lc(black) lp(solid))`
- Always: `legend(off)`
- **Must `drop res1 res2 res3 res4 res5 id` after each iteration in a loop**

---

## Required Stata Packages

```stata
ssc install sdid_event
ssc install sdid
ssc install reghdfe
ssc install coefplot
* For other projects (csdid, S&A, DCDH):
ssc install csdid
ssc install drdid
ssc install eventstudyinteract
ssc install avar
ssc install did_multiplegt_dyn
```

---

## PROJECT: PEDL Energy / Hexagon (South Africa)

For this project, see `D:/Dropbox_archive/PEDL_energy/code/hexagon/did/CLAUDE.md`.

Key differences from ATLAS:
- Unit: H3 hexagonal cells (`hex7` → `encode` to `hex_id`)
- Time: monthly (`group(year month)` → `time_period`) or yearly
- Treatment: high load shedding shock (>90th pctile AND >0)
- Cohort: `cohort = treatment_time` (0 = never treated)
- Methods: `csdid`, `eventstudyinteract`, `sdid_event`, `did_multiplegt_dyn`
- Plot style: `color("51 153 204%30/50")` bands, `mcolor("0 51 102")` dots

---

## General DID Data Requirements Checklist

Before running any staggered DiD estimator, verify:

- [ ] Numeric panel ID (`unique_id` or `hex_id`)
- [ ] Numeric time variable (`year` or `time_period`)
- [ ] Panel is set: `xtset [id] [time]`
- [ ] Treatment indicator: binary absorbing (`treat_absorbing`)
- [ ] Cohort variable: first treatment time (0 or `.` = never treated) — for `csdid`/`eventstudyinteract`
- [ ] `rel_time` defined (and set to missing/-999 for never treated) — for `eventstudyinteract`/TWFE
- [ ] Outcome variable is named `outcome` (or pass the actual variable name)
- [ ] Dynamic window computed (`pre`, `post`, `total`) before `sdid_event`
- [ ] `capture` used around estimator calls in loops
- [ ] `drop res1...res5 id` after each loop iteration (sdid_event)
