********************************************************************************
* 00_data_prep.do
* ATLAS Afforestation - NDVI Panel Dataset Preparation
*
* Input:  GEE_Extracts_2 country subfolders (*_covariates.csv)
* Output: $data_dir/atlas_ndvi_panel.dta
*
* Run this file ONCE before 01_site.do, 02_project.do, 03_cohort.do, 04_country.do
* Step 1 (CSV load) is auto-skipped if all_covariates_combined_2.dta already exists.
* To force a rebuild (e.g. after adding new countries), delete that file first.
*
* data_group in the output panel: 1 = GEE_Extracts (Group 1), 2 = GEE_Extracts_2 (Group 2)
********************************************************************************


********************************************************************************
* 00a_build_combined.do
* Load and merge ALL CSVs from BOTH GEE extract folders
* Group 1: GEE_Extracts   (flat folder, *.csv)
* Group 2: GEE_Extracts_2 (country subfolders, *_covariates.csv)
********************************************************************************

local user = c(username)

if "`user'" == "wyf19"    global dropdir "C:/Users/wyf19/Dropbox"
if "`user'" == "wangy390"  global dropdir "D:/Dropbox"
if "`user'" == "WANGY390"  global dropdir "C:/Users/WANGY390/Dropbox"

global gee1_dir "$dropdir/Afforestation_Transition/Data/Processed Data/Processed from GEE/GEE_Extracts"
global gee2_dir "$dropdir/Afforestation_Transition/Data/Processed Data/Processed from GEE/GEE_Extracts_2"
global gee_dir  "$gee2_dir"

local first = 1

********************************************************************************
* GROUP 1: flat folder
********************************************************************************

local files : dir "$gee1_dir" files "*.csv"

foreach f of local files {
    import delimited "$gee1_dir/`f'", clear
    tostring proj_id site_rpt, replace force

    local is_control = strpos("`f'", "control") > 0
    if `is_control' {
        gen treatment = 0
    }
    else {
        gen treatment = 1
        capture rename poly_id treated_polygon_id
    }

    gen data_group = 1

    if `first' {
        tempfile combined
        save "`combined'"
        local first = 0
    }
    else {
        append using "`combined'", force
        save "`combined'", replace
    }
}

********************************************************************************
* GROUP 2: country subfolders
********************************************************************************

local dirs : dir "$gee2_dir" dirs "*"

foreach d of local dirs {
    local files : dir "$gee2_dir/`d'" files "*_covariates.csv"

    foreach f of local files {
        import delimited "$gee2_dir/`d'/`f'", clear
        tostring proj_id site_rpt, replace force

        local is_control = strpos("`f'", "control") > 0
        if `is_control' {
            gen treatment = 0
        }
        else {
            gen treatment = 1
            capture rename poly_id treated_polygon_id
        }

        gen data_group = 2

        if `first' {
            tempfile combined
            save "`combined'"
            local first = 0
        }
        else {
            append using "`combined'", force
            save "`combined'", replace
        }
    }
}

********************************************************************************
* Clean and save
********************************************************************************

use "`combined'", clear

replace country = "Cote dIvoire"        if strpos(country, "Ivoire") > 0
replace country = "Central African Rep" if country == "Central African Rep."

* Drop duplicates across groups (Group 2 takes priority if same site appears in both)
duplicates drop treated_polygon_id ctry_id proj_id site_id site_rpt control_id year variable, force

save "$gee2_dir/all_covariates_combined_2.dta", replace

quietly levelsof country, local(ctry_list)
local n : word count `ctry_list'
display "Combined dataset: `n' countries"
levelsof country

********************************************************************************
* STEP 1: Load & merge all country CSVs (skip if combined DTA already exists)
********************************************************************************

capture confirm file "$gee_dir/all_covariates_combined_2.dta"
if _rc == 0  display "all_covariates_combined_2.dta exists - skipping CSV load."
if _rc != 0  do "$code_dir/00a_build_combined.do"

********************************************************************************
* STEP 2: Filter to MODIS NDVI, construct IDs, smooth, clean
********************************************************************************

use "$gee_dir/all_covariates_combined_2.dta", clear
keep if variable == "modis_ndvi"
duplicates drop
drop if plant_yr == .
replace control_id = 0 if mi(control_id)

* Clean country names - remove special characters for file-safe labels
replace country = "Cote dIvoire"       if strpos(country, "Ivoire") > 0
replace country = "Dem Rep Congo"      if strpos(country, "Dem") > 0 & strpos(country, "Congo") > 0
replace country = "Central African Rep" if strpos(country, "Central African") > 0
replace country = "Guinea Bissau"      if strpos(country, "Bissau") > 0
replace country = "Congo"              if country == "Congo" | country == "Republic of Congo"
replace country = trim(country)

* Site ID (5-key): 1 treated polygon + ~100 matched controls
egen group_both  = group(treated_polygon_id ctry_id proj_id site_id site_rpt)
bys group_both: egen proj_plant_yr = min(plant_yr)

* Panel unit ID
egen unique_id = group(treated_polygon_id ctry_id proj_id site_id site_rpt control_id treatment)

* Project group: all sites sharing proj_id within a country
egen proj_group  = group(ctry_id proj_id)
bys proj_group: egen proj_treat_yr = min(plant_yr)

* Treatment indicator
gen treat_absorbing = (control_id == 0 & year >= proj_plant_yr)

* NDVI smoothing: interpolate missing years + 4-yr rolling mean
sort unique_id year
by unique_id: ipolate mean year, gen(mean_ipo) epolate
by unique_id: gen smooth_mean = (mean_ipo[_n-3] + mean_ipo[_n-2] + mean_ipo[_n-1] + mean_ipo[_n]) / 4

* Data quality filters
gen missing = mi(smooth_mean)
by unique_id: egen missing_total = sum(missing)
drop if missing_total == 25

gen treatment_year = year if treat_absorbing == 1
by unique_id: egen first_year = min(treatment_year)
drop if first_year <= 2003

bys country: egen max_treat = max(treat_absorbing)
drop if max_treat == 0

* Cohort label
gen cohort = proj_plant_yr

********************************************************************************
* STEP 3: Save master panel
********************************************************************************

keep country ctry_id proj_id site_id site_rpt treated_polygon_id control_id treatment ///
     year mean mean_ipo smooth_mean missing missing_total                              ///
     group_both unique_id proj_group                                                   ///
     plant_yr proj_plant_yr proj_treat_yr first_year treat_absorbing cohort

compress
save "$dropdir/Afforestation_Transition/Data/Processed Data/atlas_ndvi_panel.dta", replace
display "Saved: atlas_ndvi_panel.dta"
count

* Descriptive counts
quietly levelsof country, local(ctry_list)
local n_countries : word count `ctry_list'

quietly levelsof cohort, local(cohort_list)
local n_cohorts : word count `cohort_list'

quietly su group_both, meanonly
local n_sites = r(max)

quietly su proj_group, meanonly
local n_proj = r(max)

display " "
display "========================================"
display "  ATLAS NDVI Panel - Summary"
display "========================================"
display "  Countries : `n_countries'"
display "  Cohorts   : `n_cohorts'  (`cohort_list')"
display "  Projects  : `n_proj'"
display "  Sites     : `n_sites'"
display "========================================"