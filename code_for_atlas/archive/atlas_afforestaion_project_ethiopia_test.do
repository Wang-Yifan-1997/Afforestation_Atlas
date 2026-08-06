if c(username) == "wyf19" {
    global dropdir "C:/Users/wyf19/Dropbox"
}
else if c(username) == "wangy390" {
    global dropdir "D:/Dropbox"
}

global gee_dir  "$dropdir/Afforestation_Transition/Data/Processed Data/Processed from GEE/GEE_Extracts_2"
global fig_dir  "$dropdir/Afforestation_Transition/Output/Figure/atlas"

use `"$gee_dir/all_covariates_combined_2.dta"', clear
keep if variable == "modis_ndvi" & country == "Ethiopia"
duplicates drop
drop if plant_yr == .

replace control_id = 0 if mi(control_id)

egen group_both = group(treated_polygon_id ctry_id proj_id site_id site_rpt)
bys group_both: egen proj_plant_yr = min(plant_yr)

egen unique_id = group(treated_polygon_id ctry_id proj_id site_id site_rpt control_id treatment)
gen treat_absorbing = (control_id == 0 & year >= proj_plant_yr)

sort unique_id year
by unique_id: ipolate mean year, gen(mean_ipo) epolate
by unique_id: gen smooth_mean = (mean_ipo[_n-3] + mean_ipo[_n-2] + mean_ipo[_n-1] + mean_ipo[_n]) / 4
gen missing = mi(smooth_mean)
by unique_id: egen missing_total = sum(missing)
drop if missing_total == 25

bys group_both: egen max_treat = max(treat_absorbing)
drop if max_treat == 0

su group_both, meanonly
local n_proj = r(max)

forvalues g = 1/`n_proj' {

    display "===== Project `g' / `n_proj' ====="
    preserve
    keep if group_both == `g'

    quietly {
        su year if year > 2002, meanonly
        local year_min = r(min)
        local year_max = r(max)
        su year if treat_absorbing == 1 & year > 2002, meanonly
        local treat_year = r(min)
    }
    local pre   = `treat_year' - `year_min'
    local post  = `year_max' - `treat_year' + 1
    local total = `pre' + `post'

    display "  group_both: `g'  |  treat yr: `treat_year'  pre: `pre'  post: `post'"

    capture sdid_event smooth_mean unique_id year treat_absorbing if year > 2002, ///
        vce(placebo) placebo(all)
    if _rc != 0 {
        display "  WARNING: sdid_event failed for group `g', skipping"
    }
    else {
        mat res = e(H)[2..`=`total'+1', 1..5]
        svmat res
        gen id = _n - 1 if !missing(res1)
        replace id = `post' - _n if _n > `post' & !missing(res1)
        sort id
        twoway (rarea res3 res4 id, lc(gs10) fc(gs11%50)) ///
               (scatter res1 id, mc(blue) ms(d)), ///
               legend(off) title("Ethiopia - Group `g' sdid_event") ///
               xtitle(Relative time to treatment change) ///
               ytitle(Smooth NDVI) ///
               yline(0, lc(red) lp(-)) xline(0, lc(black) lp(solid))
        graph export `"$fig_dir/project/ethiopia_sdid_event_`g'_modis_ndvi.jpg"', replace
        graph export `"$fig_dir/project/ethiopia_sdid_event_`g'_modis_ndvi.pdf"', replace
        drop res1 res2 res3 res4 res5 id
    }

    restore
}



** Do it cohort by cohort
* Get cohorts (unique treatment years)
gen treatment_year = proj_plant_yr if treat_absorbing == 1
bys group_both: egen cohort = min(treatment_year)
drop if mi(cohort)

levelsof cohort, local(cohorts)

preserve
keep if cohort == 2018

quietly {
    su year if year > 2002, meanonly
    local year_min = r(min)
    local year_max = r(max)
    su year if treat_absorbing == 1 & year > 2002, meanonly
    local treat_year = r(min)
}
local pre   = `treat_year' - `year_min'
local post  = `year_max' - `treat_year' + 1
local total = `pre' + `post'

display "treat yr: `treat_year'  pre: `pre'  post: `post'"

sdid_event smooth_mean unique_id year treat_absorbing if year > 2002, ///
    vce(placebo) placebo(all)

mat res = e(H)[2..`=`total'+1', 1..5]
svmat res
gen id = _n - 1 if !missing(res1)
replace id = `post' - _n if _n > `post' & !missing(res1)
sort id
twoway (rarea res3 res4 id, lc(gs10) fc(gs11%50)) ///
       (scatter res1 id, mc(blue) ms(d)), ///
       legend(off) title("Ethiopia - Cohort 2018 sdid_event") ///
       xtitle(Relative time to treatment change) ///
       ytitle(Smooth NDVI) ///
       yline(0, lc(red) lp(-)) xline(0, lc(black) lp(solid))

restore
