if c(username) == "wyf19" {
    global dropdir "C:/Users/wyf19/Dropbox"
}
else if c(username) == "wangy390" {
    global dropdir "D:/Dropbox"
}

global gee_dir "$dropdir/Afforestation_Transition/Data/Processed Data/Processed from GEE/GEE_Extracts"

stop
* Loop over all CSV files and append
local files : dir "$gee_dir" files "*.csv"
local first = 1

foreach f of local files {
    import delimited "$gee_dir/`f'", clear
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

use "`combined'", clear

replace country = "Cote dIvoire" if strpos(country, "Ivoire") > 0
replace country = "Central African Rep" if country == "Central African Rep."

save "$gee_dir/all_covariates_combined.dta", replace




**** ANALYSIS
use "$gee_dir/all_covariates_combined.dta", clear
*keep if variable == "landsat_ndvi"
keep if variable == "modis_ndvi"


replace control_id = 0 if mi(control_id)
egen unique_id = group(treated_polygon_id ctry_id proj_id site_id site_rpt control_id)

gen treat_absorbing = (control_id == 0 & year>= plant_yr)

*reghdfe mean treat_absorbing, absorb(unique_id year) vce(cluster unique_id)

* do some smoothing
sort unique_id year
by unique_id: ipolate mean year, gen(mean_ipo) epolate
by unique_id: gen smooth_mean = (mean_ipo[_n-3] + mean_ipo[_n-2] + mean_ipo[_n-1] + mean_ipo[_n])/4
gen missing = mi(smooth_mean)


* do some additional data cleaning
by unique_id: egen missing_total = sum(missing)
tab missing_total
drop if missing_total == 25

gen treatment_year = year if treat_absorbing == 1
by unique_id: egen first_year = min(treatment_year)
tab first_year
drop if first_year <= 2003

bys country: egen max_treat = max(treat_absorbing)
tab max_treat
drop if max_treat == 0


levelsof country, local(countries)

foreach c of local countries {
	
	display "`c'"
	
    * Calculate pre and post treatment periods
    quietly {
        su year if country == "`c'" & year > 2002, meanonly
        local year_min = r(min)
        local year_max = r(max)
        
        su year if country == "`c'" & treat_absorbing == 1 & year > 2002, meanonly
        local treat_year = r(min)
        
    }
	
	local pre  = `treat_year' - `year_min'      // years before treatment
	local post = `year_max' - `treat_year' + 1        // years after treatment
	local total = `pre' + `post'                 // replaces 26 in e(H)[2..27]
	
	display `pre'
    display `post'
	
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
    graph export "$dropdir/Afforestation_Transition/Output/Figure/atlas/sdid_event_`c'_modis_ndvi.jpg", replace
    graph export "$dropdir/Afforestation_Transition/Output/Figure/atlas/sdid_event_`c'_modis_ndvi.pdf", replace
    * Drop svmat columns before next iteration
    drop res1 res2 res3 res4 res5 id
}


* Get list of countries
levelsof country, local(countries)

preserve
* Store results
gen coef = .
gen se = .

foreach c of local countries {
    sdid smooth_mean unique_id year treat_absorbing if year > 2002 & country == "`c'", ///
        vce(placebo) reps(100)
    
    * Extract coefficient and SE from e() after sdid
    replace coef = e(ATT) if country == "`c'"
    replace se   = e(ATT) + e(se) if country == "`c'"  // placeholder, adjust as needed
}

* Keep one row per country
keep coef se country
duplicates drop country, force
save "$dropdir/Afforestation_Transition/Data/Processed Data/sdid_results_modis_ndvi.dta", replace

restore


