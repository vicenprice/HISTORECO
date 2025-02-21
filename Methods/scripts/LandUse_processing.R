################################# LAND USE CODE ############################################

# LOAD NECESSARY LIBRARIES --------------------------------
library(exactextractr)
library(rgdal)
library(raster)
library(tidyverse)
library(readxl)
library(writexl)
library(sf)
library(st)
library(terra)
library(stringr)


#################### LAND USE ZONAL STATISTICS


## DATA LOADING --------------------------------

# Path to the folder with the climatic rasters and the municipal spatial base
folder_path <- "./folderpath" 
municipalities_path <- "./folderpath/Municipalities.shp"
# List of raster files
l <- list.files(folder_path, pattern = "asc", full.names = T) 
# Read vector base
v <- st_read(dsn = municipalities_path) 


## PROCESSING ------------------------------------

# year counter /timespan counter
year = 1900 

for(i in l){
  # string for timespan for the names
  year_s <- as.character(year)
  # Raster reading
  r <- raster(i)
  
  # Zonal statistics
  v$zs <- exact_extract(r, v, "stat") # Zonal statistics operation (in stat we write de variable(s) needed)
  att_table <- as_tibble(v) # Attribute table as tibble (tidyverse table)
  att_table <- att_table %>% dplyr::mutate( # New columns identifying timespan
    Year = paste0(year_s, "s"),
  ) %>% dplyr::select(CODIGOINE, year, zs) # Selection of colums we want to preserve
  # Exportation
  output_name <- paste0("NAME", year_s, ".xlsx") # Name for the file
  assign(output_name, att_table) # Create an object in memory with that name
  write_xlsx(att_table, paste0(output_name)) # Export the temporary results
  print(paste0("The file ", output_name, " was completed successfully")) # Print to follow the process
  year = year + 10
}

## UNION OF ALL FILES RELATED TO EACH MONTH -------------

objects <- ls(pattern = "pattern")

# Create a list of these objects
file_list <- mget(objects)

# Bind all dataframes into one
combined <- bind_rows(object_list) 

# Export the combined result
write_xlsx(combined, "combined_result.xlsx")





############################## IRRIGATION ADJUSTMENT FOR LAST DECADES 

# READING AND CLEANING THE GLOBAL IRRIGATED AREAS RASTER FILE ----------------
gia_path <- "./giafile.tif"
gia <- raster(gia_path) # Read the raster file for the areas
cellStats(gia_reclass, "max") # Check that the file was reclassified correctly (maximum = 1)

# IRRIGATION CALCULATION -----------------------
# Zonal statistics --> number of cells per municipality with value = 1.
v@data$irrigation_cells <- exact_extract(gia_reclass, v, 'sum') # Column with the value per municipality = irrigation_cells
att_table <- as_tibble(v@data) # Attribute table as tibble (tidyverse table)

# CONVERSION OF CELLS WITH VALUE 1 TO IRRIGATED HECTARES ----------------
att_table <- att_table %>% dplyr::mutate( # New columns
  lat_rad = x * pi / 180, # Column with latitude in radians
  lon_rad = y * pi / 180, # Column with longitude in radians
  degree_meter_lat = 111319.9 * cos(lat_rad), # Degree to meter conversion at that latitude
  degree_meter_lon = 111319.9 * cos(lon_rad), # Degree to meter conversion at that longitude
  pixel_meters_lat =  0.008333333 * degree_meter_lat, # Pixel size * conversion at that latitude
  pixel_meters_lon =  0.008333333 * degree_meter_lon, # Pixel size * conversion at that longitude
  area_pixel_m2 = pixel_meters_lat * pixel_meters_lon, # Pixel area at those coordinates = lat size * lon size
  irrigation_GIA_m2 = irrigation_cells * area_pixel_m2, # Irrigation in m2 = cells with value 1 * pixel area at that latitude
  irrigation_GIA_ha = irrigation_GIA_m2 / 10000 # Convert to hectares
)



############################## AJUSTE DE REGADÍO DE LAS DÉCADAS MÁS RECIENTES

# CARGA DE DATOS ----------------------
rest2010 <- as_tibble(read_excel("./pathregadio2010.xlsx")) # Load estimated irrigation area 2010
rest2000 <- as_tibble(read_excel("./pathregadio2000.xlsx")) # Load estimated irrigation area 2010 
rok2002 <- as_tibble(read_excel("./datos/ESYRCE_2002.xlsx")) #Load official irrigation area 2002
rok2010 <- as_tibble(read_excel("./datos/2010_irrigationESYRCE.xlsx"))  #Load official irrigation area 2010

