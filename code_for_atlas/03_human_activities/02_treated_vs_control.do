********************************************************************************
* 02_treated_vs_control.do
* ATLAS Afforestation - Do afforestation sites have more human activity?
*
* Research question:
*   At a single point in time, do treated afforestation polygons have more
*   buildings and roads than their matched control polygons?
*
* Data: cross-sectional snapshot -- one observation per polygon.
*   Treated polygons: inside afforestation project boundaries
*   Control polygons: ~100 matched controls per treated polygon
*
* What this can and cannot show:
*   CAN show: whether treated polygons currently have more/less human activity
*             than their matched controls at the same point in time
*   CANNOT show: whether afforestation CAUSED the difference (no pre-data)
*   CANNOT show: whether human activity existed before the project started
*
* The matching assumption: control polygons are similar to treated polygons
* in terms of geography, land cover, and accessibility -- so any difference
* in human activity reflects the project's presence, not pre-existing differences.
*
* Method:
*   1. Raw comparison: treated vs control means (t-test, tabstat)
*   2. Within-project regression: activity ~ treated, absorb(proj_id)
*      Controls for project-level geography and context
*
* Data coverage: Ethiopia only.
*
* Input files:
*   building/combined_polygon_building_stats.csv
*   road/combined_polygon_road_stats.csv
********************************************************************************

local user = c(username)

if "`user'" == "wyf19"    global dropdir "C:/Users/wyf19/Dropbox"
if "`user'" == "wangy390"  global dropdir "D:/Dropbox"
if "`user'" == "WANGY390"  global dropdir "C:/Users/WANGY390/Dropbox"

global fig_dir  "$dropdir/Afforestation_Transition/Output/Figure/atlas"
global ctrl_dir "$dropdir/Afforestation_Transition/RA/xinyi wang/tasks/Building & Road/Control/ethiopia test data (+control)"

cap mkdir "$fig_dir/03_human_activities"

********************************************************************************
* STEP 1: Load building data
********************************************************************************

import delimited "$ctrl_dir/building/combined_polygon_building_stats.csv", ///
    varnames(1) encoding(utf8) clear

rename plant_yr plant_yr_bld
tempfile bld
save "`bld'"

********************************************************************************
* STEP 2: Load road data
********************************************************************************

import delimited "$ctrl_dir/road/combined_polygon_road_stats.csv", ///
    varnames(1) encoding(utf8) clear

foreach v in bridleway footway living_street motorway motorway_link path       ///
             pedestrian primary primary_link residential secondary              ///
             secondary_link service steps tertiary tertiary_link track          ///
             track_grade1 track_grade2 track_grade3 track_grade4 track_grade5  ///
             trunk trunk_link unclassified unknown {
    capture replace `v' = 0 if mi(`v')
}

gen total_road_length_m = bridleway + footway + living_street + motorway +     ///
    motorway_link + path + pedestrian + primary + primary_link + residential +  ///
    secondary + secondary_link + service + steps + tertiary + tertiary_link +   ///
    track + track_grade1 + track_grade2 + track_grade3 + track_grade4 +        ///
    track_grade5 + trunk + trunk_link + unclassified + unknown

keep poly_id group plant_year country proj_id total_roads total_road_length_m
rename plant_year plant_yr_road

tempfile road
save "`road'"

********************************************************************************
* STEP 3: Merge and create outcome variables
********************************************************************************

use "`bld'", clear
merge 1:1 poly_id proj_id using "`road'", keep(1 3) nogen

* Treatment indicator
gen treated = (group == "treated")

* Binary activity indicators
gen has_building = (total_buildings > 0)
gen has_road     = (total_road_length_m > 0) if !mi(total_road_length_m)
replace has_road = 0 if mi(has_road) & !mi(total_buildings)
gen has_human    = (has_building == 1 | has_road == 1)

* Continuous (IHS handles zeros)
gen l_building_area = asinh(total_area_sqm)
gen l_building_n    = asinh(total_buildings)
gen l_road_length   = asinh(total_road_length_m)

* Project numeric ID
encode proj_id, gen(proj_id_enc)

* Plant year
gen plant_yr = plant_yr_bld
replace plant_yr = plant_yr_road if mi(plant_yr) & !mi(plant_yr_road)
gen plant_yr_int = round(plant_yr)

********************************************************************************
* STEP 4: Raw comparison -- treated vs control
*
* Interpretation: does the average treated polygon have more or fewer
* buildings/roads than the average control polygon?
* Note: this is unconditional and may reflect pre-existing differences.
********************************************************************************

display " "
display "========================================================"
display "  STEP 4: Raw comparison -- treated vs control"
display "========================================================"

display "--- Buildings ---"
tabstat total_buildings total_area_sqm has_building, ///
    by(treated) stat(n mean sd p50) longstub

ttest total_buildings, by(treated)
ttest total_area_sqm,  by(treated)
ttest has_building,    by(treated)

display "--- Roads ---"
tabstat total_road_length_m has_road, ///
    by(treated) stat(n mean sd p50) longstub

ttest total_road_length_m, by(treated)
ttest has_road,            by(treated)

display "--- Human activity (any) ---"
tabstat has_human, by(treated) stat(n mean sd) longstub
ttest has_human, by(treated)

********************************************************************************
* STEP 5: Within-project regression
*
* Interpretation: within the same project, treated polygons have beta more
* buildings/roads than their matched controls. This is the cleanest comparison
* because it controls for project-level geography and context.
* Positive beta = treated polygons have MORE human activity than controls.
* Negative beta = treated polygons have LESS human activity than controls.
*
* Caveat: we still cannot say afforestation CAUSED this -- the difference
* could reflect pre-existing differences not captured by the matching.
********************************************************************************

