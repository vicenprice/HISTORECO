README
================
Guillermo Rodríguez-López, Ignacio Cazcarro, Ana Serrano, Miguel
Martín-Retortillo
2024-10-10

# HISTORECO: Historical Spanish transition database on climate, geography, and economics of the 20th-21st Century

### Authors:

Guillermo Rodríguez-López, Ana Serrano, Miguel Martín-Retortillo,
Ignacio Cazcarro (corresponding author: <icazcarr@unizar.es>)

------------------------------------------------------------------------

## Description

**HISTORECO** is a comprehensive database that includes 45 geographic,
climatic, hydrological, demographic, and economic variables (64 independent columns apart from the 7 first of identification of the municipality in "Historeco.csv") spanning the
20th and 21st centuries, covering **8,122 homogeneous municipalities in Spain**
each of which has one value per decade. It is a unique dataset that
integrates data from various sources, facilitating the analysis of
long-term temporal and spatial trends across multiple disciplines such
as climate, geography, and socio-economic development.

The dataset combines information from twenty sources,
harmonizing and downscaling them to the municipal level using GIS and
programming tools (mainly QGIS, R, and Python). This is the most
extensive dataset of its kind in terms of temporal depth and spatial
granularity available for Spain.

This project has been developed thanks to funding from the Ramón Areces
Foundation, without which it would not have been possible.

------------------------------------------------------------------------

## Data Structure

The database is provided in two main formats:

1.  **Panel Data (CSV)**:

    -   One observation per municipality and decade.
    -   7 initial identification columns (e.g., NUTS codes, municipality
        names) followed by the set of variables.

2.  **Spatial Data (Shapefile)**:

    -   A spatial representation of the municipalities with an
        associated attribute table containing one column per variable
        and decade.
        The shapefile comprises 8,205 objects/polygons given that it also includes 87 objects of communal forests (mainly in Navarre, with the “facerías” regime, Basque Country, Castile and Leon, Cantabria and one case in Castile-La Mancha and another in Asturias).

3.  **Atribute table format**: An archive with the same structure as the
    attribute table, one row per municipality and one column per
    variable and decade, but with no spatial representation
    (Historeco\_wide.csv).

4.  **Municipalities spatial base**: A shapefile with the Spanish
    municipalities is also included in case you want to use it and join
    it with the file Historeco\_wide.csv in an autonomous way.This
    shapefile comes from the National Geographic Institute (IGN,
    <https://centrodedescargas.cnig.es/CentroDescargas/catalogo.do>).

5.  **Yearly Panel Data (CSV)** "Historeco_Year.csv": A more exploratory (in progress) database
    where yearly data is provided since 1950 for several climatic, land use, hydrological and geographic variables.

------------------------------------------------------------------------

## Variables

The database contains **45 variables** divided into five thematic
groups:

1.  **Climatic Variables** (e.g., total precipitation, mean temperature,
    frost days).
2.  **Geographical Variables** (e.g., distance to the coast, altitude,
    area, ruggedness).
3.  **Land Use Variables** (e.g., dryland surface, irrigated area,
    pastures, total crop area).
4.  **Hydrological Variables** (e.g., river basin, reservoir volume,
    distance to watercourses).
5.  **Socio-economic Variables** (e.g., population, urban/rural
    classification, distance to large municipalities).

------------------------------------------------------------------------

## Usage

### Panel Data Format

The CSV file is structured with one observation per municipality and
decade, enabling longitudinal analysis across multiple variables. It
includes demographic, geographic, climatic, and socio-economic data,
making it suitable for various fields of research.

### Spatial Data Format

The Shapefile includes the municipal polygons, allowing for direct use
in GIS applications. Researchers can use this format to create maps,
perform spatial analyses, and combine the data with other spatial
datasets.

------------------------------------------------------------------------

## Methods

The data were derived using a variety of statistical and GIS techniques,
tailored to homogenize and rescale the original data from various
primary sources Full details of the methodological process for each
thematic group are available in the methods folder.

------------------------------------------------------------------------

## Citation

If you use this database in your research, please cite the following
paper:

Rodríguez-López, G., Serrano, A., Martín-Retortillo, M. & Cazcarro, I.(2025).
HISTORECO: Historical Spanish Transition Database on Climate, Geography,
and Economics of the 20th-21st Century. Under Review in Scientific Data.

------------------------------------------------------------------------

## License

This dataset is released under the **Creative Commons Attribution 4.0
International License (CC BY 4.0)**. You are free to share and adapt the
material as long as you provide appropriate credit.

------------------------------------------------------------------------

## Contact

For any questions regarding the database or issues using it, please
contact the corresponding author **Ignacio Cazcarro** at
<icazcarr@unizar.es>.
