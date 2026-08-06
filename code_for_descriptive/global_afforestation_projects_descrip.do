/********************************************************************************************
*   PROJECT: Afforestation_Transition
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

* Check the base directory exists
di "Using Dropbox directory: ${dropdir}"

*===============================================================================
* 1. Load and clean Global Afforestation Projects data
*===============================================================================

import delimited "${dropdir}\Afforestation_Transition\Data\Processed Data\Global Afforestation Projects\Description\updated_LoDIA_Reforestation_Dataset_Antarctica_description.csv", ///
	delimiter(comma) bindquote(strict) varnames(1) encoding(UTF-8) stringcols(_all) maxquotedrows(200) clear
tostring site_id_created, replace
tempfile Antarctica
save "`Antarctica'"

import delimited "${dropdir}\Afforestation_Transition\Data\Processed Data\Global Afforestation Projects\Description\updated_LoDIA_Reforestation_Dataset_NewWorld_description.csv", ///
	delimiter(comma) bindquote(strict) varnames(1) encoding(UTF-8) stringcols(_all) maxquotedrows(200) clear
tempfile NewWorld
save "`NewWorld'"

import delimited "${dropdir}\Afforestation_Transition\Data\Processed Data\Global Afforestation Projects\Description\updated_LoDIA_Reforestation_Dataset_OldWorld_Part1_description.csv", ///
	delimiter(comma) bindquote(strict) varnames(1) encoding(UTF-8) stringcols(_all) maxquotedrows(200) clear
tempfile OldWorld
save "`OldWorld'"

import delimited "${dropdir}\Afforestation_Transition\Data\Processed Data\Global Afforestation Projects\Description\updated_LoDIA_Reforestation_Dataset_OldWorld_Part2_description.csv", ///
	delimiter(comma) bindquote(strict) varnames(1) encoding(UTF-8) stringcols(_all) maxquotedrows(200) clear

append using "`Antarctica'"
append using "`NewWorld'"
append using "`OldWorld'"

* Loop over all variables
foreach var of varlist * {
	quietly  count
	local r_total = `r(N)'

    quietly count if mi(`var')
	local r_missing = `r(N)'
	
    local propmiss = `r_missing' / `r_total'
	
    if `propmiss' > 0.95 {
        drop `var'
        di "Dropped variable `var' (missing proportion = `propmiss')"
    }
}

compress
save "${dropdir}\Afforestation_Transition\Data\Processed Data\Global Afforestation Projects\ForAnalysis.dta", replace

*===============================================================================
* 2.1. Analysis: site and project level
*===============================================================================

use "${dropdir}\Afforestation_Transition\Data\Processed Data\Global Afforestation Projects\ForAnalysis.dta", replace

//these are likely useless
drop project_pdf_available project_id_created project_geometries_invalid host_name url tob_three_ndvi_months

//might be useful later
drop planting_date_derived

//drop obs that miss important variables
drop if mi(country)

//drop obs that seem to be double counted. however, it might be that it is first afforested, and then nested in another larger program
//drop if !mi(nested_in)

foreach var in planting_date_reported tree_cover_area_2000 tree_cover_area_2005 tree_cover_area_2010 tree_cover_area_2015 tree_cover_area_2020 site_sqkm_derived{
	destring `var', replace 
}
replace planting_date_reported = . if planting_date_reported > 2500 | planting_date_reported < 1500
fre planting_date_reported
//Yifan comment: we need to figure out why this is not smooth

keep site_id_created project_id_reported planting_date_reported tree_cover_area_2000 tree_cover_area_2005 tree_cover_area_2010 tree_cover_area_2015 tree_cover_area_2020 country site_sqkm_derived
drop if mi(tree_cover_area_2000) & mi(tree_cover_area_2005)

reshape long tree_cover_area_, i(site_id_created project_id planting_date_reported country site_sqkm_derived) j(year)
rename *_ * 
gen treat = year >= planting_date_reported

egen group_id = group(site_id_created project_id)

winsor2 tree_cover_area, suffix(_w) cuts(0.1 99.9)
gen l_tree_cover_area = asinh(tree_cover_area)
gen tree_cover_area_D = tree_cover_area>0
gen tree_cover_share = tree_cover_area / site_sqkm_derived
replace tree_cover_share = 1 if tree_cover_share > 1

reghdfe tree_cover_area treat, a(year group_id) cluster(group_id)
reghdfe tree_cover_area_w treat, a(year group_id) cluster(group_id)
reghdfe tree_cover_share treat, a(year group_id) cluster(group_id)
reghdfe tree_cover_area_D treat, a(year group_id) cluster(group_id)

reghdfe l_tree_cover_area treat, a(year group_id) cluster(group_id)


*===============================================================================
* 2.1. Analysis: country
*===============================================================================

use "${dropdir}\Afforestation_Transition\Data\Processed Data\Global Afforestation Projects\ForAnalysis.dta", replace

//these are likely useless
drop project_pdf_available project_id_created project_geometries_invalid host_name url tob_three_ndvi_months

//might be useful later
drop planting_date_derived

//drop obs that miss important variables
drop if mi(country)

//drop obs that seem to be double counted. however, it might be that it is first afforested, and then nested in another larger program
//drop if !mi(nested_in)

foreach var in planting_date_reported tree_cover_area_2000 tree_cover_area_2005 tree_cover_area_2010 tree_cover_area_2015 tree_cover_area_2020 site_sqkm_derived{
	destring `var', replace 
}
replace planting_date_reported = . if planting_date_reported > 2500 | planting_date_reported < 1500
fre planting_date_reported
//Yifan comment: we need to figure out why this is not smooth

keep site_id_created project_id_reported planting_date_reported tree_cover_area_2000 tree_cover_area_2005 tree_cover_area_2010 tree_cover_area_2015 tree_cover_area_2020 country site_sqkm_derived
drop if mi(tree_cover_area_2000) & mi(tree_cover_area_2005)

//remove all the ones that are not changing
gen all_the_same = tree_cover_area_2000 == tree_cover_area_2020
drop if all_the_same == 1

reshape long tree_cover_area_, i(site_id_created project_id planting_date_reported country site_sqkm_derived) j(year)
rename *_ * 
gen treat = year >= planting_date_reported

replace project_id = site_id_created if mi(project_id)
egen group_id = group(site_id_created project_id)

winsor2 tree_cover_area, suffix(_w) cuts(0.1 99.9)
gen l_tree_cover_area = asinh(tree_cover_area)
gen tree_cover_area_D = tree_cover_area>0
gen tree_cover_share = tree_cover_area / site_sqkm_derived
replace tree_cover_share = 1 if tree_cover_share > 1

reghdfe tree_cover_area treat, a(year group_id) cluster(group_id)
reghdfe tree_cover_area_w treat, a(year group_id) cluster(group_id)
reghdfe tree_cover_share treat, a(year group_id) cluster(group_id)
reghdfe tree_cover_area_D treat, a(year group_id) cluster(group_id)

reghdfe l_tree_cover_area treat, a(year group_id) cluster(group_id)

stop

drop if planting_date_reported <= 2000
sdid_event tree_cover_area_w group_id year treat, vce(bootstrap) brep(50) placebo(all)
mat res = e(H)[2..9,1..5]
svmat res
gen id = _n - 1 if !missing(res1)
replace id = 4 - _n if _n > 4 & !missing(res1)
sort id
twoway (rarea res3 res4 id, lc(gs10) fc(gs11%50)) (scatter res1 id, mc(blue) ms(d)), legend(off) ///
	xtitle(Relative time to treatment change) ytitle(Forest Cover) yline(0, lc(red) lp(-)) xline(0, lc(black) lp(solid))
