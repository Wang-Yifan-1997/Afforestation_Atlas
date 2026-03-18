# 🌳 Afforestation Atlas — Urgent TODO

*Short-run priorities. For the full task list see README.md.*

---

## GEE / Satellite Pipeline

- [ ] Fix batch processing failures for 20+ countries — debug memory limits, projection errors, polygon validity
- [ ] Add Landsat NDVI and Hansen Global Forest Change extraction to pipeline
- [ ] Add ESA CCI Biomass / aboveground biomass as additional forest outcome
- [ ] Add DMSP-OLS nighttime lights for pre-2012 coverage; add land use/land cover classification
- [ ] Extract road and building footprint data for pre-treatment human activity checks
- [ ] Write up pros/cons reference note for each satellite data source (resolution, coverage, limitations)

---

## Afforestation Project Data

- [ ] Descriptive statistics: project count by country, by year, by agent; share with valid geolocation; size distribution
- [ ] Make country-by-country project maps
- [ ] Spatial deduplication: identify overlapping polygons, document decision rules, keep raw data as robustness
- [ ] Investigate and document additional sources: Restor Eco (withdrawn), reforestation.app, Berkeley Carbon Offsets DB, Verra VCS, Gold Standard
- [ ] Write data memo on coverage gaps and known missing programs (e.g. China's Green Great Wall)
- [ ] Collect project characteristics where available: agent type, species, community benefit-sharing, enforcement
- [ ] For projects with PDFs: build LLM extraction pipeline for structured variables; validate on hand-coded sample

---

## Forest Policy

- [ ] Pull sample policy documents from FAOLEX; read and summarize key dimensions (timing, agent, stringency, penalties, coordination with other policy)
- [ ] Once understanding is solid: build LLM coding pipeline (check two relevant NBER pipeline papers first)
- [ ] Assess FAOLEX coverage gaps; cross-check against FAO FRA / UNREDD+ reports

---

## Household Survey (DHS)

- [ ] Download and clean DHS data for all study countries; build merged master dataset
- [ ] Summary statistics table for key welfare variables; document coverage and missingness
- [ ] Spatial linkage to afforestation projects: compute cluster coverage share and distance to nearest project/control polygon
- [ ] Test reverse channel: do projects surrounded by more agricultural workers show worse NDVI outcomes?

---

## Absolute Must-Adds from Extended List

- [ ] **Leakage check**: measure NDVI/forest cover in buffer rings (5–20km) around treated projects — test if afforestation just displaces clearing nearby *(high priority; speaks directly to external validity)*
- [ ] **Rainfall control**: add CHIRPS or ERA5 precipitation as a covariate — confounds NDVI and is easy to add *(low effort, high payoff)*
- [ ] **Placebo timing test**: assign fake treatment years; confirm null effects *(essential for any DiD credibility)*

---

*Last updated: 2026*
