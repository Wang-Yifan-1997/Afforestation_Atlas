********************************************************************************
* 01_economic_outcomes.do
* Are households near afforestation projects richer / more agricultural?
* Selection check: cross-section, treated vs untreated clusters
********************************************************************************

local user = c(username)
if "`user'" == "wyf19"    global dropdir "C:/Users/wyf19/Dropbox"
if "`user'" == "wangy390"  global dropdir "D:/Dropbox"
if "`user'" == "WANGY390"  global dropdir "C:/Users/WANGY390/Dropbox"

global merged_dir "$dropdir/Afforestation_Transition/Data/Processed Data/DHS/merged"
global fig_dir    "$dropdir/Afforestation_Transition/Output/Figure/atlas"

cap mkdir "$fig_dir/04_DHS"

use "$merged_dir/dhs_cluster_wealth.dta", clear
destring latnum longnum, replace force

encode dhscc, gen(country_num)
gen urban = (urban_rura == "U") if !mi(urban_rura)

foreach v in agri_land_ha cattle goats sheep {
    cap gen l_`v' = asinh(`v')
}

********************************************************************************
* Treated vs untreated
********************************************************************************

local outcomes hv271_mean electricity own_agri_land l_agri_land_ha own_livestock l_cattle l_goats

display " "
display "Treated (<=100 km) vs untreated clusters"
display "========================================="

foreach out of local outcomes {
    reghdfe `out' treated urban latnum longnum, ///
        absorb(country_num survey_yr) vce(robust)
    if _rc == 0 display "  `out':  b = " %8.4f _b[treated] "  SE = " %6.4f _se[treated] "  p = " %5.3f 2*ttail(e(df_r), abs(_b[treated]/_se[treated])) "  N = " e(N)
}

gen l_distance = asinh(dist_aff_km)

foreach out of local outcomes {
    cap confirm var `out'
    if _rc != 0 continue

    * Binscatter
    cap binscatter `out' dist_aff_km, ///
        xtitle("Distance to nearest project (km)") ///
        ytitle("") ///
        title("") ///
        legend(off)
    cap graph export "$fig_dir/04_DHS/binscatter_`out'_dist.jpg", replace
    cap graph export "$fig_dir/04_DHS/binscatter_`out'_dist.pdf", replace
}


foreach out of local outcomes {
    cap confirm var `out'
    if _rc != 0 continue

    * Binscatter
    cap binscatter `out' l_distance, ///
        xtitle("Distance to nearest project (km)") ///
        ytitle("") ///
        title("") ///
        legend(off)
    cap graph export "$fig_dir/04_DHS/binscatter_`out'_l_dist.jpg", replace
    cap graph export "$fig_dir/04_DHS/binscatter_`out'_l_dist.pdf", replace
}


********************************************************************************
* Raw means by distance bin
********************************************************************************

gen dist_bin = .
replace dist_bin = 1 if dist_aff_km <= 10
replace dist_bin = 2 if dist_aff_km > 10  & dist_aff_km <= 20
replace dist_bin = 3 if dist_aff_km > 20  & dist_aff_km <= 50
replace dist_bin = 4 if dist_aff_km > 50  & dist_aff_km <= 100
replace dist_bin = 5 if dist_aff_km > 100 & !mi(dist_aff_km)
label define dist_lbl 1 "0-10km" 2 "10-20km" 3 "20-50km" 4 "50-100km" 5 ">100km"
label values dist_bin dist_lbl

display " "
display "Raw means by distance bin"
display "========================="
tabstat hv271_mean electricity own_agri_land own_livestock cattle, ///
    by(dist_bin) stat(mean n) nototal

display " "
display "===== done ====="



********************************************************************************
* Policy Selection
********************************************************************************


