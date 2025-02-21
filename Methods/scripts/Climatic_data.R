#################### CLIMATIC ZONAL STATISTICS ############################
  
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

