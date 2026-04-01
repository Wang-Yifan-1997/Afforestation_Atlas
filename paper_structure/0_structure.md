# Paper Structure: The Global Afforestation Atlas

---

## Title Candidates
**The Global Afforestation Atlas**
---

## Abstract *(~200 words)*

---

## 1. Introduction *(~5–7 pages)*

### 1.1 Motivation and Policy Background
- Scale of global commitment: Bonn Challenge (350M ha by 2030), UN Decade on Ecosystem Restoration (1B ha), COP pledges
- Public expenditure: China's Grain for Green ($100B+), AFR100 (100M ha across Africa), voluntary carbon markets
- The core empirical gap: billions spent, little credible causal evidence on effectiveness
- Preview of key findings: average +5pp NDVI gain; large heterogeneity

### 1.2 Research Questions
1. **Effectiveness:** What is the causal effect of afforestation programs on vegetation cover, forest carbon, and ecosystem restoration?
2. **Heterogeneity:** Why do some programs succeed while others deliver zero effect — and what role do local economic conditions, policy design, and implementing agents play?
3. **Welfare:** Do afforestation programs benefit local households through income and employment channels, or do they impose costs through land restrictions?
4. **Policy:** How do national forest policies shape the incentives to launch programs and the probability of success?

### 1.3 What We Do
- Data construction: satellite pipeline (GEE), project-level characteristics (LLM + manual), policy coding (FAOLEX), household data (DHS)
- Identification strategy: synthetic DiD with randomly drawn control polygons matched on pre-treatment NDVI
- Main results and heterogeneity
- Structural model and policy counterfactuals

### 1.4 Contribution
- First globally representative causal estimates of afforestation effectiveness
- New data asset (Atlas) as a public good for researchers and policymakers
- Links micro-level conservation evidence to theory
- Policy-relevant: identifies where programs should be targeted and how they should be designed

---

## 2. Related Literature *(~4–5 pages)*

### 2.1 Forest Conservation and Afforestation
- Effectiveness of forest conservation programs (Ferraro & Pattanayak 2006; Andam et al. 2008; Pfaff et al. 2014; Jayachandran et al. 2017)
- Afforestation-specific evidence: China's Grain for Green (Feng et al. 2016; Bryan et al. 2018); REDD+ programs
- Limitations of existing work: focus on deforestation prevention rather than active planting; limited geographic scope; selection into treatment

### 2.2 Natural Resource Management, Property Rights, and Governance
- Property rights and resource conservation (Hardin 1968; Ostrom 1990; Besley & Ghatak 2010)
- Community-based conservation and benefit-sharing (Agrawal 2001; Ferraro 2011; Jack & Jayachandran 2024)
- Political economy of conservation policy (Burgess et al. 2012 on Indonesian deforestation; Durante & Mastrobuoni 2020)

### 2.3 Satellite Remote Sensing in Economics
- Nighttime lights as an economic proxy (Henderson et al. 2012; Donaldson & Storeygard 2016)
- NDVI and vegetation indices in economic research (Balboni et al. 2023; Burgess et al. 2019)
- Google Earth Engine applications in development economics
- Causal identification using satellite panel data

### 2.4 LLM-Assisted Text Analysis in Economics
- Machine reading of policy documents (Ash et al. 2024; Colmer et al. 2024)
- Large language models for information extraction in economics research

---

## 3. Data *(~8–10 pages)*

### 3.1 Afforestation Project Data
- **Primary source:** John et al. (2025) — 1.29 million planting sites from 45,628 georeferenced projects globally
- Coverage: countries, years, project types (plantation, natural regeneration, agroforestry)
- **Additional sources and cross-validation:**
  - Reforestation Tracker (reforestation.app / Mongabay)
  - Berkeley Carbon Trading / GSPP Offsets Database (Verra VCS, Gold Standard ARR credits)
  - FAO Forest Resource Assessment nationally reported programs
  - Known gaps: China's Green Great Wall; private plantation undercount; documentation bias toward carbon-market projects
- **Spatial cleaning:** deduplication of overlapping polygons across reporting platforms; decision rules documented; raw data retained as robustness sample
- **Descriptive statistics:** project count by country, year, and type; size distribution (hectares); share with valid geolocation; project timeline

### 3.2 Satellite Data (Google Earth Engine)
- **Vegetation / Forest Cover:**
  - MODIS NDVI (MOD13A3): 500m, monthly, 2000– [primary outcome]
  - Landsat NDVI (5/7/8/9): 30m, 16-day, 1984– [pre-2000 baseline; high-res validation]
  - Sentinel-2 NDVI: 10m, 5-day, 2015– [recent high-resolution check on subsample]
  - Hansen Global Forest Change: 30m annual tree cover loss/gain, 2000–
