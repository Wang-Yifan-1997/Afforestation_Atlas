********************************************************************************
* 02_policy_het.do
* ATLAS Afforestation - Q1: Treatment Effect Heterogeneity by Policy Environment
*
* Research question: Do reforestation programs produce larger NDVI gains in
* countries with stronger or more supportive forest policy?
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

replace n_policies     = 0 if mi(n_policies)
replace n_high         = 0 if mi(n_high)
replace n_supportive   = 0 if mi(n_supportive)
replace pct_high       = 0 if mi(pct_high)
replace pct_supportive = 0 if mi(pct_supportive)

* How many countries have policy data
display "Countries with policy match:"
tabulate country if n_policies > 0

tabstat n_high n_supportive n_policies, by(country) stat(mean min max)

********************************************************************************
* Step 3: Keep sites with at least one valid ATT
********************************************************************************

keep country country_num cohort_yr group_both ///
     twfe_att twfe_se sdid_att sdid_se eb_att eb_se sc_att sc_se ///
     n_policies n_high n_supportive pct_high pct_supportive

gen any_att = (!mi(twfe_att) | !mi(sdid_att) | !mi(eb_att) | !mi(sc_att))
drop if !any_att
drop any_att

display "Sites with valid ATT: `r(N)'"

* Sort by country and year before cumulating
sort country cohort_yr
by country: gen cum_npolicies = sum(n_policies)
gen asinh_npolicies = asinh(cum_npolicies)

*gen asinh_npolicies = asinh(n_policies)
*label var asinh_npolicies "Inverse hyperbolic sine of N active policies"

********************************************************************************
* Step 4: Regressions - ATT ~ asinh_npolicies + FEs
********************************************************************************

* Simple cross-country (no FEs)
capture regress sdid_att asinh_npolicies, vce(robust)
if _rc == 0 {
    local b_xc   = _b[asinh_npolicies]
    local se_xc  = _se[asinh_npolicies]
    local p_xc   = 2*ttail(e(df_r), abs(`b_xc'/`se_xc'))
    display "Cross-country OLS:  b(asinh_npolicies) = " %6.4f `b_xc' "  SE = " %6.4f `se_xc' "  p = " %5.3f `p_xc'
}

* Within-country: absorb country FE + cohort FE
capture reghdfe sdid_att asinh_npolicies, ///
    absorb(cohort_yr) vce(robust)
if _rc == 0 {
    local b_wit   = _b[asinh_npolicies]
    local se_wit  = _se[asinh_npolicies]
    local p_wit   = 2*ttail(e(df_r), abs(`b_wit'/`se_wit'))
    display "Within-country HDFE: b(asinh_npolicies) = " %6.4f `b_wit' "  SE = " %6.4f `se_wit' "  p = " %5.3f `p_wit'
}

* TWFE ATT robustness
capture reghdfe twfe_att asinh_npolicies, ///
    absorb(cohort_yr) vce(robust)
if _rc == 0 {
    local b_twfe_het  = _b[asinh_npolicies]
    local se_twfe_het = _se[asinh_npolicies]
    display "TWFE robustness:     b(asinh_npolicies) = " %6.4f `b_twfe_het' "  SE = " %6.4f `se_twfe_het'
}

********************************************************************************
* Step 5: Scatter plots
********************************************************************************

* --- 5a. Site scatter: ATT vs asinh_npolicies (all countries, colored by country)
twoway ///
    (scatter sdid_att asinh_npolicies, mc(navy%30) ms(o) msize(small)) ///
    (lfit sdid_att asinh_npolicies, lc(black) lp(solid)), ///
    legend(off) ///
    yline(0, lc(red) lp(-)) ///
    title("Site NDVI ATT vs. Number of Active Policies at Planting") ///
    xtitle("N active policies at cohort year") ///
    ytitle("SDID ATT (smooth NDVI)") ///
    note("One dot = one site. Policy measured at country x treatment-year level.")
graph export "$fig_dir/02_policy/het/scatter_sdid_att_npolicies.jpg", replace
graph export "$fig_dir/02_policy/het/scatter_sdid_att_npolicies.pdf", replace

* --- 5b. Cross-country mean ATT vs mean asinh_npolicies --------------------------
preserve
    collapse (mean) sdid_att twfe_att asinh_npolicies (count) n_sites = sdid_att, ///
        by(country country_num)

    twoway ///
        (scatter sdid_att asinh_npolicies, mlabel(country) mlabpos(12) mc(navy) ms(d) msize(medium)) ///
        (lfit sdid_att asinh_npolicies, lc(gs8) lp(dash)), ///
        legend(off) ///
        yline(0, lc(red) lp(-)) ///
        title("Country-Mean ATT vs. Mean Number of Active Policies") ///
        xtitle("Avg. active policies at cohort year") ///
        ytitle("Mean SDID ATT across sites")
    graph export "$fig_dir/02_policy/het/scatter_country_mean_att_npolicies.jpg", replace
    graph export "$fig_dir/02_policy/het/scatter_country_mean_att_npolicies.pdf", replace
restore

* --- 5c. Cohort-level mean ATT vs asinh_npolicies ---------------------------------
preserve
    collapse (mean) sdid_att twfe_att asinh_npolicies (count) n_sites = sdid_att, ///
        by(country country_num cohort_yr)

    twoway ///
        (scatter sdid_att asinh_npolicies, mc(navy%40) ms(o) msize(small) mlabel(cohort_yr) mlabpos(12)) ///
        (lfit sdid_att asinh_npolicies, lc(black) lp(solid)), ///
        legend(off) ///
        yline(0, lc(red) lp(-)) ///
        title("Cohort-Mean ATT vs. Number of Active Policies") ///
        xtitle("N active policies at cohort year") ///
        ytitle("Mean SDID ATT (country x cohort)") ///
        note("Labels = treatment (planting) year.")
    graph export "$fig_dir/02_policy/het/scatter_cohort_att_npolicies.jpg", replace
    graph export "$fig_dir/02_policy/het/scatter_cohort_att_npolicies.pdf", replace
restore

********************************************************************************
* Step 7: Save regression summary
********************************************************************************

preserve
    clear
    set obs 3
    gen str40 spec    = ""
    gen float b_npol  = .
    gen float se_npol = .

    replace spec    = "OLS cross-country (no FE)"         in 1
    replace b_npol  = `b_xc'                              in 1
    replace se_npol = `se_xc'                             in 1

    replace spec    = "HDFE sdid_att (country+cohort FE)" in 2
    replace b_npol  = `b_wit'                             in 2
    replace se_npol = `se_wit'                            in 2

    replace spec    = "HDFE twfe_att (country+cohort FE)" in 3
    replace b_npol  = `b_twfe_het'                        in 3
    replace se_npol = `se_twfe_het'                       in 3

    save "$res_dir/02_policy/het_results_npolicies.dta", replace
    display "Heterogeneity regression summary saved."
restore

display "===== 02_policy_het.do complete ====="
display "Figures: $fig_dir/02_policy/het/"
display "Results: $res_dir/02_policy/het_results_npolicies.dta"