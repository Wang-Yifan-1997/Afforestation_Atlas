********************************************************************************
* atlas_afforestation_gee2_all.do
* ATLAS afforestation project — GEE_Extracts_2 data
*
* Structure:
*   STEP 1  Load & merge all country CSVs from GEE_Extracts_2 subfolders
*   STEP 2  Country-by-country: sdid_event + TWFE event study
*   STEP 3  Ethiopia site-by-site: sdid_event per site, then cohort pooled
*
* Regression unit ("site"):
*   group_both = group(treated_polygon_id ctry_id proj_id site_id site_rpt)
*   Each site = 1 treated polygon + ~100 matched control polygons
*   unique_id  = group(...above... control_id treatment)  — panel unit
*
* Outcome: smooth_mean (4-yr rolling mean of ipolated modis_ndvi)
* Treatment indicator: treat_absorbing = 1 if treated unit & year >= proj_plant_yr
********************************************************************************

if c(username) == "wyf19" {
    global dropdir "C:/Users/wyf19/Dropbox"
}
else if c(username) == "wangy390" {
    global dropdir "D:/Dropbox"
}

global gee_dir   "$dropdir/Afforestation_Transition/Data/Processed Data/Processed from GEE/GEE_Extracts_2"
global fig_dir   "$dropdir/Afforestation_Transition/Output/Figure/atlas"
global data_dir  "$dropdir/Afforestation_Transition/Data/Processed Data"

cap mkdir "$fig_dir/project"

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

save `"$gee_dir/all_covariates_combined_2.dta"', replace


********************************************************************************
* STEP 2: Country-by-country — sdid_event + TWFE event study
********************************************************************************

use `"$gee_dir/all_covariates_combined_2.dta"', clear
keep if variable == "modis_ndvi"
duplicates drop
drop if plant_yr == .

replace control_id = 0 if mi(control_id)

* Site grouping and panel ID
egen group_both = group(treated_polygon_id ctry_id proj_id site_id site_rpt)
bys group_both: egen proj_plant_yr = min(plant_yr)
egen unique_id = group(treated_polygon_id ctry_id proj_id site_id site_rpt control_id treatment)

gen treat_absorbing = (control_id == 0 & year >= proj_plant_yr)

* Smoothing
sort unique_id year
by unique_id: ipolate mean year, gen(mean_ipo) epolate
by unique_id: gen smooth_mean = (mean_ipo[_n-3] + mean_ipo[_n-2] + mean_ipo[_n-1] + mean_ipo[_n]) / 4
gen missing = mi(smooth_mean)

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

    capture sdid_event smooth_mean unique_id year treat_absorbing ///
        if year > 2002 & country == "`c'", vce(placebo) placebo(all)
    if _rc != 0 {
        display "WARNING: sdid_event failed for `c', skipping"
        continue
    }

    mat res = e(H)[2..`=`total'+1', 1..5]
    svmat res
    gen id = _n - 1 if !missing(res1)
    replace id = `post' - _n if _n > `post' & !missing(res1)
    sort id
    twoway (rarea res3 res4 id, lc(gs10) fc(gs11%50)) ///
           (scatter res1 id, mc(blue) ms(d)), ///
           legend(off) title("`c' sdid_event") ///
           xtitle(Relative time to treatment change) ytitle(Smooth NDVI) ///
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
    capture sdid smooth_mean unique_id year treat_absorbing ///
        if year > 2002 & country == "`c'", vce(placebo) reps(100)
    if _rc == 0 {
        replace coef = e(ATT)         if country == "`c'"
        replace se   = e(ATT) + e(se) if country == "`c'"
    }
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
            xtitle(Relative time to treatment) ytitle(Smooth NDVI) ///
            legend(off)
        graph export `"$fig_dir/twfe_event_`c'_modis_ndvi.jpg"', replace
        graph export `"$fig_dir/twfe_event_`c'_modis_ndvi.pdf"', replace
    }
    else {
        display "WARNING: TWFE failed for `c', skipping"
    }
    restore
}


