# Afforestation Zone Building \& Road Analysis Workflow

**Test Case: Ethiopia**
This repository contains a complete workflow for calculating building and road statistics within afforestation polygons, optimized for memory efficiency and scalability\.

---

## Overview

This pipeline processes two primary geospatial datasets to generate standardized statistics for afforestation zones:

1. **Road Network Data**: From OpenStreetMap \(OSM\)

2. **Building Footprint Data**: From Google Open Buildings V3

The workflow includes data preprocessing, spatial join operations, statistical aggregation, visualization, and cross\-dataset merging\. All code is modular, configurable, and designed to handle large datasets efficiently\.

---

## Workflow Diagram

```Plaintext
Data Acquisition → Preprocessing → Spatial Analysis → Statistics Generation → Visualization → Data Merging
```

---

## Datasets

### 1\. Road Dataset: OpenStreetMap \(OSM\)

- **Official Source**: Geofabrik Africa Download Portal

- **Available Formats**: Per\-country `\.osm\.pbf` \(raw data\) and `\.shp\.zip` \(preprocessed shapefiles\)

- **Key Limitations**:

    - No bulk download for multiple countries

    - Continental\-level `\.shp\.zip` is unavailable \(only country\-level extracts\)

- **Download Method**:

    - Manual download from the Geofabrik website

    - Automated web scraping can be implemented for batch country downloads

- **Test Data**: Ethiopia OSM shapefile \(100 MB, as of 2025\-08\-15\)

### 2\. Building Dataset: Google Open Buildings V3

- **Official Source**: Google Open Buildings Download Colab Notebook

- **Data Format**: Per\-country CSV files with WKT geometry, area, and confidence scores

- **Key Limitations**:

    - No bulk download for multiple countries

    - Large file sizes \(e\.g\., Ethiopia dataset \~3 GB\)

    - Local processing requires sufficient memory

- **Download Method**: Run the Colab notebook online \(requires Google account\) to download country\-specific data

- **Note**: The Colab link may require authentication to access and run

---

## Code Implementation

### Prerequisites

```Bash
pip install geopandas pandas matplotlib shapely tqdm gzip
```

### 1\. OSM Road Statistics Processing

**File**: `osm\_road\_stats\.py`
Calculates road count, total length, and type distribution per afforestation polygon\.

