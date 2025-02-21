############################## GEOGRAPHICAL VARIABLES #########################

# Load libraries 
library(exactextractr)
library(rgdal)
library(raster)
library(tidyverse)
library(readxl)
library(writexl)
library(sf)
library(st)
library(terra)



## Data Reading
ruta <- "./DEMpath" # Path to the raster
v <- st_read(dsn = "./GIS/Municipios_IGN_ETRS89.shp") # Read vector base
r <- raster(ruta) # Read raster (Digital Elevation Model)
coastline <- st_read("./path/to/coastline.shp")  # Coastline

#### ALTITUDE AND RUGGEDNESS ----------------

# Zonal Statistics
v$zs_mean <- exact_extract(r, v, "mean") # Mean altitude
v$zs_sd <- exact_extract(r, v, "st_dev") # Standard deviation of altitude = ruggedness
att_table <- as_tibble(v) # Attribute table as tibble (tidyverse table)

# Export
write_xlsx(att_table, "altitude_ruggedness")



### DISTANCE OPERATIONS -----------

# Extract centroids
centroids <- st_centroid(v)

# Add X and Y coordinates
centroids <- centroids %>%
  mutate(x = st_coordinates(.)[,1], 
         y = st_coordinates(.)[,2])

#  Generate layers for Madrid and provincial capitals
madrid <- municipalities %>% 
  filter(CODIGOINE  == "28050 ")  # Filter by municipality code

provincial_capitals <- municipalities %>% 
  filter(capital == 1)  # Filter based on a province capital dummy

# Calculate distance to Madrid using qgisprocess
madrid_distance_layer <- qgisprocess::qgis_run_algorithm("qgis:distancetonearesthub",
                                                         INPUT = centroids,
                                                         HUBS = madrid,
                                                         OUTPUT = "memory:")

# Extract the distances from the output
centroids$distance_to_madrid <- st_drop_geometry(madrid_distance_layer)

#Calculate distance to provincial capitals using qgisprocess
provincial_distance_layer <- qgisprocess::qgis_run_algorithm("qgis:distancetonearesthub",
                                                             INPUT = centroids,
                                                             HUBS = provincial_capitals,
                                                             OUTPUT = "memory:")
# Extract the distances from the output
centroids$distance_to_provincial_capital <- st_drop_geometry(provincial_distance_layer)

# Calculate distance to the coastline using qgisprocess
coastline_distance_layer <- qgisprocess::qgis_run_algorithm("qgis:distancetonearesthub",
                                                            INPUT = centroids,
                                                            HUBS = coastline,
                                                            OUTPUT = "memory:")

# Extract the distances from the output
centroids$distance_to_coastline <- st_drop_geometry(coastline_distance_layer)

#  write to CSV
write.csv(centroids, ".//municipalities_with_distances.csv")  # Adjust the path 