********************************************************************************
* STEP 3: Ethiopia — site-by-site sdid_event, then cohort pooled
*
* Regression unit: group_both = group(treated_polygon_id ctry_id proj_id site_id site_rpt)
* = one site with ~100 matched control polygons.
* proj_plant_yr = min(plant_yr) within site → single treatment year per site.
********************************************************************************

use `"$gee_dir/all_covariates_combined_2.dta"', clear
keep if variable == "modis_ndvi" & country == "Ethiopia"
duplicates drop
destring plant_yr, replace force
drop if plant_yr == .
drop if plant_yr <= 2003
drop if plant_yr >= 2024

replace control_id = 0 if mi(control_id)

* Site grouping
egen group_both = group(treated_polygon_id ctry_id proj_id site_id site_rpt)
bys group_both: egen proj_plant_yr = min(plant_yr)

* Panel unit
egen unique_id = group(treated_polygon_id ctry_id proj_id site_id site_rpt control_id treatment)

* Treatment indicator
gen treat_absorbing = (control_id == 0 & year >= proj_plant_yr)

* Smoothing
sort unique_id year
by unique_id: ipolate mean year, gen(mean_ipo) epolate
by unique_id: gen smooth_mean = (mean_ipo[_n-3] + mean_ipo[_n-2] + mean_ipo[_n-1] + mean_ipo[_n]) / 4
gen missing = mi(smooth_mean)

by unique_id: egen missing_total = sum(missing)
drop if missing_total == 25

bys group_both: egen max_treat = max(treat_absorbing)
drop if max_treat == 0

save `"$data_dir/ethiopia_site_data.dta"', replace

* --- 3a: site-by-site sdid_event ---
su group_both, meanonly
local n_sites = r(max)

forvalues g = 1/`n_sites' {

    display "===== Site `g' / `n_sites' ====="
    preserve
    keep if group_both == `g'

    * Skip if no treated obs after 2002
    quietly su year if treat_absorbing == 1 & year > 2002, meanonly
    if r(N) == 0 {
        display "  Skipping site `g': no treated obs after 2002"
        restore
        continue
    }

    quietly {
        su year if year > 2002, meanonly
        local year_min  = r(min)
        local year_max  = r(max)
        su year if treat_absorbing == 1 & year > 2002, meanonly
        local treat_year = r(min)
    }
    local pre   = `treat_year' - `year_min'
    local post  = `year_max' - `treat_year' + 1
    local total = `pre' + `post'

    display "  treat yr: `treat_year'  pre: `pre'  post: `post'"

    capture sdid_event smooth_mean unique_id year treat_absorbing if year > 2002, ///
        vce(placebo) placebo(all)
    if _rc != 0 {
        display "  WARNING: sdid_event failed for site `g', skipping"
    }
    else {
        mat res = e(H)[2..`=`total'+1', 1..5]
        svmat res
        gen id = _n - 1 if !missing(res1)
        replace id = `post' - _n if _n > `post' & !missing(res1)
        sort id
        twoway (rarea res3 res4 id, lc(gs10) fc(gs11%50)) ///
               (scatter res1 id, mc(blue) ms(d)), ///
               legend(off) title("Ethiopia - Site `g' sdid_event") ///
               xtitle(Relative time to treatment change) ytitle(Smooth NDVI) ///
               yline(0, lc(red) lp(-)) xline(0, lc(black) lp(solid))
        graph export `"$fig_dir/project/ethiopia_sdid_event_site`g'_modis_ndvi.jpg"', replace
        graph export `"$fig_dir/project/ethiopia_sdid_event_site`g'_modis_ndvi.pdf"', replace
        drop res1 res2 res3 res4 res5 id
    }

    restore
}

