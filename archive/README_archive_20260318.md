# Afforestation Atlas Task

GEE: 
1. process NDVI data for every Africa country. currently our batch processing code works for 10+ countries but there are 20+ countries failed
2. Do it with different source of NDVI, do if for other measurement of forest cover (for example, hansen) or biostock.
3. do it for different measure of nighttime light, for example, nighttime light and landuse (which can be informative of industry composition)
4. understand what's the pros and cons of different measure of these data. what's the potential additional robustness we can do. what's the raw data source (which satellite, launched in which year etc.)
5. road data, building data etc to see if there is human activities before the project; we can also if there is new building or road being build, how does it impact the afforestation program

afforestation projects:
1. basic descriptives: the total number of projects, number of projeccts by country, by year. number of projects with valid location. the map of the projects country by country
2. further data cleaning for the project data: some projects may be overleapping -- different agent report the same project in different programs. use spatial join to make sure we do not double count (and use the raw data as robustness since we might make mistakes in this step).
3. are there any other source of afforestation projects. if these other sources are subsample or our data or complement (i know 3 extra data: one dataset is the paper withdrawed the publication of the data because of the data provider -- Restor Eco. this one we for sure missing. another source https://reforestation.app. it has some extra information which is useful. another one is https://gspp.berkeley.edu/berkeley-carbon-trading-project/offsets-database).
4. for all the other datasets, and also for the original dataset we use, write a memo to document what might be potential source of missing -- the original paper describes some reasons. for example, China's Green Great Wall is likely not covered. 
5. what additional information we can get for these projects. do we know the kinds of trees, do we know who are the agent -- NGO? government? firms? they may have different incentives. do we know more detailed implementation practice? how thet do it? do they share profits with local community. are there government enforcement etc.
6. for a subsample of the projects, we may know the detailed project pdf. it might be hundred of pages. can we use LLM to extract the information, and generate rich variables in a structured way. then we can run some additional analysis on this subsample (of course also replicate all the previous analysis with this subsample)

forest policy:
1. https://www.fao.org/faolex/background/en/
2. read some example of the policy document and summarize what can we learn from the policy document. what's the timing, who are the agent, how stringent is the policy. what's the potential cost of the policy. are there coordinations with other types of government policy or department.
3. then once we build a solid understanding of the policy document, put the policy text into LLM (two NBER example papers on this and worth checking their pipeline).
4. what's the coverage of the dataset. are there other data source that are available. can we check if we systematically miss any policies or it covers almost all of it or it's a good random representative sample.
5. potential analysis: what's the impact of the policy, are there policy complementarity, are they cost effective (welfare), what makes government to enact these policies (structural transformation?)

survey data:
1. DHS data for all african countries
2. clean the data, create a merged master data for each country.
3. what variables are available, what's the coverage. does it exist for every period and how many are missing. some summary statistics table (mean, median, p25, p75, min, max, standard deviation, count)
4. afforestation project -> DHS: calculate the share of the cluster area that are covered by afforestation areas (likely close to 0); calculate the share of the culster area with 10km buffer that are covered by afforestation areas. then we can test if household close to afforestation projects also make more money and have higher consumption.
5. DHS --> afforestation project: calculate the distance of the cluster buffer to afforestation projects and counterfactual control polygons, and see if afforestation projects are likely to fail if surrounded by agriculture workers

Additional comments and thoughts:
1. To be added
