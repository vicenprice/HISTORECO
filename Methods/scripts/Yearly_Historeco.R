####### YEARLY DATABASE #####################
library(pacman)
library(tidyverse)
library(writexl)
library(readxl)
library(sf)
library(spdep)


# Annualization of static variables -------------------------------------

## Data loading
d <- as_tibble(read_csv("Historeco+.csv"))

## Keep only the time-static variables
static <- d %>% dplyr::select(
  1:7, 21:45,51,52, 54:63
)
names(static)

# Expand so that variables are annualized up to 2021
static <- static %>%
  mutate(anio = map(Year, ~ seq(.x, max(.x + 9, 2021)))) %>%  # Expand up to 2021 if necessary
  unnest(anio)  # Expand the list of years

# Rename and select the variables of interest
static <- static %>%
  dplyr::select(1:6, anio, everything()) %>%
  dplyr::select(-Year) %>%
  dplyr::rename(Year = anio) 



# Calculation of the cultivated and irrigated area of neighboring municipalities ----------------------------

## Data loading
### Load crop data and select the variables of interest
irri <- as_tibble(read_excel("./BD_anual/results/Irrigated_year.xlsx")) #%>% dplyr::select(CODIGOINE, Año, Irrigated)
dry <- as_tibble(read_excel("./BD_anual/results/Dryland_year.xlsx")) %>% dplyr::select(CODIGOINE, Año, Dryland)
### Load the spatial database
munis <- st_read("./data/Municipalities.shp")


## Compute the total cultivated area variable
### Join the irrigated and dryland tibbles
cult <- irri %>% left_join(dry, by = c("CODIGOINE", "Año")) 
### Sum both to obtain the cultivated area
cult <- cult %>% dplyr::mutate(
  cultivated_area = Irrigated + Dryland
) 
### Object with only the cultivated area
onlycult <- cult %>% dplyr::select(CODIGOINE, Año, cultivated_area)


## Merge with the municipal spatial database
### Convert irrigation and cultivated area values to wide format
wirri <- irri %>% pivot_wider(values_from = Irrigated, names_from = Año)
wcult <- onlycult %>% pivot_wider(values_from = cultivated_area, names_from = Año)
### Merge with the shapefile
spirri <- munis %>% left_join(wirri, by = "CODIGOINE")
spcult <- munis %>% left_join(wcult, by = "CODIGOINE")


## Compute the neighboring municipalities' area for both variables 
### Create the neighborhood matrix (using the queen criterion)
neighbors <- poly2nb(spirri, queen = TRUE)
### Convert the neighbors list into a dataframe
neighbor_list <- nb2listw(neighbors, style = "B", zero.policy = TRUE) 
### Select the irrigation hectares columns (1950:2023)
irrigation_cols <- as.character(1950:2023)
### Compute the sum of irrigation of neighboring municipalities for each year
for(year in irrigation_cols) {
  spirri[[paste0("IrriNeigh_", year)]] <- sapply(1:length(neighbors), function(i) {
    sum(spirri[[year]][neighbors[[i]]], na.rm = TRUE)
  })
}
### Compute the sum of cultivated area of neighboring municipalities for each year
for(year in irrigation_cols) {
  spcult[[paste0("CultNeigh_", year)]] <- sapply(1:length(neighbors), function(i) {
    sum(spcult[[year]][neighbors[[i]]], na.rm = TRUE)
  })
}


## Adjust the new data to the desired structure
spirri <- spirri %>% st_drop_geometry() %>%
  as_tibble() %>%
  dplyr::select(CODIGOINE, matches("Neigh")) %>%
  pivot_longer(
    cols = starts_with("IrriNeigh_"),  # Select columns with pattern "IrriNeigh_YYYY"
    names_to = "Year",                 # New column containing years
    names_prefix = "IrriNeigh_",       # Remove the "IrriNeigh_" prefix to get only the year
    values_to = "irrig_neighb"         # New column with irrigation hectares of neighbors
  ) 
