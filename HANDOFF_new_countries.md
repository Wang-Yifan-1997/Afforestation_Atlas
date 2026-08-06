# Handoff — Integrating the 46 New Countries into the ATLAS NDVI Pipeline

**Written 2026-08-06.** For Yifan and for any Claude agent picking this up on another
machine. This file is self-contained — you should not need the original chat.

> **Claude agent reading this:** the data-placement work is already done and synced via
> Dropbox. Your job is Steps 1–6 below. Steps 2, 3 and 6 involve running code or editing
> code — **show the user a plan/diff and get confirmation before making code changes**
> (the pipeline owner prefers to review first).

---

## TL;DR — what's left to do

1. Confirm Dropbox has synced (expect **58** folders / **610** CSVs under `GEE_Extracts_2`).
2. *(Recommended)* Speed up the loader before rebuilding — it's O(n²) and slow at this scale.
3. Run the Stata rebuild: `00_data_prep.do`.
4. Verify the panel now has ~58 countries.
5. Rotate the LSE password (it was in plaintext).
6. *(Optional)* Merge the `code-pipeline` branch into `main`.

---

## Background

- **Project:** ATLAS afforestation — impact of afforestation projects on vegetation (NDVI),
  using Google Earth Engine satellite extracts analyzed in Stata. Full pipeline reference:
  `Code/code_for_atlas/CLAUDE.md`.
- **This task:** expand the sample from ~12 (mostly African) countries to **+46 new
  countries** (`albania … vietnam`, the "remain countries").
- **Source of new data:** the RA delivered them as a *flat* folder:
  `Afforestation_Transition/RA/xinyi wang/0731 remain countries(updating)`
  (same file format as the existing `GEE_Extracts_2` group).

---

## What is ALREADY done (do **not** redo)

- [x] **Code pushed to GitHub** — branch **`code-pipeline`** of
  `https://github.com/Wang-Yifan-1997/Afforestation_Atlas`.
  `main` (xinyi's planning docs) and `Building-&-Road` were left untouched.
- [x] **Data ingested** — 711 files copied from the flat RA folder into per-country
  subfolders under `GEE_Extracts_2/` → now **58 folders, 610 `*_covariates.csv`**.
  Done with `Code/code_for_cleaning/ingest_gee_new_countries.ps1` (non-destructive; the RA
  source folder is untouched).
- [x] **Stale cache deleted** — `GEE_Extracts_2/all_covariates_combined_2.dta` was removed
  to force a clean rebuild.

All of the above lives in Dropbox, so it syncs to your other machine automatically.

---

## Machine / path setup

The Stata do-files auto-detect the machine from `c(username)`:

| Username   | Dropbox root                |
|------------|-----------------------------|
| `wyf19`    | `C:/Users/wyf19/Dropbox`    |
| `wangy390` | `D:/Dropbox`                |
| `WANGY390` | `C:/Users/WANGY390/Dropbox` |

If your other machine's username is **none of these**, add a matching line to the
`dropdir` block at the top of `00_data_prep.do`. The ingestion `.ps1` uses the same
convention and falls back to `%USERPROFILE%\Dropbox` for unknown machines.

---

## Step 1 — Confirm Dropbox has synced

Run in **PowerShell** (auto-detects your Dropbox root):

```powershell
$dropdir = switch ($env:USERNAME) {
    "wyf19"    { "C:\Users\wyf19\Dropbox" }
    "wangy390" { "D:\Dropbox" }
    "WANGY390" { "C:\Users\WANGY390\Dropbox" }
    default    { "$env:USERPROFILE\Dropbox" }
}
$dest = Join-Path $dropdir "Afforestation_Transition\Data\Processed Data\Processed from GEE\GEE_Extracts_2"
(Get-ChildItem $dest -Directory).Count                             # expect 58
(Get-ChildItem $dest -Recurse -Filter *_covariates.csv).Count      # expect 610
```

If the counts are lower, let Dropbox finish syncing before continuing.

**If the RA added more files** to the `(updating)` folder since 2026-08-06, re-ingest first:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dropdir "Afforestation_Transition\Code\code_for_cleaning\ingest_gee_new_countries.ps1")
Remove-Item (Join-Path $dest "all_covariates_combined_2.dta") -Force -ErrorAction SilentlyContinue
```

---

## Step 2 — *(Recommended)* Speed up the loader before rebuilding

**Why:** `Code/code_for_atlas/01_effectiveness/01_ndvi/00a_build_combined.do` appends one CSV
at a time and **re-saves the entire growing dataset on every iteration** (O(n²)). At 610
CSVs the combined file is ~3–4 GB, so this can take *hours* and must fit entirely in RAM.

**The fix (same output, linear time):** import each CSV, `save` it to its own small
tempfile, collect the tempfile names in a local, then do a **single** `append using
file1 file2 …` at the end — instead of appending+resaving inside the loop.

**How to do it:** ask your Claude agent —
> "Rewrite the Group-1 and Group-2 loaders in `00a_build_combined.do` to a single-pass
> `append using`, keep the exact same columns/`data_group`/country-cleaning logic and
> output file, and show me the diff before saving."

If you **skip** this, the rebuild still works — just budget time and make sure you're on
64-bit Stata with enough memory (`query memory`; raise `set max_memory` if needed).

---

## Step 3 — Rebuild the panel (Stata)

Open Stata → **Do-file Editor** → open and run:

```
Code/code_for_atlas/01_effectiveness/01_ndvi/00_data_prep.do
```

(It sets `$dropdir`/`$gee_dir` for your machine automatically, so no path edits needed.)
This rebuilds **`all_covariates_combined_2.dta`** and **`atlas_ndvi_panel.dta`** including
all countries.

Packages used by the *analysis* do-files (not the rebuild itself): `sdid_event`, `sdid`,
`reghdfe`, `coefplot`. Install any that are missing with `ssc install <name>`.

---

## Step 4 — Verify

```stata
use "$gee_dir/all_covariates_combined_2.dta", clear
tab data_group            // group 2 should be much larger than before
levelsof country          // expect ~58 countries incl. Albania, Spain, Vietnam, ...

