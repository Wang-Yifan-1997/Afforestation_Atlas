********************************************************************************
* 01_policy_prep.do
* ATLAS Afforestation — Policy Data Preparation
*
* Imports the LLM-extracted policy database (Excel), parses active/inactive
* dates, and builds a country-year panel (2000–2024) with policy scores:
*   n_policies    — total active policies in country c, year t
*   n_high        — active high-strength policies
*   n_supportive  — active supportive-tone policies
*   pct_high      — share of active policies that are high-strength
*   pct_supportive— share of active policies with supportive tone
*
* Output:
*   $res_dir/policy_country_year.dta   — country × year panel, 2000–2024
*
* Source Excel:
*   $dropdir/Afforestation_Transition/RA/xianghao meng/policy_extracted_results.xlsx
********************************************************************************

local user = c(username)

if "`user'" == "wyf19"    global dropdir "C:/Users/wyf19/Dropbox"
if "`user'" == "wangy390"  global dropdir "D:/Dropbox"
if "`user'" == "WANGY390"  global dropdir "C:/Users/WANGY390/Dropbox"

global data_dir "$dropdir/Afforestation_Transition/Data/Processed Data"
global res_dir  "$data_dir/results/02_policy"
global policy_xl `"$dropdir/Afforestation_Transition/RA/xianghao meng/policy_extracted_results.xlsx"'

cap mkdir "$data_dir/results"
cap mkdir "$data_dir/results/02_policy"

********************************************************************************
* Step 1: Import and clean policy Excel
********************************************************************************

import excel using `"$policy_xl"', firstrow clear

* Rename columns to clean Stata names
rename Country             country
rename RegulationLegislati policy_name
rename Links               policy_link
rename issuing_government   issuing_govt
rename policy_dates_active   active_raw
rename policy_dates_inactive inactive_raw
rename targeted_areas      targeted_areas
rename policy_objectives    objectives
rename policy_tone          policy_tone
rename policy_tools         policy_tools
rename policy_strength      policy_strength
rename policy_conditionality conditionality
rename monitor_measures     monitor_measures
         
keep country active_raw inactive_raw policy_tone policy_strength

* Drop blank rows
drop if mi(country)

* -----------------------------------------------------------------------
* Step 2: Parse active_year from raw date strings
* Formats observed: "YYYY-MM-DD", "DD Mon YYYY", "YYYY"
* -----------------------------------------------------------------------

* Try ISO format first (YYYY-MM-DD or YYYY)
gen active_yr = year(date(active_raw, "YMD"))

* Try day-month-year text format ("21 May 1993")
replace active_yr = year(date(active_raw, "DMY")) if mi(active_yr)

* Last-resort fallback: grab last 4 chars if they look like a year 1900–2050
gen _tail4 = substr(active_raw, -4, 4)
gen _tail4_n = real(_tail4)
replace active_yr = _tail4_n if mi(active_yr) & _tail4_n >= 1900 & _tail4_n <= 2050
drop _tail4 _tail4_n

* -----------------------------------------------------------------------
* Step 3: Parse inactive_year — "Unknown" / blank → 9999 (still active)
* -----------------------------------------------------------------------

gen inactive_yr = year(date(inactive_raw, "YMD"))
replace inactive_yr = year(date(inactive_raw, "DMY")) if mi(inactive_yr)
gen _tail4 = substr(inactive_raw, -4, 4)
gen _tail4_n = real(_tail4)
replace inactive_yr = _tail4_n if mi(inactive_yr) & _tail4_n >= 1900 & _tail4_n <= 2050
drop _tail4 _tail4_n
replace inactive_yr = 9999 if mi(inactive_yr)

* Drop policies with no usable active year
drop if mi(active_yr)

* -----------------------------------------------------------------------
* Step 4: Harmonise country names to match GEE panel and ForAnalysis.dta
* -----------------------------------------------------------------------

replace country = "Somalia" if strpos(country, "Somalia") > 0
replace country = "Sudan"   if country == "Suban"
* Gambia is listed as "Gambia" in both datasets — no change needed

* -----------------------------------------------------------------------
* Step 5: Binary policy quality indicators
* -----------------------------------------------------------------------

gen is_high       = (policy_strength == "high")
gen is_supportive = (policy_tone     == "supportive")
gen is_any        = 1

* -----------------------------------------------------------------------
* Step 6: Expand to one row per (policy × active year 2000–2024)
* -----------------------------------------------------------------------

* Cap active span to 2000–2024 analysis window
gen yr_start = max(active_yr, 2000)
gen yr_end   = min(inactive_yr, 2024)

* Length of active span within window (0 if policy predates or post-dates window)
gen span = yr_end - yr_start + 1
replace span = 0 if span < 0

drop if span == 0

* Unique policy identifier before expand
gen policy_id = _n

expand span
bysort policy_id: gen yr = yr_start + _n - 1

* -----------------------------------------------------------------------
* Step 7: Collapse to country × year panel
* -----------------------------------------------------------------------

collapse ///
    (sum) n_policies = is_any    ///
    (sum) n_high     = is_high   ///
    (sum) n_supportive = is_supportive, ///
    by(country yr)

* Derived shares
gen pct_high       = n_high       / n_policies if n_policies > 0
gen pct_supportive = n_supportive / n_policies if n_policies > 0
replace pct_high       = 0 if mi(pct_high)
replace pct_supportive = 0 if mi(pct_supportive)

label var n_policies    "Active policies (count)"
label var n_high        "High-strength active policies"
label var n_supportive  "Supportive-tone active policies"
label var pct_high      "Share of active policies that are high-strength"
label var pct_supportive "Share of active policies with supportive tone"
label var yr            "Year"

sort country yr

save "$res_dir/policy_country_year.dta", replace
display "Policy country-year panel saved: $res_dir/policy_country_year.dta"
display "Countries: `r(N)' observations"
