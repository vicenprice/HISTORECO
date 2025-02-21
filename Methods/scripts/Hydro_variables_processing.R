############################## HYDROLOGICAL VARIABLES #########################
# Load necessary libraries
library(dplyr)
library(readxl)
library(readr)
library(stringdist)
library(janitor)
library(rgdal)
library(tidyr)
library(openxlsx)


#### RESERVOIR VARIABLES ------------------------------------

# Read SEPREM dam data, filter out rows with irrelevant data
embal_year <- read_excel('.../presas_seprem.xlsx') %>%
  filter(!str_detect(Volumen, "Finaliza"), !str_detect(Nombre, "\\(DIQUE"), !is.na(Año_finalización))

# Read the original dams dataset, select relevant columns and filter out rows without a dam name
embal_original <- read_excel('.../Embalses_base.xlsx') %>%
  select(1:6) %>%
  filter(!is.na(NOM_EMBA))

# Assign year of completion based on matching dam names between the two datasets
embal_original <- embal_original %>%
  mutate(AÑO = embal_year$Año_finalización[match(NOM_EMBA, embal_year$Nombre)],
         Nombre = embal_year$Nombre[match(NOM_EMBA, embal_year$Nombre)])

# Separate dams with assigned years and find those not matched
embal_original_añosi <- filter(embal_original, !is.na(AÑO))
emb_year_dist <- anti_join(embal_year, embal_original_añosi, by = "Nombre")

# Read manually matched dam data and combine them with the original dataset
emb_match_II <- read_excel('.../embalses_match_II.xlsx')
embal_original <- embal_original %>%
  mutate(AñoII = emb_match_II$Año_finalización[match(Nombre, emb_match_II$Nombre.y)],
         Año_construccion = coalesce(AÑO, AñoII)) %>%
  select(1:6, Año_construccion)

# Read shapefile data of Spanish dams, standardize dam names and assign construction years from the dataset
v_embalses <- readOGR('.../embalses_spain.shp') %>%
  mutate(NOM_EMBA = gsub('�', 'ñ', toupper(NOM_EMBA))) %>%
  arrange(NOM_EMBA)

v_embalses@data$Año <- embal_original$Año_construccion[match(v_embalses@data$NOM_EMBA, embal_original$NOM_EMBA)]
writeOGR(v_embalses, '.../Embalses_Spain_year.shp', driver = "ESRI Shapefile", overwrite = TRUE)

# Read data on dams by municipality, calculate the proportion of area and volume for each municipality
embalses_clean <- read_excel('.../embalses_muni_20211021.xlsx') %>%
  mutate(area_embalse_proporcion = area_embalse_muni / AREA_EMBA,
         volumen_embalse_muni = VOL_EMBA * area_embalse_proporcion,
         volumen_embalse_util_muni = VOL_UTIL * area_embalse_proporcion) %>%
  adorn_totals("row")

# Group dam data by municipality, summarizing the area and volume variables
muni_embalses <- embalses_clean %>%
  group_by(CODIGOINE, NAMEUNIT) %>%
  summarise(across(starts_with('area_embalse'), sum, na.rm = TRUE),
            across(starts_with('volumen'), sum, na.rm = TRUE))

# Create a table that includes all municipalities, even those without dams, and populate it with dam data
t_embalses <- read_excel('.../Municipios_IGN.xlsx') %>%
  select(CODIGOINE, Municipio)

# For each variable, match data from the dam dataset to the municipalities
for (col in colnames(muni_embalses)[-1]) {
  t_embalses[[col]] <- muni_embalses[[col]][match(t_embalses$CODIGOINE, muni_embalses$CODIGOINE)]
}

# Replace missing values with zero and calculate row totals
t_embalses[is.na(t_embalses)] <- 0
t_embalses <- adorn_totals(t_embalses, "row")
write_xlsx(t_embalses, '.../Embalses2010s_acumulado.xlsx')

# Calculate accumulated dam data by decade
for (n in seq(1900, 2010, by = 10)) {
  tabla <- embalses_clean %>%
    filter(Año < n) %>%
    group_by(CODIGOINE, NAMEUNIT) %>%
    summarise(across(starts_with('area_embalse'), sum, na.rm = TRUE),
              across(starts_with('volumen'), sum, na.rm = TRUE)) %>%
    adorn_totals("row")
  
  write_xlsx(tabla, paste0("Embalses", n, "s_acumulado.xlsx"))
}

