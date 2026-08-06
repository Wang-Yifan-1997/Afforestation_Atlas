********************************************************************************
* 04_policy_strength_scatter.do
* ATLAS Afforestation — Policy Strength: Two Cross-Country Scatter Figures
*
* Figure 1 (scatter_sdid_asinh):
*   Y = asinh(country-mean SDID ATT)  [Africa only — ATT data coverage]
*   X = asinh(cumulative policy strength)
*   Source: 01_site_results.dta + 项目强度.xlsx
*
* Figure 2 (scatter_asinh_unweighted_reversed):
*   Y = asinh(total reforestation programs per country)  [global]
*   X = asinh(cumulative policy strength)
*   Source: ForAnalysis.dta + 项目强度.xlsx
*
* Cumulative policy strength = sum of strength weights across all FAOLEX
* forestry policy entries for a country (very_low=1, low=2, medium=3, high=4).
*
* Inputs:
*   $res_dir/01_effectiveness/01_ndvi/01_site_results.dta
*   $data_dir/Global Afforestation Projects/ForAnalysis.dta
*   $data_dir/FAOLEX/项目强度.xlsx
*
* Outputs: $fig_dir/02_policy/strength/
********************************************************************************

local user = c(username)

if "`user'" == "wyf19"    global dropdir "C:/Users/wyf19/Dropbox"
if "`user'" == "wangy390"  global dropdir "D:/Dropbox"
if "`user'" == "WANGY390"  global dropdir "C:/Users/WANGY390/Dropbox"

global data_dir "$dropdir/Afforestation_Transition/Data/Processed Data"
global fig_dir  "$dropdir/Afforestation_Transition/Output/Figure/atlas"
global res_dir  "$data_dir/results"

cap mkdir "$fig_dir/02_policy"
cap mkdir "$fig_dir/02_policy/strength"

********************************************************************************
* Step 1: Build country-level cumulative policy strength from 项目强度.xlsx
* One row per FAOLEX forestry policy entry; strength encoded as very_low=1 … high=4.
* Country names harmonised to match policy_country_year.dta conventions.
********************************************************************************

import excel `"$data_dir/FAOLEX/项目强度.xlsx"', ///
    sheet("Sheet1") firstrow clear

rename Country country
rename policy_strength strength

replace country = strtrim(country)
replace country = "Cote dIvoire"        if strpos(lower(country), "ivoire")  > 0
replace country = "Guinea Bissau"       if strpos(lower(country), "bissau")  > 0
replace country = "Central African Rep" if strpos(lower(country), "central african") > 0
replace country = "Dem Rep Congo"       if strpos(lower(country), "dem")    > 0 & ///
                                           strpos(lower(country), "congo")  > 0
replace country = "Cabo Verde"          if strpos(lower(country), "cape verde") > 0 | ///
                                           lower(country) == "cabo verde"

drop if missing(strength)
gen strength_weight = .
replace strength_weight = 1 if lower(strength) == "very_low"
replace strength_weight = 2 if lower(strength) == "low"
replace strength_weight = 3 if lower(strength) == "medium"
replace strength_weight = 4 if lower(strength) == "high"

gen is_high = (strength_weight == 4)

collapse (sum)  cum_strength = strength_weight ///
         (mean) avg_strength = strength_weight ///
         (sum)  n_high       = is_high, by(country)

gen asinh_cum_strength = asinh(cum_strength)
gen asinh_avg_strength = asinh(avg_strength)
gen asinh_n_high       = asinh(n_high)

tempfile strength_data
save "`strength_data'"
display "Strength data: `r(N)' countries"

********************************************************************************
* Step 2: Build country-level total program counts from ForAnalysis.dta
********************************************************************************

use `"$data_dir/Global Afforestation Projects/ForAnalysis.dta"', clear

gen plant_yr = real(substr(planting_date_derived, 1, 4))
replace plant_yr = . if plant_yr < 1990
replace plant_yr = . if plant_yr > 2024
drop if mi(plant_yr)
drop if mi(country)

duplicates drop project_id_created country plant_yr, force

gen one = 1
collapse (sum) cum_projects = one, by(country)
gen asinh_cum_projects = asinh(cum_projects)

tempfile project_data
save "`project_data'"
display "Program data: `r(N)' countries"

********************************************************************************
* Step 3: Build country-mean SDID ATT from site-level results
* Geographic coverage: Africa only (matches ATT data scope)
********************************************************************************