display " "
display "========================================================"
display "  STEP 5: Within-project regression (project FE)"
display "========================================================"

display "--- Buildings ---"
reghdfe total_buildings  treated, absorb(proj_id_enc) vce(cluster proj_id_enc)
reghdfe total_area_sqm   treated, absorb(proj_id_enc) vce(cluster proj_id_enc)
reghdfe l_building_area  treated, absorb(proj_id_enc) vce(cluster proj_id_enc)
reghdfe has_building     treated, absorb(proj_id_enc) vce(cluster proj_id_enc)

display "--- Roads ---"
reghdfe total_road_length_m treated, absorb(proj_id_enc) vce(cluster proj_id_enc)
reghdfe l_road_length       treated, absorb(proj_id_enc) vce(cluster proj_id_enc)
reghdfe has_road            treated, absorb(proj_id_enc) vce(cluster proj_id_enc)

display "--- Any human activity ---"
reghdfe has_human treated, absorb(proj_id_enc) vce(cluster proj_id_enc)

********************************************************************************
* STEP 6: Visualizations
********************************************************************************

* --- 6a. Kernel density: building area by group
twoway (kdensity l_building_area if treated == 0 & l_building_area < 15, ///
            color(navy%70))                                               ///
       (kdensity l_building_area if treated == 1 & l_building_area < 15, ///
            color(maroon%70)),                                            ///
    xtitle("Building footprint (IHS sq m)") ytitle("Density")            ///
    legend(label(1 "Control") label(2 "Treated") pos(1) ring(0) col(1))  ///
    title("Building intensity: treated vs control (Ethiopia)")            ///
    note("Snapshot comparison -- cannot infer causality without pre-treatment data.")
graph export "$fig_dir/03_human_activities/kdensity_building_treat_ctrl.jpg", replace
graph export "$fig_dir/03_human_activities/kdensity_building_treat_ctrl.pdf", replace

* --- 6b. Kernel density: road length by group
twoway (kdensity l_road_length if treated == 0 & total_road_length_m > 0, ///
            color(navy%70))                                                ///
       (kdensity l_road_length if treated == 1 & total_road_length_m > 0, ///
            color(maroon%70)),                                             ///
    xtitle("Road length (IHS metres)") ytitle("Density")                  ///
    legend(label(1 "Control") label(2 "Treated") pos(1) ring(0) col(1))   ///
    title("Road density: treated vs control (Ethiopia)")                   ///
    note("Restricted to polygons with any roads.")
graph export "$fig_dir/03_human_activities/kdensity_road_treat_ctrl.jpg", replace
graph export "$fig_dir/03_human_activities/kdensity_road_treat_ctrl.pdf", replace

* --- 6c. Bar chart: share with buildings/roads by group
preserve
    collapse (mean) has_building has_road has_human, by(treated)
    gen group_label = "Control"
    replace group_label = "Treated" if treated == 1

    graph bar has_building has_road has_human, over(group_label) ///
        bargap(30) ///
        legend(label(1 "Has buildings") label(2 "Has roads") ///
               label(3 "Has buildings or roads") pos(6) row(1)) ///
        ytitle("Share of polygons") ///
        title("Human activity presence: treated vs control") ///
        note("Snapshot comparison at a single point in time.")
    graph export "$fig_dir/03_human_activities/bar_activity_presence.jpg", replace
    graph export "$fig_dir/03_human_activities/bar_activity_presence.pdf", replace
restore

* --- 6d. By-project scatter: treated vs control mean
preserve
    gen l_buildings   = asinh(total_buildings)

    collapse (mean) l_buildings l_road_length has_human ///
             (count) n = total_buildings, by(proj_id treated)

    reshape wide l_buildings l_road_length has_human n, ///
        i(proj_id) j(treated)

    quietly su l_buildings0, meanonly
    local xmax_bld = r(max)
    quietly su l_road_length0, meanonly
    local xmax_road = r(max)

    twoway (scatter l_buildings1 l_buildings0, mc(blue%60) ms(o)) ///
           (function y = x, range(0 `xmax_bld') lc(red) lp(-)),  ///
        legend(label(1 "Project") label(2 "45 degree line") pos(4) ring(0)) ///
        xtitle("Control: asinh(avg buildings)") ///
        ytitle("Treated: asinh(avg buildings)") ///
        title("Buildings: treated vs control (by project)") ///
        note("Points above the line: treated has more buildings than controls.")
    graph export "$fig_dir/03_human_activities/scatter_building_treat_ctrl_byproject.jpg", replace
    graph export "$fig_dir/03_human_activities/scatter_building_treat_ctrl_byproject.pdf", replace

    twoway (scatter l_road_length1 l_road_length0, mc(blue%60) ms(o)) ///
           (function y = x, range(0 `xmax_road') lc(red) lp(-)),     ///
        legend(label(1 "Project") label(2 "45 degree line") pos(4) ring(0)) ///
        xtitle("Control: asinh(avg road length)") ///
        ytitle("Treated: asinh(avg road length)") ///
        title("Roads: treated vs control (by project)") ///
        note("Points above the line: treated has more roads than controls.")
    graph export "$fig_dir/03_human_activities/scatter_road_treat_ctrl_byproject.jpg", replace
    graph export "$fig_dir/03_human_activities/scatter_road_treat_ctrl_byproject.pdf", replace
restore

display " "
display "Done: 02_treated_vs_control.do"
display "Output: $fig_dir/03_human_activities/"
