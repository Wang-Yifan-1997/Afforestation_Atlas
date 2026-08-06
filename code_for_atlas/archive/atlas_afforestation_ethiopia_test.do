use "$gee_dir/all_covariates_combined_2.dta", clear
keep if variable == "modis_ndvi"
keep if country == "Ethiopia"
duplicates drop
drop if plant_yr == .

replace control_id = 0 if mi(control_id)
egen group_both   = group(treated_polygon_id ctry_id proj_id site_id site_rpt)
bys group_both: egen proj_plant_yr = min(plant_yr)
egen unique_id    = group(treated_polygon_id ctry_id proj_id site_id site_rpt control_id treatment)
gen treat_absorbing = (control_id == 0 & year >= proj_plant_yr)

sort unique_id year
by unique_id: ipolate mean year, gen(mean_ipo) epolate
by unique_id: gen smooth_mean = (mean_ipo[_n-3] + mean_ipo[_n-2] + mean_ipo[_n-1] + mean_ipo[_n]) / 4
gen missing = mi(smooth_mean)
by unique_id: egen missing_total = sum(missing)
drop if missing_total == 25

bys group_both: egen max_treat = max(treat_absorbing)
drop if max_treat == 0
drop if proj_plant_yr <= 2003

gen cohort   = proj_plant_yr
gen rel_time = year - cohort
replace rel_time = . if treatment == 0

* Keep 2018 cohort + its controls
* Tag the relevant group_both values
gen keep_flag = (cohort == 2018)
bys group_both: egen any_2018 = max(keep_flag)
keep if any_2018 == 1
drop keep_flag any_2018

keep unique_id group_both cohort treatment control_id year smooth_mean rel_time treat_absorbing

********************************************************************************
* RESHAPE TO WIDE
********************************************************************************

reshape wide smooth_mean treat_absorbing rel_time, ///
    i(unique_id group_both cohort treatment control_id) j(year)

********************************************************************************
* ENTROPY BALANCING on pre-2018 NDVI years
********************************************************************************

gen treated_unit = (treatment == 1)

* Balance on each pre-treatment year's NDVI: 2003-2017
ebalance treated_unit smooth_mean2003 smooth_mean2004 smooth_mean2005 ///
    smooth_mean2006 smooth_mean2007 smooth_mean2008 smooth_mean2009 ///
    smooth_mean2010 smooth_mean2011 smooth_mean2012 smooth_mean2013 ///
    smooth_mean2014 smooth_mean2015 smooth_mean2016 smooth_mean2017, targets(1)

rename _webal _ebal_weight
replace _ebal_weight = 1 if treatment == 1

********************************************************************************
* RESHAPE BACK TO LONG
********************************************************************************

reshape long smooth_mean treat_absorbing rel_time, ///
    i(unique_id group_both cohort treatment control_id _ebal_weight) j(year)

drop if mi(smooth_mean)

********************************************************************************
* EVENT STUDY DUMMIES
********************************************************************************

quietly su rel_time if treatment == 1 & year > 2002, meanonly
local rel_min = abs(r(min))
local rel_max = r(max)

display "pre: `rel_min'  post: `rel_max'"

forvalues k = `rel_min'(-1)2 {
    gen g_`k' = (rel_time == -`k') if !mi(rel_time)
    replace g_`k' = 0 if mi(g_`k')
}
forvalues k = 0/`rel_max' {
    gen g`k' = (rel_time == `k') if !mi(rel_time)
    replace g`k' = 0 if mi(g`k')
}

set matsize 800

reghdfe smooth_mean g_* g0-g`rel_max' [aw=_ebal_weight] if year > 2002, ///
    absorb(unique_id year) vce(cluster unique_id)

********************************************************************************
* MANUAL PLOT
********************************************************************************

matrix b = e(b)
matrix V = e(V)

clear
local total_obs = (`rel_min' - 1) + 1 + (`rel_max' + 1)
set obs `total_obs'
gen id    = .
gen coef  = .
gen ci_lo = .
gen ci_hi = .

local row = 1
forvalues k = `rel_min'(-1)2 {
    replace id    = -`k'                                                             in `row'
    replace coef  = b[1, colnumb(b, "g_`k'")]                                       in `row'
    replace ci_lo = coef - 1.96*sqrt(V[colnumb(b,"g_`k'"),colnumb(b,"g_`k'")])     in `row'
    replace ci_hi = coef + 1.96*sqrt(V[colnumb(b,"g_`k'"),colnumb(b,"g_`k'")])     in `row'
    local row = `row' + 1
}

* Baseline -1
replace id    = -1 in `row'
replace coef  = 0  in `row'
replace ci_lo = 0  in `row'
replace ci_hi = 0  in `row'
local row = `row' + 1

forvalues k = 0/`rel_max' {
    replace id    = `k'                                                              in `row'
    replace coef  = b[1, colnumb(b, "g`k'")]                                        in `row'
    replace ci_lo = coef - 1.96*sqrt(V[colnumb(b,"g`k'"),colnumb(b,"g`k'")])       in `row'
    replace ci_hi = coef + 1.96*sqrt(V[colnumb(b,"g`k'"),colnumb(b,"g`k'")])       in `row'
    local row = `row' + 1
}

sort id
twoway (rarea ci_lo ci_hi id, lc(gs10) fc(gs11%50)) ///
       (connected coef id, mc(blue) ms(d) lc(blue)), ///
       legend(off) ///
       title("Ethiopia - Cohort 2018 TWFE+EB event study") ///
       xtitle(Relative time to treatment) ytitle(Smooth NDVI) ///
       yline(0, lc(red) lp(-)) xline(-0.5, lc(black) lp(solid))
graph export `"$fig_dir/twfe_eb_event_Ethiopia_cohort2018_modis_ndvi.jpg"', replace
graph export `"$fig_dir/twfe_eb_event_Ethiopia_cohort2018_modis_ndvi.pdf"', replace