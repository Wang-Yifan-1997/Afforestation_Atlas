if c(username) == "wyf19" {
    global dropdir "C:/Users/wyf19/Dropbox"
}
else if c(username) == "wangy390" | c(username) == "WANGY390" {
    global dropdir "C:/Users/wangy390/Dropbox"
}

s
* method 0
import delimited "$dropdir/Afforestation_Transition/Data/Processed Data/Control_Polygons/control_ndvi_timeseries.csv", clear
destring mean_ndvi median_ndvi sd_ndvi planting_date_reported years_since_treatment, replace force
gen treat = 0

tempfile control_ndvi
save "`control_ndvi'"

import delimited "$dropdir/Afforestation_Transition/Data/Processed Data/Treated_Polygons/treated_ndvi_timeseries.csv", clear
destring mean_ndvi median_ndvi sd_ndvi, replace force
drop min_ndvi max_ndvi p25_ndvi p75_ndvi n_pixels
rename polygon_id treated_polygon_id 
gen control_id = 0
gen treat = 1

append using "`control_ndvi'"

keep treated_polygon_id planting_date_reported year mean_ndvi years_since_treatment control_id period treat

gen treat_absorbing = (treat == 1 & years_since_treatment >= 0)

gen ATT = .
gen ATT_se = .
gen id = .

forvalues i = 1/2512 {
    quietly reghdfe mean_ndvi treat_absorbing if treated_polygon_id == `i', ///
        absorb(control_id year) vce(cluster control_id)
    
	quietly replace id = `i' if _n == `i'
    quietly replace ATT = _b[treat_absorbing] if _n == `i'
    quietly replace ATT_se = _se[treat_absorbing] if _n == `i'
    
    if mod(`i', 100) == 0 {
        display "Processed polygon `i' of 2512"
    }
}

gen t_stat = ATT / ATT_se
gen p_value = 2 * ttail(e(df_r), abs(t_stat))


save "$dropdir/Afforestation_Transition/Data/Temp Data/Ghana_program_treatment_effect.dta", replace




import delimited "$dropdir/Afforestation_Transition/Data/Temp Data/ghana_list.csv", clear
gen id = _n
rename (st_d_cr prjct__) (site_id_created project_id_reported)
tempfile ghana_list
save "`ghana_list'"

import delimited "$dropdir/Afforestation_Transition/Data/Temp Data/ghana_data_full.csv", clear
compress
destring site_id_created, force replace
drop if mi(site_id_created)
merge 1:1 site_id_created project_id_reported using "`ghana_list'"
keep if _merge == 3
drop _merge

merge 1:1 id using "$dropdir/Afforestation_Transition/Data/Temp Data/Ghana_program_treatment_effect.dta"
keep if _merge == 3
drop _merge

replace road_presence = 1 - road_presence
replace built_area_presence = 1 - built_area_presence

hist ATT, by(road_presence)
hist ATT, by(built_area_presence)

reg ATT built_area_presence
reg ATT road_presence
reg ATT built_area_presence##road_presence

gen l_built_area_2018 = asinh(built_area_2018)
reg ATT l_built_area_2018
scatter ATT l_built_area_2018 if l_built_area_2018 > 0
twoway lpolyci ATT l_built_area_2018 if l_built_area_2018 > 0 & l_built_area_2018 < 10, legend(off)
binscatter ATT l_built_area_2018 if l_built_area_2018 > 0 & l_built_area_2018 < 10

histogram ATT, freq xline(0)
graph export "$dropdir/Afforestation_Transition/Output/Figure/hist_ATT_ghana.png", replace
histogram ATT if p_value <= 0.05, freq xline(0)
graph export "$dropdir/Afforestation_Transition/Output/Figure/hist_significant_ATT_ghana.png", replace

histogram ATT if built_area_presence == 0 & road_presence == 0, freq xline(0)
graph export "$dropdir/Afforestation_Transition/Output/Figure/hist_ATT_ghana_no_human_activity.png", replace

twoway (kdensity ATT if (built_area_presence == 0 & road_presence == 0) & ATT>-0.2 & ATT <0.2, color(navy%80)) ///
       (kdensity ATT if (built_area_presence == 1 | road_presence == 1) & ATT>-0.2 & ATT <0.2, color(maroon%80)), ///
       xtitle("") ///
       legend(label(1 "no human activity") label(2 "has human activity") pos(6) row(1))
graph export "$dropdir/Afforestation_Transition/Output/Figure/hist_ATT_ghana_comparison.png", replace

