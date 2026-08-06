if c(username) == "wyf19" {
    global dropdir "C:/Users/wyf19/Dropbox"
}
else if c(username) == "wangy390" | c(username) == "WANGY390" {
    global dropdir "C:/Users/wangy390/Dropbox"
}

import delimited "$dropdir/Afforestation_Transition/Data/Processed Data/Processed from GEE/GEE_Extracts/angola_control_covariates.csv", clear

tempfile angola_control_covariates
save "`angola_control_covariates'"

import delimited "$dropdir/Afforestation_Transition/Data/Processed Data/Processed from GEE/GEE_Extracts/angola_treated_covariates.csv", clear
rename poly_id treated_polygon_id
append using "`angola_control_covariates'"

keep if variable == "landsat_ndvi"

replace control_id = 0 if mi(control_id)
egen unique_id = group(treated_polygon_id ctry_id proj_id site_id site_rpt control_id)

gen treat_absorbing = (control_id == 0 & year>= plant_yr)


reghdfe mean treat_absorbing, absorb(unique_id year) vce(cluster unique_id)

*keep if treated_polygon_id == 242909
sort unique_id year
by unique_id: ipolate mean year, gen(mean_ipo) epolate
by unique_id: gen smooth_mean = (mean_ipo[_n-3] + mean_ipo[_n-2] + mean_ipo[_n-1] + mean_ipo[_n])/4

sdid smooth_mean unique_id year treat_absorbing if year > 2002, vce(placebo) reps(100) graph


	
