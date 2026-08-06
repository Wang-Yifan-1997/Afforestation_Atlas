"""
Batch process ALL African countries through Google Earth Engine
UPDATED: Simple if-check for zero-area polygons
"""

import ee
import time
from datetime import datetime

# =============================================================================
# STEP 1: AUTHENTICATE AND INITIALIZE
# =============================================================================

print("="*70)
print("GOOGLE EARTH ENGINE BATCH PROCESSOR - ALL COUNTRIES")
print("="*70)

print("\nAuthenticating...")

try:
    ee.Initialize(project='ee-ywang390')
    print("✓ Initialized with project: ee-ywang390")
except Exception as e:
    print(f"✗ Initialization failed: {e}")
    exit(1)

# =============================================================================
# STEP 2: CONFIGURATION
# =============================================================================

print("\nLoading configuration...")

# **ALL 37 COUNTRIES**
COUNTRIES = [
    {'asset': 'angola_treated_polygons', 'name': 'Angola'},
    {'asset': 'botswana_treated_polygons', 'name': 'Botswana'},
    {'asset': 'burkina_faso_treated_polygons', 'name': 'Burkina Faso'},
    {'asset': 'burundi_treated_polygons', 'name': 'Burundi'},
    {'asset': 'c_te_d_ivoire_treated_polygons', 'name': "Cote d'Ivoire"},
    {'asset': 'cameroon_treated_polygons', 'name': 'Cameroon'},
    {'asset': 'central_african_rep__treated_polygons', 'name': 'Central African Rep'},  # FIXED
    {'asset': 'chad_treated_polygons', 'name': 'Chad'},
    {'asset': 'congo_treated_polygons', 'name': 'Rep of the Congo'},  # FIXED
    {'asset': 'dem_rep_congo_treated_polygons', 'name': 'Dem Rep of the Congo'},  # FIXED
    {'asset': 'ethiopia_treated_polygons', 'name': 'Ethiopia'},
    {'asset': 'gabon_treated_polygons', 'name': 'Gabon'},
    {'asset': 'gambia_treated_polygons', 'name': 'Gambia, The'},  # FIXED
    {'asset': 'ghana_treated_polygons', 'name': 'Ghana'},
    {'asset': 'guinea_bissau_treated_polygons', 'name': 'Guinea-Bissau'},
    {'asset': 'guinea_treated_polygons', 'name': 'Guinea'},
    {'asset': 'kenya_treated_polygons', 'name': 'Kenya'},
    {'asset': 'lesotho_treated_polygons', 'name': 'Lesotho'},
    {'asset': 'madagascar_treated_polygons', 'name': 'Madagascar'},
    {'asset': 'malawi_treated_polygons', 'name': 'Malawi'},
    {'asset': 'mali_treated_polygons', 'name': 'Mali'},
    {'asset': 'mauritania_treated_polygons', 'name': 'Mauritania'},
    {'asset': 'morocco_treated_polygons', 'name': 'Morocco'},
    {'asset': 'mozambique_treated_polygons', 'name': 'Mozambique'},
    {'asset': 'namibia_treated_polygons', 'name': 'Namibia'},
    {'asset': 'niger_treated_polygons', 'name': 'Niger'},
    {'asset': 'nigeria_treated_polygons', 'name': 'Nigeria'},
    {'asset': 'rwanda_treated_polygons', 'name': 'Rwanda'},
    {'asset': 's_sudan_treated_polygons', 'name': 'South Sudan'},
    {'asset': 'senegal_treated_polygons', 'name': 'Senegal'},
    {'asset': 'sierra_leone_treated_polygons', 'name': 'Sierra Leone'},
    {'asset': 'south_africa_treated_polygons', 'name': 'South Africa'},
    {'asset': 'tanzania_treated_polygons', 'name': 'Tanzania'},
    {'asset': 'togo_treated_polygons', 'name': 'Togo'},
    {'asset': 'uganda_treated_polygons', 'name': 'Uganda'},
    {'asset': 'zambia_treated_polygons', 'name': 'Zambia'},
    {'asset': 'zimbabwe_treated_polygons', 'name': 'Zimbabwe'},
]

