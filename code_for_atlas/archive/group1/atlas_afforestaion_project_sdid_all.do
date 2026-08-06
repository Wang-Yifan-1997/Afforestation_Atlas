if c(username) == "wyf19" {
    global dropdir "C:/Users/wyf19/Dropbox"
}
else if c(username) == "wangy390" {
    global dropdir "D:/Dropbox"
}

global gee_dir "$dropdir/Afforestation_Transition/Data/Processed Data/Processed from GEE/GEE_Extracts"


s
**** ANALYSIS
use "$gee_dir/all_covariates_combined.dta", clear
*keep if variable == "landsat_ndvi"
keep if variable == "modis_ndvi"


replace control_id = 0 if mi(control_id)
egen group_both = group(treated_polygon_id ctry_id proj_id site_id site_rpt)
egen unique_id = group(treated_polygon_id ctry_id proj_id site_id site_rpt control_id)

gen treat_absorbing = (control_id == 0 & year>= plant_yr)

*reghdfe mean treat_absorbing, absorb(unique_id year) vce(cluster unique_id)

* do some smoothing
sort unique_id year
by unique_id: ipolate mean year, gen(mean_ipo) epolate

* do some additional data cleaning
gen missing = mi(mean)
by unique_id: egen missing_total = sum(missing)
tab missing_total
drop if missing_total == 25

gen treatment_year = year if treat_absorbing == 1
by unique_id: egen first_year = min(treatment_year)
tab first_year

bys country: egen max_treat = max(treat_absorbing)
tab max_treat
drop if max_treat == 0

save "$dropdir/Afforestation_Transition/Output/Figure/atlas/project/sdid_event_data.dta", replace

use "$dropdir/Afforestation_Transition/Output/Figure/atlas/project/sdid_event_data.dta", clear

forvalues group_both = 1/103{
	
	preserve
	
	keep if group_both == `group_both'
	capture sdid mean unique_id year treat_absorbing, vce(noinference)
	if _rc != 0 {
		display "WARNING: sdid failed, skipping"
	}
	else {
		sdid mean unique_id year treat_absorbing, vce(placebo) graph graph_export("$dropdir/Afforestation_Transition/Output/Figure/atlas/project/sdid_`group_both'_modis_ndvi", .pdf)
		sdid mean unique_id year treat_absorbing, vce(placebo) graph method(sc) graph_export("$dropdir/Afforestation_Transition/Output/Figure/atlas/project/sc_`group_both'_modis_ndvi", .pdf)
		
		sdid_event mean unique_id year treat_absorbing, ///
			vce(placebo) placebo(all)
		
		mat res = e(H)[2..25,1..5]
		su year
		local year_max = r(max)
		su year if treat_absorbing == 1, meanonly
		local treat_year = r(min)
		local post  = `year_max' - `treat_year' + 1
		svmat res
		gen id = _n - 1 if !missing(res1)
		replace id = `post' - _n if _n > `post' & !missing(res1)
		sort id
		twoway (rarea res3 res4 id, lc(gs10) fc(gs11%50)) (scatter res1 id, mc(blue) ms(d)), legend(off) title(sdid_event) ///
			xtitle(Relative time to treatment change) ytitle(NDVI) yline(0, lc(red) lp(-)) xline(0, lc(black) lp(solid))
		graph export "$dropdir/Afforestation_Transition/Output/Figure/atlas/project/sdid_event_`group_both'_modis_ndvi.jpg", replace
		graph export "$dropdir/Afforestation_Transition/Output/Figure/atlas/project/sdid_event_`group_both'_modis_ndvi.pdf", replace
	}
	
	restore
	
}

use "$dropdir/Afforestation_Transition/Output/Figure/atlas/project/sdid_event_data.dta", clear
gen coef = .
gen se = .

forvalues group_both = 1/103{
    
	capture sdid mean unique_id year treat_absorbing if group_both == `group_both', vce(noinference)
	if _rc != 0 {
		display "WARNING: sdid failed, skipping"
	}
	else {
		sdid mean unique_id year treat_absorbing if group_both == `group_both', vce(placebo) reps(100)
		* Extract coefficient and SE from e() after sdid
		replace coef = e(ATT) if country == "`c'"
		replace se   = e(ATT) + e(se) if country == "`c'"  // placeholder, adjust as needed
	}
	
}

* Keep one row per country
keep coef se country group_both
save "$dropdir/Afforestation_Transition/Data/Processed Data/sdid_event_data_results_modis_ndvi.dta", replace


s

sdid mean unique_id year treat_absorbing, vce(noinference)
if mistake, then skip the rest, otherwise continute
sdid mean unique_id year treat_absorbing, vce(placebo) graph
sdid mean unique_id year treat_absorbing, vce(placebo) graph method(sc)

sdid_event mean unique_id year treat_absorbing, ///
    vce(placebo) placebo(all)
mat res = e(H)[2..25,1..5]

su year if year > 2002
local year_max = r(max)
su year if treat_absorbing == 1, meanonly
local treat_year = r(min)

local post  = `year_max' - `treat_year' + 1

svmat res
gen id = _n - 1 if !missing(res1)
replace id = `post' - _n if _n > `post' & !missing(res1)
sort id
twoway (rarea res3 res4 id, lc(gs10) fc(gs11%50)) (scatter res1 id, mc(blue) ms(d)), legend(off) title(sdid_event) ///
	xtitle(Relative time to treatment change) ytitle(NDVI) yline(0, lc(red) lp(-)) xline(0, lc(black) lp(solid))

s
preserve

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

display "pre: `pre', post: `post', total: `total'"

sdid_event mean unique_id year treat_absorbing if year > 2002, ///
    vce(placebo) placebo(all)

mat res = e(H)[2..`=`total'+1', 1..5]
svmat res
gen id = _n - 1 if !missing(res1)
replace id = `post' - _n if _n > `post' & !missing(res1)
sort id
twoway (rarea res3 res4 id, lc(gs10) fc(gs11%50)) ///
       (scatter res1 id, mc(blue) ms(d)), ///
       legend(off) title("Project 77 sdid_event") ///
       xtitle(Relative time to treatment change) ///
       ytitle(Smooth Mean) ///
       yline(0, lc(red) lp(-)) xline(0, lc(black) lp(solid))

restore