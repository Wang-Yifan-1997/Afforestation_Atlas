# Split global afforestation polygon data by country and save as GeoPackage files.
# Output: Data/Processed Data/Global Afforestation Projects/by_country/<country>.gpkg
# Run this once; subsequent scripts load the pre-split country files directly.

user <- Sys.info()[["user"]]
if (user == "wangy390") {
  .libPaths(c("H:/R/library", .libPaths()))
  setwd("D:/Dropbox/Afforestation_Transition")
} else if (user == "wyf19") {
  setwd("C:/Users/wyf19/Dropbox/Afforestation_Transition")
} else {
  stop("Unknown user — add your path here.")
}

library(sf)
library(data.table)
library(dplyr)
library(tools)

cat("Working directory:", getwd(), "\n\n")

# ─────────────────────────────────────────────────────────────
# 1. Load and combine all description CSVs
# ─────────────────────────────────────────────────────────────
descrip_folder <- "Data/Processed Data/Global Afforestation Projects/Description"
descrip_files  <- list.files(descrip_folder, pattern = "_description\\.csv$", full.names = TRUE)

cat("Reading", length(descrip_files), "description files...\n")
all_descrip <- rbindlist(lapply(descrip_files, fread), fill = TRUE)
# ensure join keys are character
all_descrip[, site_id_created    := as.character(site_id_created)]
all_descrip[, project_id_reported := as.character(project_id_reported)]
all_descrip[, site_id_reported   := as.character(site_id_reported)]

cat("Total description rows:", nrow(all_descrip), "\n")
cat("Countries:", length(unique(all_descrip$country)), "\n\n")

# ─────────────────────────────────────────────────────────────
# 2. Load and combine all polygon shapefiles
# ─────────────────────────────────────────────────────────────
geo_folder <- "Data/Processed Data/Global Afforestation Projects/Geography"
shp_files  <- list.files(geo_folder, pattern = "_geography_polygon\\.shp$", full.names = TRUE)

cat("Reading", length(shp_files), "polygon shapefiles...\n")

geo_list <- lapply(shp_files, function(shp) {
  cat("  →", basename(shp), "\n")
  sf_obj <- st_read(shp, quiet = TRUE)
  # shapefile truncates names: st_d_cr=site_id_created, prjct__=project_id_reported, st_d_rp=site_id_reported
  sf_obj %>% mutate(across(c(st_d_cr, prjct__, st_d_rp), as.character))
})

geo_all <- bind_rows(geo_list)
cat("Total polygons:", nrow(geo_all), "\n\n")

# ─────────────────────────────────────────────────────────────
# 3. Join geometry with description to attach country + metadata
# ─────────────────────────────────────────────────────────────
cat("Joining geometry with description data...\n")

geo_joined <- geo_all %>%
  left_join(
    as.data.frame(all_descrip),
    by = c("st_d_cr" = "site_id_created",
           "prjct__" = "project_id_reported",
           "st_d_rp" = "site_id_reported")
  )

cat("Polygons after join:", nrow(geo_joined), "\n")
cat("Polygons with country info:", sum(!is.na(geo_joined$country)), "\n")
cat("Polygons without match:", sum(is.na(geo_joined$country)), "\n\n")

# Drop polygons that didn't match any description entry
geo_joined <- geo_joined %>% filter(!is.na(country))

# ─────────────────────────────────────────────────────────────
# 4. Split by country and save as GeoPackage
# ─────────────────────────────────────────────────────────────
out_dir <- "Data/Processed Data/Global Afforestation Projects/by_country"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

countries <- sort(unique(geo_joined$country))
cat("Saving", length(countries), "country files...\n\n")

for (ctry in countries) {
  ctry_sf <- geo_joined %>% filter(country == ctry)
  
  # sanitise country name for use as filename AND layer name
  safe_name <- gsub("[^a-zA-Z0-9]", "_", ctry)
  safe_name <- gsub("_+", "_", safe_name)
  safe_name <- gsub("^_|_$", "", safe_name)
  
  out_path <- file.path(out_dir, paste0(safe_name, ".gpkg"))
  
  # Fix: Explicitly specify layer name (must be alphanumeric)
  st_write(ctry_sf, out_path, layer = safe_name, delete_dsn = TRUE, quiet = TRUE)
  cat(sprintf("  %-35s %4d polygons → %s\n", ctry, nrow(ctry_sf), basename(out_path)))
}

cat("\nDone. All country files saved to:", out_dir, "\n")


