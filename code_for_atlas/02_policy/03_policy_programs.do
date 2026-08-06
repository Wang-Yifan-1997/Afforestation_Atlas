********************************************************************************
* 03_policy_programs.do
* ATLAS Afforestation - Q2: Does Policy Strength Lead to More Programs?
*
* Research question: Do countries with more forestry policies adopt more
* afforestation / reforestation programs in subsequent years?
* Placebo: non-forestry policies (all other FAOLEX subjects) should NOT predict
* program counts — identification of a forestry-specific channel.
*
* Note on geographic coverage: FAOLEX policy panel is global; ForAnalysis.dta
* is also global. The panel spine uses all FAOLEX-covered countries so the
* analysis is worldwide, not Africa-only.
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

duplicates drop project_id_created country plant_yr, force

gen one = 1
collapse (sum) new_proj = one, by(country plant_yr)
rename plant_yr yr

tempfile proj_counts
save "`proj_counts'"

********************************************************************************
* Step 2: Build balanced panel using policy data as spine
* Panel is GLOBAL — all countries appearing in FAOLEX forestry policy data
********************************************************************************

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

* Merge policy scores
merge 1:1 country yr using "$res_dir/02_policy/policy_country_year.dta", nogen
replace n_forest    = 0 if mi(n_forest)
replace n_nonforest = 0 if mi(n_nonforest)
replace n_policies  = 0 if mi(n_policies)

********************************************************************************
* Step 2b: Merge policy strength from 项目强度.xlsx
* One row per FAOLEX forestry policy entry with a categorical strength rating.
* Strength encoding: very_low=1, low=2, medium=3, high=4
* cum_strength  = sum of strength weights across all policies (country-level total)
* avg_strength  = mean strength weight across all policies (country-level average)
* Country names are harmonised to match policy_country_year.dta conventions.
* This is a time-invariant (cross-sectional) country-level measure.
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

* Merge project counts
merge 1:1 country yr using "`proj_counts'", nogen
replace new_proj = 0 if mi(new_proj)

* IDs and transformations
encode country, gen(country_num)
gen log_new_proj       = log(new_proj + 1)
gen asinh_new_proj     = asinh(new_proj)
gen asinh_nforest      = asinh(n_forest)
gen asinh_nnonforest   = asinh(n_nonforest)
gen asinh_npolicies    = asinh(n_policies)        // = asinh_nforest
gen asinh_cum_strength = asinh(cum_strength)
gen asinh_avg_strength = asinh(avg_strength)

sort country_num yr
by country_num: gen cum_proj         = sum(new_proj)
by country_num: gen cum_nforest      = sum(n_forest)
by country_num: gen cum_nnonforest   = sum(n_nonforest)
gen log_cum_proj          = log(cum_proj + 1)
gen asinh_cum_proj        = asinh(cum_proj)
gen asinh_cum_nforest     = asinh(cum_nforest)
gen asinh_cum_nnonforest  = asinh(cum_nnonforest)

by country_num: gen n_forest_lag1     = n_forest[_n-1]
by country_num: gen n_nonforest_lag1  = n_nonforest[_n-1]
by country_num: gen asinh_nforest_l1  = asinh_nforest[_n-1]

sort country yr
save "$res_dir/02_policy/programs_panel.dta", replace
display "Country-year panel saved."

count
tab country
********************************************************************************
* Step 3: Panel descriptives
********************************************************************************

* Time trend: new reforestation programs by year
preserve
    collapse (sum) new_proj, by(yr)
    keep if yr >= 2000 & yr <= 2024
    twoway ///
        (bar new_proj yr, barwidth(0.8) fc(gs12) lc(gs12)), ///
        legend(off) ///
        xtitle(Year) ytitle("New Reforestation Programs")
    graph export "$fig_dir/02_policy/programs/trends_programs.jpg", replace
    graph export "$fig_dir/02_policy/programs/trends_programs.pdf", replace
restore

