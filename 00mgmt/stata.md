# Stata Coding Rules — Afforestation Atlas

These rules apply to every do file in this project. Violations will cause silent
wrong results or cryptic errors. Read this before writing any Stata code.

---

## 1. Path setup — correct pattern

Always use `local user = c(username)` first, then single-line `if` statements.
Do NOT use `if c(username) == ... { }` compound blocks — they do not work reliably.

```stata
local user = c(username)

if "`user'" == "wyf19"    global dropdir "C:/Users/wyf19/Dropbox"
if "`user'" == "wangy390"  global dropdir "D:/Dropbox"
if "`user'" == "WANGY390"  global dropdir "C:/Users/WANGY390/Dropbox"
```

The `local user = c(username)` line is required. The `if` statements reference `` `user' `` — without it, the macro is empty and no path gets set.

---

## 2. No semicolons as command separators

Stata does NOT use `;` as a command separator (unless you explicitly set `#delimit ;`,
which we never do). A `;` mid-line causes a syntax error or silently corrupts the
expression being evaluated.

**Wrong — will error:**
```stata
gen twfe_att = .;  gen twfe_se  = .
local b_twfe = .; local se_twfe = .
local yr_min = r(min); local yr_max = r(max)
matrix b = e(b); matrix V = e(V)
clear; set obs `tobs'
replace id = -1 in `row'; replace coef = 0 in `row'
gen id = .; gen coef = .; gen ci_lo = .; gen ci_hi = .
```

**Correct — one command per line:**
```stata
gen twfe_att = .
gen twfe_se  = .
local b_twfe  = .
local se_twfe = .
local yr_min = r(min)
local yr_max = r(max)
matrix b = e(b)
matrix V = e(V)
clear
set obs `tobs'
replace id = -1 in `row'
replace coef = 0 in `row'
gen id    = .
gen coef  = .
gen ci_lo = .
gen ci_hi = .
```

---

## 3. Never open and close a brace block on the same line

Stata cannot parse `{ ... }` on a single line in do files — it causes "matching close brace not found".
The closing `}` must always be on its own line.

**Wrong:**
```stata
if r(N) == 0 { continue }
if _rc == 0 { display "ok" }
```

**Correct:**
```stata
if r(N) == 0 {
    continue
}
if _rc == 0 {
    display "ok"
}
```

---

## 4. No nested loops/foreach inside compound `if { }` blocks

Stata cannot reliably parse `foreach` or `forvalues` inside a compound `if { }` block
in a do file. The brace counter gets confused and throws "matching close brace not found".

**Wrong:**
```stata
if _rc != 0 {
    foreach d of local dirs {
        ...
    }
}
```

**Correct — move complex logic to a helper do file and call it:**
```stata
if _rc != 0  do "$code_dir/helper.do"
```

Or restructure without nesting loops in `if` blocks.

---

## 5. `sdid_event` — dynamic window and matrix extraction

Always compute `pre`, `post`, `total` from the data before calling `sdid_event`.
Never hardcode these. The matrix row range depends on them.

```stata
quietly su year, meanonly
local yr_min = r(min)
local yr_max = r(max)
quietly su year if treat_absorbing == 1, meanonly
local yr_t  = r(min)
local pre   = `yr_t' - `yr_min'
local post  = `yr_max' - `yr_t' + 1
local total = `pre' + `post'

capture sdid_event smooth_mean unique_id year treat_absorbing, vce(placebo) placebo(all)
if _rc == 0 {
    mat res = e(H)[2..`=`total'+1', 1..5]
    svmat res
    gen id = _n - 1          if !missing(res1)
    replace id = `post' - _n if _n > `post' & !missing(res1)
    sort id
    * ... plot ...
    drop res1 res2 res3 res4 res5 id   // MUST drop before next iteration
}
```

---

## 6. Always `capture` estimation commands in loops

`sdid_event`, `sdid`, `reghdfe`, `csdid` all fail silently on small samples or
degenerate panels. Wrap every call in `capture` inside a loop.

```stata
capture sdid_event smooth_mean unique_id year treat_absorbing, vce(placebo) placebo(all)
if _rc != 0 {
    display "WARNING: sdid_event failed for `label', skipping"
    restore
    continue
}
```

---

## 7. Always `drop res1 res2 res3 res4 res5 id` after each `sdid_event` loop iteration

Forgetting this causes "already defined" errors in the next iteration.

---

## 8. Required packages

```stata
ssc install sdid_event
ssc install sdid
ssc install reghdfe
ssc install coefplot
ssc install ebalance
ssc install csdid
ssc install drdid
ssc install eventstudyinteract
ssc install avar
ssc install did_multiplegt_dyn
```

---

## 9. Plot style convention

| Element | Specification |
|---------|--------------|
| CI band | `rarea res3 res4 id, lc(gs10) fc(gs11%50)` |
| Point estimates | `scatter res1 id, mc(blue) ms(d)` |
| Zero line | `yline(0, lc(red) lp(-))` |
| Treatment line | `xline(0, lc(black) lp(solid))` |
| Legend | Always `legend(off)` |

---

## 10. Key variable conventions

| Variable | Construction |
|----------|-------------|
| `group_both` | `egen group_both = group(treated_polygon_id ctry_id proj_id site_id site_rpt)` |
| `unique_id` | `egen unique_id = group(treated_polygon_id ctry_id proj_id site_id site_rpt control_id treatment)` |
| `proj_plant_yr` | `bys group_both: egen proj_plant_yr = min(plant_yr)` |
| `treat_absorbing` | `gen treat_absorbing = (control_id == 0 & year >= proj_plant_yr)` |
| `smooth_mean` | 4-yr rolling mean of `ipolate`-d NDVI — main outcome |
| `first_year` | `by unique_id: egen first_year = min(treatment_year)` |
| `cohort` | `gen cohort = proj_plant_yr` |

---

## 11. Data cleaning filters (always apply in this order)

```stata
drop if missing_total == 25     // units with ALL years missing
drop if first_year <= 2003      // pre-MODIS era
drop if max_treat == 0          // countries/groups with no treated obs
drop if plant_yr == .           // missing treatment timing
```

Always compute `max_treat` at the right grouping level:
```stata
bys country: egen max_treat = max(treat_absorbing)   // for country-level filter
```
