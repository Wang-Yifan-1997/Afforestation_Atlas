********************************************************************************
* 02_project.do
* ATLAS Afforestation - Project-Level NDVI Regressions
*
* Analysis unit: project (proj_group = ctry_id x proj_id)
*   One project may contain multiple treated polygons (sites) planted
*   in the same or different years. All sites and their matched controls
*   are pooled within the project regression.
*
* Methods (per project):
*   1. TWFE      - reghdfe event study (staggered) + static ATT
*   2. SDID      - sdid_event (event study) + sdid (ATT)
*   3. SC        - sdid method(sc): ATT + trend graph
*   4. EB + TWFE - entropy balance on pre-project NDVI, then weighted TWFE
*
* Output figures:  $fig_dir/01_effectiveness/01_ndvi/project/{twfe|sdid|sc|eb}/
* Output results:  $res_dir/02_project_results.dta  (one row per project)
*
* Requires: 00_data_prep.do run first
********************************************************************************

local user = c(username)

if "`user'" == "wyf19"    global dropdir "C:/Users/wyf19/Dropbox"
if "`user'" == "wangy390"  global dropdir "D:/Dropbox"
if "`user'" == "WANGY390"  global dropdir "C:/Users/WANGY390/Dropbox"

global data_dir "$dropdir/Afforestation_Transition/Data/Processed Data"
global fig_dir  "$dropdir/Afforestation_Transition/Output/Figure/atlas"
global res_dir  "$data_dir/results/01_effectiveness/01_ndvi"

foreach m in twfe sdid sc eb {
    cap mkdir "$fig_dir/01_effectiveness"
    cap mkdir "$fig_dir/01_effectiveness/01_ndvi"
    cap mkdir "$fig_dir/01_effectiveness/01_ndvi/project"
    cap mkdir "$fig_dir/01_effectiveness/01_ndvi/project/`m'"
}

* local country_filter `"& country == "Ethiopia""'
local country_filter ""

stop, currently projects and sites are not super different

********************************************************************************
* Load data, initialize result variables
********************************************************************************

use "$data_dir/atlas_ndvi_panel.dta", clear
if `"`country_filter'"' != "" keep if `country_filter'

gen twfe_att = .
gen twfe_se  = .
gen sdid_att = .
gen sdid_se  = .
gen sc_att   = .
gen sc_se    = .
gen eb_att   = .
gen eb_se    = .

quietly su proj_group, meanonly
local n_proj = r(max)
display "Total projects to process: `n_proj'"

********************************************************************************
* Project loop
********************************************************************************

forvalues p = 1/`n_proj' {

    quietly su year if proj_group == `p' & treat_absorbing == 1 & year > 2002, meanonly
    if r(N) == 0 {
        continue
    }

    quietly levelsof country  if proj_group == `p', local(ctry_lbl) clean
    quietly levelsof proj_id  if proj_group == `p', local(proj_lbl) clean
    quietly su proj_treat_yr  if proj_group == `p', meanonly
    local treat_yr = r(min)
    display "Project `p'/`n_proj' | `ctry_lbl' | `proj_lbl' | treat yr: `treat_yr'"

    * --------------------------------------------------------------------------
    * METHOD 1: TWFE
    * --------------------------------------------------------------------------
    local b_twfe  = .
    local se_twfe = .
    preserve
        keep if proj_group == `p' & year > 2002
        gen rel_time = year - first_year

        capture reghdfe smooth_mean ib(-1).rel_time, ///
            absorb(unique_id year) vce(cluster unique_id) nocons
        if _rc == 0 {
            coefplot, keep(*.rel_time) omitted baselevels vertical recast(connected) ///
                ciopts(recast(rarea) fc(gs11%50) lc(gs10)) legend(off) ///
                yline(0, lc(red) lp(-)) xline(-0.5, lc(black) lp(solid)) ///
                title("Project `p' (`ctry_lbl') TWFE") xtitle(Relative time) ytitle(Smooth NDVI)
            graph export "$fig_dir/01_effectiveness/01_ndvi/project/twfe/proj`p'_twfe.jpg", replace
            graph export "$fig_dir/01_effectiveness/01_ndvi/project/twfe/proj`p'_twfe.pdf", replace
        }

        capture reghdfe smooth_mean treat_absorbing, ///
            absorb(unique_id year) vce(cluster unique_id) nocons
        if _rc == 0 {
            local b_twfe  = _b[treat_absorbing]
            local se_twfe = _se[treat_absorbing]
        }
    restore
    replace twfe_att = `b_twfe'  if proj_group == `p'
    replace twfe_se  = `se_twfe' if proj_group == `p'

    * --------------------------------------------------------------------------
    * METHOD 2: SDID
    * --------------------------------------------------------------------------
    local b_sdid  = .
    local se_sdid = .
    preserve
        keep if proj_group == `p' & year > 2002

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
                   title("Project `p' (`ctry_lbl') SDID") ///
                   yline(0, lc(red) lp(-)) xline(0, lc(black) lp(solid)) ///
                   xtitle(Relative time) ytitle(Smooth NDVI)
            graph export "$fig_dir/01_effectiveness/01_ndvi/project/sdid/proj`p'_sdid_event.jpg", replace
            graph export "$fig_dir/01_effectiveness/01_ndvi/project/sdid/proj`p'_sdid_event.pdf", replace
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
    replace sdid_att = `b_sdid'  if proj_group == `p'
    replace sdid_se  = `se_sdid' if proj_group == `p'

    * --------------------------------------------------------------------------
    * METHOD 3: SC
    * --------------------------------------------------------------------------
    local b_sc  = .
    local se_sc = .
    preserve
        keep if proj_group == `p' & year > 2002
        capture sdid smooth_mean unique_id year treat_absorbing, vce(noinference) method(sc)
        if _rc == 0 {
            capture sdid smooth_mean unique_id year treat_absorbing, ///
                vce(placebo) reps(100) method(sc) graph ///
                graph_export("$fig_dir/01_effectiveness/01_ndvi/project/sc/proj`p'_sc", .pdf)
            if _rc == 0 {
                local b_sc  = e(ATT)
                local se_sc = e(se)
            }
        }
    restore
    replace sc_att = `b_sc'  if proj_group == `p'
    replace sc_se  = `se_sc' if proj_group == `p'

    * --------------------------------------------------------------------------
    * METHOD 4: EB + TWFE
    * --------------------------------------------------------------------------
    *skip this for now 

}   // end project loop

********************************************************************************
* Save results
********************************************************************************

keep country ctry_id proj_id proj_group proj_treat_yr ///
     twfe_att twfe_se sdid_att sdid_se sc_att sc_se eb_att eb_se
duplicates drop proj_group, force
drop if mi(proj_group)
save "$res_dir/02_project_results.dta", replace
display "Project results saved: $res_dir/02_project_results.dta"