********************************************************************************
* 03_cohort.do
* ATLAS Afforestation - Cohort-Level NDVI Regressions
* Method: SDID only
********************************************************************************

local user = c(username)

if "`user'" == "wyf19"    global dropdir "C:/Users/wyf19/Dropbox"
if "`user'" == "wangy390"  global dropdir "D:/Dropbox"
if "`user'" == "WANGY390"  global dropdir "C:/Users/WANGY390/Dropbox"

global data_dir "$dropdir/Afforestation_Transition/Data/Processed Data"
global fig_dir  "$dropdir/Afforestation_Transition/Output/Figure/atlas"
global res_dir  "$data_dir/results/01_effectiveness/01_ndvi"

cap mkdir "$fig_dir/01_effectiveness"
cap mkdir "$fig_dir/01_effectiveness/01_ndvi"
cap mkdir "$fig_dir/01_effectiveness/01_ndvi/cohort"
cap mkdir "$fig_dir/01_effectiveness/01_ndvi/cohort/sdid"

local country_filter ""
* local country_filter "Ethiopia"

********************************************************************************
* Load data
********************************************************************************

use "$data_dir/atlas_ndvi_panel.dta", clear
if "`country_filter'" != "" keep if country == "`country_filter'"

drop if country == "Ethiopia" // too big

tempfile results_running
local results_started = 0

********************************************************************************
* Country x Cohort loop
********************************************************************************

levelsof country, local(ctry_list)

foreach c of local ctry_list {

    quietly levelsof cohort if country == "`c'", local(cohort_list)

    foreach cohort_yr of local cohort_list {

        quietly su year if country == "`c'" & cohort == `cohort_yr' ///
            & treat_absorbing == 1 & year > 2002, meanonly
        if r(N) == 0 {
            continue
        }

        display "===== `c' | Cohort `cohort_yr' ====="

        local lbl_c = subinstr("`c'", " ", "_", .)
        local lbl_c = subinstr("`lbl_c'", "'", "", .)
        local lbl_c = subinstr("`lbl_c'", ".", "", .)
        local lbl_c = subinstr("`lbl_c'", "-", "_", .)

        local b_sdid  = .
        local se_sdid = .

        * ----------------------------------------------------------------------
        * SDID event study + ATT
        * ----------------------------------------------------------------------
        preserve
            keep if country == "`c'" & (cohort == `cohort_yr' | treatment == 0)
            keep if year > 2002

            quietly su year, meanonly
            local yr_min = r(min)
            local yr_max = r(max)
            quietly su year if treat_absorbing == 1, meanonly
            local yr_t  = r(min)
            local pre   = `yr_t' - `yr_min'
            local post  = `yr_max' - `yr_t' + 1
            local total = `pre' + `post'

            capture sdid_event smooth_mean unique_id year treat_absorbing, ///
                vce(placebo) placebo(all)
            if _rc == 0 {
                mat res = e(H)[2..`=`total'+1', 1..5]
                svmat res
                gen id = _n - 1          if !missing(res1)
                replace id = `post' - _n if _n > `post' & !missing(res1)
                sort id
                twoway (rarea res3 res4 id, lc(gs10) fc(gs11%50)) ///
                       (scatter res1 id, mc(blue) ms(d)), legend(off) ///
                       title("`c' Cohort `cohort_yr' SDID") ///
                       yline(0, lc(red) lp(-)) xline(0, lc(black) lp(solid)) ///
                       xtitle(Relative time) ytitle(Smooth NDVI)
                graph export "$fig_dir/01_effectiveness/01_ndvi/cohort/sdid/`lbl_c'_c`cohort_yr'_sdid_event.jpg", replace
                graph export "$fig_dir/01_effectiveness/01_ndvi/cohort/sdid/`lbl_c'_c`cohort_yr'_sdid_event.pdf", replace
                drop res1 res2 res3 res4 res5 id
            }

            capture sdid smooth_mean unique_id year treat_absorbing, vce(noinference)
            if _rc == 0 {
                capture sdid smooth_mean unique_id year treat_absorbing, vce(placebo) reps(100)
                if _rc == 0 {
                    local b_sdid  = e(ATT)
                    local se_sdid = e(se)
                }
            }
        restore

        * ----------------------------------------------------------------------
        * Append results
        * ----------------------------------------------------------------------
        preserve
            clear
            set obs 1
            gen str30 country = "`c'"
            gen cohort        = `cohort_yr'
            gen sdid_att      = `b_sdid'
            gen sdid_se       = `se_sdid'
            if `results_started' {
                append using "`results_running'"
            }
            save "`results_running'", replace
            local results_started = 1
        restore

    }   // end cohort loop
}   // end country loop

********************************************************************************
* Save results
********************************************************************************

use "`results_running'", clear
save "$res_dir/03_cohort_results.dta", replace
display "Cohort results saved: $res_dir/03_cohort_results.dta"