s

*===============================================================================
* 0. Define file paths based on user
*===============================================================================

if c(username) == "wyf19" {
    global dropdir "C:/Users/wyf19/Dropbox"
}
else if c(username) == "wangy390" | c(username) == "WANGY390" {
    global dropdir "C:/Users/wangy390/Dropbox"
}


* method 1
import delimited "$dropdir/Afforestation_Transition/Data/Processed Data/Control_Polygons/control_ndvi_timeseries.csv", clear
destring mean_ndvi median_ndvi sd_ndvi planting_date_reported years_since_treatment, replace force
gen treat = 0

tempfile control_ndvi
save "`control_ndvi'"

import delimited "$dropdir/Afforestation_Transition/Data/Processed Data/Treated_Polygons/treated_ndvi_timeseries.csv", clear
destring mean_ndvi median_ndvi sd_ndvi, replace force
drop min_ndvi max_ndvi p25_ndvi p75_ndvi n_pixels
rename polygon_id treated_polygon_id 
gen control_id = 0
gen treat = 1

append using "`control_ndvi'"

keep treated_polygon_id planting_date_reported year mean_ndvi years_since_treatment control_id period treat

*************** Start Analysis ****************
drop if years_since_treatment == 0

collapse (mean) mean_ndvi, ///
    by(treated_polygon_id treat period)

gen post = .
replace post = 1 if period == "post_treatment"
replace post = 0 if period == "pre_treatment"
drop if post == .
	
reshape wide mean_ndvi, ///
    i(treated_polygon_id post) ///
    j(treat)
	
gen D_ndvi = mean_ndvi1 - mean_ndvi0
drop mean_ndvi1 mean_ndvi0

drop period

reshape wide D_ndvi, ///
    i(treated_polygon_id) ///
    j(post)
	
gen DD_ndvi = D_ndvi1 - D_ndvi0
summarize DD_ndvi, d

reg DD_ndvi, cluster(treated_polygon_id)
kdensity DD_ndvi
histogram DD_ndvi



s
* use bootstrap to construct confidence interval
* dataset: one row per treated_polygon_id with att_i
set seed 12345

bootstrap r(mean), reps(1000) seed(12345): summarize DD_ndvi

* This prints bootstrap SE and percentile-based CI (you can request specific CI types too)
estat bootstrap, percentile
s
* method 1.5
import delimited "$dropdir/Afforestation_Transition/Data/Processed Data/Control_Polygons/control_ndvi_timeseries.csv", clear
destring mean_ndvi median_ndvi sd_ndvi planting_date_reported years_since_treatment, replace force
gen treat = 0

tempfile control_ndvi
save "`control_ndvi'"

import delimited "$dropdir/Afforestation_Transition/Data/Processed Data/Treated_Polygons/treated_ndvi_timeseries.csv", clear
destring mean_ndvi median_ndvi sd_ndvi, replace force
drop min_ndvi max_ndvi p25_ndvi p75_ndvi n_pixels
rename polygon_id treated_polygon_id 
gen control_id = 0
gen treat = 1

append using "`control_ndvi'"

keep treated_polygon_id planting_date_reported year mean_ndvi years_since_treatment control_id period treat

* Keep event window
keep if inrange(years_since_treatment, -24, 16)

* Collapse to treated/control means within project & k
collapse (mean) mean_ndvi, by(treated_polygon_id treat years_since_treatment)

reshape wide mean_ndvi, i(treated_polygon_id years_since_treatment) j(treat)

rename mean_ndvi1 ndvi_t
rename mean_ndvi0 ndvi_c

gen gap = ndvi_t - ndvi_c

* Base year gap (k = -1)
bys treated_polygon_id: egen gap_base = max(cond(years_since_treatment==-1, gap, .))

gen att_i_k = gap - gap_base

keep treated_polygon_id years_since_treatment att_i_k
drop if missing(att_i_k)


tempfile base
save `base', replace

set seed 12345
local reps = 1000

* Collect results
tempfile bootres
postfile bstrap int k double att using `bootres', replace

forvalues r = 1/`reps' {

    use `base', clear

    * Resample treated projects WITH replacement
    bsample, cluster(treated_polygon_id)

    * Average across projects at each k
    collapse (mean) att_i_k, by(years_since_treatment)

    * Store
    quietly {
        levelsof years_since_treatment, local(Ks)
        foreach kk of local Ks {
            su att_i_k if years_since_treatment==`kk', meanonly
            post bstrap (`kk') (r(mean))
        }
    }
}

