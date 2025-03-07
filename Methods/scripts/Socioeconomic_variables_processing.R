############################## SOCIOECONOMIC VARIABLES #########################

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

# SLoad the population dataset
# Assuming 'population_data' is a dataframe that contains the municipal population data
population_data <- read.csv("./population.csv") # Load your data

#  Classify municipalities into urban, intermediate, and rural
# Create the urban_rural variable based on population thresholds
population_data <- population_data %>%
  mutate(urban_rural = case_when(
    population < 2000 ~ "rural",
    population >= 2000 & population < 10000 ~ "intermediate",
    population >= 10000 ~ "urban",
    TRUE ~ NA_character_ # Handle NA values
  ))

# Calculate distances to municipalities with more than p inhabitants
# Define a function to calculate distances
calculate_distance_to_population <- function(df, p) {
  # Filter municipalities based on the population threshold
  municipalities_below_p <- df %>% filter(population < p)
  municipalities_above_p <- df %>% filter(population >= p)
  
  # Convert dataframes to spatial objects
  st_below_p <- st_as_sf(municipalities_below_p, coords = c("longitude", "latitude"), crs = 4326)
  st_above_p <- st_as_sf(municipalities_above_p, coords = c("longitude", "latitude"), crs = 4326)
  
  # Calculate nearest municipality using the QGIS tool
  distances <- qgisprocess::qgis_run_algorithm("qgis:nearestneighbour", 
                                               INPUT = st_below_p,
                                               NEAREST = st_above_p,
                                               OUTPUT = "TEMPORARY_OUTPUT")
  
  # Extract distances
  return(distances)
}

# Calculate distances for 5000 and 10000 inhabitants
distance_pop_5000_ <- calculate_distance_to_population(population_data, 5000)
distance_pop_10000_ <- calculate_distance_to_population(population_data, 10000)

# Classify municipalities into Simpson areas
# Assuming 'simpson_area_data' contains the regions classification for municipalities
simpson_area_data <- read.csv("path_to_simpson_area_data.csv")

# Merge population data with Simpson area data
merged_data <- population_data %>%
  left_join(simpson_area_data, by = "codigo_provincia") %>%
  mutate(Simpson_Areas_5 = ifelse(region == "5", area_name, NA),
         Simpson_Areas_11 = ifelse(region == "11", area_name, NA))

# Final dataset with all calculated variables
final_data <- merged_data %>%
  select(municipality, population, urban_rural, distance_pop_5000_, distance_pop_10000_, Simpson_Areas_4, Simpson_Areas_10)

# Save the final dataset
write.csv(final_data, "output.csv", row.names = FALSE)
