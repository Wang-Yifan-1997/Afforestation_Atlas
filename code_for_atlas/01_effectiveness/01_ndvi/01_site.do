********************************************************************************
* 01_site.do
* ATLAS Afforestation — Site-Level NDVI Regressions
*
* Analysis unit: site (group_both) = 1 treated polygon + ~100 matched controls
*   → Most granular level; one regression per site
*
* Methods (per site):
*   1. TWFE        — reghdfe event study + static ATT
*   2. SDID        — sdid_event (event study) + sdid (ATT)
*   3. SC          — sdid method(sc): ATT + trend graph  [not a formal event study]
*   4. EB + TWFE   — entropy balance on pre-treatment NDVI, then weighted TWFE
*
* Output figures:  $fig_dir/01_effectiveness/01_ndvi/site/{twfe|sdid|sc|eb}/
* Output results:  $res_dir/01_site_results.dta  (one row per site)
*
* Requires: 00_data_prep.do run first
* Runtime:  slow (~N_sites × 4 methods); restrict country_filter for testing
********************************************************************************

local user = c(username)

if "`user'" == "wyf19"   global dropdir "C:/Users/wyf19/Dropbox"
if "`user'" == "wangy390" global dropdir "D:/Dropbox"
if "`user'" == "WANGY390" global dropdir "C:/Users/WANGY390/Dropbox"

global data_dir "$dropdir/Afforestation_Transition/Data/Processed Data"
global fig_dir  "$dropdir/Afforestation_Transition/Output/Figure/atlas"
global res_dir  "$data_dir/results/01_effectiveness/01_ndvi"

* Output directories
foreach m in twfe sdid sc eb {
    cap mkdir "$fig_dir/01_effectiveness"
    cap mkdir "$fig_dir/01_effectiveness/01_ndvi"
    cap mkdir "$fig_dir/01_effectiveness/01_ndvi/site"
    cap mkdir "$fig_dir/01_effectiveness/01_ndvi/site/`m'"
}

* ── Optional: restrict to one country to test or run in parallel ─────────────
* Uncomment and set the country name to limit the loop:
* local country_filter `"& country == "Ethiopia""'
local country_filter ""

********************************************************************************
* Load data, initialize result variables
********************************************************************************

use `"$data_dir/atlas_ndvi_panel.dta"', clear
if `"`country_filter'"' != "" keep if `country_filter'

* One result row per site; fill during loop
gen twfe_att = .
gen twfe_se  = .
gen sdid_att = .
gen sdid_se  = .
gen sc_att   = .
gen sc_se    = .
gen eb_att   = .
gen eb_se    = .

quietly su group_both, meanonly
local n_sites = r(max)
display "Total sites to process: `n_sites'"

********************************************************************************
* Site loop
********************************************************************************