* Time trend: new forestry policies per year and their average strength
* new_forest    = first difference of active policy count within country (floored at 0)
* avg_strength_new = weighted avg strength of new policies, using country avg_strength as proxy
preserve
    sort country_num yr
    by country_num: gen new_forest = n_forest - n_forest[_n-1]
    replace new_forest = 0 if new_forest < 0 | mi(new_forest)

    * Weighted strength of new policies: new policy count x country avg strength
    gen new_strength_wt = new_forest * avg_strength

    collapse (sum) new_forest new_strength_wt, by(yr)

    * avg_strength_new = weighted average strength of new policies adopted this year
    gen avg_strength_new = new_strength_wt / new_forest if new_forest > 0

    keep if yr >= 2000 & yr <= 2024

    twoway ///
        (bar  new_forest yr, barwidth(0.8) fc(gs12) lc(gs12)) ///
        (line avg_strength_new yr, lc(red) lp(solid) yaxis(2)), ///
        legend(order(1 "New Forestry Policies" 2 "Average Policy Strength") ///
               pos(11) ring(0) col(1)) ///
        xtitle(Year) ytitle("New Forestry Policies", axis(1)) ///
        ytitle("Average Policy Strength", axis(2)) ///
        yscale(range(0 1.2) axis(2)) ///
        ylabel(0(0.2)1.2, axis(2))
    graph export "$fig_dir/02_policy/programs/trends_new_policies_strength.jpg", replace
    graph export "$fig_dir/02_policy/programs/trends_new_policies_strength.pdf", replace
restore

* Cross-country scatter: total programs vs mean forestry policies (raw counts)
preserve
    collapse (sum) new_proj (mean) n_forest, by(country country_num)
    twoway ///
        (scatter new_proj n_forest, mlabel(country) mlabpos(12) mc(navy) ms(d)) ///
        (lfit   new_proj n_forest, lc(gs8) lp(dash)), ///
        legend(off) ///
        xtitle("Mean active forestry policies per year") ///
        ytitle("Total unique programs")
    graph export "$fig_dir/02_policy/programs/scatter_total_progs_nforest.jpg", replace
    graph export "$fig_dir/02_policy/programs/scatter_total_progs_nforest.pdf", replace
restore

* Cross-country scatter: total programs vs mean non-forestry policies (placebo, raw counts)
preserve
    collapse (sum) new_proj (mean) n_nonforest, by(country country_num)
    twoway ///
        (scatter new_proj n_nonforest, mlabel(country) mlabpos(12) mc(maroon) ms(d)) ///
        (lfit   new_proj n_nonforest, lc(gs8) lp(dash)), ///
        legend(off) ///
        xtitle("Mean active non-forestry policies per year") ///
        ytitle("Total unique programs")
    graph export "$fig_dir/02_policy/programs/scatter_total_progs_nnonforest.jpg", replace
    graph export "$fig_dir/02_policy/programs/scatter_total_progs_nnonforest.pdf", replace
restore

* Cross-country scatter: programs vs forestry policies (asinh, all countries)
preserve
    collapse (sum) new_proj (mean) asinh_nforest, by(country country_num)
    gen asinh_new_proj_cs = asinh(new_proj)
    twoway ///
        (scatter asinh_new_proj_cs asinh_nforest, mlabel(country) mlabpos(12) mc(navy) ms(d)) ///
        (lfit   asinh_new_proj_cs asinh_nforest, lc(gs8) lp(dash)), ///
        legend(off) ///
        xtitle("Number of forestry policies") ///
        ytitle("Number of reforestation programs")
    graph export "$fig_dir/02_policy/programs/scatter_asinh_progs_nforest.jpg", replace
    graph export "$fig_dir/02_policy/programs/scatter_asinh_progs_nforest.pdf", replace
restore

* Cross-country scatter: programs vs non-forestry policies (asinh, placebo, all countries)
preserve
    collapse (sum) new_proj (mean) asinh_nnonforest, by(country country_num)
    gen asinh_new_proj_cs = asinh(new_proj)
    twoway ///
        (scatter asinh_new_proj_cs asinh_nnonforest, mlabel(country) mlabpos(12) mc(maroon) ms(d)) ///
        (lfit   asinh_new_proj_cs asinh_nnonforest, lc(gs8) lp(dash)), ///
        legend(off) ///
        xtitle("Number of non-forestry policies") ///
        ytitle("Number of reforestation programs")
    graph export "$fig_dir/02_policy/programs/scatter_asinh_progs_nnonforest.jpg", replace
    graph export "$fig_dir/02_policy/programs/scatter_asinh_progs_nnonforest.pdf", replace
