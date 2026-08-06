import ee

ee.Initialize(project='ee-ywang390')

countries_list = [
    'Algeria',
    'Angola',
    'Benin',
    'Botswana',
    'Burkina Faso',
    'Burundi',
    'Cameroon',
    'Cape Verde',
    'Central African Republic',
    'Chad',
    'Comoros',
    'Congo',
    'Democratic Republic of the Congo',
    "Cote d'Ivoire",
    'Djibouti',
    'Egypt',
    'Equatorial Guinea',
    'Eritrea',
    'Ethiopia',
    'Gabon',
    'Gambia',
    'Ghana',
    'Guinea',
    'Guinea-Bissau',
    'Kenya',
    'Lesotho',
    'Liberia',
    'Libya',
    'Madagascar',
    'Malawi',
    'Mali',
    'Mauritania',
    'Mauritius',
    'Morocco',
    'Mozambique',
    'Namibia',
    'Niger',
    'Nigeria',
    'Rwanda',
    'Sao Tome and Principe',
    'Senegal',
    'Seychelles',
    'Sierra Leone',
    'Somalia',
    'South Africa',
    'South Sudan',
    'Sudan',
    'Swaziland',
    'Tanzania',
    'Togo',
    'Tunisia',
    'Uganda',
    'Zambia',
    'Zimbabwe',
]

years = range(2000, 2025)
countries_fc = ee.FeatureCollection('USDOS/LSIB_SIMPLE/2017')

submitted = 0
failed = 0

for country_name in countries_list:
    country_geom = countries_fc.filter(
        ee.Filter.eq('country_na', country_name)
    ).geometry()

    code = country_name.replace(' ', '_').replace("'", '').replace('.', '')

    for year in years:
        try:
            dataset = ee.ImageCollection('LANDSAT/COMPOSITES/C02/T1_L2_ANNUAL_NDVI') \
                .filterDate(f'{year}-01-01', f'{year}-12-31')

            ndvi = dataset.mosaic().select('NDVI').clip(country_geom)

            task = ee.batch.Export.image.toDrive(
                image=ndvi,
                description=f'NDVI_{code}_{year}',
                folder=f'NDVI_Africa/{code}',
                fileNamePrefix=f'ndvi_{code}_{year}',
                region=country_geom,
                scale=120,
                maxPixels=1e13,
                crs='EPSG:4326',
                fileFormat='GeoTIFF'
            )
            task.start()
            submitted += 1
            print(f'Submitted: {country_name} {year}  [{submitted} total]')

        except Exception as e:
            failed += 1
            print(f'FAILED: {country_name} {year} — {e}')

print(f'\nDone! {submitted} tasks submitted, {failed} failed.')