START_YEAR = 2000
END_YEAR = 2024
NUM_CONTROLS_PER_TREATED = 100
PROJECT_PATH = 'projects/ee-ywang390/assets'
EXPORT_FOLDER = 'GEE_Extracts'

print(f"✓ Will process {len(COUNTRIES)} countries")
print(f"✓ Years: {START_YEAR}-{END_YEAR}")
print(f"✓ Controls per treated polygon: {NUM_CONTROLS_PER_TREATED}")
print(f"✓ Output folder: {EXPORT_FOLDER}")

# =============================================================================
# STEP 3: DEFINE EXTRACTION FUNCTIONS
# =============================================================================

def generate_control_polygons(treated_polygons, country_boundary, num_controls):
    """Generate random control polygons for each treated polygon"""
    
    def generate_controls_for_one(treated_feature):
        treated_geom = treated_feature.geometry()
        treated_area = treated_geom.area()
        
        # **SIMPLE FIX: Return empty if area is 0**
        return ee.Algorithms.If(
            treated_area.gt(0),
            generate_controls_with_area(treated_feature, treated_geom, treated_area, num_controls, country_boundary),
            ee.FeatureCollection([])  # Return empty if zero area
        )
    
    def generate_controls_with_area(treated_feature, treated_geom, treated_area, num_controls, country_boundary):
        treated_id = treated_feature.get('poly_id')
        planting_year = treated_feature.get('plant_yr')
        country = treated_feature.get('country')
        
        # Get all IDs from treated polygon
        ctry_id = treated_feature.get('ctry_id')
        proj_id = treated_feature.get('proj_id')
        site_id = treated_feature.get('site_id')
        site_rpt = treated_feature.get('site_rpt')
        
        radius = ee.Number(treated_area).divide(3.14159).sqrt()
        
        control_points = ee.FeatureCollection.randomPoints(
            region=country_boundary.difference(treated_geom.buffer(1000)),
            points=num_controls,
            seed=ee.Number(treated_id).toInt()
        )
        
        return control_points.map(lambda point: 
            ee.Feature(point.buffer(radius)).set({
                'treated_polygon_id': treated_id,
                'plant_yr': planting_year,
                'country': country,
                'ctry_id': ctry_id,
                'proj_id': proj_id,
                'site_id': site_id,
                'site_rpt': site_rpt
            })
        )
    
    all_controls = treated_polygons.map(generate_controls_for_one).flatten()
    
    controls_list = all_controls.toList(all_controls.size())
    num_controls_total = all_controls.size()
    
    def add_control_id(i):
        feature = ee.Feature(controls_list.get(i))
        return feature.set('control_id', ee.Number(i).add(1))
    
    controls_with_ids = ee.FeatureCollection(
        ee.List.sequence(0, num_controls_total.subtract(1)).map(add_control_id)
    )
    
    return controls_with_ids