# Calculate non-accumulated dam data for each decade
for (n_down in seq(1900, 2010, by = 10)) {
  n_up <- n_down + 10
  tabla <- embalses_clean %>%
    filter(Año < n_up & Año >= n_down) %>%
    group_by(CODIGOINE, NAMEUNIT) %>%
    summarise(across(starts_with('area_embalse'), sum, na.rm = TRUE),
              across(starts_with('volumen'), sum, na.rm = TRUE)) %>%
    adorn_totals("row")
  
  write_xlsx(tabla, paste0("Embalses_", n_down, "s.xlsx"))
}

# Reorganize the accumulated data into a final table
l_emb <- list.files('./embalses/tablas_embalses', pattern = 'acumul', full.names = TRUE)

tabla_ej <- read_excel('./Municipios_IGN.xlsx') %>%
  select(NAMEUNIT, CODIGOINE)

# Read all accumulated tables by decade and append their data to the final table
for (i in l_emb) {
  fecha <- substr(basename(i), 36, 40)
  t <- read_excel(i) %>%
    select(1, 3:5) %>%
    rename_with(~paste0(., "_", fecha), 2:4)
  
  for (col in colnames(t)[-1]) {
    tabla_ej[[col]] <- t[[col]][match(tabla_ej$CODIGOINE, t$CODIGOINE)]
  }
}

# Replace missing values with zero and create a long format table for further analysis
tabla_ej[is.na(tabla_ej)] <- 0

embalses_longer <- tabla_ej %>%
  pivot_longer(cols = 3:ncol(tabla_ej), names_pattern = "(.+)(_\\d{4}s)", names_to = c(".value", "Año"))

write_xlsx(embalses_longer, '.../Embalses_final_longer.xlsx')




##### WATER COURSES VARIABLES ----------------------------------
# 1. Load Shapefiles (Municipalities, Complete water network, and Main watercourses)
# Replace the paths below with your actual file paths

municipalities <- st_read("./municipalities_shapefile.shp")
all_rivers <- st_read("./water_network_shapefile.shp")
main_rivers <- st_read("./mainwatercourses.shp")

# 2. Convert the river shapefiles (polylines) to points using the QGIS algorithm 'Points along geometry'

# Conversion for all rivers
all_river_points <- qgis_run_algorithm("native:pointsalonglines", 
                                       INPUT = all_rivers, 
                                       DISTANCE = 100,  # Distance between points (in meters)
                                       OUTPUT = tempfile())$OUTPUT

all_river_points_sf <- st_read(all_river_points)

# Conversion for main rivers
main_river_points <- qgis_run_algorithm("native:pointsalonglines", 
                                        INPUT = main_rivers, 
                                        DISTANCE = 100,  # Adjust distance as needed
                                        OUTPUT = tempfile())$OUTPUT

main_river_points_sf <- st_read(main_river_points)

# 3. Calculate centroids for municipalities
municipality_centroids <- st_centroid(municipalities)

# 4. Calculate the distance from each municipality centroid to the nearest river and the nearest main river

# Distance to the nearest river (all watercourses)
dist_all_rivers <- qgis_run_algorithm("qgis:distancetonearesthubpoints", 
                                      INPUT = municipality_centroids, 
                                      HUBS = all_river_points_sf, 
                                      FIELD = "river_id",  # Field to identify the river (if available)
                                      OUTPUT = tempfile())$OUTPUT

dist_all_rivers_sf <- st_read(dist_all_rivers)

# Distance to the nearest main river
dist_main_rivers <- qgis_run_algorithm("qgis:distancetonearesthubpoints", 
                                       INPUT = municipality_centroids, 
                                       HUBS = main_river_points_sf, 
                                       FIELD = "main_river_id",  # Field to identify the main river (if available)
                                       OUTPUT = tempfile())$OUTPUT

dist_main_rivers_sf <- st_read(dist_main_rivers)

# 5. Join the results back to the municipality centroids, so each municipality now has the nearest river distance

municipalities_with_distances <- municipality_centroids %>%
  left_join(dist_all_rivers_sf, by = "CODIGOINE") %>% 
  left_join(dist_main_rivers_sf, by = "CODIGOINE")

# 6. Now, you can save the resulting data with distances to rivers as a new shapefile or CSV
st_write(municipalities_with_distances, "OUTPUT.shp")