# AJUSTE DEL 2002 A VALORES de 2000  DEL REGADIO OFICIAL ----------------
# Adjustment from 2002 to 2000 totals to homogenise year
tot2000 = 3235510 # Total official irrigated hectares in Spain 
rok2000 <- rok2002  %>%
  mutate(tot2002 = sum(Total_irrigation), tot2000 = tot2000, 
         # Adjustment of regional values to official national totals in 2000
         irrigation_ok_2000 = Total_irrigation / tot2002 * tot2000)  

# CÁLCULO TASA DE CAMBIO 2000 - 2010 OFICIAL BY REGION --------------------  

# Union data of official irrigation data from 2000 & 2001
difok_0010 <- rok2010 %>% left_join(rok2000, by = "CODNUT2") 
# Field to numeric type
difok_0010$irrigation_ok_2010 <- as.numeric(difok_0010$irrigation_ok_2010)
#Evolution rate 2010 / 2000 of irrigation offcial values by region 
difok_0010 <- difok_0010 %>%  mutate(diferencia_ok_0010 = irrigation_ok_2010 - irrigation_ok_2000,
                                     tc0010_of = irrigation_ok_2010 / irrigation_ok_2000) 

# Selecting only the evolution rate
tc_of <- difok_0010 %>% dplyr::select(CODNUT2, tasacambio0010_of) 


# TASA DE EVOLUCIÓN DOBLE ASTERISCO (ESTIMADA 2010 / OFICIAL 2000) ------------

# Select only the adjusted irrigation for 2000 
rof00 <- difok_0010 %>% dplyr::select(CODNUT2, irrigation_ok_2000)
#Agregamos el área de regadío estimada para 2010 por regiones
rest2010ccaa <- rest2010 %>% group_by(CODNUT2, ccaa) %>%
  summarise_if(is.numeric, sum, na.rm = T) 
#Agregamos el área de regadío estimada para 2000 por regiones
rest2000ccaa <- rest2000 %>% group_by(CODNUT2, ccaa) %>%
  summarise_if(is.numeric, sum, na.rm = T)
#r Calculamos la tasa de cambio regional entre el regadio del 2000 y del 2010
tc_as <- rest2000ccaa %>% left_join(rest2010ccaa, by = "CODNUT2") %>%
  mutate(tc0010_as = irrigation_ha__ / regest_2000 )%>%
  dplyr::select(CODNUT2,tasacambio0010_as)

# Ajuste a los nuevos valores--------------
irrigation_ajustado <- rest2010 %>% dplyr::left_join(tc_of, by = "CODNUT2") %>% dplyr::left_join(tc_as, by = "CODNUT2") %>%
  mutate(irrigation_ajusted2010 = irrigation_ha__ * tasacambio0010_of / tasacambio0010_as) %>% 
  dplyr::select(1:6, irrigation_ajusted2010)




####################### Calculation of the area under cultivation and irrigated land in adjacent munici-palities 

# Define the path and load the shapefile
path <- '/Users/guillerodlopez96/Desktop/DATOS_GUILLERMO/BD_historeco/GIS'
setwd(path)                      # Set working directory
crop_area <- st_read('cultivos.shp')   # Read the shapefile into an sf object

# Initialize a new column to store the cultivated area of neighboring municipalities
crop_area$supcultivada_ha_vecinos <- 0

# Calculate the cultivated area of adjacent municipalities
for (i in 1:nrow(crop_area)) {
  # Get the geometry of the current municipality
  current_geometry <- crop_area[i, "geometry"]
  
  # Find neighboring municipalities that touch the current one
  neighbors <- crop_area[st_touches(current_geometry, crop_area$geometry, sparse = FALSE)[i, ], "CODIGOI"]
  
  # Exclude the current municipality's code from the neighbors list
  neighbors <- neighbors[neighbors != crop_area$CODIGOI[i]]
  
  # Sum the cultivated area of the neighboring municipalities
  area <- sum(crop_area[crop_area$CODIGOI %in% neighbors], na.rm = TRUE)
  
  # Assign the total area of neighboring cultivated land to the new column
  crop_area$supcultivada_ha_vecinos[i] <- area
}

# Save the resulting data frame to a CSV file
write.csv(crop_area, 'supcultivada_vecinos.csv', row.names = FALSE)



