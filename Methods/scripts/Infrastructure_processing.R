# Libraries
library(tidyverse)
library(sf)
library(units)
library(writexl)
library(readxl)

# Read shapefiles
municipalities <- st_read("./data/Municipalities.shp")
airports <- st_read("./GIS/Airports/Airports.shp")

c = 1900
while(c <= 2021){ 
  # Create an object with the decade
  decade <- paste0(as.character(c - 10), "s")
  
  # Ensure both shapefiles use the same coordinate system
  municipalities <- st_transform(municipalities, crs = 25830)  # UTM CRS for Spain
  airports <- st_transform(airports, crs = 25830)
  
  # Filter airports for the decade
  airports_decade <- airports %>% filter(Year <= c)
  
  # Compute municipality centroids
  centroids <- st_centroid(municipalities)
  
  # Compute distance to the nearest airport
  distances <- st_distance(centroids, airports_decade)
  
  # Get the minimum distance for each municipality
  min_distance <- apply(distances, 1, min)
  
  # Convert distances to readable units (e.g., kilometers)
  min_distance_km <- set_units(min_distance, "km")
  
  # Add minimum distances as a new column in the centroids dataframe
  centroids$airport_distance <- min_distance 
  
  # Convert to km
  centroids <- centroids %>% mutate(
    airport_distance = airport_distance / 1000,
    Year = c
  ) %>%
    dplyr::select(CODIGOINE, Year, airport_distance)
  
  # Assign the object name based on the decade
  assign(paste0("Aero", decade), centroids)
  
  # Increment counter by 10
  c = c + 1
}

# Get all object names starting with Aero
obj_names <- ls(pattern = "^Aero")

# Combine objects into a single data frame
combined_aeros <- bind_rows(mget(obj_names)) %>% arrange(Year)

# Remove individual objects
rm(list = obj_names)

combined_aeros <- combined_aeros %>% st_drop_geometry()

# Save results if needed
write_xlsx(combined_aeros, "airport_distance_year.xlsx")



# HIGH-SPEED RAIL DISTANCE -------------------------------
c = 1900
while(c <= 2021){
  # Ensure both shapefiles use the same coordinate system
  municipalities <- st_transform(municipalities, crs = 25830)  # UTM CRS for Spain
  hsr_stations <- st_transform(hsr_stations, crs = 25830)
  
  # Filter HSR stations by decade
  hsr_decade <- hsr_stations %>% filter(OPENING <= c)
  
  # Compute municipality centroids
  centroids <- st_centroid(municipalities)
  
  if (nrow(hsr_decade) == 0) {
    # No HSR stations available in this decade
    centroids <- centroids %>% mutate(
      highspeedstation_distance = Inf,
      nearest_highspeed_name = "No station available",
      Year = c
    )
  } else {
    # Compute distance to all HSR stations
    distances <- st_distance(centroids, hsr_decade)
    
    # Get the minimum distance and nearest station index
    min_indices <- apply(distances, 1, which.min)
    min_distance <- apply(distances, 1, min)
    
    # Extract the name of the nearest station
    hsr_names <- hsr_decade$NAME[min_indices]
    
    # Add minimum distances and station names as new columns
    centroids <- centroids %>% mutate(
      highspeedstation_distance = min_distance / 1000,
      nearest_highspeed_name = hsr_names,
      Year = c
    )
  }
  
  # Select final columns
  centroids <- centroids %>% dplyr::select(
    CODIGOINE, Year, highspeedstation_distance, nearest_highspeed_name
  )
  
  # Assign object name based on the decade
  assign(paste0("DistHSR", c), centroids)
  
  # Increment counter
  c = c + 1
}

# Get all object names starting with DistHSR
obj_names <- ls(pattern = "^DistHSR")

# Combine objects into a single data frame
combined_hsr <- bind_rows(mget(obj_names)) %>% arrange(Year)

# Remove individual objects
rm(list = obj_names)

# Save results if needed
write_xlsx(combined_hsr, "hsr_distance.xlsx")


# MERGING ALL DATA ------------------------
combined_stations <- as_tibble(combined_stations) %>% dplyr::select(-geometry)
combined_narrowgauge <- as_tibble(combined_narrowgauge) %>% dplyr::select(-geometry)
combined_hsr <- as_tibble(combined_hsr) %>% dplyr::select(-geometry)

railways <- combined_stations %>% left_join(combined_hsr, by = c("CODIGOINE", "Year")) %>%
  left_join(combined_narrowgauge, by = c("CODIGOINE", "Year"))

write_xlsx(railways, "railway_distance_year.xlsx")