* --- 3b: collect ATT across sites ---
use `"$data_dir/ethiopia_site_data.dta"', clear
gen coef = .
gen se   = .

su group_both, meanonly
local n_sites = r(max)

forvalues g = 1/`n_sites' {
    capture sdid smooth_mean unique_id year treat_absorbing ///
        if group_both == `g' & year > 2002, vce(noinference)
    if _rc != 0 {
        display "WARNING: sdid ATT failed for site `g', skipping"
    }
    else {
        sdid smooth_mean unique_id year treat_absorbing ///
            if group_both == `g' & year > 2002, vce(placebo) reps(100)
        replace coef = e(ATT)         if group_both == `g'
        replace se   = e(ATT) + e(se) if group_both == `g'
    }
}

keep coef se proj_id site_id site_rpt group_both country proj_plant_yr
duplicates drop group_both, force
save `"$data_dir/ethiopia_sdid_results_by_site_modis_ndvi.dta"', replace

* --- 3c: cohort-level pooled sdid_event ---
use `"$data_dir/ethiopia_site_data.dta"', clear

gen cohort = proj_plant_yr
levelsof cohort, local(cohorts)

foreach cohort_yr of local cohorts {

    display "===== Cohort `cohort_yr' ====="
    preserve
    keep if cohort == `cohort_yr' | treatment == 0

    quietly su year if treat_absorbing == 1 & year > 2002, meanonly
    if r(N) == 0 {
        display "  Skipping cohort `cohort_yr': no treated obs after 2002"
        restore
        continue
    }

    quietly {
        su year if year > 2002, meanonly
        local year_min  = r(min)
        local year_max  = r(max)
        su year if treat_absorbing == 1 & year > 2002, meanonly
        local treat_year = r(min)
    }
    local pre   = `treat_year' - `year_min'
    local post  = `year_max' - `treat_year' + 1
    local total = `pre' + `post'

    display "  treat yr: `treat_year'  pre: `pre'  post: `post'"

    capture sdid_event smooth_mean unique_id year treat_absorbing if year > 2002, ///
        vce(placebo) placebo(all)
    if _rc != 0 {
        display "  WARNING: sdid_event failed for cohort `cohort_yr', skipping"
    }
    else {
        mat res = e(H)[2..`=`total'+1', 1..5]
        svmat res
        gen id = _n - 1 if !missing(res1)
        replace id = `post' - _n if _n > `post' & !missing(res1)
        sort id
        twoway (rarea res3 res4 id, lc(gs10) fc(gs11%50)) ///
               (scatter res1 id, mc(blue) ms(d)), ///
               legend(off) title("Ethiopia - Cohort `cohort_yr' sdid_event") ///
               xtitle(Relative time to treatment change) ytitle(Smooth NDVI) ///
               yline(0, lc(red) lp(-)) xline(0, lc(black) lp(solid))
        graph export `"$fig_dir/ethiopia_sdid_event_cohort`cohort_yr'_modis_ndvi.jpg"', replace
        graph export `"$fig_dir/ethiopia_sdid_event_cohort`cohort_yr'_modis_ndvi.pdf"', replace
        drop res1 res2 res3 res4 res5 id
    }

    restore
}

* --- 3d: raw NDVI trends by cohort (diagnostic) ---
use `"$data_dir/ethiopia_site_data.dta"', clear

collapse (mean) smooth_mean, by(proj_plant_yr year treatment)

levelsof proj_plant_yr, local(cohorts)

foreach cohort_yr of local cohorts {
    preserve
    keep if proj_plant_yr == `cohort_yr'

    twoway (line smooth_mean year if treatment == 1, lc(blue) lw(medium)) ///
           (line smooth_mean year if treatment == 0, lc(red) lw(medium)), ///
           legend(order(1 "Treated" 2 "Control")) ///
           title("Ethiopia - Cohort `cohort_yr' raw trends") ///
           xtitle(Year) ytitle(Smooth NDVI) ///
           xline(`cohort_yr', lc(black) lp(dash))
    graph export `"$fig_dir/ethiopia_rawtrends_cohort`cohort_yr'_modis_ndvi.jpg"', replace
    graph export `"$fig_dir/ethiopia_rawtrends_cohort`cohort_yr'_modis_ndvi.pdf"', replace

    restore
}