- **Carbon and Biomass:**
  - ESA CCI Biomass: 100m, 2010 and 2017–2020 [aboveground carbon stock]
  - Cross-validated against NDVI trajectory for treated polygons
- **Economic Activity:**
  - NPP-VIIRS harmonized nighttime lights: 500m, monthly, 2000– [primary economic proxy]
  - DMSP-OLS: ~1km, annual, 1992–2013 [long-run pre-period baseline]
- **Land Use:**
  - ESA CCI Land Cover: 300m, annual, 1992– [industry composition around project sites]
- **Pre-treatment Infrastructure:**
  - OSM / GRIP road density: vector, within project and buffer polygons
  - Google Open Buildings / Microsoft GlobalML: construction activity pre/post project
- **Climate controls:**
  - CHIRPS precipitation: 5km, daily, 1981–
  - ERA5 temperature and reanalysis variables

### 3.3 Forest Policy Data (FAOLEX)
- FAO FAOLEX database: national forest legislation, regulations, strategies, and decrees
- **LLM-assisted coding pipeline:** ~300 country-year policy documents; extracted variables include enactment year, policy instrument type, enforcement agency, stated targets, penalty structure, links to international frameworks (CBD, UNFCCC NDCs)
- **Manual validation:** random sample of documents hand-coded to verify extraction accuracy (inter-rater reliability reported)
- **Policy stringency index:** country-year measure of regulatory ambition and enforcement; used as covariate in heterogeneity analysis
- **Coverage assessment:** cross-validated against FAO FRA, UNREDD+, and World Bank PROFOR; known gaps (subnational policies, informal decrees) documented

### 3.4 Household Survey Data (DHS)
- Demographic and Health Surveys for all study countries: consumption, income, employment, assets, food security, child health, women's empowerment
- Harmonized across survey waves; merged master dataset per country
- **Spatial linkage to projects:**
  - Share of DHS cluster area covered by afforestation polygons
  - Share of cluster area within 10km buffer covered by afforestation
  - Distance from cluster centroid to nearest treated and control polygon
- **Note on GPS precision:** DHS displaces cluster coordinates by up to 10km (urban) and 5km (rural); sensitivity analysis uses multiple buffer radii

### 3.5 Cross-Country Panel Data
- FAO Global Forest Resources Assessment: country-year forest area, planted vs. natural, growing stock (1990–2025, quinquennial)
- World Bank and GGDC 10-sector database: sectoral GDP shares
- ILOSTAT and World Bank: sectoral employment shares
- Used for macro-level motivating evidence and cross-country policy analysis

---

## 4. Empirical Strategy *(~5–6 pages)*

### 4.1 Research Design Overview
- Unit of analysis: project polygon (treated) vs. randomly drawn control polygons of identical size within the same country
- Key identifying assumption: conditional on location and pre-treatment vegetation trajectory, timing of project launch is plausibly exogenous

### 4.2 Control Group Construction
- Random placement of control polygons within the same country, excluding existing forest and other treated areas
- Matching on pre-treatment NDVI trend (propensity score or entropy balancing on trend and level)
- Additional matching covariates: elevation, soil quality, rainfall climatology, distance to roads
- Robustness: vary matching bandwidth; use pixel-level analysis

