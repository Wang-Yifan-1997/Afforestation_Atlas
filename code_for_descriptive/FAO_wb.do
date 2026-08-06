/********************************************************************************************
*   PROJECT: Afforestation_Transition
*   PURPOSE: Merge World Bank GDP data (agriculture, manufacturing, services) with
*            Global Forest Resources Assessment (FRA) data and run descriptive regressions
*   AUTHOR:  Yifan Wang
*   UPDATED: 2025-10-21
********************************************************************************************/

*===============================================================================
* 0. Define file paths based on user
*===============================================================================

if c(username) == "wyf19" {
    global dropdir "C:/Users/wyf19/Dropbox"
}
else if c(username) == "wangy390" | c(username) == "WANGY390" {
    global dropdir "C:/Users/wangy390/Dropbox"
}

* Check the base directory exists
di "Using Dropbox directory: ${dropdir}"
confirm file "${dropdir}/Afforestation_Transition/Data/Raw Data/World Bank Data/world_bank_agr.xlsx"

*===============================================================================
* 1. Load and clean World Bank data (Agriculture / Manufacturing / Services)
*===============================================================================

*---------- AGRICULTURE ----------
import excel "${dropdir}/Afforestation_Transition/Data/Raw Data/World Bank Data/world_bank_agr.xlsx", ///
    sheet("Data") firstrow clear

drop if CountryCode == ""
reshape long YR, i(CountryName CountryCode SeriesName) j(year)
drop SeriesCode
destring YR, replace force
rename (YR CountryName) (gdp_ CountryName_wb)

* Rename variable categories
replace SeriesName = "a_pct"    if SeriesName == "Agriculture, forestry, and fishing, value added (% of GDP)"
replace SeriesName = "a_growth" if SeriesName == "Agriculture, forestry, and fishing, value added (annual % growth)"
replace SeriesName = "a_value"  if SeriesName == "Agriculture, forestry, and fishing, value added (constant 2015 US$)"
replace SeriesName = "a_per_worker"  if SeriesName == "Agriculture, forestry, and fishing, value added per worker (constant 2015 US$)"

keep if inlist(SeriesName, "a_pct", "a_growth", "a_value", "a_per_worker")
reshape wide gdp, i(CountryCode year) j(SeriesName) string

* Keep key benchmark years and relabel 2024 as 2025
keep if inlist(year, 1990, 2000, 2010, 2015, 2020, 2024)
replace year = 2025 if year == 2024 // temporarily use 2024 data to proxy 2025 data for now, since 2025 is not available

tempfile agr
save "`agr'", replace


*---------- MANUFACTURING ----------
import excel "${dropdir}/Afforestation_Transition/Data/Raw Data/World Bank Data/world_bank_manu.xlsx", ///
    sheet("Data") firstrow clear

drop if CountryCode == ""
reshape long YR, i(CountryName CountryCode SeriesName) j(year)
drop SeriesCode
destring YR, replace force
rename (YR CountryName) (gdp_ CountryName_wb)

replace SeriesName = "m_pct"    if SeriesName == "Manufacturing, value added (% of GDP)"
replace SeriesName = "m_growth" if SeriesName == "Manufacturing, value added (annual % growth)"
replace SeriesName = "m_value"  if SeriesName == "Manufacturing, value added (constant 2015 US$)"
replace SeriesName = "m_per_worker"  if SeriesName == "Manufacturing, value added per worker (constant 2015 US$)"

keep if inlist(SeriesName, "m_pct", "m_growth", "m_value", "m_per_worker")
reshape wide gdp, i(CountryCode year) j(SeriesName) string
keep if inlist(year, 1990, 2000, 2010, 2015, 2020, 2024)
replace year = 2025 if year == 2024 // temporarily use 2024 data to proxy 2025 data for now, since 2025 is not available

tempfile manu
save "`manu'", replace


*---------- SERVICES ----------
import excel "${dropdir}/Afforestation_Transition/Data/Raw Data/World Bank Data/world_bank_service.xlsx", ///
    sheet("Data") firstrow clear

drop if CountryCode == ""
reshape long YR, i(CountryName CountryCode SeriesName) j(year)
drop SeriesCode
destring YR, replace force
rename (YR CountryName) (gdp_ CountryName_wb)