********************************************************************************
* Figure 1: Coefficient plot — all outcomes, treated vs untreated
********************************************************************************
* Run regressions and store results
tempfile coef_results
clear
set obs 0
gen str30 outcome = ""
gen float b  = .
gen float lo = .
gen float hi = .
gen int   order = .
save `coef_results'

local outcomes z_hv271_mean l_electricity l_own_agri_land own_livestock l_cattle l_goats
local labels `""Wealth index" "Electricity" "Own agri land" "Own livestock" "Cattle" "Goats""'

use "$merged_dir/dhs_cluster_wealth.dta", clear
gen l_hv271_mean    = asinh(hv271_mean)
gen l_electricity   = asinh(electricity)
gen l_own_agri_land = asinh(own_agri_land)

* Standardise wealth to SD units
quietly su hv271_mean
gen z_hv271_mean = (hv271_mean - r(mean)) / r(sd)

destring latnum longnum, replace force
encode dhscc, gen(country_num)
gen urban = (urban_rura == "U") if !mi(urban_rura)
foreach v in agri_land_ha cattle goats sheep {
    cap gen l_`v' = asinh(`v')
}

local i = 0
foreach out of local outcomes {
    local ++i
    local lbl : word `i' of `labels'
    cap reghdfe `out' treated, absorb(country_num survey_yr) vce(robust)
    if _rc == 0 {
        local b_s  = _b[treated]
        local lo_s = _b[treated] - 1.96 * _se[treated]
        local hi_s = _b[treated] + 1.96 * _se[treated]
        preserve
            clear
            set obs 1
            gen str30 outcome = "`lbl'"
            gen float b  = `b_s'
            gen float lo = `lo_s'
            gen float hi = `hi_s'
            gen int   order = `i'
            append using `coef_results'
            save `coef_results', replace
        restore
    }
}

use `coef_results', clear
sort order

* Separate y-axes: wealth on right (axis 2), others on left (axis 1)
* Bar + rcap style

* Reorder: wealth last, everything else on left axis
replace order = 1 if outcome == "Own agri land"
replace order = 2 if outcome == "Own livestock"
replace order = 3 if outcome == "Cattle"
replace order = 4 if outcome == "Goats"
replace order = 5 if outcome == "Electricity"
replace order = 6 if outcome == "Wealth index"
sort order

twoway ///
    (bar b order, ///
        fc(navy%70) lc(navy) barwidth(0.6)) ///
    (rcap lo hi order, ///
        lc(gs6)), ///
    yline(0, lc(red) lp(-)) ///
    ytitle("Coefficient") ///
    xtitle("") ///
    xlabel(0.5 " " 1 "Own agri land" 2 "Own livestock" 3 "Cattle" 4 "Goats" ///
           5 "Electricity" 6 "Wealth index" 6.5 " ", angle(45) noticks labsize(medium)) ///
    legend(off)
graph export "$fig_dir/04_DHS/coefplot_selection_combined.jpg", replace
graph export "$fig_dir/04_DHS/coefplot_selection_combined.pdf", replace
s

********************************************************************************
* Figure 2: Distance gradient — wealth and cattle side by side
********************************************************************************

use "$merged_dir/dhs_cluster_wealth.dta", clear
destring latnum longnum, replace force
foreach v in cattle goats dist_aff_km{
    cap gen l_`v' = asinh(`v')
}

binscatter hv271_mean l_dist_aff_km, ///
    xtitle("Distance to nearest project (km)") ///
    ytitle("Mean wealth index") ///
    yline(0, lc(red) lp(-)) legend(off) ///
    name(g_wealth, replace)

binscatter l_cattle l_dist_aff_km, ///
    xtitle("Distance to nearest project (km)") ///
    ytitle("Cattle (log)") ///
    legend(off) ///
    name(g_cattle, replace)

graph combine g_wealth g_cattle, cols(2)
graph export "$fig_dir/04_DHS/distance_gradient_combined.jpg", replace
graph export "$fig_dir/04_DHS/distance_gradient_combined.pdf", replace