```Python
# -*- coding: utf-8 -*-
"""
OSM Road Statistics for Afforestation Zones
Final Refactored Version
Author: Ariana
"""

import geopandas as gpd
import pandas as pd
import matplotlib.pyplot as plt
import os

# -------------------------- CONFIGURATION --------------------------
BASE_PATH = "./data/osm/ethiopia-260407-free.shp"
POLYGON_PATH = "./data/afforestation_polygons/ethiopia_treated_polygons.shp"
TARGET_CRS = "EPSG:20138"
OUTPUT_DIR = "./stats_results"

# -------------------------- LOAD & PREPROCESS ROAD DATA --------------------------
print("="*70)
print("Loading and Preprocessing Road Data")
print("="*70)

# Auto-detect road layer
all_shp_files = [f for f in os.listdir(BASE_PATH) if f.lower().endswith('.shp')]
road_layer_name = None
road_keywords = ['road', 'transport', 'highway', 'street', 'path', 'track']

for shp_file in all_shp_files:
    if any(keyword in shp_file.lower() for keyword in road_keywords):
        road_layer_name = shp_file.replace('.shp', '')
        break

gdf_roads = gpd.read_file(os.path.join(BASE_PATH, f"{road_layer_name}.shp"))
print(f"Loaded road layer: {road_layer_name} with {len(gdf_roads)} road segments")

# Project first, then calculate length (critical for accurate measurements)
gdf_roads_proj = gdf_roads.to_crs(TARGET_CRS)
gdf_roads_proj['length_m'] = gdf_roads_proj.length

# Identify road type column
road_type_col = 'fclass' if 'fclass' in gdf_roads.columns else 'highway'

# -------------------------- LOAD AFFORESTATION POLYGONS --------------------------
print("\n" + "="*70)
print("Loading Afforestation Polygon Data")
print("="*70)

gdf_polygons = gpd.read_file(POLYGON_PATH)
print(f"Loaded {len(gdf_polygons)} afforestation polygons")
print(f"Using unique ID field: poly_id")
print(f"Contains planting year field: plant_yr")

# Align coordinate systems
gdf_polygons_proj = gdf_polygons.to_crs(TARGET_CRS)

# -------------------------- SPATIAL JOIN & STATISTICS --------------------------
print("\n" + "="*70)
print("Calculating Road Statistics per Polygon")
print("="*70)

# Spatial join
joined = gpd.sjoin(
    gdf_polygons_proj,
    gdf_roads_proj,
    how='left',
    predicate='intersects'
)

# Detailed statistics per polygon
print("Generating detailed polygon statistics...")
road_stats = joined.groupby('poly_id').agg(
    total_roads=('index_right', 'count'),
    total_length_m=('length_m', 'sum'),
    plant_year=('plant_yr', 'first'),
    country=('country', 'first'),
    project_id=('proj_id', 'first')
).round(2)

# Statistics by road type
if road_type_col and road_type_col in joined.columns:
    type_stats = joined.pivot_table(
        index='poly_id',
        columns=road_type_col,
        values='length_m',
        aggfunc='sum',
        fill_value=0
    ).round(2)
    road_stats = pd.concat([road_stats, type_stats], axis=1)

road_stats = road_stats.reset_index()

# Yearly summary
print("\nGenerating yearly summary statistics...")
year_summary = road_stats.groupby('plant_year').agg(
    polygon_count=('poly_id', 'count'),
    avg_road_count=('total_roads', 'mean'),
    avg_road_length_m=('total_length_m', 'mean'),
    total_length_km=('total_length_m', lambda x: (x.sum()/1000).round(2))
).round(2)

# Overall summary
overall_summary = pd.DataFrame({
    'metric': [
        'Total polygons', 'Polygons with roads', 'Polygons without roads',
        'Total road length (km)', 'Avg roads per polygon', 'Avg road length per polygon (m)'
    ],
    'value': [
        len(road_stats),
        len(road_stats[road_stats['total_roads'] > 0]),
        len(road_stats[road_stats['total_roads'] == 0]),
        (road_stats['total_length_m'].sum() / 1000).round(2),
        road_stats['total_roads'].mean().round(2),
        road_stats['total_length_m'].mean().round(2)
    ]
})

# -------------------------- PRINT RESULTS --------------------------
print("\n" + "="*70)
print("Overall Summary Statistics")
print("="*70)
print(overall_summary.to_string(index=False))

print("\n" + "="*70)
print("Summary by Planting Year")
print("="*70)
print(year_summary.to_string())

print("\n" + "="*70)
print("Top 10 Polygons - Detailed Statistics")
print("="*70)
print(road_stats.head(10).to_string())

# -------------------------- SAVE RESULTS --------------------------
os.makedirs(OUTPUT_DIR, exist_ok=True)

road_stats.to_csv(os.path.join(OUTPUT_DIR, "polygon_road_stats.csv"), index=False, encoding='utf-8-sig')
year_summary.to_csv(os.path.join(OUTPUT_DIR, "yearly_road_summary.csv"), encoding='utf-8-sig')
overall_summary.to_csv(os.path.join(OUTPUT_DIR, "overall_road_summary.csv"), index=False, encoding='utf-8-sig')

print(f"\nAll statistics saved to: {OUTPUT_DIR}")

# -------------------------- VISUALIZATION --------------------------
print("\nGenerating visualization plots...")

# Plot 1: Afforestation zones & roads overlay
fig, ax = plt.subplots(figsize=(14, 12))
gdf_roads_proj.plot(ax=ax, linewidth=0.3, color='gray', alpha=0.6, label='Roads')
gdf_polygons_proj.plot(ax=ax, facecolor='none', edgecolor='red', linewidth=1.5, label='Afforestation Zones')
ax.set_title('Ethiopia Afforestation Zones and Road Distribution', fontsize=16, pad=20)
ax.set_xlabel('Easting (m)')
ax.set_ylabel('Northing (m)')
ax.legend()
plt.tight_layout()
plt.savefig(os.path.join(OUTPUT_DIR, "afforestation_roads_overlay.png"), dpi=300, bbox_inches='tight')

# Plot 2: Average road length by planting year
if not year_summary.empty:
    fig, ax = plt.subplots(figsize=(10, 6))
    year_summary['avg_road_length_m'].plot(kind='bar', ax=ax, color='#1f77b4', edgecolor='black')
    ax.set_title('Average Road Length by Planting Year', fontsize=14, pad=15)
    ax.set_xlabel('Planting Year')
    ax.set_ylabel('Average Road Length (m)')
    ax.grid(axis='y', linestyle='--', alpha=0.7)
    plt.xticks(rotation=0)
    plt.tight_layout()
    plt.savefig(os.path.join(OUTPUT_DIR, "yearly_avg_road_length.png"), dpi=300, bbox_inches='tight')

print("All visualization plots saved")
plt.show()

print("\n" + "="*70)
print("All analysis complete!")
print("="*70)
```

