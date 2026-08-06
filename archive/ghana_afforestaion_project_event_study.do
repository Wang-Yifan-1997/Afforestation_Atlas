/********************************************************************************************
*   code: ghana_afforestaion_project_event_study.do
    PROJECT: Afforestation_Transition
*   PURPOSE: Descriptives for Global Afforestation Projects
*   AUTHOR:  Yifan Wang
*   UPDATED: 2025-11-21
********************************************************************************************/

*===============================================================================
* 0. Define file paths based on user
*===============================================================================

if c(username) == "wyf19" {
    global dropdir "C:/Users/wyf19/Dropbox"
}
else if c(username) == "wangy390" | c(username) == "WANGY390" {
    global dropdir "C:/Users/wangy390/Dropbox"
}

/** Append 2 Datasets **/

import delimited "$dropdir/Afforestation_Transition/Data/Processed Data/Control_Polygons/control_ndvi_timeseries.csv", clear
destring mean_ndvi median_ndvi sd_ndvi planting_date_reported years_since_treatment, replace force
gen treat = 0

tempfile control_ndvi
save "`control_ndvi'"

import delimited "$dropdir/Afforestation_Transition/Data/Processed Data/Treated_Polygons/treated_ndvi_timeseries.csv", clear
destring mean_ndvi median_ndvi sd_ndvi, replace force
drop min_ndvi max_ndvi p25_ndvi p75_ndvi n_pixels
rename polygon_id treated_polygon_id 
gen control_id = 0
gen treat = 1

append using "`control_ndvi'"

gen l_mean_ndvi = log(mean_ndvi)


// Event Study Analysis
egen idcode = group(treated_polygon_id control_id)

gen treat_year = planting_date_reported if treat == 1
tab planting_date_reported
drop if planting_date_reported == 2024
bysort idcode: egen first_treat = min(treat_year)
drop treat_year

gen ry = year - first_treat
gen never_treat = (treat == 0)

tab ry
forvalues k = 16(-1)2{
	gen g_`k' = ry == -`k'
}
forvalues k = 0/16{
	gen g`k' = ry == `k'
}

eventstudyinteract mean_ndvi g_* g0-g16, cohort(first_treat) control_cohort(never_treat) absorb(i.idcode i.year) vce(cluster idcode)

* Extract coefficients and standard errors
matrix C = e(b_iw)
mata st_matrix("A", sqrt(diagonal(st_matrix("e(V_iw)"))))
matrix C = C \ A'

* Check the matrix
matrix list C

* Install coefplot if needed
* ssc install coefplot

* Create event study plot
coefplot matrix(C[1]), se(C[2]) ///
    vertical ///
    yline(0, lcolor(red) lpattern(dash)) ///
    xline(16.5, lcolor(black) lpattern(dash)) ///
    ytitle("Effect on NDVI") ///
    xtitle("Periods relative to treatment") ///
    title("Event Study: Afforestation Impact on NDVI") ///
    ciopts(recast(rcap) lcolor(navy)) ///
    mcolor(navy) ///
    graphregion(color(white)) bgcolor(white) ///
    xlabel(, angle(45))
	
s	   
reghdfe mean_ndvi g_* g0-g16, absorb(i.idcode i.year) vce(cluster idcode)



/** Merge 2 Datasets

import delimited "$dropdir/Afforestation_Transition/Data/Processed Data/Control_Polygons/control_ndvi_timeseries.csv", clear
keep treated_polygon_id year control_id mean_ndvi median_ndvi sd_ndvi
destring mean_ndvi median_ndvi sd_ndvi, replace force
rename (mean_ndvi median_ndvi sd_ndvi) (mean_ndvi_control median_ndvi_control sd_ndvi_control)

tempfile control_ndvi
save "`control_ndvi'"

import delimited "$dropdir/Afforestation_Transition/Data/Processed Data/Treated_Polygons/treated_ndvi_timeseries.csv", clear
destring mean_ndvi median_ndvi sd_ndvi, replace force
drop min_ndvi max_ndvi p25_ndvi p75_ndvi
rename (polygon_id mean_ndvi median_ndvi sd_ndvi) (treated_polygon_id mean_ndvi_treat median_ndvi_treat sd_ndvi_treat)
merge 1:m treated_polygon_id year using "`control_ndvi'"
/*two treated polygons find control but the treated polygon itself disapears for some reasons*/
keep if _merge == 3
drop _merge

preserve

collapse (mean) mean_ndvi_control, by(treated_polygon_id planting_date_reported year mean_ndvi_treat median_ndvi_treat sd_ndvi_treat n_pixels period years_since_treatment)

gen first_diff = mean_ndvi_treat - mean_ndvi_control

sum first_diff if years_since_treatment < 0
sum first_diff if years_since_treatment > 0

scatter first_diff years_since_treatment

restore




