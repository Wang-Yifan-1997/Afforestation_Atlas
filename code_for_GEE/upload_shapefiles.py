"""
Batch upload shapefiles using Python API (not CLI)
"""

import ee
import time
from pathlib import Path

# =============================================================================
# CONFIGURATION
# =============================================================================

UPLOAD_FOLDER = r"C:\Users\WANGY390\Dropbox\Afforestation_Transition\Data\GEE_Upload"
PROJECT_ID = 'ee-ywang390'
ASSET_FOLDER = f'projects/{PROJECT_ID}/assets'
MAX_UPLOADS = 10

# =============================================================================
# AUTHENTICATE
# =============================================================================

print("="*70)
print("BATCH UPLOAD SHAPEFILES (FIRST 10 FOR TESTING)")
print("="*70)

print("\nAuthenticating...")
try:
    ee.Initialize(project=PROJECT_ID)
    print(f"✓ Initialized with project: {PROJECT_ID}")
except Exception as e:
    print(f"✗ Authentication failed: {e}")
    print("Run: earthengine authenticate")
    exit(1)

# =============================================================================
# FIND SHAPEFILES
# =============================================================================

print("\nScanning for shapefiles...")

shp_files = list(Path(UPLOAD_FOLDER).glob("*_treated_polygons.shp"))

if not shp_files:
    print(f"✗ No shapefiles found in {UPLOAD_FOLDER}")
    exit(1)

shapefile_groups = {}
for shp_file in shp_files:
    basename = shp_file.stem
    base_path = shp_file.parent / basename
    
    files = {}
    for ext in ['.shp', '.shx', '.dbf', '.prj']:
        file_path = Path(str(base_path) + ext)
        if file_path.exists():
            files[ext] = str(file_path)
    
    if len(files) == 4:
        shapefile_groups[basename] = files

print(f"✓ Found {len(shapefile_groups)} complete shapefiles")
print(f"✓ Will upload first {MAX_UPLOADS} for testing")

# =============================================================================
# UPLOAD USING PYTHON API
# =============================================================================

print("\n" + "="*70)
print("UPLOADING VIA PYTHON API")
print("="*70)

uploaded = []
failed = []
skipped = []

for i, (basename, files) in enumerate(list(shapefile_groups.items())[:MAX_UPLOADS], 1):
    print(f"\n[{i}/{MAX_UPLOADS}] {basename}")
    
    asset_id = f'{ASSET_FOLDER}/{basename}'
    
    # Check if exists
    try:
        ee.data.getAsset(asset_id)
        print(f"  ⚠ Already exists, skipping")
        skipped.append(basename)
        continue
    except:
        pass
    
    try:
        print(f"  Uploading via Python API...")
        
        # Read shapefile data
        shp_path = files['.shp']
        
        # Use ee.data.startIngestion for shapefile upload
        with open(files['.shp'], 'rb') as shp, \
             open(files['.shx'], 'rb') as shx, \
             open(files['.dbf'], 'rb') as dbf, \
             open(files['.prj'], 'rb') as prj:
            
            # Create task
            task_id = ee.data.newTaskId()[0]
            
            # Prepare request
            request = {
                'name': asset_id,
                'tilesets': [{
                    'sources': [{
                        'primaryPath': shp_path,
                        'additionalPaths': [
                            files['.shx'],
                            files['.dbf'],
                            files['.prj']
                        ]
                    }]
                }]
            }
            
            # Start table ingestion
            ee.data.startTableIngestion(
                request=request,
                allow_overwrite=False
            )
        
        print(f"  ✓ Upload task started")
        print(f"    Task ID: {task_id}")
        uploaded.append(basename)
        
        time.sleep(3)
        
    except ee.EEException as e:
        print(f"  ✗ EE Error: {str(e)}")
        failed.append(basename)
    except Exception as e:
        print(f"  ✗ Error: {type(e).__name__}: {str(e)}")
        failed.append(basename)

# =============================================================================
# SUMMARY
# =============================================================================

print("\n" + "="*70)
print("SUMMARY")
print("="*70)
print(f"Uploaded: {len(uploaded)}")
print(f"Skipped: {len(skipped)}")
print(f"Failed: {len(failed)}")

if uploaded:
    print(f"\n✓ Upload tasks started:")
    for name in uploaded:
        print(f"  - {name}")

if failed:
    print(f"\n✗ Failed:")
    for name in failed:
        print(f"  - {name}")

print(f"\n{len(shapefile_groups) - MAX_UPLOADS} remaining")
print("\nIMPORTANT: Check ingestion status at:")
print("https://code.earthengine.google.com → Tasks tab")
print("\nFiles will appear in Assets after ingestion completes (5-30 min)")
print("="*70)