forvalues g = 1/`n_sites' {

    quietly su year if group_both == `g' & treat_absorbing == 1 & year > 2002, meanonly
    if r(N) == 0 { 
		continue 
	}   // skip sites with no treated obs after 2002

    quietly levelsof country if group_both == `g', local(ctry_lbl) clean
    quietly su proj_plant_yr if group_both == `g' & treat_absorbing == 1, meanonly
    local treat_yr = r(min)     // treatment year for this site (for EB cutoff)
    display "Site `g'/`n_sites' | `ctry_lbl' | treat yr: `treat_yr'"

    * ──────────────────────────────────────────────────────────────────────────
    * METHOD 1: TWFE
    * ──────────────────────────────────────────────────────────────────────────
    local b_twfe = .
	local se_twfe = .
    preserve
        keep if group_both == `g' & year > 2002
        gen rel_time = year - first_year

        * Event study
        capture reghdfe smooth_mean ib(-1).rel_time, ///
            absorb(unique_id year) vce(cluster unique_id) nocons
        if _rc == 0 {
            coefplot, keep(*.rel_time) omitted baselevels vertical recast(connected) ///
                ciopts(recast(rarea) fc(gs11%50) lc(gs10)) legend(off) ///
                yline(0, lc(red) lp(-)) xline(-0.5, lc(black) lp(solid)) ///
                title("Site `g' (`ctry_lbl') TWFE") xtitle(Relative time) ytitle(Smooth NDVI)
            graph export `"$fig_dir/01_effectiveness/01_ndvi/site/twfe/site`g'_twfe.jpg"', replace
            graph export `"$fig_dir/01_effectiveness/01_ndvi/site/twfe/site`g'_twfe.pdf"', replace
        }
		
        * Static ATT
        capture reghdfe smooth_mean treat_absorbing, ///
            absorb(unique_id year) vce(cluster unique_id) nocons
        if _rc == 0 {
            local b_twfe  = _b[treat_absorbing]
            local se_twfe = _se[treat_absorbing]
        }
    restore
    replace twfe_att = `b_twfe'  if group_both == `g'
    replace twfe_se  = `se_twfe' if group_both == `g'

    * ──────────────────────────────────────────────────────────────────────────
    * METHOD 2: SDID  (sdid_event event study + sdid ATT)
    * ──────────────────────────────────────────────────────────────────────────
    local b_sdid = .
	local se_sdid = .
    preserve
        keep if group_both == `g' & year > 2002

        * Dynamic window (must be computed from data, not hardcoded)
        quietly su year, meanonly
        local yr_min = r(min)
        local yr_max = r(max)
        quietly su year if treat_absorbing == 1, meanonly
        local yr_t = r(min)
        local pre   = `yr_t' - `yr_min'
        local post  = `yr_max' - `yr_t' + 1
        local total = `pre' + `post'

        * Event study
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
                   title("Site `g' (`ctry_lbl') SDID event study") ///
                   yline(0, lc(red) lp(-)) xline(0, lc(black) lp(solid)) ///
                   xtitle(Relative time) ytitle(Smooth NDVI)
            graph export `"$fig_dir/01_effectiveness/01_ndvi/site/sdid/site`g'_sdid_event.jpg"', replace
            graph export `"$fig_dir/01_effectiveness/01_ndvi/site/sdid/site`g'_sdid_event.pdf"', replace
            drop res1 res2 res3 res4 res5 id
        }
        * ATT (test feasibility first with noinference, then placebo)
        capture sdid smooth_mean unique_id year treat_absorbing, vce(noinference)
        if _rc == 0 {
            capture sdid smooth_mean unique_id year treat_absorbing, vce(placebo) reps(100)
            if _rc == 0 {
                local b_sdid  = e(ATT)
                local se_sdid = e(se)
            }
        }
    restore
    replace sdid_att = `b_sdid'  if group_both == `g'
    replace sdid_se  = `se_sdid' if group_both == `g'

    * ──────────────────────────────────────────────────────────────────────────
    * METHOD 3: SC  (Synthetic Control via sdid method(sc))
    * Reports ATT + sdid trend graph (treated vs. synthetic control over time)
    * Note: this is not a formal event study — use for ATT robustness check
    * ──────────────────────────────────────────────────────────────────────────
    local b_sc = .
	local se_sc = .
    preserve
        keep if group_both == `g' & year > 2002
        capture sdid smooth_mean unique_id year treat_absorbing, vce(noinference) method(sc)
        if _rc == 0 {
            capture sdid smooth_mean unique_id year treat_absorbing, ///
                vce(placebo) reps(100) method(sc) graph ///
                graph_export(`"$fig_dir/01_effectiveness/01_ndvi/site/sc/site`g'_sc"', .pdf)
            if _rc == 0 {
                local b_sc  = e(ATT)
                local se_sc = e(se)
            }
        }
    restore
    replace sc_att = `b_sc'  if group_both == `g'
    replace sc_se  = `se_sc' if group_both == `g'

    //* NO Etropy Balancing for site level since it's hard for EB to work with relatively smaller sample. need to debug this in the future

}   // end site loop

********************************************************************************
* Save results
********************************************************************************

keep country ctry_id proj_id site_id site_rpt group_both cohort  ///
     twfe_att twfe_se sdid_att sdid_se sc_att sc_se eb_att eb_se
duplicates drop group_both, force
drop if mi(group_both)
save `"$res_dir/01_site_results.dta"', replace

display "Site results saved: $res_dir/01_site_results.dta"
