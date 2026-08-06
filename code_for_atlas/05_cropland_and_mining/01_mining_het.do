********************************************************************************
* 01_mining_het.do
* Does mining proximity predict lower NDVI ATT?
********************************************************************************

local user = c(username)
if "`user'" == "wyf19"    global dropdir "C:/Users/wyf19/Dropbox"
if "`user'" == "wangy390"  global dropdir "D:/Dropbox"
if "`user'" == "WANGY390"  global dropdir "C:/Users/WANGY390/Dropbox"

global data_dir "$dropdir/Afforestation_Transition/Data/Processed Data"
global res_dir  "$data_dir/results/01_effectiveness/01_ndvi"
global fig_dir  "$dropdir/Afforestation_Transition/Output/Figure/atlas"

cap mkdir "$fig_dir/06_mining"

********************************************************************************
* STEP 1: Load ATT results and merge mining data
********************************************************************************

use "$data_dir/atlas_ndvi_panel.dta", clear
keep if treatment == 1
keep group_both treated_polygon_id country proj_plant_yr
duplicates drop group_both, force
tempfile site_map
save "`site_map'"

use "$res_dir/01_site_results.dta", clear
merge 1:1 group_both using "`site_map'", keep(3) nogen

preserve
    import delimited "$data_dir/mining_exposure_by_polygon.csv", ///
        varnames(1) encoding(utf8) clear
    destring poly_id dist_mine_km has_mining_50km mining_area_sqkm_50km, replace force
    rename poly_id treated_polygon_id
    tempfile mining_data
    save "`mining_data'"
restore

merge 1:1 treated_polygon_id using "`mining_data'", keep(1 3) nogen
keep if !mi(sdid_att)

gen l_dist_mine   = asinh(dist_mine_km)
gen l_mining_area = asinh(mining_area_sqkm_50km)

encode country, gen(country_num)

display "Analysis sample: `r(N)' sites"
su dist_mine_km mining_area_sqkm_50km has_mining_50km, detail

********************************************************************************
* STEP 2: Regressions
********************************************************************************

display " "
display "========================================================"
display "  sdid_att ~ mining proximity"
display "========================================================"

local xvars has_mining_50km l_dist_mine l_mining_area

foreach xvar of local xvars {
    cap reg sdid_att `xvar', vce(robust)
    if _rc == 0 display "`xvar' (no FE):  b = " %8.4f _b[`xvar'] "  SE = " %6.4f _se[`xvar'] "  p = " %5.3f 2*ttail(e(df_r), abs(_b[`xvar']/_se[`xvar'])) "  N = " e(N)

    cap reghdfe sdid_att `xvar', absorb(country_num) vce(robust)
    if _rc == 0 display "`xvar' + ctyFE: b = " %8.4f _b[`xvar'] "  SE = " %6.4f _se[`xvar'] "  p = " %5.3f 2*ttail(e(df_r), abs(_b[`xvar']/_se[`xvar'])) "  N = " e(N)
}

********************************************************************************
* STEP 3: Figures
********************************************************************************

********************************************************************************
* STEP 3: Figures
********************************************************************************

foreach xvar of local xvars {

    * Scatter with linear fit
    cap twoway ///
        (scatter sdid_att `xvar', mc(navy%40) ms(o) msize(small)) ///
        (lfit sdid_att `xvar', lc(black) lp(solid)), ///
        yline(0, lc(red) lp(-)) legend(off) ///
        xtitle("`xvar'") ytitle("SDID ATT") ///
        title("SDID ATT vs `xvar'")
    cap graph export "$fig_dir/06_mining/scatter_`xvar'.jpg", replace
    cap graph export "$fig_dir/06_mining/scatter_`xvar'.pdf", replace

    * Binscatter
    cap binscatter sdid_att `xvar', ///
        yline(0, lc(red) lp(-)) ///
        xtitle("") ytitle("") ///
        legend(off)
    cap graph export "$fig_dir/06_mining/binscatter_`xvar'.jpg", replace
    cap graph export "$fig_dir/06_mining/binscatter_`xvar'.pdf", replace

    * Low vs high
    cap drop high_x
    cap su `xvar', meanonly
    cap gen high_x = (`xvar' > r(mean)) if !mi(`xvar')

    preserve
        cap collapse (mean) sdid_att (semean) se = sdid_att, by(high_x)
        cap drop if mi(high_x)
        cap gen ci_lo = sdid_att - 1.96 * se
        cap gen ci_hi = sdid_att + 1.96 * se
        cap twoway ///
            (rcap ci_lo ci_hi high_x, lc(gs8)) ///
            (scatter sdid_att high_x, mc(maroon) ms(D) msize(large)), ///
            yline(0, lc(red) lp(-)) legend(off) ///
            xlabel(-0.25 " " 0 "Low" 1 "High" 1.25 " ", noticks labsize(large)) ///
            ytitle("") xtitle("")
        cap graph export "$fig_dir/06_mining/lowhigh_`xvar'.jpg", replace
        cap graph export "$fig_dir/06_mining/lowhigh_`xvar'.pdf", replace
    restore
}

display " "
display "===== done ====="

display " "
display "===== done ====="