postclose bstrap

use `bootres', clear

* 95% percentile CI
collapse ///
    (p50) att = att ///
    (p1) lo = att ///
    (p99) hi = att, ///
    by(k)

rename k years_since_treatment
sort years_since_treatment

keep if years_since_treatment >= -16
twoway ///
    (rcap lo hi years_since_treatment, lcolor(gs8)) ///
    (line att years_since_treatment, lcolor(navy) lwidth(medthick)) ///
    , ///
    yline(0, lpattern(dash)) ///
    xline(0, lpattern(dash)) ///
    xtitle("Years since treatment") ///
    ytitle("ATT on mean NDVI") ///
    title("Afforestation impact on NDVI (bootstrap CI)") ///
    legend(off)

	
* method 1.6
****************************************************
* 2-year binned event-study ATT with bootstrap CI *
****************************************************

*--------------------------------------------------*
* 1. Load control polygons
*--------------------------------------------------*
import delimited "$dropdir/Afforestation_Transition/Data/Processed Data/Control_Polygons/control_ndvi_timeseries.csv", clear
destring mean_ndvi median_ndvi sd_ndvi planting_date_reported years_since_treatment, replace force
gen treat = 0

tempfile control_ndvi
save "`control_ndvi'", replace

*--------------------------------------------------*
* 2. Load treated polygons
*--------------------------------------------------*
import delimited "$dropdir/Afforestation_Transition/Data/Processed Data/Treated_Polygons/treated_ndvi_timeseries.csv", clear
destring mean_ndvi median_ndvi sd_ndvi, replace force
drop min_ndvi max_ndvi p25_ndvi p75_ndvi n_pixels
rename polygon_id treated_polygon_id
gen control_id = 0
gen treat = 1

*--------------------------------------------------*
* 3. Combine treated and controls
*--------------------------------------------------*
append using "`control_ndvi'"

keep treated_polygon_id planting_date_reported year mean_ndvi ///
     years_since_treatment control_id period treat

*--------------------------------------------------*
* 4. Keep event window
*--------------------------------------------------*
keep if inrange(years_since_treatment, -24, 16)

*--------------------------------------------------*
* 5. Construct 2-year bins
*   (-24,-23)->-24; (-22,-21)->-22; ...; (0,1)->0
*--------------------------------------------------*
gen k2 = 2 * floor(years_since_treatment / 2)

*--------------------------------------------------*
* 6. Collapse to project × treatment × bin means
*--------------------------------------------------*
collapse (mean) mean_ndvi, ///
    by(treated_polygon_id treat k2)

*--------------------------------------------------*
* 7. Put treated and control side by side
*--------------------------------------------------*
reshape wide mean_ndvi, i(treated_polygon_id k2) j(treat)

rename mean_ndvi1 ndvi_t
rename mean_ndvi0 ndvi_c

*--------------------------------------------------*
* 8. Compute treated–control gap
*--------------------------------------------------*
gen gap = ndvi_t - ndvi_c

*--------------------------------------------------*
* 9. Normalize to base bin (−2 to −1 → k2 = −2)
*--------------------------------------------------*
bys treated_polygon_id: egen gap_base = ///
    max(cond(k2 == -2, gap, .))

gen att_i_k2 = gap - gap_base

keep treated_polygon_id k2 att_i_k2
drop if missing(att_i_k2)

*--------------------------------------------------*
* 10. Save base dataset for bootstrap
*--------------------------------------------------*
tempfile base2
save "`base2'", replace

*--------------------------------------------------*
* 11. Bootstrap ATT(k2) by resampling projects
*--------------------------------------------------*
set seed 12345
local reps = 1000

tempfile bootres2
postfile bstrap2 int k2 double att using "`bootres2'", replace

forvalues r = 1/`reps' {

    use "`base2'", clear

    * Resample treated projects WITH replacement
    bsample, cluster(treated_polygon_id)

    * Average ATT within each 2-year bin
    collapse (mean) att_i_k2, by(k2)

    quietly {
        levelsof k2, local(Ks)
        foreach kk of local Ks {
            su att_i_k2 if k2==`kk', meanonly
            post bstrap2 (`kk') (r(mean))
        }
    }
}

postclose bstrap2

*--------------------------------------------------*
* 12. Construct percentile confidence intervals
*--------------------------------------------------*
use "`bootres2'", clear