replace SeriesName = "s_pct"    if SeriesName == "Services, value added (% of GDP)"
replace SeriesName = "s_growth" if SeriesName == "Services, value added (annual % growth)"
replace SeriesName = "s_value"  if SeriesName == "Services, value added (constant 2015 US$)"
replace SeriesName = "s_per_worker"  if SeriesName == "Services, value added per worker (constant 2015 US$)"

keep if inlist(SeriesName, "s_pct", "s_growth", "s_value", "s_per_worker")
reshape wide gdp, i(CountryCode year) j(SeriesName) string
keep if inlist(year, 1990, 2000, 2010, 2015, 2020, 2024)
replace year = 2025 if year == 2024 // temporarily use 2024 data to proxy 2025 data for now, since 2025 is not available

tempfile service
save "`service'", replace


*===============================================================================
* 2. Load and merge Global Forest Resources Assessment (FRA) data
*===============================================================================

import delimited "${dropdir}/Afforestation_Transition/Data/Raw Data/Global Forest Resources Assessment 2025/FRA_Years_2025_10_21.csv", clear
rename (iso3 regions) (CountryCode regions_forest)
drop deskstudy

* Merge World Bank datasets (1:1 CountryCode-year)
merge 1:1 CountryCode year using "`agr'", keep(1 3)
rename _merge _merge_agr

merge 1:1 CountryCode year using "`manu'", keep(1 3)
rename _merge _merge_manu

merge 1:1 CountryCode year using "`service'", keep(1 3)
rename _merge _merge_service

* Keep only complete observations
drop if _merge_agr != 3 & _merge_manu != 3 & _merge_service != 3
order regions_forest CountryCode CountryName_wb name gdp*

*===============================================================================
* 3. Prepare variables for analysis
*===============================================================================

* OECD member countries (38 members as of 2024)
gen oecd = 0
foreach cc in AUS AUT BEL CAN CHE CHL COL CRI CZE DEU DNK ESP EST FIN FRA ///
              GBR GRC HUN IRL ISL ISR ITA JPN KOR LTU LUX LVA MEX NLD NOR ///
              NZL POL PRT SVK SVN SWE TUR USA {
    replace oecd = 1 if CountryCode == "`cc'"
}
label define oecd_lbl 0 "Non-OECD" 1 "OECD"
label values oecd oecd_lbl

* Forest outcomes
gen log_forest_area       = log(a_forestarea)
//b_naturallyregeneratingforest + b_plantedforest = a_forestarea
gen log_natural_forest 	  = log(b_naturallyregeneratingforest)
gen log_plantedforest = log(b_plantedforest)
gen log_plantationforest  = log(b_plantationforest)

bys name (year): gen forest_change = a_forestarea - a_forestarea[_n-1]
bys name (year): gen natural_forest_change = b_naturallyregeneratingforest - b_naturallyregeneratingforest[_n-1]
bys name (year): gen planted_forest_change = b_plantedforest - b_plantedforest[_n-1]
bys name (year): gen plantation_forest_change = b_plantationforest - b_plantationforest[_n-1]

gen log_forest_change = asinh(forest_change)
gen log_natural_forest_change = asinh(natural_forest_change)
gen log_planted_forest_change = asinh(planted_forest_change)
gen log_plantation_forest_change = asinh(plantation_forest_change)

//*****there will be more missing values for forest stock
gen log_stock_nat_reg = log(a_gs_tot_nat_reg) //forest growing stock for naturally regenerating forest
gen log_stock_planted = log(a_gs_tot_planted) //forest growing stock for planted forest

* Convert "yes/no" indicators to dummy variables
foreach var in policies_national policies_sub_national legislation_national ///
               legislation_sub_national platform_national platform_sub_national {
    gen D_`var' = cond(a_`var' == "yes", 1, cond(a_`var' == "no", 0, .))
}

* GDP logs and shares
foreach sec in a m s {
	gen log_gdp_`sec'_value = log(gdp_`sec'_value)
    gen log_gdp_`sec'_pct = log(gdp_`sec'_pct)
	cap gen log_gdp_`sec'_p_worker = log(gdp_`sec'_per_worker)
}

bys name (year): gen forest_change_rate = (a_forestarea - a_forestarea[_n-1]) / a_forestarea
gen afforestation_rate = b_plantedforest / a_forestarea

