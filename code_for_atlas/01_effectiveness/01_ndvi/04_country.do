********************************************************************************
* 04_country.do
* ATLAS Afforestation - Country-Level NDVI Regressions
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
cap mkdir "$fig_dir/01_effectiveness/01_ndvi/country"
cap mkdir "$fig_dir/01_effectiveness/01_ndvi/country/sdid"

********************************************************************************
* Load data
********************************************************************************

use "$data_dir/atlas_ndvi_panel.dta", clear
drop if country == "Ethiopia"

tempfile results_running
local results_started = 0

********************************************************************************
* Country loop
********************************************************************************

levelsof country, local(ctry_list)

foreach c of local ctry_list {

    quietly su year if country == "`c'" & treat_absorbing == 1 & year > 2002, meanonly
    if r(N) == 0 {
        continue
    }

    display "===== Country: `c' ====="
    local lbl_c = subinstr("`c'", " ", "_", .)
    local lbl_c = subinstr("`lbl_c'", "'", "", .)
    local lbl_c = subinstr("`lbl_c'", ".", "", .)
    local lbl_c = subinstr("`lbl_c'", "-", "_", .)

    local b_sdid  = .
    local se_sdid = .

    * --------------------------------------------------------------------------
    * SDID event study + ATT
    * --------------------------------------------------------------------------
    preserve
        keep if country == "`c'" & year > 2002

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
            * cols: 1=coef, 2=se, 3=ci_lo(95%), 4=ci_hi(95%), 5=p
            svmat res
            gen id = _n - 1          if !missing(res1)
            replace id = `post' - _n if _n > `post' & !missing(res1)

            * Compute 90% CI manually from SE (col 2)
            gen ci90_lo = res1 - 1.645 * res2 if !missing(res2)
            gen ci90_hi = res1 + 1.645 * res2 if !missing(res2)

            sort id
            twoway ///
                (rarea res3 res4 id,    lc(gs10) fc(gs11%30)) ///
                (rarea ci90_lo ci90_hi id, lc(gs6)  fc(gs8%50))  ///
                (scatter res1 id, mc(blue) ms(d)), ///
                legend(off) ///
                yline(0, lc(red) lp(-)) xline(0, lc(black) lp(solid)) ///
                xtitle(" ") ytitle(" ")
            graph export "$fig_dir/01_effectiveness/01_ndvi/country/sdid/`lbl_c'_sdid_event.jpg", replace
            graph export "$fig_dir/01_effectiveness/01_ndvi/country/sdid/`lbl_c'_sdid_event.pdf", replace
            drop res1 res2 res3 res4 res5 id ci90_lo ci90_hi
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

    * --------------------------------------------------------------------------
    * Collect results
    * --------------------------------------------------------------------------
    preserve
        clear
        set obs 1
        gen str30 country = "`c'"
        gen sdid_att      = `b_sdid'
        gen sdid_se       = `se_sdid'
        if `results_started' {
            append using "`results_running'"
        }
        save "`results_running'", replace
        local results_started = 1
    restore

}   // end country loop

********************************************************************************
* Save results
********************************************************************************

use "`results_running'", clear
save "$res_dir/04_country_results.dta", replace
display "Country results saved: $res_dir/04_country_results.dta"