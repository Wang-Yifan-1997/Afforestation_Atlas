********************************************************************************
* 00a_build_combined.do
* Build all_covariates_combined_2.dta from Group 1 AND Group 2 CSVs.
*
* Called automatically by 00_data_prep.do when the combined DTA is missing.
* Do NOT run this file directly.
*
* Group 1 (GEE_Extracts)   : flat folder, one file-pair per country
* Group 2 (GEE_Extracts_2) : one subfolder per country, multiple batch files
*
* Both groups share the same CSV layout:
*   Treated : poly_id, ctry_id, proj_id, site_id, site_rpt, year, variable,
*             mean, median, sd, country, plant_yr
*   Control : control_id, treated_polygon_id, ctry_id, proj_id, site_id,
*             site_rpt, year, variable, mean, median, sd, country, plant_yr
*
* Treatment tag comes from the filename ("control" → treatment=0, else 1).
* Treated files have poly_id which is renamed to treated_polygon_id.
********************************************************************************

local gee_dir_1 "$dropdir/Afforestation_Transition/Data/Processed Data/Processed from GEE/GEE_Extracts"
local gee_dir_2 "$gee_dir"   // already set to GEE_Extracts_2 in 00_data_prep.do

* ── helper: load one CSV, tag treatment, harmonise columns ──────────────────
cap program drop _load_csv
program define _load_csv
    args filepath

    import delimited "`filepath'", clear
    tostring proj_id site_rpt, replace force

    local is_control = strpos("`filepath'", "control") > 0
    if `is_control' {
        gen treatment = 0
    }
    else {
        gen treatment = 1
        rename poly_id treated_polygon_id
    }
end


********************************************************************************
* PART A — Group 1: flat folder (GEE_Extracts)
********************************************************************************

display "Building Group 1 from `gee_dir_1'..."

local first = 1
local files : dir `"`gee_dir_1'"' files "*_covariates.csv"

foreach f of local files {
    _load_csv "`gee_dir_1'/`f'"

    if `first' {
        tempfile g1
        save "`g1'"
        local first = 0
    }
    else {
        append using "`g1'", force
        save "`g1'", replace
    }
}

if `first' {
    display as error "WARNING: No CSV files found in `gee_dir_1' — Group 1 skipped."
    tempfile g1
    clear
    save "`g1'", emptyok
}

use "`g1'", clear
gen data_group = 1
tempfile group1_combined
save "`group1_combined'"
display "Group 1: `=_N' rows loaded."


********************************************************************************
* PART B — Group 2: subfolders (GEE_Extracts_2)
********************************************************************************

display "Building Group 2 from `gee_dir_2'..."

local first = 1
local dirs : dir `"`gee_dir_2'"' dirs "*"

foreach d of local dirs {
    local files : dir `"`gee_dir_2'/`d'"' files "*_covariates.csv"

    foreach f of local files {
        _load_csv "`gee_dir_2'/`d'/`f'"

        if `first' {
            tempfile g2
            save "`g2'"
            local first = 0
        }
        else {
            append using "`g2'", force
            save "`g2'", replace
        }
    }
}

if `first' {
    display as error "WARNING: No CSV files found in `gee_dir_2' — Group 2 skipped."
    tempfile g2
    clear
    save "`g2'", emptyok
}

use "`g2'", clear
gen data_group = 2
tempfile group2_combined
save "`group2_combined'"
display "Group 2: `=_N' rows loaded."


********************************************************************************
* PART C — Append, clean country names, save
********************************************************************************

use "`group1_combined'", clear
append using "`group2_combined'", force

replace country = "Cote dIvoire"       if strpos(country, "Ivoire") > 0
replace country = "Central African Rep" if country == "Central African Rep."

duplicates drop

display "Total combined: `=_N' rows."
display "Groups present:"
tab data_group

save `"$gee_dir/all_covariates_combined_2.dta"', replace
display "Saved: all_covariates_combined_2.dta (both groups)"
