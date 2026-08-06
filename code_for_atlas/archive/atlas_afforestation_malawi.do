if c(username) == "wyf19" {
    global dropdir "C:/Users/wyf19/Dropbox"
}
else if c(username) == "wangy390" {
    global dropdir "D:/Dropbox"
}

global gee_dir    "$dropdir/Afforestation_Transition/Data/Processed Data/Processed from GEE/GEE_Extracts_2"
global fig_dir    "$dropdir/Afforestation_Transition/Output/Figure/atlas"
global data_dir   "$dropdir/Afforestation_Transition/Data/Processed Data"

********************************************************************************
* STEP 1: Load and merge Malawi CSVs
********************************************************************************

local first = 1
local files : dir `"$gee_dir/malawi"' files "*_covariates.csv"

foreach f of local files {
    import delimited `"$gee_dir/malawi/`f'"', clear
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

use "`combined'", clear

********************************************************************************
* STEP 2: Clean and prepare Malawi NDVI panel
********************************************************************************

keep if variable == "modis_ndvi"
duplicates drop
destring plant_yr, replace force
drop if plant_yr == .          // drop projects with no planting year
drop if plant_yr <= 2003       // no meaningful pre-period
drop if plant_yr >= 2024       // only 1 year post-treatment

replace control_id = 0 if mi(control_id)

* Project-level treatment year: earliest plant_yr within each proj_id
bys proj_id: egen proj_plant_yr = min(plant_yr)

* Drop proj_rgw0BJclVAad1iXPB2dYrUze (plant_yr=2000, no pre-period)
drop if proj_plant_yr <= 2003

* Panel unit: each treated polygon and its matched controls
egen unique_id = group(treated_polygon_id ctry_id proj_id site_id site_rpt control_id treatment)

* Treatment indicator based on project-level timing
gen treat_absorbing = (control_id == 0 & year >= proj_plant_yr)

* Smoothing: linear interpolation then 4-period rolling mean
sort unique_id year
by unique_id: ipolate mean year, gen(mean_ipo) epolate
by unique_id: gen smooth_mean = (mean_ipo[_n-3] + mean_ipo[_n-2] + mean_ipo[_n-1] + mean_ipo[_n]) / 4
gen missing = mi(smooth_mean)

* Drop units entirely missing
by unique_id: egen missing_total = sum(missing)
drop if missing_total == 25

* Drop projects that have no treated observations
bys proj_id: egen max_treat = max(treat_absorbing)
drop if max_treat == 0

save `"$data_dir/malawi_project_data.dta"', replace

********************************************************************************
* STEP 3: Project-by-project sdid_event + TWFE event study
********************************************************************************

use `"$data_dir/malawi_project_data.dta"', clear
egen proj_group = group(treated_polygon_id ctry_id proj_id)
su proj_group, meanonly
local n_proj = r(max)

* --- sdid_event: project-by-project ---
forvalues g = 1/`n_proj' {

    preserve
    keep if proj_group == `g'

    quietly {
        su year if treat_absorbing == 1, meanonly
        local treat_yr = r(min)
        su year, meanonly
        local year_min = r(min)
        local year_max = r(max)
    }
    local pre   = `treat_yr' - `year_min'
    local post  = `year_max' - `treat_yr' + 1
    local total = `pre' + `post'

    * Get project name for title
    quietly levelsof proj_id, local(pid)

    display "Project `g' (`pid')  |  treat yr: `treat_yr'  pre: `pre'  post: `post'"

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
               legend(off) title("Malawi - Project `g' sdid_event") ///
               note("`pid'") ///
               xtitle(Relative time to treatment) ytitle(Smooth NDVI) ///
               yline(0, lc(red) lp(-)) xline(0, lc(black) lp(solid))
        graph export `"$fig_dir/project/malawi_sdid_event_proj`g'_modis_ndvi.jpg"', replace
        graph export `"$fig_dir/project/malawi_sdid_event_proj`g'_modis_ndvi.pdf"', replace
        drop res1 res2 res3 res4 res5 id
    }

    restore
}

* --- sdid ATT: project-by-project ---
use `"$data_dir/malawi_project_data.dta"', clear
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
save `"$data_dir/malawi_sdid_results_by_project_modis_ndvi.dta"', replace

* --- TWFE event study: project-by-project ---
use `"$data_dir/malawi_project_data.dta"', clear
egen proj_group = group(proj_id)
gen rel_time = year - proj_plant_yr

su proj_group, meanonly
local n_proj = r(max)

forvalues g = 1/`n_proj' {

    preserve
    keep if proj_group == `g'

    quietly levelsof proj_id, local(pid)

    capture reghdfe smooth_mean ib(-1).rel_time, ///
        absorb(unique_id year) vce(cluster unique_id) nocons

    if _rc == 0 {
        coefplot, keep(*.rel_time) omitted baselevels ///
            vertical recast(connected) ///
            ciopts(recast(rarea) fc(gs11%50) lc(gs10)) ///
            yline(0, lc(red) lp(-)) xline(-0.5, lc(black) lp(solid)) ///
            title("Malawi - Project `g' TWFE event study") ///
            note("`pid'") ///
            xtitle(Relative time to treatment) ytitle(Smooth NDVI) ///
            legend(off)
        graph export `"$fig_dir/project/malawi_twfe_event_proj`g'_modis_ndvi.jpg"', replace
        graph export `"$fig_dir/project/malawi_twfe_event_proj`g'_modis_ndvi.pdf"', replace
    }
    else {
        display "WARNING: TWFE event study failed for project `g', skipping"
    }

    restore
}
