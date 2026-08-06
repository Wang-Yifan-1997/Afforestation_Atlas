********************************************************************************
* 01_cropland_het.do
* Does cropland pressure predict lower NDVI ATT?
********************************************************************************

local user = c(username)
if "`user'" == "wyf19"    global dropdir "C:/Users/wyf19/Dropbox"
if "`user'" == "wangy390"  global dropdir "D:/Dropbox"
if "`user'" == "WANGY390"  global dropdir "C:/Users/WANGY390/Dropbox"

global data_dir "$dropdir/Afforestation_Transition/Data/Processed Data"
global res_dir  "$data_dir/results/01_effectiveness/01_ndvi"
global fig_dir  "$dropdir/Afforestation_Transition/Output/Figure/atlas"

cap mkdir "$fig_dir/05_cropland"

********************************************************************************
* STEP 1: Load ATT results and merge cropland data
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
    import delimited "$data_dir/cropland_pressure_by_polygon.csv", ///
        varnames(1) encoding(utf8) clear
    destring poly_id area_exp_pressure_con area_exp_pressure_exp ///
             profit_rank_con profit_rank_exp cropland_pct_2011, replace force
    rename poly_id treated_polygon_id
    tempfile cropland_data
    save "`cropland_data'"
restore

merge 1:1 treated_polygon_id using "`cropland_data'", keep(1 3) nogen
keep if !mi(sdid_att)

gen l_area_exp_con = asinh(area_exp_pressure_con)
gen l_area_exp_exp = asinh(area_exp_pressure_exp)
gen l_cropland_pct = asinh(cropland_pct_2011)

encode country, gen(country_num)

display "Analysis sample: `r(N)' sites"
su area_exp_pressure_con area_exp_pressure_exp cropland_pct_2011, detail

********************************************************************************
* STEP 2: Regressions
********************************************************************************

display " "
display "========================================================"
display "  sdid_att ~ cropland pressure"
display "========================================================"

local xvars l_area_exp_con l_area_exp_exp l_cropland_pct profit_rank_con profit_rank_exp

foreach xvar of local xvars {
    cap reg sdid_att `xvar', vce(robust)
    if _rc == 0 display "`xvar' (no FE):    b = " %8.4f _b[`xvar'] "  SE = " %6.4f _se[`xvar'] "  p = " %5.3f 2*ttail(e(df_r), abs(_b[`xvar']/_se[`xvar'])) "  N = " e(N)

    cap reghdfe sdid_att `xvar', absorb(country_num) vce(robust)
    if _rc == 0 display "`xvar' + ctyFE:   b = " %8.4f _b[`xvar'] "  SE = " %6.4f _se[`xvar'] "  p = " %5.3f 2*ttail(e(df_r), abs(_b[`xvar']/_se[`xvar'])) "  N = " e(N)
}

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
    cap graph export "$fig_dir/05_cropland/scatter_`xvar'.jpg", replace
    cap graph export "$fig_dir/05_cropland/scatter_`xvar'.pdf", replace

    * Binscatter
    cap binscatter sdid_att `xvar', ///
        yline(0, lc(red) lp(-)) ///
        xtitle("") ytitle("") ///
        legend(off)
    cap graph export "$fig_dir/05_cropland/binscatter_`xvar'.jpg", replace
    cap graph export "$fig_dir/05_cropland/binscatter_`xvar'.pdf", replace

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
		cap graph export "$fig_dir/05_cropland/lowhigh_`xvar'.jpg", replace
        cap graph export "$fig_dir/05_cropland/lowhigh_`xvar'.pdf", replace
    restore
}

display " "
display "===== done ====="