egen gdp_total = rowtotal(gdp_a_value gdp_m_value gdp_s_value)
egen gdp_total_a_s = rowtotal(gdp_a_value gdp_s_value)
gen gdp_total_per_worker_a_s = gdp_a_value / gdp_total_a_s * gdp_a_per_worker + gdp_s_value / gdp_total_a_s * gdp_s_per_worker
gen log_gdp_total_per_worker_a_s = log(gdp_total_per_worker_a_s)


*===============================================================================
* 3b. Growth rates
*===============================================================================

* Sector GDP growth rates (log difference between periods)
bys CountryCode (year): gen g_gdp_a = log(gdp_a_value) - log(gdp_a_value[_n-1])
bys CountryCode (year): gen g_gdp_m = log(gdp_m_value) - log(gdp_m_value[_n-1])
bys CountryCode (year): gen g_gdp_s = log(gdp_s_value) - log(gdp_s_value[_n-1])
bys CountryCode (year): gen g_gdp_total = log(gdp_total) - log(gdp_total[_n-1])

* Forest growth rates
bys CountryCode (year): gen g_forest       = log(a_forestarea)                    - log(a_forestarea[_n-1])
bys CountryCode (year): gen g_natural      = log(b_naturallyregeneratingforest)   - log(b_naturallyregeneratingforest[_n-1])
bys CountryCode (year): gen g_planted      = log(b_plantedforest)                 - log(b_plantedforest[_n-1])
bys CountryCode (year): gen g_plantation   = log(b_plantationforest)              - log(b_plantationforest[_n-1])

label var g_gdp_a       "Agriculture GDP growth (log diff)"
label var g_gdp_m       "Manufacturing GDP growth (log diff)"
label var g_gdp_s       "Services GDP growth (log diff)"
label var g_gdp_total   "Total GDP growth (log diff)"
label var g_forest      "Total forest area growth (log diff)"
label var g_natural     "Natural forest growth (log diff)"
label var g_planted     "Planted forest growth (log diff)"
label var g_plantation  "Plantation forest growth (log diff)"


*===============================================================================
* 4. Descriptive
*===============================================================================

gen log_gdp_total = log(gdp_total)
gen s_a_ratio = gdp_s_value / gdp_a_value
gen log_s_a_ratio = log(gdp_s_value) - log(gdp_a_value)
gen m_a_ratio = gdp_m_value / gdp_a_value
gen log_m_a_ratio = log(gdp_m_value) - log(gdp_a_value)
gen s_m_ratio = gdp_s_value / gdp_m_value
gen log_s_m_ratio = log(gdp_s_value) - log(gdp_m_value)



reg log_natural_forest_change log_gdp_total_per_worker_a_s
*log_natural_forest_change
*log_planted_forest_change
*log_plantation_forest_change

binscatter log_plantation_forest_change log_gdp_total_per_worker_a_s, ///
    nquantiles(50) line(qfit) ///
    legend(off) ///
    ytitle("Log Change of Forest Areas") ///
    xtitle("Log GDP per worker (from Agriculture and Service)") ///
	yline(0, lcolor(grey) lpattern(dash))

reg log_forest_change log_gdp_total_per_worker_a_s
binscatter log_forest_change log_gdp_total_per_worker_a_s, ///
    nquantiles(50) line(qfit) ///
    legend(off) ///
    ytitle("Log Change of Forest Areas") ///
    xtitle("Log GDP per worker (from Agriculture and Service)") ///
	yline(0, lcolor(grey) lpattern(dash)) ///
    yscale(range(-7 4)) ///
    ylabel(-6(2)4)
	
	
reg log_forest_change log_gdp_total_per_worker_a_s
reg log_forest_change log_gdp_a_p_worker
reg log_forest_change log_gdp_s_p_worker
br if !mi(log_gdp_s_p_worker)


twoway lpolyci forest_change_rate log_s_a_ratio if forest_change_rate!=0, legend(off)
twoway lpolyci forest_change_rate log_s_m_ratio if forest_change_rate!=0, legend(off)

twoway lpolyci afforestation_rate log_s_a_ratio, legend(off)
twoway lpolyci afforestation_rate log_s_m_ratio, legend(off)

