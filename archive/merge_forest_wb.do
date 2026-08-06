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

keep if inlist(SeriesName, "a_pct", "a_growth", "a_value")
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

keep if inlist(SeriesName, "m_pct", "m_growth", "m_value")
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

keep if inlist(SeriesName, "s_pct", "s_growth", "s_value")
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

* Forest outcomes
gen log_forest_area       = log(a_forestarea)
//b_naturallyregeneratingforest + b_plantedforest = a_forestarea
gen log_natural_forest 	  = log(b_naturallyregeneratingforest)
gen log_all_afforestation = log(b_plantedforest)
gen log_plantationforest  = log(b_plantationforest)

bys name (year): gen forest_change = a_forestarea - a_forestarea[_n-1]
gen log_forest_change = asinh(forest_change)

//*****there will be more missing values for forest stock
gen log_stock_nat_reg = log(a_gs_tot_nat_reg) //forest growing stock for naturally regenerating forest
gen log_stock_planted = log(a_gs_tot_planted) //forest growing stock for planted forest

* Convert "yes/no" indicators to dummy variables
foreach var in policies_national policies_sub_national legislation_national ///
               legislation_sub_national platform_national platform_sub_national {
    gen D_`var' = cond(a_`var' == "yes", 1, cond(a_`var' == "no", 0, .))
}

* GDP logs and shares
gen log_gdp_a_value = log(gdp_a_value)
gen log_gdp_m_value = log(gdp_m_value)
gen log_gdp_s_value = log(gdp_s_value)

foreach sec in a m s {
    gen log_gdp_`sec'_pct = log(gdp_`sec'_pct)
}

bys name (year): gen forest_change_rate = (a_forestarea - a_forestarea[_n-1]) / a_forestarea
gen afforestation_rate = b_plantedforest / a_forestarea

s


*===============================================================================
* 4. Descriptive
*===============================================================================

gen s_a_ratio = gdp_s_value / gdp_a_value
gen log_s_a_ratio = log(gdp_s_value) / log(gdp_a_value)
gen m_a_ratio = gdp_m_value / gdp_a_value
gen log_m_a_ratio = log(gdp_m_value) / log(gdp_a_value)
gen s_m_ratio = gdp_s_value / gdp_m_value
gen log_s_m_ratio = log(gdp_s_value) / log(gdp_m_value)

twoway lpolyci forest_change_rate log_s_a_ratio if forest_change_rate!=0, legend(off)
twoway lpolyci forest_change_rate log_s_m_ratio if forest_change_rate!=0, legend(off)

twoway lpolyci afforestation_rate log_s_a_ratio, legend(off)
twoway lpolyci afforestation_rate log_s_m_ratio, legend(off)

binscatter forest_change_rate log_s_a_ratio if forest_change_rate!=0
binscatter forest_change_rate log_s_m_ratio if forest_change_rate!=0

binscatter afforestation_rate log_s_a_ratio
binscatter afforestation_rate log_s_m_ratio

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