#10759 polygons → .gpkg
#  Albania                               32 polygons → Albania.gpkg
#  Angola                                 2 polygons → Angola.gpkg
#  Antarctica                          5698 polygons → Antarctica.gpkg
#  Argentina                            664 polygons → Argentina.gpkg
#  Armenia                                2 polygons → Armenia.gpkg
#  Australia                            875 polygons → Australia.gpkg
#  Austria                                1 polygons → Austria.gpkg
#  Bangladesh                           207 polygons → Bangladesh.gpkg
#  Belarus                                1 polygons → Belarus.gpkg
#  Belgium                                4 polygons → Belgium.gpkg
#  Bolivia                              143 polygons → Bolivia.gpkg
#  Botswana                               1 polygons → Botswana.gpkg
#  Brazil                              7715 polygons → Brazil.gpkg
#  Burkina Faso                           6 polygons → Burkina_Faso.gpkg
#  Burundi                                5 polygons → Burundi.gpkg
#  Cambodia                            5620 polygons → Cambodia.gpkg
#  Cameroon                               7 polygons → Cameroon.gpkg
#  Canada                              5842 polygons → Canada.gpkg
#  Central African Rep.                   1 polygons → Central_African_Rep.gpkg
#  Chad                                   2 polygons → Chad.gpkg
#  Chile                               2527 polygons → Chile.gpkg
#  China                               551470 polygons → China.gpkg
#  Colombia                            24348 polygons → Colombia.gpkg
#  Congo                                 15 polygons → Congo.gpkg
#  Costa Rica                          2983 polygons → Costa_Rica.gpkg
#  Côte d'Ivoire                        25 polygons → C_te_d_Ivoire.gpkg
#  Cyprus                                 1 polygons → Cyprus.gpkg
#  Czechia                                4 polygons → Czechia.gpkg
#  Dem. Rep. Congo                       52 polygons → Dem_Rep_Congo.gpkg
#  Denmark                                9 polygons → Denmark.gpkg
#  Dominican Rep.                         1 polygons → Dominican_Rep.gpkg
#  Ecuador                              289 polygons → Ecuador.gpkg
#  Estonia                               87 polygons → Estonia.gpkg
#  Ethiopia                             701 polygons → Ethiopia.gpkg
#  France                                89 polygons → France.gpkg
#  Gabon                                  4 polygons → Gabon.gpkg
#  Gambia                                38 polygons → Gambia.gpkg
#  Germany                              254 polygons → Germany.gpkg
#  Ghana                               2512 polygons → Ghana.gpkg
#  Guatemala                           3423 polygons → Guatemala.gpkg
#  Guinea                                 3 polygons → Guinea.gpkg
#  Guinea-Bissau                        230 polygons → Guinea_Bissau.gpkg
#  Haiti                                 10 polygons → Haiti.gpkg
#  Honduras                               6 polygons → Honduras.gpkg
#  India                               61197 polygons → India.gpkg
#  Indonesia                           7625 polygons → Indonesia.gpkg
#  Iran                                  10 polygons → Iran.gpkg
#  Ireland                                1 polygons → Ireland.gpkg
#  Israel                                 3 polygons → Israel.gpkg
#  Italy                                 16 polygons → Italy.gpkg
#  Japan                                  1 polygons → Japan.gpkg
#  Jordan                                 4 polygons → Jordan.gpkg
#  Kenya                               178321 polygons → Kenya.gpkg
#  Laos                                1349 polygons → Laos.gpkg
#  Latvia                                16 polygons → Latvia.gpkg
#  Lesotho                                3 polygons → Lesotho.gpkg
#  Lithuania                              2 polygons → Lithuania.gpkg
#  Madagascar                           120 polygons → Madagascar.gpkg
#  Malawi                                40 polygons → Malawi.gpkg
#  Malaysia                               9 polygons → Malaysia.gpkg
#  Mali                                   1 polygons → Mali.gpkg
#  Mauritania                             1 polygons → Mauritania.gpkg
#  Mexico                              110819 polygons → Mexico.gpkg
#  Mongolia                               1 polygons → Mongolia.gpkg
#  Morocco                              226 polygons → Morocco.gpkg
#  Mozambique                          5063 polygons → Mozambique.gpkg
#  Myanmar                             1648 polygons → Myanmar.gpkg
#  Namibia                                2 polygons → Namibia.gpkg
#  Nepal                                 28 polygons → Nepal.gpkg
#  New Zealand                            2 polygons → New_Zealand.gpkg
#  Nicaragua                           2846 polygons → Nicaragua.gpkg
#  Niger                                139 polygons → Niger.gpkg
#  Nigeria                              464 polygons → Nigeria.gpkg
#  Norway                                 1 polygons → Norway.gpkg
#  Oman                                   3 polygons → Oman.gpkg
#  Pakistan                             938 polygons → Pakistan.gpkg
#  Panama                                82 polygons → Panama.gpkg
#  Paraguay                             801 polygons → Paraguay.gpkg
#  Peru                                24018 polygons → Peru.gpkg
#  Philippines                          774 polygons → Philippines.gpkg
#  Poland                                 1 polygons → Poland.gpkg
#  Portugal                             263 polygons → Portugal.gpkg
#  Romania                              264 polygons → Romania.gpkg
#  Russia                                 3 polygons → Russia.gpkg
#  Rwanda                              46402 polygons → Rwanda.gpkg
#  S. Sudan                               1 polygons → S_Sudan.gpkg
#  Senegal                             3475 polygons → Senegal.gpkg
#  Serbia                                 2 polygons → Serbia.gpkg
#  Sierra Leone                        1877 polygons → Sierra_Leone.gpkg
#  South Africa                         208 polygons → South_Africa.gpkg
#  Spain                                723 polygons → Spain.gpkg
#  Sri Lanka                           2490 polygons → Sri_Lanka.gpkg
#  Switzerland                            3 polygons → Switzerland.gpkg
#  Tanzania                            4777 polygons → Tanzania.gpkg
#  Thailand                              78 polygons → Thailand.gpkg
#  Timor-Leste                            8 polygons → Timor_Leste.gpkg
#  Togo                                   5 polygons → Togo.gpkg
#  Uganda                              19404 polygons → Uganda.gpkg
#  Ukraine                                2 polygons → Ukraine.gpkg
#  United Arab Emirates                  12 polygons → United_Arab_Emirates.gpkg
#  United Kingdom                        42 polygons → United_Kingdom.gpkg
#  United States of America            3744 polygons → United_States_of_America.gpkg
#  Uruguay                             12822 polygons → Uruguay.gpkg
#  Venezuela                             46 polygons → Venezuela.gpkg
#  Vietnam                               15 polygons → Vietnam.gpkg
#  Zambia                               358 polygons → Zambia.gpkg
#  Zimbabwe                              14 polygons → Zimbabwe.gpkg