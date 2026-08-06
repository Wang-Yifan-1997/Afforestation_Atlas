********************************************************************************
* 01_policy_prep_faolex.do
* ATLAS Afforestation — Policy Data Preparation (FAOLEX)
*
* Imports FAOLEX_All.csv, parses active/inactive years, and builds a
* country-year panel (2000-2024) with:
*   n_forest     — count of active forestry policies in country c, year t
*   n_nonforest  — count of active non-forestry policies in country c, year t
*   n_policies   — alias for n_forest (backward compatibility)
*
* Active period logic:
*   - Non-repealed → active from Date of text year to 2024
*   - Repealed + Last amended date → active to last-amended year (proxy for repeal)
*   - Repealed + no amendment date → active to 2024 (repeal year unknown; conservative)
*
* Note: FAOLEX covers all countries; treatment-effect data is Africa-only.
* Downstream scripts handle the imperfect geographic overlap via keep(master match).
*
* Output:
*   $res_dir/policy_country_year.dta   — country × year panel, 2000-2024
*
* Source:
*   $dropdir/.../FAOLEX/FAOLEX_All.csv
********************************************************************************

local user = c(username)

if "`user'" == "wyf19"    global dropdir "C:/Users/wyf19/Dropbox"
if "`user'" == "wangy390"  global dropdir "D:/Dropbox"
if "`user'" == "WANGY390"  global dropdir "C:/Users/WANGY390/Dropbox"

global data_dir "$dropdir/Afforestation_Transition/Data/Processed Data"
global res_dir  "$data_dir/results/02_policy"
global faolex   `"$dropdir/Afforestation_Transition/Data/Raw Data/FAOLEX/FAOLEX_All.csv"'

cap mkdir "$data_dir/results"
cap mkdir "$data_dir/results/02_policy"

********************************************************************************
* Step 1: Import CSV
********************************************************************************

import delimited using `"$faolex"', clear varnames(1) encoding("utf-8")

* Actual variable names created by Stata (BOM survives as ďż prefix on first var):
* ďżrecordid recordurl documenturl texturl title originaltitle dateoftext
* lastamendeddate availablewebsite languageofdocument countryterritory
* regionalorganizations territorialsubdivision typeoftext repealed
* abstract primarysubjects domain keywords

cap rename ďżrecordid         record_id     // strip BOM from first variable
rename dateoftext            date_raw
rename lastamendeddate       amend_raw
rename countryterritory      country
rename primarysubjects       primary_subj
rename typeoftext            type_text

********************************************************************************
* Step 2: Flag forestry vs non-forestry; keep all records
********************************************************************************

drop if mi(country) | country == ""

gen is_forest    = (strpos(lower(primary_subj), "forest") > 0)
gen is_nonforest = 1 - is_forest

display "Total records: `c(N)'"
count if is_forest
display "  of which forestry: `r(N)'"

********************************************************************************
* Step 3: Parse active year from "Date of text" (DD-MM-YYYY)
********************************************************************************

gen active_yr = year(date(date_raw, "DMY"))

* Fallback: grab 4-digit year from end of string
gen _tail = substr(date_raw, -4, 4)
gen _tail_n = real(_tail)
replace active_yr = _tail_n if mi(active_yr) & _tail_n >= 1900 & _tail_n <= 2050
drop _tail _tail_n

drop if mi(active_yr)

********************************************************************************
* Step 4: Parse inactive year
********************************************************************************

gen amend_yr = year(date(amend_raw, "DMY"))
gen _tail = substr(amend_raw, -4, 4)
gen _tail_n = real(_tail)
replace amend_yr = _tail_n if mi(amend_yr) & _tail_n >= 1900 & _tail_n <= 2050
drop _tail _tail_n

gen inactive_yr = 9999                                     // default: still active
replace inactive_yr = amend_yr if repealed == "Y" & !mi(amend_yr)  // proxy repeal date
replace inactive_yr = 2024     if repealed == "Y" &  mi(amend_yr)  // unknown repeal date

drop amend_yr amend_raw date_raw

********************************************************************************
* Step 5: Country name harmonisation
********************************************************************************

* --- 5a. Drop multi-country entries (contain ";") ---
* These are bilateral/multilateral agreements and cannot be assigned to one country
drop if strpos(country, ";") > 0

