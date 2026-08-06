********************************************************************************
* 03_policy_programs.do
* ATLAS Afforestation - Q2: Does Policy Strength Lead to More Programs?
*
* Research question: Do countries with more forest policies adopt more
* afforestation / reforestation programs in subsequent years?
*
* Inputs:
*   $data_dir/Global Afforestation Projects/ForAnalysis.dta
*   $res_dir/02_policy/policy_country_year.dta
*
* Outputs (figures):  $fig_dir/02_policy/programs/
* Outputs (results):  $res_dir/02_policy/programs_panel.dta
*                     $res_dir/02_policy/programs_reg_results.dta
********************************************************************************

local user = c(username)

if "`user'" == "wyf19"    global dropdir "C:/Users/wyf19/Dropbox"
if "`user'" == "wangy390"  global dropdir "D:/Dropbox"
if "`user'" == "WANGY390"  global dropdir "C:/Users/WANGY390/Dropbox"

global data_dir "$dropdir/Afforestation_Transition/Data/Processed Data"
global fig_dir  "$dropdir/Afforestation_Transition/Output/Figure/atlas"
global res_dir  "$data_dir/results"

cap mkdir "$fig_dir/02_policy"
cap mkdir "$fig_dir/02_policy/programs"

********************************************************************************
* Step 1: Build country-year project counts from ForAnalysis.dta
********************************************************************************

use "$data_dir/Global Afforestation Projects/ForAnalysis.dta", clear

gen plant_yr = real(substr(planting_date_derived, 1, 4))
replace plant_yr = . if plant_yr < 1990
replace plant_yr = . if plant_yr > 2024
drop if mi(plant_yr)
drop if mi(country)

* Deduplicate at project x year level
duplicates drop project_id_created country plant_yr, force

* Collapse to country-year project count
gen one = 1
collapse (sum) new_proj = one, by(country plant_yr)
rename plant_yr yr

tab country
tempfile proj_counts
save "`proj_counts'"

********************************************************************************
* Step 2: Build balanced panel using policy data as spine
********************************************************************************

* Use ALL countries in the policy data as the spine
use "$res_dir/02_policy/policy_country_year.dta", clear

quietly levelsof country, local(ctries)
local n_ctries : word count `ctries'
local n_obs = `n_ctries' * 25

clear
set obs `n_obs'
gen str50 country = ""
gen yr = .
local row = 1
foreach c of local ctries {
    forvalues y = 2000/2024 {
        replace country = "`c'" in `row'
        replace yr      = `y'   in `row'
        local row = `row' + 1
    }
}

* Merge in policy scores
merge 1:1 country yr using "$res_dir/02_policy/policy_country_year.dta", nogen
replace n_policies     = 0 if mi(n_policies)
replace n_supportive   = 0 if mi(n_supportive)
replace pct_supportive = 0 if mi(pct_supportive)

* Merge in project counts
merge 1:1 country yr using "`proj_counts'", nogen
replace new_proj = 0 if mi(new_proj)

* IDs and transformations
encode country, gen(country_num)
gen log_new_proj    = log(new_proj + 1)
gen asinh_new_proj  = asinh(new_proj)
gen asinh_npolicies = asinh(n_policies)

* Cumulative programs and policies
sort country_num yr
by country_num: gen cum_proj      = sum(new_proj)
by country_num: gen cum_npolicies = sum(n_policies)
gen log_cum_proj          = log(cum_proj + 1)
gen asinh_cum_proj        = asinh(cum_proj)
gen asinh_cum_npolicies   = asinh(cum_npolicies)

* Lagged policy variables
by country_num: gen n_policies_lag1    = n_policies[_n-1]
by country_num: gen asinh_npol_lag1    = asinh_npolicies[_n-1]

sort country yr
save "$res_dir/02_policy/programs_panel.dta", replace
display "Country-year panel saved."

tab country
count

********************************************************************************
* Step 3: Panel descriptives
********************************************************************************

preserve
    collapse (sum) new_proj n_policies n_supportive, by(yr)
    twoway ///
        (bar  new_proj yr, barwidth(0.8) fc(gs12) lc(gs12)) ///
        (line n_policies yr, lc(red) lp(solid) yaxis(2)) ///
        (line n_supportive yr, lc(navy) lp(dash) yaxis(2)), ///
        legend(order(1 "New programs" 2 "Active policies" 3 "Supportive-tone policies") ///
               pos(11) ring(0) col(1)) ///
        xtitle(Year) ytitle("New programs", axis(1)) ///
        ytitle("Active policies (count)", axis(2)) ///
        title("Annual New Afforestation Programs vs. Policy Count")
    graph export "$fig_dir/02_policy/programs/trends_programs_vs_policy.jpg", replace
    graph export "$fig_dir/02_policy/programs/trends_programs_vs_policy.pdf", replace
restore

* Cross-sectional scatter: total programs vs mean n_policies
preserve
    collapse (sum) new_proj (mean) n_policies n_supportive, by(country country_num)
    twoway ///
        (scatter new_proj n_policies, mlabel(country) mlabpos(12) mc(navy) ms(d)) ///
        (lfit   new_proj n_policies, lc(gs8) lp(dash)), ///
        legend(off) ///
        title("Total Programs vs. Mean Active Policies (2000-2024)") ///
        xtitle("Mean N active policies per year") ///
        ytitle("Total unique programs")
    graph export "$fig_dir/02_policy/programs/scatter_total_progs_npolicies.jpg", replace
    graph export "$fig_dir/02_policy/programs/scatter_total_progs_npolicies.pdf", replace
restore

