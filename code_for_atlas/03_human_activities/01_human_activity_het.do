********************************************************************************
* 01_human_activity_het.do
* ATLAS Afforestation - Human Activity Heterogeneity
*
* Research question:
*   Among treated afforestation sites, does the NDVI treatment effect differ
*   by human activity intensity?
*   i.e. sites with more buildings/roads -- do they gain more or less NDVI?
*
* This is purely a cross-sectional heterogeneity analysis:
*   - We have NDVI ATT estimates per site (from 01_site.do)
*   - We have a snapshot of buildings and roads per treated polygon
*   - We ask: does ATT correlate with human activity intensity?
*
* What this can and cannot show:
*   CAN show: correlation between human activity presence and NDVI treatment effect
*   CANNOT show: whether afforestation caused more/less human activity (no pre-data)
*   CANNOT show: whether human activity caused the NDVI effect (reverse causality possible)
*
* Data coverage: Ethiopia only.
*
* Requires:
*   $data_dir/atlas_ndvi_panel.dta      -- run 00_data_prep.do first
*   $res_dir/01_site_results.dta        -- run 01_site.do first
*   road_building_combined_stats.csv    -- in RA/xinyi wang/tasks/Building & Road/
********************************************************************************

local user = c(username)

if "`user'" == "wyf19"    global dropdir "C:/Users/wyf19/Dropbox"
if "`user'" == "wangy390"  global dropdir "D:/Dropbox"
if "`user'" == "WANGY390"  global dropdir "C:/Users/WANGY390/Dropbox"

global data_dir  "$dropdir/Afforestation_Transition/Data/Processed Data"
global res_dir   "$data_dir/results/01_effectiveness/01_ndvi"
global fig_dir   "$dropdir/Afforestation_Transition/Output/Figure/atlas"
global ha_dir    "$dropdir/Afforestation_Transition/RA/xinyi wang/tasks/Building & Road"

cap mkdir "$fig_dir/03_human_activities"

********************************************************************************
* STEP 1: Build group_both to treated_polygon_id mapping from NDVI panel
********************************************************************************

use "$data_dir/atlas_ndvi_panel.dta", clear
keep if treatment == 1 & country == "Ethiopia"
keep group_both treated_polygon_id country proj_id site_id site_rpt
duplicates drop group_both, force
tempfile site_map
save "`site_map'"

********************************************************************************
* STEP 2: Load site-level ATT results and add treated polygon ID
********************************************************************************

use "$res_dir/01_site_results.dta", clear
keep if country == "Ethiopia"
merge 1:1 group_both using "`site_map'", keep(3) nogen

********************************************************************************
* STEP 3: Load and clean building/road data
********************************************************************************

preserve

    import delimited "$ha_dir/road_building_combined_stats.csv", ///
        varnames(1) encoding(utf8) clear

    keep poly_id                                                    ///
         path primary residential secondary service tertiary        ///
         track track_grade2 track_grade3 track_grade4 unclassified  ///
         total_buildings total_area_sqm avg_area_sqm avg_confidence ///
         plant_yr country proj_id

    foreach v in path primary residential secondary service tertiary ///
                 track track_grade2 track_grade3 track_grade4 unclassified {
        replace `v' = 0 if mi(`v')
    }

    gen total_road_length_m = path + primary + residential + secondary + ///
                              service + tertiary + track + track_grade2 + ///
                              track_grade3 + track_grade4 + unclassified

    gen has_building = (total_buildings > 0)
    gen has_road     = (total_road_length_m > 0)
    gen has_human    = (has_building == 1 | has_road == 1)

    gen l_building_area = asinh(total_area_sqm)
    gen l_building_n    = asinh(total_buildings)
    gen l_road_length   = asinh(total_road_length_m)

    keep poly_id has_building has_road has_human                   ///
         total_buildings total_area_sqm total_road_length_m        ///
         l_building_area l_building_n l_road_length

    destring poly_id, replace force
    rename poly_id treated_polygon_id

    tempfile ha_data
    save "`ha_data'"

restore

merge 1:1 treated_polygon_id using "`ha_data'", keep(1 3) nogen

********************************************************************************
* STEP 4: Descriptive -- how much human activity is there in treated sites?
*
* This tells us the baseline context: are afforestation sites in areas with
* substantial human activity or relatively untouched areas?
********************************************************************************