### 2\. Google Open Buildings Batch Processing

**File**: `google\_buildings\_batch\.py`
Memory\-optimized batch processing for large building datasets \(reduces memory usage from 32GB\+ to \&lt;8GB\)\.

```Python
# -*- coding: utf-8 -*-
"""
Google Open Buildings - Batch Processing (Memory Optimized)
Core Strategy: Split buildings into small batches, process incrementally, merge results
Memory Usage: Reduced from 32GB+ to <8GB
Author: Ariana
"""

import geopandas as gpd
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import os
from shapely import wkt
import gzip
from tqdm import tqdm

# -------------------------- CONFIGURATION --------------------------
BASE_PATH = "./data/google_buildings"
POLYGON_PATH = "./data/afforestation_polygons/ethiopia_treated_polygons.shp"
BUILDINGS_PATH = os.path.join(BASE_PATH, "open_buildings_v3_polygons_ne_10m_ETH.csv.gz")
ROAD_STATS_PATH = "./stats_results/polygon_road_stats.csv"
OUTPUT_DIR = "./stats_results"

# Batch size (adjust based on memory: 50k for 8GB, 100k for 16GB, 200k for 32GB+)
BATCH_SIZE = 50000
CONFIDENCE_THRESHOLD = 0.7
TARGET_CRS = "EPSG:20138"

# -------------------------- CORE PROCESSING FUNCTIONS --------------------------
def load_polygons():
    """Load and preprocess polygon data (once at start)"""
    print("="*70)
    print("Step 1/6: Loading Afforestation Polygons")
    print("="*70)
    
    gdf_polygons = gpd.read_file(POLYGON_PATH)
    gdf_polygons_proj = gdf_polygons.to_crs(TARGET_CRS)
    
    # Build spatial index for faster queries
    print("Building spatial index...")
    polygon_sindex = gdf_polygons_proj.sindex
    print(f"Loaded {len(gdf_polygons)} polygons")
    
    # Initialize results dictionary
    results = {
        'poly_id': [],
        'total_buildings': [],
        'total_area_sqm': [],
        'total_confidence': [],
        'area_sq_sum': []  # For std/mean calculation
    }
    
    # Pre-populate with all poly_ids (initial values = 0)
    for poly_id in gdf_polygons_proj['poly_id']:
        results['poly_id'].append(poly_id)
        results['total_buildings'].append(0)
        results['total_area_sqm'].append(0.0)
        results['total_confidence'].append(0.0)
        results['area_sq_sum'].append(0.0)
    
    # Create ID-to-index mapping for fast lookups
    poly_id_to_idx = {pid: i for i, pid in enumerate(results['poly_id'])}
    
    return gdf_polygons, gdf_polygons_proj, polygon_sindex, results, poly_id_to_idx

def process_buildings(gdf_polygons_proj, polygon_sindex, results, poly_id_to_idx):
    """Process building data in batches with memory optimization"""
    print("\n" + "="*70)
    print("Step 2/6: Batch Processing Buildings (Memory Optimized)")
    print("="*70)
    
    # Get total line count for progress bar
    print("Calculating total lines...")
    with gzip.open(BUILDINGS_PATH, 'rb') as f:
        total_lines = sum(1 for _ in f) - 1  # Subtract header
    print(f"{total_lines:,} buildings total → {total_lines//BATCH_SIZE + 1} batches")
    
    # Batch processing loop
    chunk_iter = pd.read_csv(BUILDINGS_PATH, chunksize=BATCH_SIZE)
    total_processed = 0
    
    for batch_idx, df_batch in enumerate(tqdm(chunk_iter, desc="Processing", total=total_lines//BATCH_SIZE + 1)):
        # Convert batch to GeoDataFrame
        try:
            gdf_batch = gpd.GeoDataFrame(
                df_batch,
                geometry=gpd.GeoSeries.from_wkt(df_batch['geometry']),
                crs='EPSG:4326'
            )
            gdf_batch_proj = gdf_batch.to_crs(TARGET_CRS)
        except Exception as e:
            print(f"Batch {batch_idx} conversion failed, skipping: {e}")
            continue
        
        # Filter low-confidence buildings
        gdf_batch_filtered = gdf_batch_proj[gdf_batch_proj['confidence'] >= CONFIDENCE_THRESHOLD].copy()
        if len(gdf_batch_filtered) == 0:
            total_processed += len(df_batch)
            continue
        
        # Use spatial index to find candidate polygons
        batch_bounds = gdf_batch_filtered.total_bounds
        possible_matches_idx = list(polygon_sindex.intersection(batch_bounds))
        possible_matches = gdf_polygons_proj.iloc[possible_matches_idx]
        
        if len(possible_matches) == 0:
            total_processed += len(df_batch)
            continue
        
        # Clip buildings to candidate polygon bounds
        possible_bounds = possible_matches.total_bounds
        gdf_batch_clipped = gdf_batch_filtered.cx[possible_bounds[0]:possible_bounds[2], 
                                                    possible_bounds[1]:possible_bounds[3]]
        
        if len(gdf_batch_clipped) == 0:
            total_processed += len(df_batch)
            continue
        
        # Spatial join (only on candidate polygons)
        joined = gpd.sjoin(
            possible_matches[['poly_id', 'geometry']],
            gdf_batch_clipped[['area_in_meters', 'confidence', 'geometry']],
            how='inner',
            predicate='contains'
        )
        
        # Incrementally update results
        if 'poly_id' in joined.columns and len(joined) > 0:
            for _, row in joined.iterrows():
                poly_id = row['poly_id']
                area = row['area_in_meters']
                conf = row['confidence']
                
                if poly_id in poly_id_to_idx:
                    idx = poly_id_to_idx[poly_id]
                    results['total_buildings'][idx] += 1
                    results['total_area_sqm'][idx] += area
                    results['total_confidence'][idx] += conf
                    results['area_sq_sum'][idx] += area * area
        
        total_processed += len(df_batch)
        
        # Print progress every 10 batches
        if (batch_idx + 1) % 10 == 0:
            current_count = sum(results['total_buildings'])
            print(f"\n  Processed {total_processed:,} / {total_lines:,} buildings")
            print(f"Found {current_count:,} buildings inside polygons")
    
    print(f"\nBatch processing complete! Found {sum(results['total_buildings']):,} total buildings")
    return results

def calculate_statistics(results, gdf_polygons):
    """Calculate final statistics and merge with polygon attributes"""
    print("\n" + "="*70)
    print("Step 3/6: Calculating Final Statistics")
    print("="*70)
    
    # Convert to DataFrame
    building_stats = pd.DataFrame(results)
    
    # Calculate averages
    building_stats['avg_area_sqm'] = building_stats.apply(
        lambda row: row['total_area_sqm'] / row['total_buildings'] if row['total_buildings'] > 0 else 0,
        axis=1
    ).round(2)
    
    building_stats['avg_confidence'] = building_stats.apply(
        lambda row: row['total_confidence'] / row['total_buildings'] if row['total_buildings'] > 0 else 0,
        axis=1
    ).round(2)
    
    # Merge with polygon attributes
    building_stats = pd.merge(
        building_stats,
        gdf_polygons[['poly_id', 'plant_yr', 'country', 'proj_id']],
        on='poly_id',
        how='left'
    )
    
    # Reorder columns
    building_stats = building_stats[[
        'poly_id', 'total_buildings', 'total_area_sqm', 
        'avg_area_sqm', 'avg_confidence',
        'plant_yr', 'country', 'proj_id'
    ]]
    
    return building_stats

def generate_summaries(building_stats):
    """Generate overall and year-by-year summary statistics"""
    print("\n" + "="*70)
    print("Step 4/6: Generating Summary Statistics")
    print("="*70)
    
    # Yearly summary
    year_summary = building_stats.groupby('plant_yr').agg(
        polygon_count=('poly_id', 'count'),
        polygons_with_buildings=('total_buildings', lambda x: (x>0).sum()),
        avg_buildings_per_polygon=('total_buildings', 'mean'),
        avg_total_area_sqm=('total_area_sqm', 'mean'),
        total_area_sqkm=('total_area_sqm', lambda x: (x.sum()/1000000).round(2))
    ).round(2)
    
    # Overall summary
    overall_summary = pd.DataFrame({
        'metric': [
            'Total polygons', 'Polygons with buildings', 'Polygons without buildings',
            'Total buildings', 'Total area (sq km)',
            'Avg buildings per polygon', 'Avg building area (sq m)'
        ],
        'value': [
            len(building_stats),
            len(building_stats[building_stats['total_buildings'] > 0]),
            len(building_stats[building_stats['total_buildings'] == 0]),
            building_stats['total_buildings'].sum(),
            (building_stats['total_area_sqm'].sum() / 1000000).round(2),
            building_stats['total_buildings'].mean().round(2),
            building_stats[building_stats['total_buildings'] > 0]['avg_area_sqm'].mean().round(2)
        ]
    })
    
    # Print results
    print("\nOverall Summary")
    print(overall_summary.to_string(index=False))
    
    print("\nYearly Summary")
    print(year_summary.to_string())
    
    print("\nTop 10 Polygons")
    print(building_stats.head(10).to_string())
    
    return year_summary, overall_summary

def save_results(building_stats, year_summary, overall_summary):
    """Save all results to CSV files"""
    print("\n" + "="*70)
    print("Step 5/6: Saving Results")
    print("="*70)
    
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    building_stats.to_csv(os.path.join(OUTPUT_DIR, "polygon_building_stats.csv"), index=False, encoding='utf-8-sig')
    year_summary.to_csv(os.path.join(OUTPUT_DIR, "yearly_building_summary.csv"), encoding='utf-8-sig')
    overall_summary.to_csv(os.path.join(OUTPUT_DIR, "overall_building_summary.csv"), index=False, encoding='utf-8-sig')
    
    print(f"Results saved to: {OUTPUT_DIR}")

def visualize_results(building_stats, year_summary, gdf_polygons):
    """Generate visualization plots"""
    print("\n" + "="*70)
    print("Step 6/6: Generating Visualizations")
    print("="*70)
    
    # Merge stats with polygons for visualization
    gdf_polygons_vis = gdf_polygons.merge(building_stats, on='poly_id', how='left')
    gdf_polygons_vis = gdf_polygons_vis.to_crs(TARGET_CRS)
    
    # Plot 1: Building Density Map
    print("Generating density map...")
    fig, ax = plt.subplots(figsize=(14, 12))
    
    # Categorize building counts
    gdf_polygons_vis['building_category'] = pd.cut(
        gdf_polygons_vis['total_buildings'],
        bins=[-1, 0, 10, 100, 1000, float('inf')],
        labels=['No Buildings', '1-10', '11-100', '101-1000', '1000+']
    )
    
    # Plot categories
    color_map = {
        'No Buildings': '#d3d3d3',
        '1-10': '#ffcc80',
        '11-100': '#ff9800',
        '101-1000': '#f57c00',
        '1000+': '#e65100'
    }
    
    for category, color in color_map.items():
        subset = gdf_polygons_vis[gdf_polygons_vis['building_category'] == category]
        if len(subset) > 0:
            subset.plot(ax=ax, facecolor=color, edgecolor='black', linewidth=0.5, label=category)
    
    # Create legend
    legend_elements = [mpatches.Patch(color=color, label=cat) for cat, color in color_map.items()]
    ax.legend(handles=legend_elements, loc='upper right', title='Building Count')
    ax.set_title('Building Density in Ethiopian Afforestation Zones', fontsize=16, pad=20)
    ax.set_xlabel('Easting (m)')
    ax.set_ylabel('Northing (m)')
    plt.tight_layout()
    plt.savefig(os.path.join(OUTPUT_DIR, "building_density_map.png"), dpi=300, bbox_inches='tight')
    print("Density map saved")
    
    # Plot 2: Yearly Statistics
    print("\nGenerating yearly stats plot...")
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 6))
    
    # Remove 2024 outlier and calculate ratios
    year_summary_no_outlier = year_summary[year_summary.index != 2024.0].copy()
    year_summary_no_outlier = year_summary_no_outlier.assign(
        buildings_ratio=lambda x: x['polygons_with_buildings'] / x['polygon_count'] * 100
    )
    year_summary_no_outlier.index = year_summary_no_outlier.index.astype(int).astype(str)
    
    # Left plot: Average buildings
    ax1.bar(year_summary_no_outlier.index, 
            year_summary_no_outlier['avg_buildings_per_polygon'], 
            color='#ff7f0e', edgecolor='black')
    ax1.set_title('Avg Buildings per Polygon by Planting Year (Excl. 2024 Outlier)', fontsize=12, pad=10)
    ax1.set_xlabel('Planting Year')
    ax1.set_ylabel('Avg Buildings per Polygon')
    ax1.grid(axis='y', linestyle='--', alpha=0.7)
    
    # Right plot: Ratio of polygons with buildings
    ax2.bar(year_summary_no_outlier.index, 
            year_summary_no_outlier['buildings_ratio'], 
            color='#2ca02c', edgecolor='black')
    ax2.set_title('Ratio of Polygons with Buildings by Planting Year (Excl. 2024 Outlier)', fontsize=12, pad=10)
    ax2.set_xlabel('Planting Year')
    ax2.set_ylabel('Polygons with Buildings (%)')
    ax2.grid(axis='y', linestyle='--', alpha=0.7)
    
    plt.tight_layout()
    plt.savefig(os.path.join(OUTPUT_DIR, "yearly_building_stats.png"), dpi=300, bbox_inches='tight')
    print("Yearly stats plot saved")
    
    plt.show()

def merge_road_data(building_stats):
    """Merge road statistics with building statistics"""
    print("\n" + "="*70)
    print("Merging Road & Building Statistics")
    print("="*70)
    
    if os.path.exists(ROAD_STATS_PATH):
        road_stats = pd.read_csv(ROAD_STATS_PATH)
        combined_stats = pd.merge(
            road_stats,
            building_stats,
            on='poly_id',
            how='outer',
            suffixes=('_road', '_building')
        )
        combined_path = os.path.join(OUTPUT_DIR, "road_building_combined_stats.csv")
        combined_stats.to_csv(combined_path, index=False, encoding='utf-8-sig')
        print(f"Merge complete! File saved to: {combined_path}")
    else:
        print("Road stats file not found, skipping merge")

# -------------------------- MAIN EXECUTION --------------------------
if __name__ == "__main__":
    # Step 1: Load polygons
    gdf_polygons, gdf_polygons_proj, polygon_sindex, results, poly_id_to_idx = load_polygons()
    
    # Step 2: Process buildings
    results = process_buildings(gdf_polygons_proj, polygon_sindex, results, poly_id_to_idx)
    
    # Step 3: Calculate statistics
    building_stats = calculate_statistics(results, gdf_polygons)
    
    # Step 4: Generate summaries
    year_summary, overall_summary = generate_summaries(building_stats)
    
    # Step 5: Save results
    save_results(building_stats, year_summary, overall_summary)
    
    # Step 6: Visualize
    visualize_results(building_stats, year_summary, gdf_polygons)
    
    # Step 7: Merge road data
    merge_road_data(building_stats)
    
    print("\n" + "="*70)
    print("All Analysis Complete!")
    print("="*70)
```

