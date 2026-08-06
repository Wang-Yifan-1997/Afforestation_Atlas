if c(username) == "wyf19" {
    global dropdir "C:/Users/wyf19/Dropbox"
}
else if c(username) == "wangy390" {
    global dropdir "D:/Dropbox"
}

global gee_dir    "$dropdir/Afforestation_Transition/Data/Processed Data/Processed from GEE/GEE_Extracts_2"
global fig_dir    "$dropdir/Afforestation_Transition/Output/Figure/atlas"
global data_dir   "$dropdir/Afforestation_Transition/Data/Processed Data"

stop
********************************************************************************
* STEP 1: Load and merge all covariates CSVs from country subfolders
********************************************************************************

local first = 1
local dirs : dir `"$gee_dir"' dirs "*"

foreach d of local dirs {
    local files : dir `"$gee_dir/`d'"' files "*_covariates.csv"

    foreach f of local files {
        import delimited `"$gee_dir/`d'/`f'"', clear
        tostring proj_id site_rpt, replace force

        * Tag control vs treated based on filename
        local is_control = strpos("`f'", "control") > 0
        if `is_control' {
            gen treatment = 0
        }
        else {
            gen treatment = 1
            rename poly_id treated_polygon_id
        }

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

use "`combined'", clear

replace country = "Cote dIvoire" if strpos(country, "Ivoire") > 0
replace country = "Central African Rep" if country == "Central African Rep."

save "$gee_dir/all_covariates_combined_2.dta", replace


********************************************************************************
* STEP 2: Country-by-country SDID regression  (mirrors event_study_all.do)
********************************************************************************

use "$gee_dir/all_covariates_combined_2.dta", clear
keep if variable == "modis_ndvi"
duplicates drop //why ther will be duplicates
drop if plant_yr == .

replace control_id = 0 if mi(control_id)
egen unique_id = group(treated_polygon_id ctry_id proj_id site_id site_rpt control_id treatment)

gen treat_absorbing = (control_id == 0 & year >= plant_yr)

* Smoothing: linear interpolation then 4-period rolling mean
sort unique_id year
by unique_id: ipolate mean year, gen(mean_ipo) epolate
by unique_id: gen smooth_mean = (mean_ipo[_n-3] + mean_ipo[_n-2] + mean_ipo[_n-1] + mean_ipo[_n]) / 4
gen missing = mi(smooth_mean)

* Data cleaning
by unique_id: egen missing_total = sum(missing)
drop if missing_total == 25

gen treatment_year = year if treat_absorbing == 1
by unique_id: egen first_year = min(treatment_year)
drop if first_year <= 2003

bys country: egen max_treat = max(treat_absorbing)
drop if max_treat == 0

* --- sdid_event: country-by-country ---
levelsof country, local(countries)

foreach c of local countries {

    display "`c'"

    quietly {
        su year if country == "`c'" & year > 2002, meanonly
        local year_min = r(min)
        local year_max = r(max)

        su year if country == "`c'" & treat_absorbing == 1 & year > 2002, meanonly
        local treat_year = r(min)
    }

    local pre   = `treat_year' - `year_min'
    local post  = `year_max' - `treat_year' + 1
    local total = `pre' + `post'

    display "pre: `pre'  post: `post'"

    sdid_event smooth_mean unique_id year treat_absorbing if year > 2002 & country == "`c'", ///
        vce(placebo) placebo(all)

    mat res = e(H)[2..`=`total'+1', 1..5]
    svmat res
    gen id = _n - 1 if !missing(res1)
    replace id = `post' - _n if _n > `post' & !missing(res1)
    sort id
    twoway (rarea res3 res4 id, lc(gs10) fc(gs11%50)) ///
           (scatter res1 id, mc(blue) ms(d)), ///
           legend(off) title("`c' sdid_event") ///
           xtitle(Relative time to treatment change) ///
           ytitle(Smooth Mean) ///
           yline(0, lc(red) lp(-)) xline(0, lc(black) lp(solid))
    graph export `"$fig_dir/sdid_event_`c'_modis_ndvi.jpg"', replace
    graph export `"$fig_dir/sdid_event_`c'_modis_ndvi.pdf"', replace

    drop res1 res2 res3 res4 res5 id
}

* --- sdid ATT: country-by-country ---
preserve
gen coef = .
gen se   = .

foreach c of local countries {
    sdid smooth_mean unique_id year treat_absorbing if year > 2002 & country == "`c'", ///
        vce(placebo) reps(100)

    replace coef = e(ATT)         if country == "`c'"
    replace se   = e(ATT) + e(se) if country == "`c'"
}

keep coef se country
duplicates drop country, force
save `"$data_dir/sdid_results_modis_ndvi_gee2.dta"', replace
restore

* --- TWFE event study: country-by-country ---
foreach c of local countries {

    display "`c'"

    preserve
    keep if country == "`c'" & year > 2002

    gen rel_time = year - first_year

    capture reghdfe smooth_mean ib(-1).rel_time, ///
        absorb(unique_id year) vce(cluster unique_id) nocons

    if _rc == 0 {
        coefplot, keep(*.rel_time) omitted baselevels ///
            vertical recast(connected) ///
            ciopts(recast(rarea) fc(gs11%50) lc(gs10)) ///
            yline(0, lc(red) lp(-)) xline(-0.5, lc(black) lp(solid)) ///
            title("`c' TWFE event study") ///
            xtitle(Relative time to treatment) ytitle(Smooth Mean) ///
            legend(off)
        graph export `"$fig_dir/twfe_event_`c'_modis_ndvi.jpg"', replace
        graph export `"$fig_dir/twfe_event_`c'_modis_ndvi.pdf"', replace
    }
    else {
        display "WARNING: TWFE event study failed for `c', skipping"
    }

    restore
}