display " "
display "========================================================"
display "  STEP 4: Human activity in treated sites (Ethiopia)"
display "========================================================"

tab has_human
tab has_building
tab has_road
tabulate has_building has_road, row col

su total_buildings total_area_sqm total_road_length_m, detail

********************************************************************************
* STEP 5: Does NDVI treatment effect vary by human activity?
*
* Interpretation: a negative coefficient on has_building means that sites
* with buildings have LOWER NDVI gains from afforestation. This could reflect:
*   (a) human encroachment reducing vegetation
*   (b) selection: projects in already-degraded areas have lower NDVI gains
*   (c) reverse causality: better forest outcomes attract people later
*
* We cannot distinguish these mechanisms without panel data on human activity.
********************************************************************************

keep if !mi(sdid_att)

display " "
display "========================================================"
display "  STEP 5: NDVI ATT by human activity presence"
display "========================================================"

* Mean ATT by activity group
tabstat sdid_att twfe_att, by(has_human)    stat(n mean sd)
tabstat sdid_att twfe_att, by(has_building) stat(n mean sd)
tabstat sdid_att twfe_att, by(has_road)     stat(n mean sd)

* t-test
ttest sdid_att, by(has_human)

* Binary regressors
display "--- Binary regressors ---"
reg sdid_att has_building,          vce(robust)
reg sdid_att has_road,              vce(robust)
reg sdid_att has_building has_road, vce(robust)

* Continuous regressors
display "--- Continuous regressors (inverse hyperbolic sine) ---"
reg sdid_att l_building_area,              vce(robust)
reg sdid_att l_road_length,               vce(robust)
reg sdid_att l_building_area l_road_length, vce(robust)

* TWFE ATT robustness
display "--- TWFE ATT robustness ---"
reg twfe_att l_building_area, vce(robust)
reg twfe_att l_road_length,   vce(robust)

********************************************************************************
* STEP 6: Visualizations
********************************************************************************

* --- 6a. Kernel density: ATT by human activity presence
twoway (kdensity sdid_att if has_human == 0 & sdid_att > -0.3 & sdid_att < 0.3, 	///
            color(navy%80))                                                       	///
       (kdensity sdid_att if has_human == 1 & sdid_att > -0.3 & sdid_att < 0.3, 	///
            color(maroon%80)),                                                    	///
    xtitle("") ytitle("Density")                 ///
    xline(0, lc(red) lp(-))                                                      	///
    legend(label(1 "No human activity") label(2 "Has human activity") 				///
       pos(0) bplacement(neast) ring(0) row(2))
graph export "$fig_dir/03_human_activities/kdensity_att_by_human.jpg", replace
graph export "$fig_dir/03_human_activities/kdensity_att_by_human.pdf", replace
s
* --- 6b. Kernel density: ATT by building presence
twoway (kdensity sdid_att if has_building == 0 & sdid_att > -0.3 & sdid_att < 0.3, ///
            color(navy%80))                                                          ///
       (kdensity sdid_att if has_building == 1 & sdid_att > -0.3 & sdid_att < 0.3, ///
            color(maroon%80)),                                                       ///
    xtitle("SDID ATT") ytitle("Density")                                            ///
    xline(0, lc(red) lp(-))                                                         ///
    legend(label(1 "No buildings") label(2 "Has buildings") pos(6) row(1))          ///
    title("NDVI treatment effect by building presence (Ethiopia)")
graph export "$fig_dir/03_human_activities/kdensity_att_by_building.jpg", replace
graph export "$fig_dir/03_human_activities/kdensity_att_by_building.pdf", replace

* --- 6c. Binscatter: ATT vs building footprint
binscatter sdid_att l_building_area,           ///
    xtitle("Building footprint")    ///
    ytitle("")           ///
    title("") ///
    legend(off)
graph export "$fig_dir/03_human_activities/binscatter_att_building.jpg", replace
graph export "$fig_dir/03_human_activities/binscatter_att_building.pdf", replace

* --- 6d. Binscatter: ATT vs road length
binscatter sdid_att l_road_length,             ///
    xtitle("Road length")         ///
    ytitle("")           ///
    title("")       ///
    legend(off)
graph export "$fig_dir/03_human_activities/binscatter_att_road.jpg", replace
graph export "$fig_dir/03_human_activities/binscatter_att_road.pdf", replace