binscatter forest_change_rate log_s_a_ratio if forest_change_rate!=0
binscatter forest_change_rate log_s_m_ratio if forest_change_rate!=0

binscatter afforestation_rate log_s_a_ratio
binscatter afforestation_rate log_s_m_ratio

twoway lpolyci log_forest_change gdp_a_pct if forest_change_rate!=0 & gdp_a_pct > 0.1 & gdp_a_pct < 44, legend(off) k(gaus) ytitle("Log Change of Forest Areas") xtitle("Share of Agriculture Industry")
twoway lpolyci log_forest_change gdp_m_pct if forest_change_rate!=0 & gdp_m_pct > 0.6 & gdp_m_pct < 35, legend(off) k(gaus) ytitle("Log Change of Forest Areas") xtitle("Share of Manufacturing Industry")
twoway lpolyci log_forest_change gdp_s_pct if forest_change_rate!=0 & gdp_s_pct > 24 & gdp_s_pct < 87, legend(off) k(gaus) ytitle("Log Change of Forest Areas") xtitle("Share of Service Industry")

*—————————————————————————lpolyci——————————————————————————*
* --- Agriculture ---
twoway lpolyci log_forest_change gdp_a_pct ///
    if forest_change_rate!=0 & gdp_a_pct > 0.5 & gdp_a_pct < 33, ///
    k(gaus) legend(off) ///
    ytitle("Log Change of Forest Areas") ///
    xtitle("Agriculture Share")
graph save g1.gph, replace

* --- Manufacturing ---
twoway lpolyci log_forest_change gdp_m_pct ///
    if forest_change_rate!=0 & gdp_m_pct > 2.5 & gdp_m_pct < 24, ///
    k(gaus) legend(off) ///
    ytitle("") ///
    xtitle("Manufacturing Share")
graph save g2.gph, replace

* --- Services ---
twoway lpolyci log_forest_change gdp_s_pct ///
    if forest_change_rate!=0 & gdp_s_pct > 33 & gdp_s_pct < 75, ///
    k(gaus) legend(off) ///
    ytitle("") ///
    xtitle("Service Share")
graph save g3.gph, replace

* --- Combine subgraphs ---
graph combine g1.gph g2.gph g3.gph, col(3)


*—————————————————————————binscatter——————————————————————————*
binscatter log_forest_change gdp_a_pct ///
    if forest_change_rate!=0 & gdp_a_pct > 0.5 & gdp_a_pct < 33, ///
    nquantiles(100) line(qfit) ///
    legend(off) ///
    ytitle("Log Change of Forest Areas") ///
    xtitle("Agriculture Share") ///
	yline(0, lcolor(grey) lpattern(dash)) ///
    yscale(range(-7 6)) ///
    ylabel(-6(2)6)

graph save "${dropdir}/Afforestation_Transition/Output/Figure/temp/g1.gph", replace

binscatter log_forest_change gdp_m_pct ///
    if forest_change_rate!=0 & gdp_m_pct > 2.5 & gdp_m_pct < 24, ///
    nquantiles(100) line(qfit) ///
    legend(off) ///
    ytitle("") ///
    xtitle("Manufacturing Share") ///
	yline(0, lcolor(grey) lpattern(dash)) ///
    yscale(range(-7 6)) ///
    ylabel(-6(2)6)

graph save "${dropdir}/Afforestation_Transition/Output/Figure/temp/g2.gph", replace

binscatter log_forest_change gdp_s_pct ///
    if forest_change_rate!=0 & gdp_s_pct > 33 & gdp_s_pct < 75, ///
    nquantiles(100) line(qfit) ///
    legend(off) ///
    ytitle("") ///
    xtitle("Service Share") ///
	yline(0, lcolor(grey) lpattern(dash)) ///
    yscale(range(-7 6)) ///
    ylabel(-6(2)6)

graph save "${dropdir}/Afforestation_Transition/Output/Figure/temp/g3.gph", replace

graph combine "${dropdir}/Afforestation_Transition/Output/Figure/temp/g1.gph" "${dropdir}/Afforestation_Transition/Output/Figure/temp/g2.gph" "${dropdir}/Afforestation_Transition/Output/Figure/temp/g3.gph", col(3)

graph export "${dropdir}/Afforestation_Transition/Output/Figure/forest_gdp_share_sector.pdf", replace
graph export "${dropdir}/Afforestation_Transition/Output/Figure/forest_gdp_share_sector.png", replace