* Cross-sectional scatter: asinh versions
preserve
    collapse (sum) new_proj (mean) asinh_npolicies, by(country country_num)
    gen asinh_new_proj_cs = asinh(new_proj)
    twoway ///
        (scatter asinh_new_proj_cs asinh_npolicies, mlabel(country) mlabpos(12) mc(navy) ms(d)) ///
        (lfit   asinh_new_proj_cs asinh_npolicies, lc(gs8) lp(dash)), ///
        legend(off) ///
        title("Asinh(Total Programs) vs. Asinh(Mean Active Policies)") ///
        xtitle("Asinh(mean N active policies per year)") ///
        ytitle("Asinh(total unique programs)")
    graph export "$fig_dir/02_policy/programs/scatter_asinh_progs_npolicies.jpg", replace
    graph export "$fig_dir/02_policy/programs/scatter_asinh_progs_npolicies.pdf", replace
restore

********************************************************************************
* Step 4: Panel OLS regressions
* (A) log_new_proj ~ n_policies + country_FE + year_FE
* (B) asinh_new_proj ~ asinh_npolicies + country_FE + year_FE
* (C) Lagged: log_new_proj ~ n_policies_lag1
********************************************************************************

local b_pol_ols  = .
local se_pol_ols = .
local b_pol_asinh  = .
local se_pol_asinh = .
local b_pol_lag1   = .
local se_pol_lag1  = .

* --- (A) Log count outcome
capture reghdfe log_new_proj n_policies, ///
    absorb(country_num yr) vce(cluster country_num)
if _rc == 0 {
    local b_pol_ols  = _b[n_policies]
    local se_pol_ols = _se[n_policies]
    display "Panel OLS (log):   b(n_policies) = " %6.3f `b_pol_ols' ///
            "  SE = " %6.3f `se_pol_ols'
}

* --- (B) Asinh-asinh (elasticity interpretation)
capture reghdfe asinh_new_proj asinh_npolicies, ///
    absorb(country_num yr) vce(cluster country_num)
if _rc == 0 {
    local b_pol_asinh  = _b[asinh_npolicies]
    local se_pol_asinh = _se[asinh_npolicies]
    display "Panel asinh-asinh: b(asinh_npolicies) = " %6.3f `b_pol_asinh' ///
            "  SE = " %6.3f `se_pol_asinh'
}

* --- (C) One-year lag
capture reghdfe log_new_proj n_policies_lag1, ///
    absorb(country_num yr) vce(cluster country_num)
if _rc == 0 {
    local b_pol_lag1  = _b[n_policies_lag1]
    local se_pol_lag1 = _se[n_policies_lag1]
    display "Panel OLS lag-1:   b(n_policies_lag1) = " %6.3f `b_pol_lag1' ///
            "  SE = " %6.3f `se_pol_lag1'
}

********************************************************************************
* Step 5: Event study around first adoption of any forest policy
********************************************************************************

sort country_num yr
by country_num: gen had_policy    = (n_policies >= 1)
by country_num: gen first_pol_yr  = yr if had_policy & (had_policy[_n-1] == 0 | _n == 1)
by country_num: egen policy_adopt_yr = min(first_pol_yr)
drop had_policy first_pol_yr

gen never_treated = mi(policy_adopt_yr)
replace policy_adopt_yr = 0 if never_treated

gen rel_pol = yr - policy_adopt_yr if !never_treated
replace rel_pol = . if never_treated

gen rel_pol_binned = rel_pol
replace rel_pol_binned = -10 if rel_pol < -10 & !mi(rel_pol)
replace rel_pol_binned =  10 if rel_pol >  10 & !mi(rel_pol)

capture reghdfe log_new_proj ib(-1).rel_pol_binned if !never_treated, ///
    absorb(country_num yr) vce(cluster country_num) nocons
if _rc == 0 {
    coefplot, keep(*rel_pol_binned*) omitted baselevels vertical recast(connected) ///
        ciopts(recast(rarea) fc(gs11%50) lc(gs10)) legend(off) ///
        yline(0, lc(red) lp(-)) xline(-0.5, lc(black) lp(solid)) ///
        title("Event Study: Log New Programs Around First Forest Policy Adoption") ///
        xtitle("Years relative to first policy adoption") ///
        ytitle("Log(new programs + 1)") ///
        note("Baseline = year before adoption (t=-1). Country + year FEs.")
    graph export "$fig_dir/02_policy/programs/event_study_programs_policy.jpg", replace
    graph export "$fig_dir/02_policy/programs/event_study_programs_policy.pdf", replace
}

********************************************************************************
* Step 6: Save regression summary
********************************************************************************

preserve
    clear
    set obs 3
    gen str60 spec   = ""
    gen float b_pol  = .
    gen float se_pol = .

    replace spec   = "Panel OLS: log(new_proj+1) ~ n_policies"         in 1
    replace b_pol  = `b_pol_ols'                                        in 1
    replace se_pol = `se_pol_ols'                                       in 1

    replace spec   = "Panel asinh-asinh: asinh(proj) ~ asinh(policies)" in 2
    replace b_pol  = `b_pol_asinh'                                      in 2
    replace se_pol = `se_pol_asinh'                                     in 2

    replace spec   = "Panel OLS lag-1: log(new_proj+1) ~ n_pol_lag1"   in 3
    replace b_pol  = `b_pol_lag1'                                       in 3
    replace se_pol = `se_pol_lag1'                                      in 3

    save "$res_dir/02_policy/programs_reg_results.dta", replace
    display "Regression results saved."
restore

display "===== 03_policy_programs.do complete ====="
display "Figures: $fig_dir/02_policy/programs/"
display "Panel:   $res_dir/02_policy/programs_panel.dta"