* --- 5b. Drop non-sovereign territories and subdivisions ---
drop if strpos(country, "(") > 0         // e.g. "Bermuda (UK)", "Madeira Islands (Portugal)"
drop if strpos(country, "Province") > 0  // e.g. "Taiwan Province of China"
drop if strpos(country, "SAR") > 0       // e.g. "China, Hong Kong SAR"
drop if strpos(country, "Zanzibar") > 0  // part of Tanzania — handled separately below

* --- 5c. Standard name fixes ---
replace country = "Tanzania"                 if country == "United Republic of Tanzania"
replace country = "Dem Rep Congo"            if strpos(country, "Dem. Rep.") > 0 & strpos(country, "Congo") > 0
replace country = "Congo"                    if country == "Congo, Rep."
replace country = "Cote dIvoire"             if strpos(country, "voire") > 0
replace country = "Gambia"                   if strpos(country, "Gambia") > 0
replace country = "Libya"                    if strpos(country, "Libya") > 0
replace country = "Egypt"                    if strpos(country, "Egypt") > 0
replace country = "Sudan"                    if country == "Sudan"
replace country = "Eswatini"                 if country == "Swaziland"
replace country = "Central African Rep"      if strpos(country, "Central African") > 0
replace country = "Equatorial Guinea"        if strpos(country, "Equatorial Guinea") > 0
replace country = "Guinea Bissau"            if strpos(country, "Bissau") > 0
replace country = "Cabo Verde"               if strpos(country, "Cape Verde") > 0 | country == "Cabo Verde"
replace country = "Sao Tome and Principe"    if strpos(country, "Sao Tom") > 0
replace country = "Turkey"                   if strpos(country, "rkiye") > 0
replace country = "South Sudan"              if country == "South Sudan"
replace country = "Bolivia"                  if strpos(country, "Bolivia") > 0
replace country = "Venezuela"                if strpos(country, "Venezuela") > 0
replace country = "Iran"                     if strpos(country, "Iran") > 0
replace country = "North Korea"              if strpos(country, "Democratic People") > 0
replace country = "South Korea"              if country == "Republic of Korea"
replace country = "Moldova"                  if strpos(country, "Moldova") > 0
replace country = "Laos"                     if strpos(country, "Lao People") > 0
replace country = "Syria"                    if strpos(country, "Syrian") > 0
replace country = "Russia"                   if country == "Russian Federation"
replace country = "Micronesia"               if strpos(country, "Micronesia") > 0
replace country = "Kosovo"                   if strpos(country, "Kosovo") > 0
replace country = "Netherlands"              if strpos(country, "Netherlands") > 0
replace country = "United States"            if strpos(country, "United States") > 0
replace country = "United Kingdom"           if strpos(country, "United Kingdom") > 0

* --- 5d. Key Africa names that must match atlas_ndvi_panel.dta exactly ---
* Check your atlas panel with: levelsof country
replace country = "Burkina Faso"             if country == "Burkina Faso"
replace country = "Central African Rep"      if country == "Central African Republic"
replace country = "Dem Rep Congo"            if country == "Congo, Dem. Rep."
replace country = "Guinea Bissau"            if country == "Guinea-Bissau"
replace country = "Cote dIvoire"             if country == "Cote d'Ivoire"

display "Unique countries after cleaning:"
levelsof country

* Inspect unique country names after harmonisation
tab country, sort

********************************************************************************
* Step 6: Cap active span to 2000-2024 analysis window and expand
********************************************************************************

gen policy_id = _n

gen yr_start = max(active_yr, 2000)
gen yr_end   = min(inactive_yr, 2024)
gen span     = yr_end - yr_start + 1
replace span = 0 if span < 0 | mi(span)
drop if span == 0

display "Policies with valid span in 2000-2024: `c(N)'"

expand span
bysort policy_id: gen yr = yr_start + _n - 1

********************************************************************************
* Step 7: Collapse to country × year
********************************************************************************

collapse (sum) n_forest = is_forest n_nonforest = is_nonforest, by(country yr)

* import delimited creates strL variables; merge requires str# — recast before saving
recast str50 country

* Alias for backward compatibility with 02_policy_het.do
gen n_policies = n_forest

label var n_forest    "Active forestry policies (FAOLEX, Primary subjects contains 'forest')"
label var n_nonforest "Active non-forestry policies (FAOLEX, all other subjects)"
label var n_policies  "= n_forest (backward compatibility)"
label var yr          "Year"

sort country yr

save "$res_dir/policy_country_year.dta", replace
display "FAOLEX policy country-year panel saved: $res_dir/policy_country_year.dta"

tabstat n_forest n_nonforest, by(yr) stat(sum) nototal
