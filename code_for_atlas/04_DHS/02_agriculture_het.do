********************************************************************************
* 02_agriculture_het.do
* Does pre-treatment agriculture predict lower NDVI ATT?
********************************************************************************

local user = c(username)
if "`user'" == "wyf19"    global dropdir "C:/Users/wyf19/Dropbox"
if "`user'" == "wangy390"  global dropdir "D:/Dropbox"
if "`user'" == "WANGY390"  global dropdir "C:/Users/WANGY390/Dropbox"

global data_dir   "$dropdir/Afforestation_Transition/Data/Processed Data"
global merged_dir "$data_dir/DHS/merged"
global fig_dir    "$dropdir/Afforestation_Transition/Output/Figure/atlas"
global res_dir    "$data_dir/results"

cap mkdir "$fig_dir/04_DHS"
cap mkdir "$res_dir/04_DHS"

********************************************************************************
* STEP 1: Load and merge data
********************************************************************************

use "$res_dir/01_effectiveness/01_ndvi/01_site_results.dta", clear
tostring site_id, replace force
rename site_id nearest_site_id

merge 1:1 nearest_site_id using "$merged_dir/dhs_site_chars.dta", keep(3) nogen
display "Analysis sample: `r(N)' sites"

foreach v in agri_land_ha_50km cattle_50km goats_50km {
    cap gen l_`v' = asinh(`v')
}

foreach v in own_agri_land_50km l_agri_land_ha_50km l_cattle_50km l_goats_50km {
    cap {
        quietly su `v'
        gen z_`v' = (`v' - r(mean)) / r(sd)
    }
}
egen agri_index = rowmean(z_own_agri_land_50km z_l_agri_land_ha_50km ///
                           z_l_cattle_50km z_l_goats_50km)

tostring cohort, gen(cohort_str)
encode cohort_str, gen(cohort_num)
encode country,    gen(country_num)

local xvars   own_agri_land_50km l_agri_land_ha_50km l_cattle_50km l_goats_50km agri_index
local outcomes sdid_att

********************************************************************************
* STEP 2: Regressions
********************************************************************************

display " "
display "========================================================"
display "  sdid_att ~ pre-treatment agriculture"
display "========================================================"

foreach out of local outcomes {
    display " "
    display "--- `out' ---"
    foreach xvar of local xvars {
        cap reg `out' `xvar', vce(robust)
        if _rc == 0 display "  `xvar' (no FE):      b = " %8.4f _b[`xvar'] "  SE = " %6.4f _se[`xvar'] "  p = " %5.3f 2*ttail(e(df_r), abs(_b[`xvar']/_se[`xvar'])) "  N = " e(N)

        cap reghdfe `out' `xvar', absorb(cohort_num) vce(robust)
        if _rc == 0 display "  `xvar' + cohortFE:   b = " %8.4f _b[`xvar'] "  SE = " %6.4f _se[`xvar'] "  p = " %5.3f 2*ttail(e(df_r), abs(_b[`xvar']/_se[`xvar'])) "  N = " e(N)

        cap reghdfe `out' `xvar', absorb(cohort_num country_num) vce(robust)
        if _rc == 0 display "  `xvar' + cohort+cty: b = " %8.4f _b[`xvar'] "  SE = " %6.4f _se[`xvar'] "  p = " %5.3f 2*ttail(e(df_r), abs(_b[`xvar']/_se[`xvar'])) "  N = " e(N)
    }
}

********************************************************************************
* STEP 3: Figures
********************************************************************************

foreach xvar of local xvars {
    foreach out of local outcomes {

        cap confirm var `xvar'
        if _rc != 0 continue
        cap confirm var `out'
        if _rc != 0 continue

        * --- Scatter with linear fit ---
        cap twoway ///
            (scatter `out' `xvar', mc(navy%40) ms(o) msize(small)) ///
            (lfit `out' `xvar', lc(black) lp(solid)), ///
            xtitle("`xvar'") ytitle("") ///
            title("") legend(off)
        cap graph export "$fig_dir/04_DHS/scatter_`out'_`xvar'.jpg", replace
        cap graph export "$fig_dir/04_DHS/scatter_`out'_`xvar'.pdf", replace

        * --- Binscatter ---
        cap binscatter `out' `xvar', ///
            xtitle("") ytitle("") ///
            title("") ///
            legend(off)
        cap graph export "$fig_dir/04_DHS/binscatter_`out'_`xvar'.jpg", replace
        cap graph export "$fig_dir/04_DHS/binscatter_`out'_`xvar'.pdf", replace

        * --- Low vs high bar chart ---
        cap drop high_x
        cap su `xvar', meanonly
        cap gen high_x = (`xvar' > r(mean)) if !mi(`xvar')

        preserve
			collapse (mean) `out' (semean) se = `out', by(high_x)
			drop if mi(high_x)
			gen ci_lo = `out' - 1.96 * se
			gen ci_hi = `out' + 1.96 * se
			twoway ///
				(bar `out' high_x, fc(navy%70) lc(navy) barwidth(0.4) base(0)) ///
				(rcap ci_lo ci_hi high_x, lc(gs6)), ///
				yline(0, lc(red) lp(-)) ///
				xlabel(-0.5 " " 0 "Low" 1 "High" 1.5 " ", noticks labsize(large)) ///
				xscale(range(-0.5 1.5)) ///
				ytitle("") xtitle("") legend(off)
			graph export "$fig_dir/04_DHS/lowhigh_`out'_`xvar'.jpg", replace
			graph export "$fig_dir/04_DHS/lowhigh_`out'_`xvar'.pdf", replace
		restore
    }
}

display " "
display "===== done ====="