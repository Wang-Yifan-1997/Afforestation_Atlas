# =============================================================================
# BATCH UPLOAD SHAPEFILES TO GEE ASSETS
# =============================================================================

import ee
import os
import glob
import time

# Initialize Earth Engine
ee.Initialize()

# Configuration
upload_dir = "Data/GEE_Upload"
asset_prefix = "users/ywang390/"  # <-- CHANGE THIS TO YOUR USERNAME

# Get all shapefiles
shapefiles = glob.glob(os.path.join(upload_dir, "*_treated_polygons.shp"))

print(f"Found {len(shapefiles)} countries to upload")
print("=" * 60)

for shp_path in shapefiles:
    # Extract country name
    basename = os.path.basename(shp_path)
    country_name = basename.replace("_treated_polygons.shp", "")
    
    # Asset ID
    asset_id = asset_prefix + country_name + "_treated_polygons"
    
    print(f"\nUploading: {country_name}")
    print(f"  Shapefile: {basename}")
    print(f"  Asset ID: {asset_id}")
    
    try:
        # Check if asset already exists
        try:
            ee.data.getAsset(asset_id)
            print(f"  ⚠️  Asset already exists, skipping...")
            continue
        except ee.EEException:
            pass  # Asset doesn't exist, proceed with upload
        
        # Start upload task
        task = ee.batch.Export.table.toAsset(
            collection=ee.FeatureCollection(shp_path),
            description=country_name + "_upload",
            assetId=asset_id
        )
        
        task.start()
        print(f"  ✓ Upload task started")
        
        # Wait a bit to avoid overwhelming the API
        time.sleep(2)
        
    except Exception as e:
        print(f"  ✗ Error: {e}")

print("\n" + "=" * 60)
print("All upload tasks submitted!")
print("Check Tasks tab in GEE Code Editor to monitor progress")
print("=" * 60)