### 4.3 Estimator: Synthetic Difference-in-Differences
- Primary estimator: `sdid` (Arkhangelsky et al. 2021) — reweights control units to parallel pre-treatment trend
- Event study specification (`sdid_event`): documents dynamic treatment effects by years since project launch; pre-treatment coefficients test parallel trends
- Synthetic control (`method(sc)`) for individual large projects as supplementary analysis
- Staggered adoption: projects launched in different years; use heterogeneity-robust DiD estimators (Callaway & Sant'Anna 2021; Sun & Abraham 2021)

### 4.4 Outcome Variables
- **Primary:** MODIS NDVI (monthly average within polygon, annual); Hansen tree cover gain
- **Secondary:** ESA CCI Biomass change (carbon stock); nighttime lights (economic activity); ESA land cover class
- **Household welfare:** DHS per capita consumption, food security, employment sector

### 4.5 Potential Confounders and Threats to Identification
- Rainfall shocks: controlled using CHIRPS precipitation at polygon-year level
- Temperature trends: MODIS LST or ERA5
- Coincident policy changes: interacted with policy stringency index from FAOLEX
- Selection on pre-trend: directly tested via pre-treatment event-study coefficients
- Spatial spillovers / leakage: measured in buffer rings around treated polygons (see Section 6.2)

---

## 5. Results I: Afforestation Effectiveness *(~8–10 pages)*

### 5.1 The Global Afforestation Atlas
- Country-by-country event-study figures: one panel per country showing pre/post NDVI trajectory for treated vs. synthetic control (cf. Kleven et al. child penalty atlas)
- Summary statistics on ATT distribution: mean, median, p10/p90 across all projects
- Geographic patterns: which regions show consistent gains vs. consistent null effects

### 5.2 Average Treatment Effect
- Baseline SDID estimate: +~5 percentage points NDVI within 5 years (Sub-Saharan Africa preliminary)
- Dynamic event study: when do effects appear, how do they evolve over 10+ years?
- By project type: plantation vs. natural regeneration vs. agroforestry — which delivers faster/larger NDVI gains?
- Carbon and biomass: translate NDVI gains into implied carbon sequestration (back-of-envelope)

### 5.3 Heterogeneity: Why Some Programs Work and Others Fail
- **By country-level structural conditions:**
  - Agricultural employment share (from DHS and ILOSTAT): high land pressure → lower ATT
  - Stage of structural transformation: services/industry share → higher ATT
  - GDP per capita: resource-rich but agrarian-poor economies (Gabon, Congo) as distinct category
- **By project characteristics:**
  - Implementing agent: NGO vs. government vs. private firm vs. multilateral
  - Funding source: ODA vs. carbon markets vs. domestic budget
  - Species composition: native vs. exotic; monoculture vs. mixed planting
  - Enforcement: presence of third-party audit, carbon credit verification
  - Community involvement: profit-sharing, land tenure arrangements
- **By policy environment:**
  - Higher FAOLEX policy stringency index → higher probability of positive ATT?
  - Policy complementarity: land tenure reform interacted with afforestation

### 5.4 Illustrative Case Studies
- **Ghana:** strong positive effect — what distinguishes successful projects here?
- **Gambia:** consistent gains — small country, lower land pressure, active NGO presence
- **Gabon / Cameroon:** near-zero effects — oil-rich, low agricultural employment, but why does this predict failure rather than success?
- Use these to motivate the structural model in Section 7

---

## 6. Results II: Economic and Welfare Impacts *(~5–6 pages)*

### 6.1 Household Welfare Effects
- DiD/SDID using spatial proximity to afforestation projects as exposure (DHS clusters within 10km buffer)
- Outcomes: per capita consumption, food security, agricultural vs. non-agricultural employment
- Heterogeneity: welfare effects larger where benefit-sharing is present; smaller where land restrictions bind
- Placebo: same analysis using control polygons as "treatment" — confirm null

### 6.2 Local Labor Market Effects
- Does afforestation shift employment from agriculture toward forestry, services, or conservation jobs?
- Use DHS employment sector variables + nighttime lights as proxies for local activity
- Heterogeneity: land-abundant areas (Gabon, Namibia) vs. high land-pressure areas (Burundi, Gambia)

### 6.3 Land Use Spillovers and Leakage
- Does afforestation in one polygon displace agricultural clearing to adjacent areas?
- NDVI and forest cover measured in concentric buffer rings (5km, 10km, 20km) around treated polygons
- Spatial Durbin model to estimate displacement vs. complementarity effects
- Implication: naive project-level ATT may overstate net ecosystem benefit if leakage is large

### 6.4 Climate Co-benefits
- Local temperature effects: does tree cover reduce MODIS LST within and around treated polygons?
- Local rainfall effects: vegetation-precipitation feedback (CHIRPS post-treatment)
- Link to NDC targets: does observed sequestration close a meaningful share of country commitments?

### 6.5 Cost-Effectiveness
- Collect project budget data where available; compute cost per ton CO₂ sequestered and cost per hectare of NDVI gain
- Compare across agent type, funding source, and species composition
- Benchmark against PES programs (Jayachandran et al. 2017) and protected areas (Ferraro & Pattanayak 2006)

---

## 7. Theoretical Framework and Policy Counterfactuals *(~4–5 pages)*

### 7.1 A Model of Forest Growth and Maintenance Incentives
- Parsimonious dynamic model of forest stock following Dasgupta (1982):
  - Forest stock $F_t$ evolves as $\dot{F}_t = g(F_t) - e_t$ where $e_t$ = encroachment (local agricultural pressure)
  - Maintenance incentives depend on: opportunity cost of land, revenue sharing, property rights security, enforcement technology
- Equilibrium conditions: when will a planted forest survive vs. be encroached upon?
- Comparative statics: how does structural transformation (shift from agriculture) change the equilibrium forest stock?

### 7.2 Calibration to Empirical Estimates
- Calibrate maintenance cost parameters to match observed ATT heterogeneity across structural transformation stages
- Use project-level data on agent type and community involvement to identify revenue-sharing parameters
- Brings credible causal micro-evidence to bear on a class of natural resource models historically calibrated on aggregate data

### 7.3 Policy Counterfactuals
- **Optimal targeting:** where should programs be placed given local structural conditions? Compare observed placement to model-implied optimum — are projects going to "easy wins" or "hard cases"?
- **Optimal design:** what community benefit-sharing rate minimises long-run encroachment for a given budget?
- **International transfers:** welfare gains from carbon market revenues that fund local community incentives — size of the transfer needed to sustain forest in high land-pressure environments
- **Policy complementarity:** joint vs. separate effects of afforestation programs and land tenure reform

---

## 8. Robustness and Validation *(~3–4 pages)*

- **Placebo timing:** reassign treatment to randomly drawn years; confirm near-zero pre-trends and null post-period effects
- **Placebo geography:** run analysis in countries with no recorded afforestation projects; test for spurious NDVI trends
- **Alternative outcome variables:** Landsat NDVI (30m); Hansen tree cover gain; ESA CCI land cover; DMSP-OLS nighttime lights
- **Alternative control group:** vary matching bandwidth; pixel-level analysis (following Burgess et al. 2019)
- **Sample restrictions:** projects with high-confidence geolocation only; exclude projects near borders or protected areas
- **Deduplication sensitivity:** replicate main estimates on raw (pre-deduplication) project data
- **Heterogeneity stability:** confirm main heterogeneity results are not driven by outlier countries or large projects
- **Rainfall and climate controls:** add/remove CHIRPS precipitation; confirm robustness to climate variation

---

## 9. Conclusion *(~2–3 pages)*

- Summary of main findings: average effectiveness, large heterogeneity
- Policy implications: evidence-based targeting (where), design (how), and timing (when) of afforestation investment
- The Atlas as a public data resource: what policymakers and researchers can use it for
- Limitations and open questions: data gaps (China, private plantations), generalisability beyond Sub-Saharan Africa, long-run dynamics beyond 10 years
- Future directions: RCT collaboration (Rainforest Builder, Ghana); extension to Asia and Latin America; integration with carbon market registry data

---

## Online Appendix

- A: Data construction details (GEE pipeline, LLM coding protocol, DHS harmonization)
- B: Satellite data reference table and validation
- C: Balance tests: treated vs. control polygons on pre-treatment NDVI, elevation, rainfall, road density
- D: Full country-by-country event-study figures (Afforestation Atlas)
- E: Full heterogeneity results tables
- F: Structural model derivations and calibration details
- G: Cost-effectiveness calculations
- H: Data memo: coverage, gaps, and known biases by source

---

## Website / Public Afforestation Atlas

- Interactive map of all 45,628+ projects with satellite outcomes overlaid (NDVI trajectory, ATT estimate, project characteristics)
- Country-level fact sheets: event-study figure, descriptive statistics, policy environment summary
- Downloadable datasets: project-level ATT estimates, policy stringency index, satellite covariates
- Open-source replication code (GitHub)
- Target audiences: academic researchers, national governments, international organisations, carbon market practitioners, NGOs

---

## Key References *(to be completed)*

- Andam et al. (2008) — protected areas causal evaluation
- Arkhangelsky et al. (2021) — synthetic DiD
- Balboni et al. (2023) — satellite data in economics
- Barbier et al. (2010) — forest transition
- Bryan et al. (2018) — China's Grain for Green
- Burgess et al. (2012, 2019) — deforestation and satellite data
- Callaway & Sant'Anna (2021) — staggered DiD
- Dasgupta (1982) — natural capital dynamics
- Donaldson & Storeygard (2016) — nighttime lights
- Ferraro & Pattanayak (2006) — conservation cost-effectiveness
- Henderson et al. (2012) — nighttime lights and GDP
- Jack & Jayachandran (2024) — community conservation
- Jayachandran et al. (2017) — PES Uganda RCT
- John et al. (2025) — global afforestation project dataset
- Kleven et al. (2019) — child penalty atlas (structural inspiration)
- Ostrom (1990) — governing the commons
- Rudel et al. (2005) — forest transitions

---

*Last updated: 2026*
