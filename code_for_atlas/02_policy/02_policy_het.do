********************************************************************************
* 02_policy_het.do
* ATLAS Afforestation - Q1: Treatment Effect Heterogeneity by Policy Environment
*
* Research question: Do reforestation programs produce larger NDVI gains in
* countries with stronger or more supportive forest policy?
*
* Note on geographic coverage: policy panel (FAOLEX) is global; ATT data is
* Africa-only. The merge keeps only Africa sites (master match). Countries
* with no FAOLEX forestry policy get n_policies = 0.
*
* Inputs:
*   $res_dir/01_effectiveness/01_ndvi/01_site_results.dta
*   $res_dir/02_policy/policy_country_year.dta
*
* Outputs (figures):  $fig_dir/02_policy/het/
* Outputs (results):  $res_dir/02_policy/het_results_npolicies.dta
********************************************************************************

local user = c(username)

if "`user'" == "wyf19"    global dropdir "C:/Users/wyf19/Dropbox"
if "`user'" == "wangy390"  global dropdir "D:/Dropbox"
if "`user'" == "WANGY390"  global dropdir "C:/Users/WANGY390/Dropbox"

global data_dir "$dropdir/Afforestation_Transition/Data/Processed Data"
global fig_dir  "$dropdir/Afforestation_Transition/Output/Figure/atlas"
global res_dir  "$data_dir/results"

cap mkdir "$fig_dir/02_policy"
cap mkdir "$fig_dir/02_policy/het"

********************************************************************************
* Step 1: Load site-level ATT results
********************************************************************************

use "$res_dir/01_effectiveness/01_ndvi/01_site_results.dta", clear

count
display "Total sites: `r(N)'"

encode country, gen(country_num)
rename cohort cohort_yr

********************************************************************************
* Step 2: Merge policy scores at country x cohort year
********************************************************************************

rename cohort_yr yr
merge m:1 country yr using "$res_dir/02_policy/policy_country_year.dta", ///
    keep(master match) nogen
rename yr cohort_yr

replace n_policies = 0 if mi(n_policies)

********************************************************************************
* Step 2b: Merge policy strength from 项目强度.xlsx
* One row per FAOLEX forestry policy entry with a categorical strength rating.
* Strength encoding: very_low=1, low=2, medium=3, high=4
* cum_strength  = sum of strength weights across all policies (country-level total)
* avg_strength  = mean strength weight across all policies (country-level average)
* Country names are harmonised to match policy_country_year.dta conventions.
********************************************************************************

preserve
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
    collapse (sum) cum_strength  = strength_weight ///
             (mean) avg_strength = strength_weight, by(country)
    tempfile str_data
    save "`str_data'"
restore

merge m:1 country using "`str_data'", keep(master match) nogen
replace cum_strength = 0 if mi(cum_strength)
replace avg_strength = 0 if mi(avg_strength)
gen asinh_cum_strength = asinh(cum_strength)
gen asinh_avg_strength = asinh(avg_strength)

display "Sites matched to FAOLEX policy data:"
tabulate country if n_policies > 0

tabstat n_policies, by(country) stat(mean min max)

********************************************************************************
* Step 3: Keep sites with at least one valid ATT
********************************************************************************

keep country country_num cohort_yr group_both ///
     twfe_att twfe_se sdid_att sdid_se eb_att eb_se sc_att sc_se ///
     n_policies cum_strength avg_strength asinh_cum_strength asinh_avg_strength

gen any_att = (!mi(twfe_att) | !mi(sdid_att) | !mi(eb_att) | !mi(sc_att))
drop if !any_att
drop any_att

display "Sites with valid ATT: `r(N)'"

* Cumulative policy count up to cohort year, within country
sort country cohort_yr
by country: gen cum_npolicies = sum(n_policies)
gen asinh_npolicies = asinh(cum_npolicies)

********************************************************************************
* Step 4: Regressions - ATT ~ asinh_npolicies + FEs
********************************************************************************

