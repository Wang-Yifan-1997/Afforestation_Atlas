"""
Check all country names against GEE database
"""

import ee

ee.Initialize(project='ee-ywang390')

# Your current country list
YOUR_COUNTRIES = [
    {'asset': 'angola_treated_polygons', 'name': 'Angola'},
    {'asset': 'botswana_treated_polygons', 'name': 'Botswana'},
    {'asset': 'burkina_faso_treated_polygons', 'name': 'Burkina Faso'},
    {'asset': 'burundi_treated_polygons', 'name': 'Burundi'},
    {'asset': 'c_te_d_ivoire_treated_polygons', 'name': "Cote d'Ivoire"},
    {'asset': 'cameroon_treated_polygons', 'name': 'Cameroon'},
    {'asset': 'central_african_rep__treated_polygons', 'name': 'Central African Republic'},
    {'asset': 'chad_treated_polygons', 'name': 'Chad'},
    {'asset': 'congo_treated_polygons', 'name': 'Republic of the Congo'},
    {'asset': 'dem_rep_congo_treated_polygons', 'name': 'Democratic Republic of the Congo'},
    {'asset': 'ethiopia_treated_polygons', 'name': 'Ethiopia'},
    {'asset': 'gabon_treated_polygons', 'name': 'Gabon'},
    {'asset': 'gambia_treated_polygons', 'name': 'The Gambia'},
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

# Get all GEE country names
print("Loading GEE country database...")
countries_fc = ee.FeatureCollection('USDOS/LSIB_SIMPLE/2017')
gee_country_names = countries_fc.aggregate_array('country_na').getInfo()
gee_country_names_set = set(gee_country_names)

print(f"✓ Found {len(gee_country_names_set)} countries in GEE database\n")

# Check each of your countries
print("="*70)
print("CHECKING YOUR COUNTRY NAMES")
print("="*70)

correct = []
incorrect = []

for country in YOUR_COUNTRIES:
    your_name = country['name']
    
    # Check exact match
    if your_name in gee_country_names_set:
        print(f"✓ {your_name:<40} MATCH")
        correct.append(country)
    else:
        print(f"✗ {your_name:<40} NO MATCH")
        incorrect.append(country)

# For incorrect names, suggest alternatives
if incorrect:
    print("\n" + "="*70)
    print("SUGGESTIONS FOR INCORRECT NAMES")
    print("="*70)
    
    for country in incorrect:
        your_name = country['name']
        asset = country['asset']
        
        print(f"\n'{your_name}' (asset: {asset})")
        print("  Possible matches in GEE:")
        
        # Find similar names
        similar = []
        keywords = your_name.lower().split()
        
        for gee_name in gee_country_names_set:
            gee_lower = gee_name.lower()
            # Check if any keyword matches
            if any(keyword in gee_lower for keyword in keywords):
                similar.append(gee_name)
        
        if similar:
            for s in sorted(similar):
                print(f"    - {s}")
        else:
            print(f"    - No similar names found")
            print(f"    - Try searching manually in full list below")

# Print summary
print("\n" + "="*70)
print("SUMMARY")
print("="*70)
print(f"Correct: {len(correct)}/{len(YOUR_COUNTRIES)}")
print(f"Need fixing: {len(incorrect)}/{len(YOUR_COUNTRIES)}")

if incorrect:
    print("\nCountries that need fixing:")
    for country in incorrect:
        print(f"  - {country['name']}")

# Print full GEE list for African countries
print("\n" + "="*70)
print("ALL AFRICAN COUNTRIES IN GEE DATABASE")
print("="*70)

african_keywords = [
    'angola', 'botswana', 'burkina', 'burundi', 'cameroon', 'central african',
    'chad', 'congo', 'ethiopia', 'gabon', 'gambia', 'ghana', 'guinea', 'ivory',
    'cote', 'kenya', 'lesotho', 'madagascar', 'malawi', 'mali', 'mauritania',
    'morocco', 'mozambique', 'namibia', 'niger', 'nigeria', 'rwanda', 'senegal',
    'sierra leone', 'south africa', 'sudan', 'tanzania', 'togo', 'uganda',
    'zambia', 'zimbabwe'
]

african_countries = []
for name in gee_country_names:
    name_lower = name.lower()
    if any(keyword in name_lower for keyword in african_keywords):
        african_countries.append(name)

for name in sorted(african_countries):
    print(f"  - {name}")

print("\n" + "="*70)
print("DONE!")
print("="*70)