*—————————————————————————growth rates: forest vs sector GDP——————————————————*

* Total forest growth vs sector GDP growth
foreach sec in a m s {
    local lbl = cond("`sec'" == "a", "Agriculture", cond("`sec'" == "m", "Manufacturing", "Services"))

    binscatter g_forest g_gdp_`sec' ///
        if !mi(g_forest) & !mi(g_gdp_`sec'), ///
        nquantiles(50) line(qfit) legend(off) ///
        ytitle("Forest area growth") ///
        xtitle("`lbl' GDP growth") ///
        yline(0, lcolor(grey) lpattern(dash)) ///
        xline(0, lcolor(grey) lpattern(dash))
    graph save "${dropdir}/Afforestation_Transition/Output/Figure/temp/g_`sec'.gph", replace
}

graph combine ///
    "${dropdir}/Afforestation_Transition/Output/Figure/temp/g_a.gph" ///
    "${dropdir}/Afforestation_Transition/Output/Figure/temp/g_m.gph" ///
    "${dropdir}/Afforestation_Transition/Output/Figure/temp/g_s.gph", col(3)
graph export "${dropdir}/Afforestation_Transition/Output/Figure/forest_growth_vs_sector_growth.pdf", replace
graph export "${dropdir}/Afforestation_Transition/Output/Figure/forest_growth_vs_sector_growth.png", replace

* Planted forest growth vs sector GDP growth
foreach sec in a m s {
    local lbl = cond("`sec'" == "a", "Agriculture", cond("`sec'" == "m", "Manufacturing", "Services"))

    binscatter g_planted g_gdp_`sec' ///
        if !mi(g_planted) & !mi(g_gdp_`sec'), ///
        nquantiles(50) line(qfit) legend(off) ///
        ytitle("Planted forest growth") ///
        xtitle("`lbl' GDP growth") ///
        yline(0, lcolor(grey) lpattern(dash)) ///
        xline(0, lcolor(grey) lpattern(dash))
    graph save "${dropdir}/Afforestation_Transition/Output/Figure/temp/g_`sec'.gph", replace
}

graph combine ///
    "${dropdir}/Afforestation_Transition/Output/Figure/temp/g_a.gph" ///
    "${dropdir}/Afforestation_Transition/Output/Figure/temp/g_m.gph" ///
    "${dropdir}/Afforestation_Transition/Output/Figure/temp/g_s.gph", col(3)
graph export "${dropdir}/Afforestation_Transition/Output/Figure/planted_forest_growth_vs_sector_growth.pdf", replace
graph export "${dropdir}/Afforestation_Transition/Output/Figure/planted_forest_growth_vs_sector_growth.png", replace

* Forest growth vs total GDP growth
binscatter g_forest g_gdp_total ///
    if !mi(g_forest) & !mi(g_gdp_total), ///
    nquantiles(50) line(qfit) legend(off) ///
    ytitle("Forest area growth") ///
    xtitle("Total GDP growth") ///
    yline(0, lcolor(grey) lpattern(dash)) ///
    xline(0, lcolor(grey) lpattern(dash))
graph export "${dropdir}/Afforestation_Transition/Output/Figure/forest_growth_vs_gdp_growth.pdf", replace
graph export "${dropdir}/Afforestation_Transition/Output/Figure/forest_growth_vs_gdp_growth.png", replace


