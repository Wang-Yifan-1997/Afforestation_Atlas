<#
    ingest_gee_new_countries.ps1
    ---------------------------------------------------------------------------
    Land newly-collected per-country GEE extract files (currently delivered as a
    FLAT folder by the RA) into the canonical GEE_Extracts_2/{country}/ subfolder
    layout that the Stata loader (01_effectiveness/01_ndvi/00a_build_combined.do)
    auto-discovers.

    - Non-destructive: COPIES files; the RA source folder is left intact.
    - Idempotent:      re-run whenever the staging folder is updated
                       (Copy-Item -Force refreshes existing files).
    - Folder name  =   the filename prefix before "_batch_" (e.g. albania,
                       burkina_faso). The loader reads the actual country NAME
                       from the CSV's `country` column, so the folder name is
                       only a container and can be lowercase/clean.

    After running this, force a fresh panel build:
        1. delete  GEE_Extracts_2/all_covariates_combined_2.dta   (stale)
        2. run     code_for_atlas/01_effectiveness/01_ndvi/00_data_prep.do
    ---------------------------------------------------------------------------
#>

# --- Dropbox root per machine (mirrors the Stata/R convention) --------------
$user = $env:USERNAME
switch ($user) {
    "wyf19"    { $dropdir = "C:/Users/wyf19/Dropbox" }
    "wangy390" { $dropdir = "D:/Dropbox" }
    "WANGY390" { $dropdir = "C:/Users/WANGY390/Dropbox" }
    default    { $dropdir = Join-Path $env:USERPROFILE "Dropbox" }
}

# --- Source (flat RA staging) and destination (canonical processed layout) --
$src  = Join-Path $dropdir "Afforestation_Transition/RA/xinyi wang/0731 remain countries(updating)"
$dest = Join-Path $dropdir "Afforestation_Transition/Data/Processed Data/Processed from GEE/GEE_Extracts_2"

if (-not (Test-Path $src))  { Write-Error "Source folder not found: $src";  exit 1 }
if (-not (Test-Path $dest)) { Write-Error "Destination not found: $dest";   exit 1 }

# --- Copy every batch file into its per-country subfolder -------------------
$files = Get-ChildItem $src -File |
    Where-Object { $_.Name -match '_batch_' -and ($_.Extension -in '.csv', '.geojson') }

$summary = @{}
foreach ($f in $files) {
    $country    = ($f.Name -split '_batch_')[0]        # folder = filename prefix
    $countryDir = Join-Path $dest $country
    if (-not (Test-Path $countryDir)) {
        New-Item -ItemType Directory -Path $countryDir | Out-Null
    }
    Copy-Item $f.FullName -Destination $countryDir -Force
    if (-not $summary.ContainsKey($country)) { $summary[$country] = 0 }
    $summary[$country]++
}

# --- Report ----------------------------------------------------------------
Write-Output ("Ingested {0} files into {1} country folders under GEE_Extracts_2:" -f $files.Count, $summary.Keys.Count)
$summary.GetEnumerator() | Sort-Object Name | ForEach-Object { "  {0,-24} {1,3} files" -f $_.Key, $_.Value }