spcult <- spcult %>% st_drop_geometry() %>%
  as_tibble() %>%
  dplyr::select(CODIGOINE, matches("Neigh")) %>%
  pivot_longer(
    cols = starts_with("CultNeigh_"),  # Select columns with pattern "CultNeigh_YYYY"
    names_to = "Year",                 # New column containing years
    names_prefix = "CultNeigh_",       # Remove the "CultNeigh_" prefix to get only the year
    values_to = "cultivated_area_neighb"  # New column with cultivated area of neighbors
  ) 
### Merge the objects
landuseneigh <- spirri %>% left_join(spcult, by = c("CODIGOINE", "Year"))



# Merge all variables into a single database ------------------------------------------
## Load all climate and land-use variables files
l <- list.files("./BD_anual/results")
for(i in l){
  variable <- as_tibble(read_excel(paste0("./BD_anual/results/", i)))
  assign(i, variable)
  
}
## Clean the land-use datasets
Dryland_year.xlsx <- Dryland_year.xlsx %>% dplyr::select(CODIGOINE, Año, Dryland)
Irrigated_year.xlsx <- Irrigated_year.xlsx %>% dplyr::select(CODIGOINE, Año,Irrigated)
pasture_year.xlsx <- pasture_year.xlsx %>% dplyr::select(CODIGOINE, Año, Pasture)

## Merge all into one
GrowPP_year.xlsx <- GrowPP_year.xlsx %>% dplyr::rename(CODIGOINE = INEcode, Año = Year)
### Get names of tibbles in memory containing "xlsx"
tibble_names <- ls(pattern = "xlsx")  
### Convert names into a list of objects
tibble_list <- tibble_names %>%
  map(~ get(.)) %>%
  keep(~ inherits(., "tbl_df"))  # Filter only tibbles
### Merge all tibbles using left_join() based on "CODIGOINE" and "Año"
climlanduse <- reduce(tibble_list, ~ left_join(.x, .y, by = c("CODIGOINE", "Año")))
### Reorder columns
climlanduse <- climlanduse %>% mutate(Cultivated_area = Irrigated + Dryland) %>%
  dplyr::select(CODIGOINE, Año,Spei,Precipitation,Tmean, grow_period_pp, Frost_days, Irrigated, Dryland, Pasture, Cultivated_area) %>%
  rename(Year = Año)

### Merge land use of neighbors
climlanduse <- climlanduse %>% dplyr::left_join(landuseneigh, by = c("CODIGOINE", "Year")) 
climlanduse <- climlanduse %>% rename(INEcode = CODIGOINE) %>%
  mutate(INEcode = if_else(nchar(INEcode) == 4, 
                           str_pad(INEcode, width = 5, pad = "0"), 
                           INEcode),
         Year = as.integer(Year)
  )

static <- static %>%
  mutate(INEcode= as.character(INEcode),
         INEcode = if_else(nchar(INEcode) == 4, 
                           str_pad(INEcode, width = 5, pad = "0"), 
                           INEcode))
### Add static variables
bd_year <- climlanduse %>% left_join(static, by = c("INEcode", "Year"))


### Add reservoir data
emby <- as_tibble(read_excel("./BD_anual/data/anual_embalses.xlsx")) %>%
  mutate(Year = as.integer(Year)) %>% distinct()
bd_year <- bd_year %>% dplyr::left_join(emby, by = c("INEcode", "Year"))


### Add infrastructure data
aerosy <- as_tibble(read_excel("distancia_aeropuertos_year.xlsx")) %>% rename(
  INEcode = CODIGOINE,
  Year = Año
)
ferroy <- as_tibble(read_excel("distancia_ferrocarril_year.xlsx")) %>% rename(
  INEcode = CODIGOINE
)

bd_year <- bd_year %>% left_join(ferroy, by = c("INEcode", "Year"))
bd_year <- bd_year %>% left_join(aerosy, by = c("INEcode", "Year"))


## Filter, reorder and export
bd_year <- bd_year %>% dplyr::select(CODNUT2, ccaa, Province_code, Province, INEcode, Municipality, everything())
bd_year <- bd_year %>% filter(Year <= 2021)

write_csv(bd_year, "./BD_anual/Historeco_Year.csv")


# Extract 2021 data
bd2021 <- bd_year %>% filter(Year == 2020)
write_xlsx(bd2021, "bd2021.xlsx")