collapse ///
    (p50) att = att ///
    (p1)  lo  = att ///
    (p99) hi  = att, ///
    by(k2)

sort k2

* Optional trimming for display
keep if k2 >= -16

*--------------------------------------------------*
* 13. Plot 2-year binned event study
*--------------------------------------------------*
twoway ///
    (rcap lo hi k2, lcolor(gs8)) ///
    (line att k2, lcolor(navy) lwidth(medthick)) ///
    , ///
    yline(0, lpattern(dash)) ///
    xline(0, lpattern(dash)) ///
    xtitle("Years since treatment (2-year bins)") ///
    ytitle("ATT on mean NDVI") ///
    title("Afforestation impact on NDVI (2-year bins)") ///
    legend(off)


****************************************************
* 4-year binned event-study ATT with bootstrap CI *
****************************************************

*--------------------------------------------------*
* 1. Load control polygons
*--------------------------------------------------*
import delimited "$dropdir/Afforestation_Transition/Data/Processed Data/Control_Polygons/control_ndvi_timeseries.csv", clear
destring mean_ndvi median_ndvi sd_ndvi planting_date_reported years_since_treatment, replace force
gen treat = 0

tempfile control_ndvi
save "`control_ndvi'", replace

*--------------------------------------------------*
* 2. Load treated polygons
*--------------------------------------------------*
import delimited "$dropdir/Afforestation_Transition/Data/Processed Data/Treated_Polygons/treated_ndvi_timeseries.csv", clear
destring mean_ndvi median_ndvi sd_ndvi, replace force
drop min_ndvi max_ndvi p25_ndvi p75_ndvi n_pixels
rename polygon_id treated_polygon_id
gen control_id = 0
gen treat = 1

*--------------------------------------------------*
* 3. Combine treated and controls
*--------------------------------------------------*
append using "`control_ndvi'"

keep treated_polygon_id planting_date_reported year mean_ndvi ///
     years_since_treatment control_id period treat

*--------------------------------------------------*
* 4. Keep event window
*--------------------------------------------------*
keep if inrange(years_since_treatment, -24, 16)

*--------------------------------------------------*
* 5. Construct 4-year bins
*   (-24,-21)->-24; (-20,-17)->-20; ...; (0,3)->0
*--------------------------------------------------*
gen k4 = 4 * floor(years_since_treatment / 4)

*--------------------------------------------------*
* 6. Collapse to project × treatment × bin means
*--------------------------------------------------*
collapse (mean) mean_ndvi, ///
    by(treated_polygon_id treat k4)

*--------------------------------------------------*
* 7. Put treated and control side by side
*--------------------------------------------------*
reshape wide mean_ndvi, i(treated_polygon_id k4) j(treat)

rename mean_ndvi1 ndvi_t
rename mean_ndvi0 ndvi_c

*--------------------------------------------------*
* 8. Compute treated–control gap
*--------------------------------------------------*
gen gap = ndvi_t - ndvi_c

*--------------------------------------------------*
* 9. Normalize to base bin (−4 to −1 → k4 = −4)
*--------------------------------------------------*
bys treated_polygon_id: egen gap_base = ///
    max(cond(k4 == -4, gap, .))

gen att_i_k4 = gap - gap_base

keep treated_polygon_id k4 att_i_k4
drop if missing(att_i_k4)

*--------------------------------------------------*
* 10. Save base dataset for bootstrap
*--------------------------------------------------*
tempfile base4
save "`base4'", replace

*--------------------------------------------------*
* 11. Bootstrap ATT(k4) by resampling projects
*--------------------------------------------------*
set seed 12345
local reps = 1000

tempfile bootres4
postfile bstrap4 int k4 double att using "`bootres4'", replace

forvalues r = 1/`reps' {

    use "`base4'", clear

    * Resample treated projects WITH replacement
    bsample, cluster(treated_polygon_id)

    * Average ATT within each 4-year bin
    collapse (mean) att_i_k4, by(k4)

    quietly {
        levelsof k4, local(Ks)
        foreach kk of local Ks {
            su att_i_k4 if k4==`kk', meanonly
            post bstrap4 (`kk') (r(mean))
        }
    }
}

postclose bstrap4

*--------------------------------------------------*
* 12. Construct percentile confidence intervals
*--------------------------------------------------*
use "`bootres4'", clear

collapse ///
    (p50) att = att ///
    (p1)  lo  = att ///
    (p99) hi  = att, ///
    by(k4)

sort k4

