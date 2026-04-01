# Task Record — 2026-04-02

---

## Task 1 — Process Remaining Non-Africa Small Countries

- There are many small countries outside of Africa that have not yet been processed
- Please identify and process these countries to extract **NDVI** for both the **treated** and **control** groups, following the same pipeline used for the Africa countries
- Save the output in your Dropbox folder in the same structure as before

---

## Task 2 — Update Summary Statistics

- Once the non-Africa small countries are processed, **update the summary statistics tables and figures** from the earlier descriptive task to incorporate the newly added countries
- Make sure both the **all-countries table** and the **already-processed-countries table** are refreshed accordingly

---

## Task 3 — Regulation Database: LLM-Based Policy Coding

We have a regulation database. Please feed the policies to an LLM and ask it to extract and summarize the following for each regulation:

- **Key message**: what is the core content of the regulation?
- **Forest relevance**: how much of the regulation is related to forests / reforestation? (e.g., a share or a categorical rating)
- **Regulation strength**: how strong is the regulation? Try to find a **consistent quantification approach** — ideally something that can be coded as either a **dummy** (weak vs. strong) or a **continuous variable** (e.g., a 1–5 scale)
- **Other reforestation policies**: what other reforestation-related policies can the LLM identify that we may be missing? We need **global coverage**, so please think about how to expand the search systematically

> The goal is to produce a structured, machine-readable dataset from the regulation text. Please think carefully about prompt design so that the LLM outputs are consistent and comparable across policies. Document the prompt templates you use.

---

## Task 4 — DHS Data: Household Distance to Reforestation Projects

- Take a first look at the **DHS data** and document what variables are available — in particular: income, consumption, location (GPS coordinates), occupation/career, and any other household-level characteristics that might be relevant
- Using household GPS coordinates, **calculate the distance** from each DHS household to:
  1. The **boundary** of the nearest reforestation project
  2. The **centroid** of the nearest reforestation project
- This will be used for welfare and distributional analysis, so please make sure the distance calculations are precise and well-documented

---

## Task 5 — Within-Project Heterogeneity: Google Buildings & Road Data

This task explores spatial heterogeneity *within* reforestation projects using auxiliary data layers.

### 5.1 Google Building Data
- Use **Google building footprint data** to measure the presence and density of human settlements **inside** reforestation project boundaries
- Key question: do reforestation projects with more people living inside them perform worse (lower NDVI gain)?

### 5.2 Road Data
- Use road network data to measure **road expansion** within and around reforestation project areas
- Key question: does road expansion — potentially interacted with population presence — predict **reforestation failure**?

### 5.3 Within-Project Sub-Region Analysis
- As a more ambitious extension: **subdivide each reforestation project into smaller spatial units** (e.g., grid cells or sub-polygons)
- For each sub-unit, estimate reforestation effectiveness (NDVI-based)
- Test whether sub-units with **higher building density** or **greater road access** are systematically less effective
- This allows us to move from project-level to within-project spatial heterogeneity — which is a much sharper test of the mechanisms

---

*Last updated: 2026-03-29*


# Task Record — 2026-03-29

---

## Task 1 — Descriptive Statistics

**Folder:** `xinyi wang/tasks/task_20260329`

The folder contains both the data and the documentation. Please read the document first, then proceed with the following:

### 1.1 Summary Statistics
Produce descriptive statistics for afforestation projects, including (but not limited to):
- Planting year
- Project size
- Project type (government vs. other)
- Any other variables you find informative

Produce **two versions** of the summary statistics table:
1. **All countries** in the dataset
2. **Countries already processed/finished**

Each table should include: `mean`, `median`, `min`, `max`, `p25`, `p75`, `std`, `count`

### 1.2 Figures
- Bar graphs for key variables
- **World map** showing the distribution of all projects
- **Zoomed map** showing only the countries already processed
- **Country map** showing one country at a time
- Be innovative with figure design — these are intended for inclusion in a paper draft and should meet **publication quality** standards (follow top-5 journal formatting conventions)

### 1.3 GitHub & Replication
- Push all code to GitHub
- Organize the repository so that future RAs and collaborators can easily navigate it
- The codebase should be **replication-ready** (clear folder structure, README, comments, etc.)
- Consult an AI agent for proposals on best practices for structuring a large project like this

### 1.4 Data Documentation
Write a detailed document covering:
- Data source and provenance
- Data coverage (geographic, temporal, etc.)
- Overview of the data structure
- Key takeaways
- Key variables and their definitions
- Limitations

---

## Task 2 — Remaining Small Countries

- Finish processing the remaining small countries
- Save the output data in your Dropbox folder

---

## Task 3 — Methodology Documentation

### 3.1 High-Level Summary (for paper draft)
- A concise, paper-ready description of the data cleaning and processing approach
- Focus on key intuition and steps
- Follow the style of top-5 journal data sections (even if "high-level", more detail is better — we can always cut later)

### 3.2 Technical Documentation
- A detailed, step-by-step account of every processing decision
- You may use AI to generate a first draft of this
- Should be thorough enough to serve as a full technical appendix

---

## Task 4 — Working Hours

- Log all hours worked, regardless of whether a single day exceeds 10 hours
- The only constraint is that **total hours not exceed 130** (contracted hours)

---
