# 🌳 Afforestation Atlas

A large-scale empirical project studying the causal effects of afforestation and reforestation programs across sub-Saharan Africa, combining satellite remote sensing, causal inference methods, and policy analysis.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Data: Satellite & Remote Sensing](#1-satellite--remote-sensing-data-gee)
3. [Data: Afforestation Projects](#2-afforestation-project-data)
4. [Data: Forest & Environmental Policy](#3-forest--environmental-policy)
5. [Data: Household Surveys (DHS)](#4-household-survey-data-dhs)
6. [Empirical Strategy](#5-empirical-strategy)
7. [Welfare & Structural Analysis](#6-welfare--structural-analysis)
8. [Robustness & Validation](#7-robustness--validation)
9. [Dissemination & Documentation](#8-dissemination--documentation)

---

## Project Overview

This project builds an "Afforestation Atlas" for sub-Saharan Africa by assembling and harmonizing data on tree-planting programs, satellite-derived environmental outcomes, household welfare, and forest governance policy. The core empirical question is: **what are the causal effects of afforestation projects on environmental outcomes, local economic welfare, and structural transformation?**

**Countries covered:** Gabon, Congo Rep., Lesotho, Angola, Namibia, Mauritania, Cameroon, Guinea, Côte d'Ivoire, Burkina Faso, Mali, Chad, Gambia, Central African Republic, Burundi *(and expanding)*

**Methods:** Difference-in-differences (DiD), Synthetic Difference-in-Differences (SDID), Synthetic Control, event study designs.

---

## 1. Satellite & Remote Sensing Data (GEE)

### 1.1 NDVI & Vegetation
- [ ] Fix batch processing failures: currently ~20+ countries fail; debug memory limits, projection errors, and polygon validity issues
- [ ] Add Landsat NDVI (30m, longer historical coverage back to 1984) alongside MODIS NDVI (500m)
- [ ] Add Sentinel-2 NDVI (10m, post-2015) for high-resolution validation on a subsample
- [ ] Document pros/cons of each NDVI source: spatial resolution, temporal frequency, cloud contamination, saturation in dense canopy

### 1.2 Forest Cover
- [ ] Extract Hansen Global Forest Change (tree cover loss/gain, treecover2000 baseline, annual loss years)
- [ ] Extract ESA Climate Change Initiative (CCI) Land Cover annual maps (1992–present) for broader land use classification
- [ ] Consider PRODES (Brazil) methodology as template for annual deforestation/afforestation accounting
- [ ] Document what each measure captures: canopy cover thresholds, definition of "forest," limitations in dryland/savanna contexts

### 1.3 Carbon & Biomass
- [ ] Extract aboveground biomass density (e.g., ESA CCI Biomass, or Spawn et al. 2020 global biomass maps)
- [ ] Consider carbon stock changes as an outcome variable — directly links afforestation to climate policy goals
- [ ] Cross-validate biomass estimates against NDVI trajectory for treated polygons

### 1.4 Nighttime Lights & Land Use
- [ ] Harmonized NPP-VIIRS NTL (2000–present) already in pipeline — finalize extraction for all countries
- [ ] Add DMSP-OLS (1992–2013) for longer pre-period baseline and check inter-calibration with VIIRS
- [ ] Extract ESA or MODIS land use / land cover classification to characterize industry composition around project sites
- [ ] Use NTL as a proxy for local economic activity; test whether afforestation projects displace or complement industrial activity

### 1.5 Human Activity & Infrastructure
- [ ] Extract road density (OSM or GRIP dataset) within treated/control polygon buffers — pre-treatment baseline and changes over time
- [ ] Extract building footprint data (Google Open Buildings or Microsoft GlobalML) to detect construction activity pre/post project
- [ ] Test whether pre-treatment road/building presence predicts project placement (selection into treatment)
- [ ] Test whether new roads or buildings appear *after* afforestation, as a proxy for induced economic activity

### 1.6 Satellite Data Reference Table

| Dataset | Source | Resolution | Coverage | Key Use |
|---|---|---|---|---|
| MODIS NDVI (MOD13A3) | Terra/Aqua | 500m, monthly | 2000– | Primary vegetation outcome |
| Landsat NDVI | Landsat 5/7/8/9 | 30m, 16-day | 1984– | High-res validation |
| Sentinel-2 NDVI | ESA | 10m, 5-day | 2015– | Recent high-res check |
| Hansen GFC | UMD/Google | 30m, annual | 2000– | Forest cover loss/gain |
| ESA CCI Land Cover | ESA | 300m, annual | 1992– | Land use classification |
| ESA CCI Biomass | ESA | 100m | 2010, 2017–2020 | Aboveground carbon |
| NPP-VIIRS NTL (harmonized) | NOAA/sat-io | 500m, monthly | 2000– | Economic activity proxy |
| DMSP-OLS | NOAA | ~1km, annual | 1992–2013 | Long-run NTL baseline |
| OSM Roads / GRIP | OpenStreetMap | Vector | Various | Pre-treatment infrastructure |
| Google Open Buildings | Google | Vector | Recent | Construction activity |

---

## 2. Afforestation Project Data

### 2.1 Descriptive Analysis
- [ ] Total number of projects, by country, by year, by implementing agent
- [ ] Share of projects with valid geolocation; map of projects country-by-country
- [ ] Distribution of project size (hectares), duration, and reported investment value
- [ ] Timeline: when were projects initiated, completed, or abandoned?

### 2.2 Spatial Cleaning & Deduplication
- [ ] Spatial join to identify overlapping polygons — flag likely duplicates reported across multiple programs
- [ ] Establish deduplication decision rules and document them; retain raw data as robustness check
- [ ] Check if any treated polygons overlap with each other after deduplication

### 2.3 Additional Data Sources
- [ ] **Restor Eco**: data withdrawn by provider — document as likely missing; consider reaching out directly
- [ ] **Reforestation Tracker** ([reforestation.app](https://reforestation.app)): check overlap with main dataset; use as complement or for additional covariates
- [ ] **Berkeley Carbon Trading / GSPP Offsets Database** ([link](https://gspp.berkeley.edu/berkeley-carbon-trading-project/offsets-database)): extract afforestation/reforestation credits (ARR); merge with main dataset on location and timing
- [ ] Check **Verra VCS** and **Gold Standard** registries for registered afforestation projects in study countries
- [ ] Check **FAO FRA** (Forest Resource Assessment) country reports for nationally reported planting programs
- [ ] Write a **data memo** documenting each source, coverage, known gaps, and known biases (e.g., China's Green Great Wall, private plantation undercount, project-level vs. national reporting)

### 2.4 Project Characteristics & Heterogeneity
- [ ] Implementing agent: NGO, government, private firm, multilateral — extract and harmonize across sources
- [ ] Species composition: native vs. exotic species, monoculture vs. mixed planting (ecological and economic implications)
- [ ] Implementation practices: community participation, profit-sharing with local households, land tenure arrangements
- [ ] Enforcement mechanism: is there government monitoring, carbon credit verification, third-party audit?
- [ ] Funding source: domestic government budget, ODA, carbon markets, blended finance

### 2.5 LLM-Assisted Information Extraction from Project PDFs
- [ ] Identify the subsample of projects with available project design documents (PDFs)
- [ ] Build an LLM pipeline to extract structured variables: agent type, species, community benefit-sharing, land tenure, enforcement, budget, timeline, monitoring protocol
- [ ] Validate extraction accuracy on a hand-coded random sample (inter-rater reliability)
- [ ] Replicate main analysis on this subsample; test whether richer project characteristics predict treatment effect heterogeneity

---

## 3. Forest & Environmental Policy

### 3.1 Data Source
- FAO FAOLEX database: [https://www.fao.org/faolex/background/en/](https://www.fao.org/faolex/background/en/)

### 3.2 Policy Document Analysis
- [ ] Read a sample of policy documents per country; document: policy type (law, regulation, decree, strategy), timing of enactment, responsible ministry/agency, enforcement mechanism, stated targets, penalties
- [ ] Classify policies by stringency (aspirational strategy vs. legally binding mandate)
- [ ] Check for policy complementarity: forestry policy coordinated with agricultural reform, land tenure reform, climate NDC commitments
- [ ] Document potential welfare costs: land restrictions on smallholders, displacement of pastoralists, opportunity cost of land

### 3.3 LLM-Based Policy Coding
- [ ] Following NBER pipeline papers (e.g., Ash et al.; Colmer et al.), use LLM to code policy documents at scale
- [ ] Extract: enactment year, policy instrument type, target species/region, enforcement agency, stated penalty, link to international frameworks (CBD, UNFCCC NDCs)
- [ ] Build a country-year policy stringency index as a covariate in the main empirical model

### 3.4 Coverage Assessment
- [ ] Assess whether FAOLEX provides complete coverage of relevant legislation or systematically misses certain policy types (informal decrees, subnational policies)
- [ ] Cross-validate against country-level reports from FAO FRA, UNREDD+, and World Bank PROFOR

### 3.5 Potential Policy Analyses
- [ ] **Policy impact**: does stronger forest legislation lead to higher project density or better outcomes?
- [ ] **Policy complementarity**: do afforestation projects perform better in countries with supportive land tenure reform?
- [ ] **Political economy**: what drives governments to enact forest policy — structural transformation, international aid conditionality, carbon market access?

---

## 4. Household Survey Data (DHS)

### 4.1 Data Assembly
- [ ] Download DHS data for all sub-Saharan African study countries
- [ ] Harmonize across survey waves; build a merged master dataset per country with consistent variable definitions
- [ ] Document variable availability, temporal coverage, and missingness by country-wave

### 4.2 Summary Statistics
- [ ] Summary statistics table: mean, median, p25, p75, min, max, SD, N for all key household welfare variables (consumption, income, assets, food security, health)
- [ ] Check DHS cluster GPS precision and displacement (DHS displaces cluster coordinates by up to 10km for urban, 5km for rural — important for spatial matching)

### 4.3 Afforestation → Household Welfare (Treatment Effects on Households)
- [ ] Calculate share of DHS cluster area covered by afforestation polygons (likely ~0 for most clusters)
- [ ] Calculate share of cluster area within 10km buffer covered by afforestation polygons
- [ ] Calculate distance from DHS cluster centroid to nearest afforestation project (treated) and nearest control polygon
- [ ] Run DiD/SDID using spatial proximity to afforestation projects as exposure variable; outcomes: per capita consumption, food security, women's empowerment, child health
- [ ] Heterogeneity: does the welfare effect differ by implementing agent (NGO vs. government), species composition, or profit-sharing arrangement?

### 4.4 Agriculture Pressure → Project Success (Reverse Channel)
- [ ] Calculate share of agricultural workers in DHS clusters surrounding each project
- [ ] Test whether afforestation projects surrounded by more agricultural workers are more likely to fail, be abandoned, or show lower NDVI gains
- [ ] This links to the political economy of conservation: land pressure as a threat to program sustainability

---

## 5. Empirical Strategy

### 5.1 Core Identification
- [ ] Primary design: Synthetic DiD (`sdid`) with treated afforestation polygons vs. randomly generated control polygons, matched on pre-treatment NDVI trajectory and geographic covariates
- [ ] Event study (`sdid_event`) to test parallel pre-trends and document dynamic treatment effects
- [ ] Synthetic control (`method(sc)`) for individual treated projects as robustness

### 5.2 Treatment Definition
- [ ] Define treatment timing precisely: planting year, or year the project enters a registry?
- [ ] Distinguish between *project announcement* and *implementation* — staggered adoption design if timing varies
- [ ] Assess extent of treatment effect heterogeneity by project age (effects may take 5–10 years to appear in canopy data)

### 5.3 Control Group Construction
- [ ] Document control polygon generation: random placement, exclusion of existing forest, matching on soil, elevation, rainfall
- [ ] Consider **matching on pre-treatment NDVI trend** (propensity score or Mahalanobis) to improve balance
- [ ] Consider using **pixels** rather than polygons as the unit of analysis for higher statistical power (following Burgess et al. 2019 on deforestation)

### 5.4 Potential Confounders
- [ ] Rainfall shocks (use CHIRPS or ERA5 precipitation as a covariate/control)
- [ ] Temperature trends (MODIS LST or ERA5)
- [ ] Policy changes coinciding with project start
- [ ] Selection into treatment: projects placed in areas with naturally recovering vegetation — test with pre-trend analysis

---

## 6. Welfare & Structural Analysis

*Inspired by frontier papers in environmental and development economics (e.g., Burgess et al. 2019; Duflo et al. 2008; Jayachandran et al. 2017; Jack & Jayachandran 2024; Balboni et al. 2023)*

### 6.1 Local Labor Market Effects
- [ ] Test whether afforestation projects shift local employment from agriculture toward forestry/services (structural transformation channel)
- [ ] Use DHS employment variables and NTL as proxies; ideally link to country-level labor surveys if available
- [ ] Heterogeneity: effects likely larger in land-abundant, low-density areas (e.g., Gabon, Namibia) vs. high land-pressure areas (Burundi, Gambia)

### 6.2 Land Use Spillovers & Leakage
- [ ] Test for "leakage": does afforestation in one area displace agricultural deforestation to adjacent areas?
- [ ] Measure NDVI and forest cover in buffer rings (5km, 10km, 20km) around treated projects
- [ ] Spatial Durbin or spatial lag model to capture cross-polygon spillovers

### 6.3 Ecosystem Services & Climate Co-benefits
- [ ] Estimate carbon sequestration implied by observed biomass/NDVI gains (back-of-envelope welfare calculation)
- [ ] Test whether afforestation affects local temperature (MODIS LST) and rainfall patterns (CHIRPS) — local climate feedback
- [ ] Link to country NDC targets: does observed sequestration close meaningful share of stated commitments?

### 6.4 Cost-Effectiveness
- [ ] Collect project budget data where available; compute cost per ton CO₂ sequestered and cost per hectare of vegetation gain
- [ ] Compare across implementing agent type, funding source, and species composition
- [ ] Benchmark against other conservation interventions (PES programs, protected areas — see Ferraro & Pattanayak 2006; Jayachandran et al. 2017)

### 6.5 Political Economy of Afforestation
- [ ] What predicts which countries/regions get more projects? Donor conditionality? Carbon market access? Political connections?
- [ ] Test whether policy stringency (Section 3) or international aid intensity predicts project placement
- [ ] Assess if projects are placed strategically in low-threat areas (easy wins) vs. high-threat areas (where intervention is most needed)

---

## 7. Robustness & Validation

- [ ] Placebo tests: assign fake treatment timing; confirm null effects
- [ ] Restrict to projects with stricter geolocation confidence; re-run main estimates
- [ ] Use raw (pre-deduplication) project data as alternative sample
- [ ] Alternative NDVI sources (Landsat, Sentinel-2) as outcome variable substitutes
- [ ] Alternative NTL source (DMSP-OLS extended series) for economic activity outcomes
- [ ] Heterogeneity by project size, implementing agent, species type, and funding source
- [ ] Placebo geography: run analysis in countries not covered by any project — test for spurious trends

---

## 8. Dissemination & Documentation

- [ ] Write a **data documentation memo** for each data source: provenance, cleaning steps, known limitations, coverage gaps
- [ ] Maintain a **replication package**: all code (R, Python, Stata), intermediate data outputs, and final analysis datasets
- [ ] Produce **country-level fact sheets**: one page per country summarizing project coverage, environmental outcomes, and welfare evidence
- [ ] Produce an **interactive map** (e.g., kepler.gl or R Leaflet) of all projects with key metadata visible on click
- [ ] Track all major TODO items, decisions, and open questions in this README

---

## Notes & Open Questions

- Agriculture GDP share is a problematic cross-country comparator due to extractive industry distortions (especially Gabon, Congo Rep., Angola, Namibia). Prefer agricultural employment share.
- VIIRS nighttime lights only start 2012; use harmonized NPP-VIIRS dataset for pre-2012 coverage.
- DHS cluster displacement (up to 10km) introduces spatial measurement error in proximity-based analyses — consider sensitivity analysis with different buffer radii.
- Some project PDFs may be in French or Portuguese — LLM pipeline needs multilingual support.

---

*Last updated: 2026*