* Optional trimming for display
keep if k4 >= -16

*--------------------------------------------------*
* 13. Plot 4-year binned event study
*--------------------------------------------------*
twoway ///
    (rcap lo hi k4, lcolor(gs8)) ///
    (line att k4, lcolor(navy) lwidth(medthick)) ///
    , ///
    yline(0, lpattern(dash)) ///
    xline(0, lpattern(dash)) ///
    xtitle("Years since treatment (4-year bins)") ///
    ytitle("ATT on mean NDVI") ///
    title("Afforestation impact on NDVI (4-year bins)") ///
    legend(off)

graph export "$dropdir/Afforestation_Transition/Output/Figure/event_study_4year_bins.png", replace width(2000)
	

	
	
****************************************************
* 5-year binned event-study ATT with bootstrap CI *
****************************************************

*--------------------------------------------------*
* 1. Load control polygons
*--------------------------------------------------*
import delimited "$dropdir/Afforestation_Transition/Data/Processed Data/Control_Polygons/control_ndvi_timeseries.csv", clear
destring mean_ndvi median_ndvi sd_ndvi planting_date_reported years_since_treatment, replace force
gen treat = 0

tempfile control_ndvi
save "`control_ndvi'", replace

*--------------------------------------------------*
* 2. Load treated polygons
*--------------------------------------------------*
import delimited "$dropdir/Afforestation_Transition/Data/Processed Data/Treated_Polygons/treated_ndvi_timeseries.csv", clear
destring mean_ndvi median_ndvi sd_ndvi, replace force
drop min_ndvi max_ndvi p25_ndvi p75_ndvi n_pixels
rename polygon_id treated_polygon_id
gen control_id = 0
gen treat = 1

*--------------------------------------------------*
* 3. Combine treated and controls
*--------------------------------------------------*
append using "`control_ndvi'"

keep treated_polygon_id planting_date_reported year mean_ndvi ///
     years_since_treatment control_id period treat

*--------------------------------------------------*
* 4. Keep event window (-20 to 15)
*--------------------------------------------------*
keep if inrange(years_since_treatment, -20, 15)

*--------------------------------------------------*
* 5. Construct 5-year bins
*   (-20,-16)->-20; (-15,-11)->-15; (-10,-6)->-10; 
*   (-5,-1)->-5; (0,4)->0; (5,9)->5; (10,14)->10; (15)->15
*--------------------------------------------------*
gen k5 = 5 * floor(years_since_treatment / 5)

*--------------------------------------------------*
* 6. Collapse to project × treatment × bin means
*--------------------------------------------------*
collapse (mean) mean_ndvi, ///
    by(treated_polygon_id treat k5)

*--------------------------------------------------*
* 7. Put treated and control side by side
*--------------------------------------------------*
reshape wide mean_ndvi, i(treated_polygon_id k5) j(treat)

rename mean_ndvi1 ndvi_t
rename mean_ndvi0 ndvi_c

*--------------------------------------------------*
* 8. Compute treated–control gap
*--------------------------------------------------*
gen gap = ndvi_t - ndvi_c

*--------------------------------------------------*
* 9. Normalize to base bin (−5 to −1 → k5 = −5)
*--------------------------------------------------*
bys treated_polygon_id: egen gap_base = ///
    max(cond(k5 == -5, gap, .))

gen att_i_k5 = gap - gap_base

keep treated_polygon_id k5 att_i_k5
drop if missing(att_i_k5)

*--------------------------------------------------*
* 10. Save base dataset for bootstrap
*--------------------------------------------------*
tempfile base5
save "`base5'", replace

*--------------------------------------------------*
* 11. Bootstrap ATT(k5) by resampling projects
*--------------------------------------------------*
set seed 12345
local reps = 1000

tempfile bootres5
postfile bstrap5 int k5 double att using "`bootres5'", replace

forvalues r = 1/`reps' {

    use "`base5'", clear

    * Resample treated projects WITH replacement
    bsample, cluster(treated_polygon_id)

    * Average ATT within each 5-year bin
    collapse (mean) att_i_k5, by(k5)

    quietly {
        levelsof k5, local(Ks)
        foreach kk of local Ks {
            su att_i_k5 if k5==`kk', meanonly
            post bstrap5 (`kk') (r(mean))
        }
    }
}

postclose bstrap5

*--------------------------------------------------*
* 12. Construct percentile confidence intervals
*--------------------------------------------------*
use "`bootres5'", clear