restore

* Cross-country scatter: programs vs forestry policies (asinh, countries with programs only)
preserve
    collapse (sum) new_proj (mean) asinh_nforest, by(country country_num)
    gen asinh_new_proj_cs = asinh(new_proj)
    twoway ///
    (scatter asinh_new_proj_cs asinh_nforest if asinh_new_proj_cs > 0, mlabel(country) mlabpos(12) mc(navy) ms(d) msize(medium)) ///
    (lfit asinh_new_proj_cs asinh_nforest if asinh_new_proj_cs > 0, lc(gs8) lp(dash)), ///
    legend(off) ///
    xtitle("Number of forestry policies") ///
    ytitle("Number of reforestation programs")
	
    graph export "$fig_dir/02_policy/programs/scatter_asinh_progs_nforest_pos.jpg", replace
    graph export "$fig_dir/02_policy/programs/scatter_asinh_progs_nforest_pos.pdf", replace
restore

* Cross-country scatter: programs vs non-forestry policies (asinh, placebo, countries with programs only)
preserve
    collapse (sum) new_proj (mean) asinh_nnonforest, by(country country_num)
    gen asinh_new_proj_cs = asinh(new_proj)
    twoway ///
        (scatter asinh_new_proj_cs asinh_nnonforest if asinh_new_proj_cs > 0, mlabel(country) mlabpos(12) mc(navy) ms(d) msize(medium)) ///
        (lfit   asinh_new_proj_cs asinh_nnonforest  if asinh_new_proj_cs > 0, lc(gs8) lp(dash)), ///
        legend(off) ///
        xtitle("Number of non-forestry policies") ///
        ytitle("Number of reforestation programs")
    graph export "$fig_dir/02_policy/programs/scatter_asinh_progs_nnonforest_pos.jpg", replace
    graph export "$fig_dir/02_policy/programs/scatter_asinh_progs_nnonforest_pos.pdf", replace
restore


********************************************************************************
* Step 4: Panel OLS regressions — forestry vs non-forestry (placebo)
*
* (1) Forestry only
* (2) Non-forestry only (placebo)
* (3) Horse race: both together — key spec showing forestry channel is specific
* (4) Asinh-asinh horse race
* (5) Lagged forestry (pre-trend / predictive check)
********************************************************************************

foreach loc in b_f se_b_f b_nf se_b_nf b_f_hr se_b_f_hr b_nf_hr se_b_nf_hr ///
               b_f_asinh se_b_f_asinh b_nf_asinh se_b_nf_asinh ///
               b_f_lag1 se_b_f_lag1 b_nf_lag1 se_b_nf_lag1 {
    local `loc' = .
}

* (1) Forestry only
capture reghdfe log_new_proj n_forest, ///
    absorb(country_num yr) vce(cluster country_num)
if _rc == 0 {
    local b_f    = _b[n_forest]
    local se_b_f = _se[n_forest]
    display "Forestry only:      b(n_forest)    = " %6.3f `b_f' "  SE = " %6.3f `se_b_f'
}

* (2) Non-forestry only (placebo)
capture reghdfe log_new_proj n_nonforest, ///
    absorb(country_num yr) vce(cluster country_num)
if _rc == 0 {
    local b_nf    = _b[n_nonforest]
    local se_b_nf = _se[n_nonforest]
    display "Non-forestry only:  b(n_nonforest) = " %6.3f `b_nf' "  SE = " %6.3f `se_b_nf'
}

* (3) Horse race: forestry + non-forestry together
capture reghdfe log_new_proj n_forest n_nonforest, ///
    absorb(country_num yr) vce(cluster country_num)
if _rc == 0 {
    local b_f_hr    = _b[n_forest]
    local se_b_f_hr = _se[n_forest]
    local b_nf_hr    = _b[n_nonforest]
    local se_b_nf_hr = _se[n_nonforest]
    display "Horse race — forestry:     b(n_forest)    = " %6.3f `b_f_hr'  "  SE = " %6.3f `se_b_f_hr'
    display "Horse race — non-forestry: b(n_nonforest) = " %6.3f `b_nf_hr' "  SE = " %6.3f `se_b_nf_hr'
}