---

## Output Files

All results are saved to the `\./stats\_results` directory:

|File Name|Description|
|---|---|
|`polygon\_road\_stats\.csv`|Detailed road statistics per polygon \(count, length, type\)|
|`yearly\_road\_summary\.csv`|Road statistics aggregated by planting year|
|`overall\_road\_summary\.csv`|Overall road statistics summary|
|`polygon\_building\_stats\.csv`|Detailed building statistics per polygon \(count, area, confidence\)|
|`yearly\_building\_summary\.csv`|Building statistics aggregated by planting year|
|`overall\_building\_summary\.csv`|Overall building statistics summary|
|`road\_building\_combined\_stats\.csv`|Merged road and building statistics for combined analysis|
|`afforestation\_roads\_overlay\.png`|Map showing afforestation zones and road network|
|`yearly\_avg\_road\_length\.png`|Bar chart of average road length by planting year|
|`building\_density\_map\.png`|Choropleth map of building density in afforestation zones|
|`yearly\_building\_stats\.png`|Dual bar chart of building count and coverage ratio by year|

---

## Usage Instructions

### 1\. Data Preparation

1. Create a `\./data` directory with the following subdirectories:

    - `\./data/osm`: Place OSM shapefiles here

    - `\./data/google\_buildings`: Place Google Open Buildings CSV\.gz files here

    - `\./data/afforestation\_polygons`: Place your afforestation polygon shapefile here

2. Update the `POLYGON\_PATH` in both scripts to point to your polygon file

### 2\. Run Analysis

```Bash
# First run road analysis
python osm_road_stats.py

# Then run building analysis
python google_buildings_batch.py
```

### 3\. Adjust Parameters

- `BATCH\_SIZE`: Adjust based on available RAM \(50,000 for 8GB, 100,000 for 16GB\)

- `CONFIDENCE\_THRESHOLD`: Filter low\-confidence buildings \(default: 0\.7\)

- `TARGET\_CRS`: Update to the appropriate projected CRS for your study area

---

## GitHub File Upload Notes

- **File Size Limit**: GitHub has a 100MB per\-file limit\. For large output files:

    - Use Git LFS to track large CSV and image files

    - Or host large files on a cloud storage service \(Google Drive, Dropbox\) and provide download links in the README

- **Recommended Uploads**: Include all code files, small CSV summaries, and visualization images\. Raw data files are not recommended for GitHub upload\.