collapse ///
    (p50) att = att ///
    (p1)  lo  = att ///
    (p99) hi  = att, ///
    by(k5)

sort k5

*--------------------------------------------------*
* 13. Plot 5-year binned event study
*--------------------------------------------------*
twoway ///
    (rcap lo hi k5, lcolor(navy%50) lwidth(medthick)) ///
    (scatter att k5, mcolor(navy) msize(medium)) ///
    (line att k5, lcolor(navy) lwidth(medthick) lpattern(solid)) ///
    , ///
    yline(0, lpattern(dash) lcolor(red)) ///
    xline(-2.5, lpattern(dash) lcolor(gs10)) ///
    xlabel(-20(5)15) ///
    xtitle("Years since treatment (5-year bins)", size(medium)) ///
    ytitle("ATT on mean NDVI", size(medium)) ///
    title("Afforestation Impact on NDVI", size(large)) ///
    subtitle("5-year binned event study with 95% bootstrap CI") ///
    legend(off) ///
    graphregion(color(white)) bgcolor(white)

*graph export "$dropdir/Afforestation_Transition/Output/Figures/event_study_5year_bins.png", replace width(2000)


*method 2

import delimited "$dropdir/Afforestation_Transition/Data/Processed Data/Control_Polygons/control_ndvi_timeseries.csv", clear
destring mean_ndvi median_ndvi sd_ndvi planting_date_reported years_since_treatment, replace force
gen treat = 0

tempfile control_ndvi
save "`control_ndvi'"

import delimited "$dropdir/Afforestation_Transition/Data/Processed Data/Treated_Polygons/treated_ndvi_timeseries.csv", clear
destring mean_ndvi median_ndvi sd_ndvi, replace force
drop min_ndvi max_ndvi p25_ndvi p75_ndvi n_pixels
rename polygon_id treated_polygon_id 
gen control_id = 0
gen treat = 1

append using "`control_ndvi'"

keep treated_polygon_id planting_date_reported year mean_ndvi years_since_treatment control_id period treat
gen l_mean_ndvi = log(mean_ndvi)

egen unit_id = group(treated_polygon_id treat control_id), label

*drop if years_since_treatment == 0

tab years_since_treatment
replace years_since_treatment = . if treat == 0
forvalues k = 24(-1)2 {
    gen evt_`k' = (years_since_treatment == -`k')
}
forvalues k = 0(1)16 {
    gen evt`k' = (years_since_treatment == `k')
}

gen post = (years_since_treatment >= 0)
gen post_treat = (post == 1 ^ treat == 1)
reghdfe mean_ndvi post_treat, absorb(unit_id year) ///
      cluster(treated_polygon_id)
	  
reghdfe mean_ndvi ///
      evt_* evt0-evt16, absorb(unit_id year) ///
      cluster(treated_polygon_id)
	  
coefplot , ///
    keep(evt*) ///
    vertical ///
    yline(0, lpattern(dash)) ///
    xline(24.5, lpattern(dash)) ///
    xlabel(1 "-24" 3 "-22" 5 "-20" 7 "-18" 9 "-16" ///
           11 "-14" 13 "-12" 15 "-10" 17 "-8" ///
           19 "-6" 21 "-4" 23 "-2" 25 "0" ///
           27 "2" 29 "4" 31 "6" 33 "8" ///
           35 "10" 37 "12" 39 "14" 41 "16") ///
    xtitle("Years since treatment") ///
    ytitle("Effect on mean NDVI")


* Staggered DID Method	
gen treat_year = planting_date_reported if treat == 1
tab planting_date_reported
*drop if planting_date_reported == 2024
bysort unit_id: egen first_treat = min(treat_year)
drop treat_year
gen never_treat = (treat == 0)

eventstudyinteract mean_ndvi evt_* evt0-evt16, ///
	cohort(first_treat) control_cohort(never_treat) absorb(unit_id year) vce(cluster unit_id)

* Create event study plot
coefplot matrix(C[1]), se(C[2]) ///
    vertical ///
    yline(0, lcolor(red) lpattern(dash)) ///
    xline(17, lcolor(black) lpattern(dash)) ///
    ytitle("Effect on NDVI") ///
    xtitle("Periods relative to treatment") ///
    title("Event Study: Afforestation Impact on NDVI") ///
    ciopts(recast(rcap) lcolor(navy)) ///
    mcolor(navy) ///
    graphregion(color(white)) bgcolor(white) ///
    xlabel(, angle(45))
	