* (4) Asinh-asinh horse race
capture reghdfe asinh_new_proj asinh_nforest asinh_nnonforest, ///
    absorb(country_num yr) vce(cluster country_num)
if _rc == 0 {
    local b_f_asinh    = _b[asinh_nforest]
    local se_b_f_asinh = _se[asinh_nforest]
    local b_nf_asinh    = _b[asinh_nnonforest]
    local se_b_nf_asinh = _se[asinh_nnonforest]
    display "Asinh horse race — forestry:     b = " %6.3f `b_f_asinh'  "  SE = " %6.3f `se_b_f_asinh'
    display "Asinh horse race — non-forestry: b = " %6.3f `b_nf_asinh' "  SE = " %6.3f `se_b_nf_asinh'
}

* (5) One-year lag (forestry + non-forestry)
capture reghdfe log_new_proj n_forest_lag1 n_nonforest_lag1, ///
    absorb(country_num yr) vce(cluster country_num)
if _rc == 0 {
    local b_f_lag1    = _b[n_forest_lag1]
    local se_b_f_lag1 = _se[n_forest_lag1]
    local b_nf_lag1    = _b[n_nonforest_lag1]
    local se_b_nf_lag1 = _se[n_nonforest_lag1]
    display "Lag-1 horse race — forestry:     b = " %6.3f `b_f_lag1'  "  SE = " %6.3f `se_b_f_lag1'
    display "Lag-1 horse race — non-forestry: b = " %6.3f `b_nf_lag1' "  SE = " %6.3f `se_b_nf_lag1'
}

********************************************************************************
* Step 5: Event study around first adoption of any forestry policy
********************************************************************************

sort country_num yr
by country_num: gen had_policy   = (n_policies >= 1)
by country_num: gen first_pol_yr = yr if had_policy & (had_policy[_n-1] == 0 | _n == 1)
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
        title("Event Study: Log New Programs Around First Forestry Policy (FAOLEX)") ///
        xtitle("Years relative to first forestry policy adoption") ///
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
    set obs 5
    gen str70 spec          = ""
    gen float b_forest      = .
    gen float se_forest     = .
    gen float b_nonforest   = .
    gen float se_nonforest  = .

    replace spec         = "OLS: forestry only"                          in 1
    replace b_forest     = `b_f'                                         in 1
    replace se_forest    = `se_b_f'                                      in 1

    replace spec         = "OLS: non-forestry only (placebo)"            in 2
    replace b_nonforest  = `b_nf'                                        in 2
    replace se_nonforest = `se_b_nf'                                     in 2

    replace spec         = "OLS horse race: forestry + non-forestry"     in 3
    replace b_forest     = `b_f_hr'                                      in 3
    replace se_forest    = `se_b_f_hr'                                   in 3
    replace b_nonforest  = `b_nf_hr'                                     in 3
    replace se_nonforest = `se_b_nf_hr'                                  in 3

    replace spec         = "Asinh horse race: forestry + non-forestry"   in 4
    replace b_forest     = `b_f_asinh'                                   in 4
    replace se_forest    = `se_b_f_asinh'                                in 4
    replace b_nonforest  = `b_nf_asinh'                                  in 4
    replace se_nonforest = `se_b_nf_asinh'                               in 4

    replace spec         = "OLS lag-1 horse race: forestry + non-forestry" in 5
    replace b_forest     = `b_f_lag1'                                    in 5
    replace se_forest    = `se_b_f_lag1'                                 in 5
    replace b_nonforest  = `b_nf_lag1'                                   in 5
    replace se_nonforest = `se_b_nf_lag1'                                in 5

    list, noobs sep(0)
    save "$res_dir/02_policy/programs_reg_results.dta", replace
    display "Regression results saved."
restore

display "===== 03_policy_programs.do complete ====="
display "Figures: $fig_dir/02_policy/programs/"
display "Panel:   $res_dir/02_policy/programs_panel.dta"