* Winsorize growth rates at 1st and 99th percentile
foreach v in g_gdp_a g_gdp_m g_gdp_s g_gdp_total g_forest {
    quietly su `v', detail
    replace `v' = r(p1)  if `v' < r(p1)  & !mi(`v')
    replace `v' = r(p99) if `v' > r(p99) & !mi(`v')
}
* Example for forest growth vs sector GDP share — OECD vs non-OECD
foreach grp in 0 1 {
    local lbl = cond(`grp' == 1, "OECD", "Non-OECD")

    * --- GDP share ---
    binscatter log_forest_change gdp_a_pct ///
        if forest_change_rate != 0 & oecd == `grp', ///
        nquantiles(50) line(qfit) legend(off) ///
        ytitle("Log Change of Forest Areas") xtitle("Agriculture Share") ///
        yline(0, lcolor(grey) lpattern(dash)) ///
        yscale(range(-7 6)) ylabel(-6(2)6)
    graph save "${dropdir}/Afforestation_Transition/Output/Figure/temp/g_a.gph", replace

    binscatter log_forest_change gdp_m_pct ///
        if forest_change_rate != 0 & oecd == `grp', ///
        nquantiles(50) line(qfit) legend(off) ///
        ytitle("") xtitle("Manufacturing Share") ///
        yline(0, lcolor(grey) lpattern(dash)) ///
        yscale(range(-7 6)) ylabel(-6(2)6)
    graph save "${dropdir}/Afforestation_Transition/Output/Figure/temp/g_m.gph", replace

    binscatter log_forest_change gdp_s_pct ///
        if forest_change_rate != 0 & oecd == `grp', ///
        nquantiles(50) line(qfit) legend(off) ///
        ytitle("") xtitle("Service Share") ///
        yline(0, lcolor(grey) lpattern(dash)) ///
        yscale(range(-7 6)) ylabel(-6(2)6)
    graph save "${dropdir}/Afforestation_Transition/Output/Figure/temp/g_s.gph", replace

    graph combine ///
        "${dropdir}/Afforestation_Transition/Output/Figure/temp/g_a.gph" ///
        "${dropdir}/Afforestation_Transition/Output/Figure/temp/g_m.gph" ///
        "${dropdir}/Afforestation_Transition/Output/Figure/temp/g_s.gph", col(3)
    graph export "${dropdir}/Afforestation_Transition/Output/Figure/forest_gdp_share_`lbl'.pdf", replace
    graph export "${dropdir}/Afforestation_Transition/Output/Figure/forest_gdp_share_`lbl'.png", replace

    * --- GDP growth rate ---
    binscatter g_forest g_gdp_a ///
        if !mi(g_forest) & !mi(g_gdp_a) & oecd == `grp', ///
        nquantiles(50) line(qfit) legend(off) ///
        ytitle("Forest area growth") xtitle("Agriculture GDP growth") ///
        yline(0, lcolor(grey) lpattern(dash)) ///
        xline(0, lcolor(grey) lpattern(dash))
    graph save "${dropdir}/Afforestation_Transition/Output/Figure/temp/g_a.gph", replace

    binscatter g_forest g_gdp_m ///
        if !mi(g_forest) & !mi(g_gdp_m) & oecd == `grp', ///
        nquantiles(50) line(qfit) legend(off) ///
        ytitle("") xtitle("Manufacturing GDP growth") ///
        yline(0, lcolor(grey) lpattern(dash)) ///
        xline(0, lcolor(grey) lpattern(dash))
    graph save "${dropdir}/Afforestation_Transition/Output/Figure/temp/g_m.gph", replace

    binscatter g_forest g_gdp_s ///
        if !mi(g_forest) & !mi(g_gdp_s) & oecd == `grp', ///
        nquantiles(50) line(qfit) legend(off) ///
        ytitle("") xtitle("Services GDP growth") ///
        yline(0, lcolor(grey) lpattern(dash)) ///
        xline(0, lcolor(grey) lpattern(dash))
    graph save "${dropdir}/Afforestation_Transition/Output/Figure/temp/g_s.gph", replace

    graph combine ///
        "${dropdir}/Afforestation_Transition/Output/Figure/temp/g_a.gph" ///
        "${dropdir}/Afforestation_Transition/Output/Figure/temp/g_m.gph" ///
        "${dropdir}/Afforestation_Transition/Output/Figure/temp/g_s.gph", col(3)
    graph export "${dropdir}/Afforestation_Transition/Output/Figure/forest_gdp_growth_`lbl'.pdf", replace
    graph export "${dropdir}/Afforestation_Transition/Output/Figure/forest_gdp_growth_`lbl'.png", replace
}

s


*—————————————————————————binscatter——————————————————————————*
binscatter log_planted_forest_change gdp_a_pct ///
    if forest_change_rate!=0 & gdp_a_pct > 0.5 & gdp_a_pct < 33, ///
    nquantiles(100) line(qfit) ///
    legend(off) ///
    ytitle("Log Change of Forest Areas") ///
    xtitle("Agriculture Share") ///
	yline(0, lcolor(grey) lpattern(dash)) ///
    yscale(range(-2.5 6.5)) ///
    ylabel(-2(2)6)

graph save "${dropdir}/Afforestation_Transition/Output/Figure/temp/g1.gph", replace

binscatter log_planted_forest_change gdp_m_pct ///
    if forest_change_rate!=0 & gdp_m_pct > 2.5 & gdp_m_pct < 24, ///
    nquantiles(100) line(qfit) ///
    legend(off) ///
    ytitle("") ///
    xtitle("Manufacturing Share") ///
	yline(0, lcolor(grey) lpattern(dash)) ///
    yscale(range(-2.5 6.5)) ///
    ylabel(-2(2)6)
	
graph save "${dropdir}/Afforestation_Transition/Output/Figure/temp/g2.gph", replace

binscatter log_planted_forest_change gdp_s_pct ///
    if forest_change_rate!=0 & gdp_s_pct > 33 & gdp_s_pct < 75, ///
    nquantiles(100) line(qfit) ///
    legend(off) ///
    ytitle("") ///
    xtitle("Service Share") ///
	yline(0, lcolor(grey) lpattern(dash)) ///
    yscale(range(-2.5 6.5)) ///
    ylabel(-2(2)6)

graph save "${dropdir}/Afforestation_Transition/Output/Figure/temp/g3.gph", replace

graph combine "${dropdir}/Afforestation_Transition/Output/Figure/temp/g1.gph" "${dropdir}/Afforestation_Transition/Output/Figure/temp/g2.gph" "${dropdir}/Afforestation_Transition/Output/Figure/temp/g3.gph", col(3)

graph export "${dropdir}/Afforestation_Transition/Output/Figure/plantation_forest_gdp_share_sector.pdf", replace
graph export "${dropdir}/Afforestation_Transition/Output/Figure/plantation_forest_gdp_share_sector.png", replace

*===============================================================================
*===============================================================================
* 5. Analysis
*===============================================================================
*===============================================================================


*===============================================================================
* 5.1. Baseline OLS regressions
*===============================================================================

reg log_forest_area       log_gdp_a_value
reg log_forest_area       gdp_a_pct
reg log_forest_area       log_gdp_m_value
reg log_forest_area       gdp_m_pct
reg log_forest_area       log_gdp_s_value
reg log_forest_area       gdp_s_pct

reg log_all_afforestation log_gdp_a_value
reg log_all_afforestation gdp_a_pct

*===============================================================================
* 5.2. TWFE (reghdfe)
*===============================================================================

//**********FOREST AREA
*--- Sector-by-sector regressions with country and year FE
reghdfe log_forest_area log_gdp_a_value, absorb(CountryCode year) cluster(CountryCode)
reghdfe log_forest_area gdp_a_pct,      absorb(CountryCode year) cluster(CountryCode)

reghdfe log_forest_area log_gdp_m_value, absorb(CountryCode year) cluster(CountryCode)
reghdfe log_forest_area gdp_m_pct,      absorb(CountryCode year) cluster(CountryCode)

reghdfe log_forest_area log_gdp_s_value, absorb(CountryCode year) cluster(CountryCode)
reghdfe log_forest_area gdp_s_pct,      absorb(CountryCode year) cluster(CountryCode)

*--- Joint regressions with all sectors
reghdfe log_forest_area log_gdp_a_value log_gdp_m_value log_gdp_s_value, absorb(CountryCode year) cluster(CountryCode)
reghdfe log_forest_area gdp_a_pct gdp_m_pct gdp_s_pct,                   absorb(CountryCode year) cluster(CountryCode)

//**********AFFORESTATION
*--- Same for total afforestation
reghdfe log_all_afforestation log_gdp_a_value, absorb(CountryCode year) cluster(CountryCode)
reghdfe log_all_afforestation gdp_a_pct,      absorb(CountryCode year) cluster(CountryCode)

reghdfe log_all_afforestation log_gdp_m_value, absorb(CountryCode year) cluster(CountryCode)
reghdfe log_all_afforestation gdp_m_pct,      absorb(CountryCode year) cluster(CountryCode)

reghdfe log_all_afforestation log_gdp_s_value, absorb(CountryCode year) cluster(CountryCode)
reghdfe log_all_afforestation gdp_s_pct,      absorb(CountryCode year) cluster(CountryCode)

*--- Joint regressions
reghdfe log_all_afforestation log_gdp_a_value log_gdp_m_value log_gdp_s_value, absorb(CountryCode year) cluster(CountryCode)
reghdfe log_all_afforestation gdp_a_pct gdp_m_pct gdp_s_pct,                   absorb(CountryCode year) cluster(CountryCode)

*===============================================================================
* 5.3. Policy regressions (regional-year fixed effects)
*===============================================================================

reghdfe log_forest_area D_policies_national,        absorb(regions_forest year) cluster(regions_forest)
reghdfe log_forest_area D_policies_sub_national,    absorb(regions_forest year) cluster(regions_forest)
reghdfe log_forest_area D_legislation_national,     absorb(regions_forest year) cluster(regions_forest)
reghdfe log_forest_area D_legislation_sub_national, absorb(regions_forest year) cluster(regions_forest)
reghdfe log_forest_area D_platform_national,        absorb(regions_forest year) cluster(regions_forest)
reghdfe log_forest_area D_platform_sub_national,    absorb(regions_forest year) cluster(regions_forest)

reghdfe log_all_afforestation D_policies_national,        absorb(regions_forest year) cluster(regions_forest)
reghdfe log_all_afforestation D_policies_sub_national,    absorb(regions_forest year) cluster(regions_forest)
reghdfe log_all_afforestation D_legislation_national,     absorb(regions_forest year) cluster(regions_forest)
reghdfe log_all_afforestation D_legislation_sub_national, absorb(regions_forest year) cluster(regions_forest)
reghdfe log_all_afforestation D_platform_national,        absorb(regions_forest year) cluster(regions_forest)
reghdfe log_all_afforestation D_platform_sub_national,    absorb(regions_forest year) cluster(regions_forest)

*===============================================================================
* 5.4. Policy regressions (regional-year fixed effects): not clear about the interpretation
*===============================================================================

reghdfe D_policies_national log_gdp_a_value, absorb(regions_forest year) cluster(CountryCode)
reghdfe D_policies_national gdp_a_pct,      absorb(regions_forest year) cluster(CountryCode)

reghdfe D_policies_national log_gdp_m_value, absorb(regions_forest year) cluster(CountryCode)
reghdfe D_policies_national gdp_m_pct,      absorb(regions_forest year) cluster(CountryCode)

reghdfe D_policies_national log_gdp_s_value, absorb(regions_forest year) cluster(CountryCode)
reghdfe D_policies_national gdp_s_pct,      absorb(regions_forest year) cluster(CountryCode)

*===============================================================================
* 5.5. Policy interaction: not clear about the interpretation
*===============================================================================

reghdfe log_forest_area log_gdp_a_value,        absorb(regions_forest year) cluster(regions_forest)

//**********FOREST AREA
*--- Sector-by-sector regressions with country and year FE
reghdfe log_forest_area i.D_policies_national##c.log_gdp_a_value, absorb(CountryCode year) cluster(CountryCode)
reghdfe log_forest_area i.D_policies_national##c.gdp_a_pct,      absorb(CountryCode year) cluster(CountryCode)

reghdfe log_forest_area i.D_policies_national##c.log_gdp_m_value, absorb(CountryCode year) cluster(CountryCode)
reghdfe log_forest_area i.D_policies_national##c.gdp_m_pct,      absorb(CountryCode year) cluster(CountryCode)

reghdfe log_forest_area i.D_policies_national##c.log_gdp_s_value, absorb(CountryCode year) cluster(CountryCode)
reghdfe log_forest_area i.D_policies_national##c.gdp_s_pct,      absorb(CountryCode year) cluster(CountryCode)

*--- Joint regressions with all sectors
reghdfe log_forest_area i.D_policies_national##c.log_gdp_a_value i.D_policies_national##c.log_gdp_m_value i.D_policies_national##c.log_gdp_s_value, absorb(CountryCode year) cluster(CountryCode)
reghdfe log_forest_area i.D_policies_national##c.gdp_a_pct i.D_policies_national##c.gdp_m_pct i.D_policies_national##c.gdp_s_pct, absorb(CountryCode year) cluster(CountryCode)



*===============================================================================
* End of script
*===============================================================================
display as text ">>> All datasets processed and regressions completed successfully."