def extract_covariates(polygons, id_field, is_treated):
    """Extract Hansen and NDVI covariates for polygons"""
    
    hansen = ee.Image('UMD/hansen/global_forest_change_2024_v1_12')
    treecover2000 = hansen.select('treecover2000')
    loss_year = hansen.select('lossyear')
    gain = hansen.select('gain')
    
    ndvi_landsat = ee.ImageCollection('LANDSAT/COMPOSITES/C02/T1_L2_ANNUAL_NDVI').select('NDVI')
    ndvi_modis = ee.ImageCollection('MODIS/061/MOD13A1').select('NDVI')
    
    reducer = ee.Reducer.mean().combine(
        ee.Reducer.median(), '', True
    ).combine(
        ee.Reducer.stdDev(), '', True
    )
    
    def create_props(f, year, variable, id_field, is_treated):
        props = {
            'year': year,
            'variable': variable,
            'mean': f.get('mean'),
            'median': f.get('median'),
            'sd': f.get('stdDev'),
            'country': f.get('country'),
            'plant_yr': f.get('plant_yr')
        }
        props[id_field] = f.get(id_field)
        
        if is_treated:
            props['ctry_id'] = f.get('ctry_id')
            props['proj_id'] = f.get('proj_id')
            props['site_id'] = f.get('site_id')
            props['site_rpt'] = f.get('site_rpt')
        else:
            props['treated_polygon_id'] = f.get('treated_polygon_id')
            props['ctry_id'] = f.get('ctry_id')
            props['proj_id'] = f.get('proj_id')
            props['site_id'] = f.get('site_id')
            props['site_rpt'] = f.get('site_rpt')
        
        return ee.Feature(None, props)
    
    hansen_baseline = treecover2000.reduceRegions(
        collection=polygons,
        reducer=reducer,
        scale=30,
        tileScale=4
    ).map(lambda f: create_props(f, 2000, 'hansen_treecover', id_field, is_treated))
    
    hansen_loss = loss_year.reduceRegions(
        collection=polygons,
        reducer=reducer,
        scale=30,
        tileScale=4
    ).map(lambda f: create_props(f, 2000, 'hansen_lossyear', id_field, is_treated))
    
    hansen_gain = gain.reduceRegions(
        collection=polygons,
        reducer=reducer,
        scale=30,
        tileScale=4
    ).map(lambda f: create_props(f, 2000, 'hansen_gain', id_field, is_treated))
    
    def extract_landsat_year(year):
        year = ee.Number(year)
        ndvi_year = ndvi_landsat.filterDate(
            ee.Date.fromYMD(year, 1, 1),
            ee.Date.fromYMD(year, 12, 31)
        ).filterBounds(polygons.geometry()).mosaic()
        
        return ndvi_year.reduceRegions(
            collection=polygons,
            reducer=reducer,
            scale=120,
            tileScale=4
        ).map(lambda f: create_props(f, year, 'landsat_ndvi', id_field, is_treated))
    
    landsat_ndvi = ee.FeatureCollection(
        ee.List.sequence(START_YEAR, END_YEAR).map(extract_landsat_year)
    ).flatten()
    
    def extract_modis_year(year):
        year = ee.Number(year)
        modis_year = ndvi_modis.filter(
            ee.Filter.calendarRange(year, year, 'year')
        ).filterBounds(polygons.geometry()).mean().multiply(0.0001)
        
        return modis_year.reduceRegions(
            collection=polygons,
            reducer=reducer,
            scale=500,
            tileScale=4
        ).map(lambda f: create_props(f, year, 'modis_ndvi', id_field, is_treated))
    
    modis_ndvi = ee.FeatureCollection(
        ee.List.sequence(START_YEAR, END_YEAR).map(extract_modis_year)
    ).flatten()
    
    return hansen_baseline.merge(hansen_loss).merge(hansen_gain).merge(landsat_ndvi).merge(modis_ndvi)