* Simple cross-country (no FEs)
capture regress sdid_att asinh_npolicies, vce(robust)
if _rc == 0 {
    local b_xc  = _b[asinh_npolicies]
    local se_xc = _se[asinh_npolicies]
    local p_xc  = 2*ttail(e(df_r), abs(`b_xc'/`se_xc'))
    display "Cross-country OLS:  b(asinh_npolicies) = " %6.4f `b_xc' ///
            "  SE = " %6.4f `se_xc' "  p = " %5.3f `p_xc'
}

* Within-country: absorb cohort FE
capture reghdfe sdid_att asinh_npolicies, ///
    absorb(cohort_yr) vce(robust)
if _rc == 0 {
    local b_wit  = _b[asinh_npolicies]
    local se_wit = _se[asinh_npolicies]
    local p_wit  = 2*ttail(e(df_r), abs(`b_wit'/`se_wit'))
    display "Within-country HDFE: b(asinh_npolicies) = " %6.4f `b_wit' ///
            "  SE = " %6.4f `se_wit' "  p = " %5.3f `p_wit'
}

* TWFE ATT robustness
capture reghdfe twfe_att asinh_npolicies, ///
    absorb(cohort_yr) vce(robust)
if _rc == 0 {
    local b_twfe_het  = _b[asinh_npolicies]
    local se_twfe_het = _se[asinh_npolicies]
    display "TWFE robustness:     b(asinh_npolicies) = " %6.4f `b_twfe_het' ///
            "  SE = " %6.4f `se_twfe_het'
}

********************************************************************************
* Step 5: Scatter plots
********************************************************************************

* 5a. Site scatter + binscatter
twoway ///
    (scatter sdid_att asinh_npolicies, mc(navy%30) ms(o) msize(small)) ///
    (lfit sdid_att asinh_npolicies, lc(black) lp(solid)), ///
    legend(off) yline(0, lc(red) lp(-)) ///
    xtitle("Cumulative active forestry policies (asinh) at cohort year") ///
	ytitle(" ")
graph export "$fig_dir/02_policy/het/scatter_sdid_att_npolicies.jpg", replace
graph export "$fig_dir/02_policy/het/scatter_sdid_att_npolicies.pdf", replace

binscatter sdid_att asinh_npolicies, ///
    yline(0, lc(red) lp(-)) legend(off) ///
    xtitle("Cumulative active forestry policies (asinh) at cohort year") ///
	ytitle(" ")
graph export "$fig_dir/02_policy/het/binscatter_sdid_att_npolicies.jpg", replace
graph export "$fig_dir/02_policy/het/binscatter_sdid_att_npolicies.pdf", replace

* 5b. Cross-country mean ATT + binscatter
preserve
    collapse (mean) sdid_att twfe_att asinh_npolicies (count) n_sites = sdid_att, ///
        by(country country_num)
	
	reg sdid_att asinh_npolicies
    twoway ///
        (scatter sdid_att asinh_npolicies, mlabel(country) mlabpos(12) mc(navy) ms(d) msize(medium)) ///
        (lfit sdid_att asinh_npolicies, lc(gs8) lp(dash)), ///
        legend(off) yline(0, lc(red) lp(-)) ///
        xtitle("Number of Forestry Policies") ///
		ytitle(" ")
    graph export "$fig_dir/02_policy/het/scatter_country_mean_att_npolicies.jpg", replace
    graph export "$fig_dir/02_policy/het/scatter_country_mean_att_npolicies.pdf", replace

    cap binscatter sdid_att asinh_npolicies, ///
        yline(0, lc(red) lp(-)) legend(off) ///
        xtitle("Avg. cumulative active policies at cohort year (asinh)") ///
	ytitle(" ")
    cap graph export "$fig_dir/02_policy/het/binscatter_country_mean_att_npolicies.jpg", replace
    cap graph export "$fig_dir/02_policy/het/binscatter_country_mean_att_npolicies.pdf", replace
restore
s
* 5c. Cohort-level mean ATT + binscatter
preserve
    collapse (mean) sdid_att twfe_att asinh_npolicies (count) n_sites = sdid_att, ///
        by(country country_num cohort_yr)

    twoway ///
        (scatter sdid_att asinh_npolicies, mc(navy%40) ms(o) msize(small) mlabel(cohort_yr) mlabpos(12)) ///
        (lfit sdid_att asinh_npolicies, lc(black) lp(solid)), ///
        legend(off) yline(0, lc(red) lp(-)) ///
        xtitle("Cumulative active policies at cohort year (asinh)") ///
	ytitle(" ")
    graph export "$fig_dir/02_policy/het/scatter_cohort_att_npolicies.jpg", replace
    graph export "$fig_dir/02_policy/het/scatter_cohort_att_npolicies.pdf", replace

    cap binscatter sdid_att asinh_npolicies, ///
        yline(0, lc(red) lp(-)) legend(off) ///
        xtitle("Cumulative active policies at cohort year (asinh)") ///
	ytitle(" ")
    cap graph export "$fig_dir/02_policy/het/binscatter_cohort_att_npolicies.jpg", replace
    cap graph export "$fig_dir/02_policy/het/binscatter_cohort_att_npolicies.pdf", replace
restore

********************************************************************************
* Step 6: Save regression summary
********************************************************************************

preserve
    clear
    set obs 3
    gen str50 spec    = ""
    gen float b_npol  = .
    gen float se_npol = .

    replace spec    = "OLS cross-country (no FE)"         in 1
    replace b_npol  = `b_xc'                              in 1
    replace se_npol = `se_xc'                             in 1

    replace spec    = "HDFE sdid_att (cohort FE)"         in 2
    replace b_npol  = `b_wit'                             in 2
    replace se_npol = `se_wit'                            in 2

    replace spec    = "HDFE twfe_att (cohort FE)"         in 3
    replace b_npol  = `b_twfe_het'                        in 3
    replace se_npol = `se_twfe_het'                       in 3

    save "$res_dir/02_policy/het_results_npolicies.dta", replace
    display "Heterogeneity regression summary saved."
restore

display "===== 02_policy_het.do complete ====="
display "Figures: $fig_dir/02_policy/het/"
display "Results: $res_dir/02_policy/het_results_npolicies.dta"