use "$dropdir/Afforestation_Transition/Data/Processed Data/atlas_ndvi_panel.dta", clear
levelsof country
count
```

The analysis loops (`01_site.do`, `03_cohort.do`, `04_country.do` in the same folder)
pick up the new countries automatically — they iterate over `levelsof country`. Note that
`03_cohort.do` and `04_country.do` **intentionally drop Ethiopia** (`// too big`); that's
existing behavior, not a bug.

---

## Step 5 — Security (please don't skip)

Rotate the LSE password **`LSE_afforestation_2026`**. It was stored in plaintext in
`Code/code_for_GEE/javascript_code_for_GEE/password.txt`. That file is excluded from git
(via `.gitignore`) but still exists in your Dropbox.

---

## Step 6 — *(Optional)* Merge the code into `main`

The code is on branch **`code-pipeline`**; `main` currently holds xinyi's planning docs.
To combine them, open a pull request:

```
https://github.com/Wang-Yifan-1997/Afforestation_Atlas/pull/new/code-pipeline
```

The two histories are unrelated, so a local merge would need
`git merge origin/main --allow-unrelated-histories`. A Claude agent can do this for you.

---

## Key files

| Purpose                | Path (under `Code/`)                                              |
|------------------------|------------------------------------------------------------------|
| Ingest new countries   | `code_for_cleaning/ingest_gee_new_countries.ps1`                 |
| Rebuild the panel      | `code_for_atlas/01_effectiveness/01_ndvi/00_data_prep.do`        |
| Loader (called by ↑)   | `code_for_atlas/01_effectiveness/01_ndvi/00a_build_combined.do`  |
| Analysis (site/cohort/country) | `01_site.do`, `03_cohort.do`, `04_country.do` (same folder) |
| Pipeline reference      | `code_for_atlas/CLAUDE.md`                                       |

## Known data notes

- All 46 new countries have **balanced** treated/control covariate CSVs.
- `mali` is missing only its `treated_geometry.geojson` — **harmless** for the NDVI panel
  (the loader reads only `*_covariates.csv`); it only matters if you later map mali's
  polygons.
