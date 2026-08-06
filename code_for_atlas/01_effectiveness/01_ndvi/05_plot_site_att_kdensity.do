********************************************************************************
* 02_plot_att_kdensity.do
* KDensity plots of site-level ATT distribution
********************************************************************************

local user = c(username)
if "`user'" == "wyf19"    global dropdir "C:/Users/wyf19/Dropbox"
if "`user'" == "wangy390"  global dropdir "D:/Dropbox"
if "`user'" == "WANGY390"  global dropdir "C:/Users/WANGY390/Dropbox"

global data_dir "$dropdir/Afforestation_Transition/Data/Processed Data"
global fig_dir  "$dropdir/Afforestation_Transition/Output/Figure/atlas"
global res_dir  "$data_dir/results/01_effectiveness/01_ndvi"

cap mkdir "$fig_dir/01_effectiveness/01_ndvi/site/kdensity"

use "$res_dir/01_site_results.dta", clear

********************************************************************************
* Summary statistics
********************************************************************************

display " "
display "ATT Summary Statistics"
display "======================"
su twfe_att sdid_att sc_att eb_att, detail

********************************************************************************
* Individual kdensity per method
********************************************************************************

foreach m in twfe sdid sc eb {
    quietly count if !mi(`m'_att)
    if r(N) < 2 continue

    kdensity `m'_att, lc(navy) lw(medthick) ///
        xline(0, lc(red) lp(-)) legend(off) ///
        xtitle("ATT (Smooth NDVI)") ytitle("Density")
    graph export "$fig_dir/01_effectiveness/01_ndvi/site/kdensity/kdensity_`m'_att.jpg", replace
    graph export "$fig_dir/01_effectiveness/01_ndvi/site/kdensity/kdensity_`m'_att.pdf", replace
}

********************************************************************************
* Combined overlay
********************************************************************************

twoway ///
    (kdensity twfe_att, lc(navy)         lw(medthick)) ///
    (kdensity sdid_att, lc(maroon)       lw(medthick)) ///
    (kdensity sc_att,   lc(forest_green) lw(medthick)) ///
    (kdensity eb_att,   lc(orange)       lw(medthick)), ///
    xline(0, lc(red) lp(-)) ///
    xtitle("ATT (Smooth NDVI)") ytitle("Density") ///
    legend(order(1 "TWFE" 2 "SDID" 3 "SC" 4 "EB+TWFE") pos(1) ring(0))
graph export "$fig_dir/01_effectiveness/01_ndvi/site/kdensity/kdensity_all_methods.jpg", replace
graph export "$fig_dir/01_effectiveness/01_ndvi/site/kdensity/kdensity_all_methods.pdf", replace

********************************************************************************
* Pre-treatment NDVI distribution
********************************************************************************

use "$data_dir/atlas_ndvi_panel.dta", clear
keep if treatment == 1 & year < proj_plant_yr & !mi(smooth_mean)
collapse (mean) pre_ndvi = smooth_mean, by(group_both)

su pre_ndvi, detail

kdensity pre_ndvi, lc(navy) lw(medthick) ///
    xline(0, lc(red) lp(-)) legend(off) ///
    xtitle("Mean Smooth NDVI (pre-treatment)") ytitle("Density")
graph export "$fig_dir/01_effectiveness/01_ndvi/site/kdensity/kdensity_pre_ndvi.jpg", replace
graph export "$fig_dir/01_effectiveness/01_ndvi/site/kdensity/kdensity_pre_ndvi.pdf", replace

display "Done."