********************************************************************************
* STEP 3: Ethiopia - Project-level sdid_event
********************************************************************************

use `"$gee_dir/all_covariates_combined_2.dta"', clear
keep if variable == "modis_ndvi" & country == "Ethiopia"
duplicates drop
drop if plant_yr == .

replace control_id = 0 if mi(control_id)

* Project-level treatment year: take the earliest plant_yr within each proj_id
* so all polygons in the same project share a common treatment timing for sdid_event
bys proj_id: egen proj_plant_yr = min(plant_yr)

* Panel unit: each treated polygon and each of its matched controls
egen unique_id = group(treated_polygon_id ctry_id proj_id site_id site_rpt control_id treatment)

* Treatment indicator based on project-level timing
gen treat_absorbing = (control_id == 0 & year >= proj_plant_yr)

* Smoothing: linear interpolation then 4-period rolling mean
sort unique_id year
by unique_id: ipolate mean year, gen(mean_ipo) epolate
by unique_id: gen smooth_mean = (mean_ipo[_n-3] + mean_ipo[_n-2] + mean_ipo[_n-1] + mean_ipo[_n]) / 4
gen missing = mi(smooth_mean)

* Drop units that are entirely missing
by unique_id: egen missing_total = sum(missing)
drop if missing_total == 25

* Drop projects that have no treated observations
bys proj_id: egen max_treat = max(treat_absorbing)
drop if max_treat == 0

save `"$data_dir/ethiopia_project_data.dta"', replace

* Numeric project group (proj_id can be a string)
egen proj_group = group(proj_id)
su proj_group, meanonly
local n_proj = r(max)

* --- sdid_event: project-by-project ---
forvalues g = 1/`n_proj' {

    preserve
    keep if proj_group == `g'

    quietly {
        su year if treat_absorbing == 1, meanonly
        local treat_yr  = r(min)
        su year, meanonly
        local year_min  = r(min)
        local year_max  = r(max)
    }
    local pre   = `treat_yr' - `year_min'
    local post  = `year_max' - `treat_yr' + 1
    local total = `pre' + `post'

    display "Project `g'  |  treat yr: `treat_yr'  pre: `pre'  post: `post'"

    capture sdid_event smooth_mean unique_id year treat_absorbing, ///
        vce(placebo) placebo(all)

    if _rc != 0 {
        display "WARNING: sdid_event failed for project `g', skipping"
    }
    else {
        mat res = e(H)[2..`=`total'+1', 1..5]
        svmat res
        gen id = _n - 1 if !missing(res1)
        replace id = `post' - _n if _n > `post' & !missing(res1)
        sort id
        twoway (rarea res3 res4 id, lc(gs10) fc(gs11%50)) ///
               (scatter res1 id, mc(blue) ms(d)), ///
               legend(off) title("Ethiopia - Project `g' sdid_event") ///
               xtitle(Relative time to treatment change) ytitle(Smooth NDVI) ///
               yline(0, lc(red) lp(-)) xline(0, lc(black) lp(solid))
        graph export `"$fig_dir/project/ethiopia_sdid_event_proj`g'_modis_ndvi.jpg"', replace
        graph export `"$fig_dir/project/ethiopia_sdid_event_proj`g'_modis_ndvi.pdf"', replace
        drop res1 res2 res3 res4 res5 id
    }

    restore
}

* --- Collect ATT: one row per project ---
use `"$data_dir/ethiopia_project_data.dta"', clear
egen proj_group = group(proj_id)
gen coef = .
gen se   = .

su proj_group, meanonly
local n_proj = r(max)

forvalues g = 1/`n_proj' {
    capture sdid smooth_mean unique_id year treat_absorbing ///
        if proj_group == `g', vce(noinference)
    if _rc != 0 {
        display "WARNING: sdid ATT failed for project `g', skipping"
    }
    else {
        sdid smooth_mean unique_id year treat_absorbing ///
            if proj_group == `g', vce(placebo) reps(100)
        replace coef = e(ATT)         if proj_group == `g'
        replace se   = e(ATT) + e(se) if proj_group == `g'
    }
}

keep coef se proj_id proj_group country proj_plant_yr
duplicates drop proj_group, force
save `"$data_dir/ethiopia_sdid_results_by_project_modis_ndvi.dta"', replace


********************************************************************************
* STEP 3: Ethiopia - Project-level TWFE
********************************************************************************

use `"$data_dir/ethiopia_project_data.dta"', clear

* Project defined by all five identifiers
egen group_both = group(treated_polygon_id ctry_id proj_id site_id site_rpt)
bys group_both: egen proj_plant_yr2 = min(plant_yr)
gen cohort   = proj_plant_yr2
gen rel_time = year - cohort
replace rel_time = . if treatment == 0

* Try 2018 cohort
keep if cohort == 2018 | treatment == 0

* Check rel_time range
tab rel_time

* Generate relative time dummies (omit -1 as baseline)
forvalues k = 18(-1)2 {
    gen g_`k' = (rel_time == -`k')
}
forvalues k = 0/6 {
    gen g`k' = (rel_time == `k')
}

set matsize 800

reghdfe smooth_mean g_* g0-g6, ///
    absorb(unique_id year) vce(cluster unique_id)

