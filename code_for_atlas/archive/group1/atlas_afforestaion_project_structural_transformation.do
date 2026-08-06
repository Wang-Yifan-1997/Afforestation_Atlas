if c(username) == "wyf19" {
    global dropdir "C:/Users/wyf19/Dropbox"
}
else if c(username) == "wangy390" {
    global dropdir "D:/Dropbox"
}

global gee_dir "$dropdir/Afforestation_Transition/Data/Processed Data/Processed from GEE/GEE_Extracts"



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


rename name country
replace country = "Cote dIvoire" if country == "Côte d'Ivoire"
replace country = "Central African Rep" if country == "Central African Republic"

merge m:1 country using "$dropdir/Afforestation_Transition/Data/Processed Data/sdid_results_modis_ndvi.dta"
keep if _merge == 3

tab year

egen gdp_total = rowtotal(gdp_a_value gdp_m_value gdp_s_value)
egen gdp_total_a_s = rowtotal(gdp_a_value gdp_s_value)
gen gdp_total_per_worker_a_s = gdp_a_value / gdp_total_a_s * gdp_a_per_worker + gdp_s_value / gdp_total_a_s * gdp_s_per_worker
gen log_gdp_total_per_worker_a_s = log(gdp_total_per_worker_a_s)

gen log_gdp_total = log(gdp_total)
gen s_a_ratio = gdp_s_value / gdp_a_value
gen log_s_a_ratio = log(gdp_s_value) - log(gdp_a_value)
gen m_a_ratio = gdp_m_value / gdp_a_value
gen log_m_a_ratio = log(gdp_m_value) - log(gdp_a_value)
gen s_m_ratio = gdp_s_value / gdp_m_value
gen log_s_m_ratio = log(gdp_s_value) - log(gdp_m_value)


reg coef gdp_a_pct if year == 2000
reg coef gdp_a_pct if year == 2010

keep coef se gdp_a_pct gdp_m_pct gdp_s_pct year country
reshape wide gdp_a_pct gdp_m_pct gdp_s_pct, i(country coef se) j(year)

gen gdp_a_pct_diff = gdp_a_pct2010 - gdp_a_pct2000
gen gdp_s_pct_diff = gdp_s_pct2010 - gdp_s_pct2000

twoway (scatter coef gdp_a_pct_diff if gdp_a_pct_diff < 9) (lfit coef gdp_a_pct_diff if gdp_a_pct_diff < 9), legend(off) xtitle("Change of the Share of Agriculture")

s
twoway (scatter coef gdp_a_pct if year == 2020) (lfit coef gdp_a_pct if year == 2020), legend(off) xtitle("Share of Agriculture")
twoway (scatter coef gdp_m_pct if year == 2020) (lfit coef gdp_m_pct if year == 2020), legend(off) xtitle("Share of Manufacturing")
twoway (scatter coef gdp_s_pct if year == 2020) (lfit coef gdp_s_pct if year == 2020), legend(off) xtitle("Share of Service")


twoway (scatter coef gdp_a_growth if year == 2010) (lfit coef gdp_a_growth if year == 2010), legend(off) xtitle("Share of Agriculture")
twoway (scatter coef gdp_a_per_worker if year == 2010) (lfit coef gdp_a_per_worker if year == 2010), legend(off) xtitle("Share of Agriculture")