use `"$res_dir/01_effectiveness/01_ndvi/01_site_results.dta"', clear

replace country = strtrim(country)
keep country sdid_att

collapse (mean) mean_sdid = sdid_att, by(country)
gen asinh_mean_sdid = asinh(mean_sdid)

tempfile att_data
save "`att_data'"
display "ATT data: `r(N)' countries"

********************************************************************************
* Step 4: Figure 1 — asinh(SDID ATT) vs asinh(Cumulative Policy Strength)
* Africa countries only (inner join on ATT x strength)
********************************************************************************

use "`att_data'", clear
merge 1:1 country using "`strength_data'", keep(match) nogen

count
display "Figure 1 sample: `r(N)' countries"

reg asinh_mean_sdid asinh_cum_strength
reg mean_sdid asinh_cum_strength
twoway ///
    (scatter asinh_mean_sdid asinh_cum_strength, ///
        mlabel(country) mlabpos(12) mc(navy) ms(d) msize(medium)) ///
    (lfit asinh_mean_sdid asinh_cum_strength, lc(gs8) lp(dash)), ///
    legend(off) yline(0, lc(red) lp(-)) ///
    xtitle("Policy Strength") ///
    ytitle(" ")
graph export "$fig_dir/02_policy/strength/scatter_sdid_asinh.jpg", replace
graph export "$fig_dir/02_policy/strength/scatter_sdid_asinh.pdf", replace

display "Figure 1 exported: scatter_sdid_asinh"
s
********************************************************************************
* Step 5: Figure 2 — asinh(Reforestation Programs) vs asinh(Cumulative Policy Strength)
* Global coverage (inner join on programs x strength)
********************************************************************************

use "`project_data'", clear
merge 1:1 country using "`strength_data'", keep(match) nogen

count
display "Figure 2 sample: `r(N)' countries"

twoway ///
    (scatter asinh_cum_projects asinh_cum_strength, ///
        mlabel(country) mlabpos(12) mc(navy) ms(d) msize(medium)) ///
    (lfit asinh_cum_projects asinh_cum_strength, lc(gs8) lp(dash)), ///
    legend(off) ///
    xtitle("Policy Strength") ///
    ytitle(" ")
graph export "$fig_dir/02_policy/strength/scatter_asinh_unweighted_reversed.jpg", replace
graph export "$fig_dir/02_policy/strength/scatter_asinh_unweighted_reversed.pdf", replace

display "Figure 2 exported: scatter_asinh_unweighted_reversed"

********************************************************************************
* Step 6: Figure 3 — ATT vs Average Policy Strength
* Africa countries only (inner join on ATT x strength)
********************************************************************************

use "`att_data'", clear
merge 1:1 country using "`strength_data'", keep(match) nogen

count
display "Figure 3 sample: `r(N)' countries"

twoway ///
    (scatter asinh_mean_sdid asinh_avg_strength, ///
        mlabel(country) mlabpos(12) mc(navy) ms(d) msize(medium)) ///
    (lfit asinh_mean_sdid asinh_avg_strength, lc(gs8) lp(dash)), ///
    legend(off) yline(0, lc(red) lp(-)) ///
    xtitle("Average Policy Strength (asinh)") ///
    ytitle(" ")
graph export "$fig_dir/02_policy/strength/scatter_sdid_avg_strength.jpg", replace
graph export "$fig_dir/02_policy/strength/scatter_sdid_avg_strength.pdf", replace

display "Figure 3 exported: scatter_sdid_avg_strength"

********************************************************************************
* Step 7: Figure 4 — ATT vs Number of High-Strength Policies
* Africa countries only (inner join on ATT x strength)
********************************************************************************

use "`att_data'", clear
merge 1:1 country using "`strength_data'", keep(match) nogen

count
display "Figure 4 sample: `r(N)' countries"

twoway ///
    (scatter asinh_mean_sdid asinh_n_high, ///
        mlabel(country) mlabpos(12) mc(navy) ms(d) msize(medium)) ///
    (lfit asinh_mean_sdid asinh_n_high, lc(gs8) lp(dash)), ///
    legend(off) yline(0, lc(red) lp(-)) ///
    xtitle("Number of High-Strength Policies (asinh)") ///
    ytitle(" ")
graph export "$fig_dir/02_policy/strength/scatter_sdid_n_high.jpg", replace
graph export "$fig_dir/02_policy/strength/scatter_sdid_n_high.pdf", replace

display "Figure 4 exported: scatter_sdid_n_high"

display "===== 04_policy_strength_scatter.do complete ====="
display "Figures: $fig_dir/02_policy/strength/"