def process_country(asset_name, country_name):
    """Process one country: load data, generate controls, extract covariates, submit tasks"""
    
    print(f"\n{'='*70}")
    print(f"Processing: {country_name}")
    print(f"{'='*70}")
    
    tasks_submitted = []
    
    try:
        print("  [1/6] Loading treated polygons...", end=" ")
        treated_polygons = ee.FeatureCollection(f'{PROJECT_PATH}/{asset_name}')
        n_treated = treated_polygons.size().getInfo()
        print(f"✓ ({n_treated} polygons)")
        
        print("  [2/6] Loading country boundary...", end=" ")
        countries_fc = ee.FeatureCollection('USDOS/LSIB_SIMPLE/2017')
        country_boundary = countries_fc.filter(ee.Filter.eq('country_na', country_name)).geometry()
        print("✓")
        
        print(f"  [3/6] Generating {NUM_CONTROLS_PER_TREATED} control polygons per treated...", end=" ")
        control_polygons = generate_control_polygons(treated_polygons, country_boundary, NUM_CONTROLS_PER_TREATED)
        n_controls = control_polygons.size().getInfo()
        print(f"✓ ({n_controls} total controls)")
        
        print("  [4/6] Extracting covariates for treated polygons...", end=" ")
        treated_data = extract_covariates(treated_polygons, 'poly_id', is_treated=True)
        print("✓")
        
        print("  [5/6] Extracting covariates for control polygons...", end=" ")
        control_data = extract_covariates(control_polygons, 'control_id', is_treated=False)
        print("✓")
        
        print("  [6/6] Submitting export tasks...")
        
        export_country_name = asset_name.replace('_treated_polygons', '')
        
        task1 = ee.batch.Export.table.toDrive(
            collection=treated_polygons.select(['poly_id', 'ctry_id', 'proj_id', 'site_id', 'site_rpt', 'country', 'plant_yr']),
            description=f'{export_country_name}_treated_geometry',
            folder=EXPORT_FOLDER,
            fileNamePrefix=f'{export_country_name}_treated_geometry',
            fileFormat='GeoJSON'
        )
        task1.start()
        tasks_submitted.append(task1.id)
        print(f"    ✓ {export_country_name}_treated_geometry")
        
        task2 = ee.batch.Export.table.toDrive(
            collection=control_polygons.select(['control_id', 'treated_polygon_id', 'ctry_id', 'proj_id', 'site_id', 'site_rpt', 'country', 'plant_yr']),
            description=f'{export_country_name}_control_geometry',
            folder=EXPORT_FOLDER,
            fileNamePrefix=f'{export_country_name}_control_geometry',
            fileFormat='GeoJSON'
        )
        task2.start()
        tasks_submitted.append(task2.id)
        print(f"    ✓ {export_country_name}_control_geometry")
        
        task3 = ee.batch.Export.table.toDrive(
            collection=treated_data,
            description=f'{export_country_name}_treated_covariates',
            folder=EXPORT_FOLDER,
            fileNamePrefix=f'{export_country_name}_treated_covariates',
            fileFormat='CSV',
            selectors=['poly_id', 'ctry_id', 'proj_id', 'site_id', 'site_rpt', 'year', 'variable', 'mean', 'median', 'sd', 'country', 'plant_yr']
        )
        task3.start()
        tasks_submitted.append(task3.id)
        print(f"    ✓ {export_country_name}_treated_covariates")
        
        task4 = ee.batch.Export.table.toDrive(
            collection=control_data,
            description=f'{export_country_name}_control_covariates',
            folder=EXPORT_FOLDER,
            fileNamePrefix=f'{export_country_name}_control_covariates',
            fileFormat='CSV',
            selectors=['control_id', 'treated_polygon_id', 'ctry_id', 'proj_id', 'site_id', 'site_rpt', 'year', 'variable', 'mean', 'median', 'sd', 'country', 'plant_yr']
        )
        task4.start()
        tasks_submitted.append(task4.id)
        print(f"    ✓ {export_country_name}_control_covariates")
        
        print(f"\n  ✓ SUCCESS: {len(tasks_submitted)} tasks submitted for {country_name}")
        return tasks_submitted
        
    except Exception as e:
        print(f"\n  ✗ ERROR: {str(e)}")
        return []


# =============================================================================
# STEP 4: PROCESS ALL COUNTRIES
# =============================================================================

print("\n" + "="*70)
print("PROCESSING ALL 37 COUNTRIES")
print("="*70)

all_tasks = []
successful = []
failed = []
start_time = datetime.now()

for i, country in enumerate(COUNTRIES, 1):
    print(f"\n[{i}/{len(COUNTRIES)}]", end=" ")
    
    try:
        tasks = process_country(country['asset'], country['name'])
        if tasks:
            all_tasks.extend(tasks)
            successful.append(country['name'])
        else:
            failed.append(country['name'])
        
        if i < len(COUNTRIES):
            print("\n  Waiting 5 seconds before next country...")
            time.sleep(5)
            
    except Exception as e:
        print(f"\n  ✗ FAILED: {str(e)}")
        failed.append(country['name'])
        continue

# =============================================================================
# STEP 5: SUMMARY
# =============================================================================

end_time = datetime.now()
duration = (end_time - start_time).total_seconds()

print("\n" + "="*70)
print("BATCH PROCESSING COMPLETE!")
print("="*70)
print(f"\nSummary:")
print(f"  Total countries: {len(COUNTRIES)}")
print(f"  Successful: {len(successful)}")
print(f"  Failed: {len(failed)}")
print(f"  Total tasks submitted: {len(all_tasks)}")
print(f"  Processing time: {duration/60:.1f} minutes")

if failed:
    print(f"\n✗ Failed countries:")
    for name in failed:
        print(f"  - {name}")

print(f"\nAll files in Google Drive folder: {EXPORT_FOLDER}")
print(f"Monitor at: https://code.earthengine.google.com → Tasks tab")
print(f"Expected completion: 2-8 hours")
print("="*70)