/*

* --- 6e. Bar chart: mean ATT by above/below median human activity
quietly su l_building_area, detail
local p50_bld = r(p50)
gen high_building = (l_building_area > `p50_bld') if !mi(l_building_area)

preserve
    collapse (mean) sdid_att twfe_att (semean) se_sdid = sdid_att, by(high_building)
    gen ci_lo = sdid_att - 1.96 * se_sdid
    gen ci_hi = sdid_att + 1.96 * se_sdid
    gen xpos  = high_building

    twoway (rcap ci_lo ci_hi xpos, lc(gs8)) ///
           (scatter sdid_att xpos, mc(navy) ms(d) msize(large)), ///
           legend(off) ///
           yline(0, lc(red) lp(-)) ///
           xlabel(-0.25 " " 0 "Low" 1 "High" 1.25 " " , noticks labsize(large)) ///
           ytitle("") xtitle("")
    graph export "$fig_dir/03_human_activities/bar_att_by_building_intensity.jpg", replace
    graph export "$fig_dir/03_human_activities/bar_att_by_building_intensity.pdf", replace
restore


* --- 6f. Bar chart: mean ATT by above/below median road length
quietly su l_road_length, detail
local p50_road = r(p50)
gen high_road = (l_road_length > `p50_road') if !mi(l_road_length)

preserve
    collapse (mean) sdid_att twfe_att (semean) se_sdid = sdid_att, by(high_road)
    gen ci_lo = sdid_att - 1.96 * se_sdid
    gen ci_hi = sdid_att + 1.96 * se_sdid
    gen xpos  = high_road

    twoway (rcap ci_lo ci_hi xpos, lc(gs8)) ///
           (scatter sdid_att xpos, mc(navy) ms(d) msize(large)), ///
           legend(off) ///
           yline(0, lc(red) lp(-)) ///
           xlabel(-0.25 " " 0 "Low" 1 "High" 1.25 " ", noticks labsize(large)) ///
           ytitle("") xtitle("")
    graph export "$fig_dir/03_human_activities/bar_att_by_road_intensity.jpg", replace
    graph export "$fig_dir/03_human_activities/bar_att_by_road_intensity.pdf", replace
restore


*/

* --- 6e+6f. Bar chart: mean ATT by building and road intensity (combined)
quietly su l_building_area, detail
local p50_bld = r(p50)
gen high_building = (l_building_area > `p50_bld') if !mi(l_building_area)

quietly su l_road_length, detail
local p50_road = r(p50)
gen high_road = (l_road_length > `p50_road') if !mi(l_road_length)

* Building panel
preserve
    collapse (mean) sdid_att (semean) se_sdid = sdid_att, by(high_building)
    drop if mi(high_building)
    gen ci_lo = sdid_att - 1.96 * se_sdid
    gen ci_hi = sdid_att + 1.96 * se_sdid
    gen xpos  = high_building

    twoway (rcap ci_lo ci_hi xpos, lc(gs8)) ///
           (scatter sdid_att xpos, mc(navy) ms(d) msize(large)), ///
           legend(off) yline(0, lc(red) lp(-)) ///
           xlabel(-0.25 " " 0 "Low" 1 "High" 1.25 " ", noticks labsize(large)) ///
           ytitle("Reforestation Effectiveness") xtitle("Building intensity") ///
           name(g_building, replace)
restore

* Road panel
preserve
    collapse (mean) sdid_att (semean) se_sdid = sdid_att, by(high_road)
    drop if mi(high_road)
    gen ci_lo = sdid_att - 1.96 * se_sdid
    gen ci_hi = sdid_att + 1.96 * se_sdid
    gen xpos  = high_road

    twoway (rcap ci_lo ci_hi xpos, lc(gs8)) ///
           (scatter sdid_att xpos, mc(navy) ms(d) msize(large)), ///
           legend(off) yline(0, lc(red) lp(-)) ///
           xlabel(-0.25 " " 0 "Low" 1 "High" 1.25 " ", noticks labsize(large)) ///
           ytitle("") xtitle("Road density") ///
           name(g_road, replace)
restore

* Combine
graph combine g_building g_road, cols(2) ycommon
graph export "$fig_dir/03_human_activities/bar_att_building_road_combined.jpg", replace
graph export "$fig_dir/03_human_activities/bar_att_building_road_combined.pdf", replace
