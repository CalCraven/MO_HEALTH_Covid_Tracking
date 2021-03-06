# Build ZIP Code Data ####

## Load Data ####
stl_city <- st_read("https://raw.githubusercontent.com/slu-openGIS/STL_BOUNDARY_ZCTA/master/data/geometries/STL_ZCTA_St_Louis_City.geojson", 
                           crs = 4326, stringsAsFactors = FALSE)
stl_county <- st_read("https://raw.githubusercontent.com/slu-openGIS/STL_BOUNDARY_ZCTA/master/data/geometries/STL_ZCTA_St_Louis_County.geojson", 
                    crs = 4326, stringsAsFactors = FALSE)
st_charles <- st_read("https://raw.githubusercontent.com/slu-openGIS/STL_BOUNDARY_ZCTA/master/data/geometries/STL_ZCTA_St_Charles_County.geojson", 
                      crs = 4326, stringsAsFactors = FALSE)
jeffco <- st_read("https://raw.githubusercontent.com/slu-openGIS/STL_BOUNDARY_ZCTA/master/data/geometries/STL_ZCTA_Jefferson_County.geojson", 
                      crs = 4326, stringsAsFactors = FALSE)

city_county <- st_read("https://raw.githubusercontent.com/slu-openGIS/STL_BOUNDARY_ZCTA/master/data/geometries/STL_ZCTA_City_County.geojson", 
                       crs = 4326, stringsAsFactors = FALSE)
region <- st_read("https://raw.githubusercontent.com/slu-openGIS/STL_BOUNDARY_ZCTA/master/data/geometries/STL_ZCTA_Regional.geojson", 
                       crs = 4326, stringsAsFactors = FALSE)

## Build County Level Data ####
### Define Dates
city_dates <- c(seq(as.Date("2020-04-01"), as.Date("2020-05-18"), by="days"), seq(as.Date("2020-05-20"), date, by="days"))
county_dates <- c(seq(as.Date("2020-04-06"), as.Date("2020-05-18"), by="days"), seq(as.Date("2020-05-20"), date, by="days"))
st_charles_dates <- seq(as.Date("2020-07-14"), date, by="days")
jeffco_dates <- seq(as.Date("2020-07-23"), date, by="days")

### Process Individual Jurisdictions
city_data <- process_zip(county = 510, dates = city_dates)
county_data <- process_zip(county = 189, dates = county_dates)
st_charles_data <- process_zip(county = 183, dates = st_charles_dates)
jeffco_data <- process_zip(county = 99, dates = jeffco_dates)

### Clean-up
rm(city_dates, county_dates, st_charles_dates, jeffco_dates)

### Save Individual Jurisdictions
write_csv(city_data, "data/zip/zip_stl_city.csv")
write_csv(county_data, "data/zip/zip_stl_county.csv")
write_csv(st_charles_data, "data/zip/zip_st_charles_county.csv")
write_csv(jeffco_data, "data/zip/zip_jefferson_county.csv")

## Subset to Report Date ####
### Subset and Project
stl_city <- filter(city_data, report_date == date) %>%
  left_join(stl_city, ., by = c("GEOID_ZCTA" = "zip"))
stl_county <- filter(county_data, report_date == date) %>%
  left_join(stl_county, ., by = c("GEOID_ZCTA" = "zip"))
st_charles <- filter(st_charles_data, report_date == date) %>%
  left_join(st_charles, ., by = c("GEOID_ZCTA" = "zip"))
jeffco <- filter(jeffco_data, report_date == date) %>%
  left_join(jeffco, ., by = c("GEOID_ZCTA" = "zip"))

### Clean-up
rm(city_data, county_data, st_charles_data, jeffco_data)

### Save Individual Jurisdictions
st_write(stl_city, "data/zip/daily_snapshot_stl_city.geojson", delete_dsn = TRUE)
st_write(stl_county, "data/zip/daily_snapshot_stl_county.geojson", delete_dsn = TRUE)
st_write(st_charles, "data/zip/daily_snapshot_st_charles_county.geojson", delete_dsn = TRUE)
st_write(jeffco, "data/zip/daily_snapshot_jefferson_county.geojson", delete_dsn = TRUE)

## Add Race and Poverty Data ####
stl_city <- left_join(stl_city, build_pop_zip(county = 510), by = "GEOID_ZCTA")
stl_county <- left_join(stl_county, build_pop_zip(county = 189), by = "GEOID_ZCTA")
st_charles <- left_join(st_charles, build_pop_zip(county = 183), by = "GEOID_ZCTA")
jeffco <- left_join(jeffco, build_pop_zip(county = 99), by = "GEOID_ZCTA")

## Build City-County Level Data ####
### Load Data
pop <- read_csv("https://raw.githubusercontent.com/slu-openGIS/STL_BOUNDARY_ZCTA/master/data/demographics/STL_ZCTA_City_County_Total_Pop.csv",
                col_types = cols(
                  GEOID_ZCTA = col_character(),
                  total_pop = col_double()
                  )) 

### Identify Zips with Missing Data
city_county_na <- rbind(stl_city, stl_county) %>%
  select(GEOID_ZCTA, cases) %>%
  filter(is.na(cases) == TRUE)
city_county_na <- unique(city_county_na$GEOID_ZCTA)

### Subset Zips that are Partially Missing
city_county_partials <- rbind(stl_city, stl_county) %>%
  select(GEOID_ZCTA, cases, case_rate, wht_pct, blk_pct, pvty_pct) %>%
  filter(GEOID_ZCTA %in% city_county_na == TRUE)

### Subset and Process Zips that are Complete
city_county_full <- rbind(stl_city, stl_county) %>%
  select(GEOID_ZCTA, cases) %>%
  filter(GEOID_ZCTA %in% city_county_na == FALSE)

st_geometry(city_county_full) <- NULL

city_county_full %>%
  group_by(GEOID_ZCTA) %>%
  summarise(cases = sum(cases)) -> city_county_full

city_county <- filter(city_county, GEOID_ZCTA %in% unique(city_county_full$GEOID_ZCTA)) %>%
  left_join(., city_county_full, by = "GEOID_ZCTA") %>%
  left_join(., pop, by = "GEOID_ZCTA") %>%
  mutate(case_rate = cases/total_pop*1000) %>%
  select(-total_pop)

city_county <- left_join(city_county, build_pop_zip(county = "city-county"), by = "GEOID_ZCTA")


### Combine Geometries
city_county <- rbind(city_county, city_county_partials)

### Write Data
st_write(city_county, "data/zip/daily_snapshot_city_county.geojson", delete_dsn = TRUE)

### Clean-up
rm(city_county, city_county_full, city_county_partials, city_county_na, pop)

## Build City-County Level Data ####
### Load Data
pop <- read_csv("https://raw.githubusercontent.com/slu-openGIS/STL_BOUNDARY_ZCTA/master/data/demographics/STL_ZCTA_Regional_Total_Pop.csv",
                col_types = cols(
                  GEOID_ZCTA = col_character(),
                  total_pop = col_double()
                )) 

### Identify Zips with Missing Data
regional_na <- rbind(stl_city, stl_county, st_charles, jeffco) %>%
  select(GEOID_ZCTA, cases) %>%
  filter(is.na(cases) == TRUE)
regional_na <- unique(regional_na$GEOID_ZCTA)

### Subset Zips that are Partially Missing
regional_partials <- rbind(stl_city, stl_county, st_charles, jeffco) %>%
  select(GEOID_ZCTA, cases, case_rate, wht_pct, blk_pct, pvty_pct) %>%
  filter(GEOID_ZCTA %in% regional_na == TRUE)

### Subset and Process Zips that are Complete
regional_full <- rbind(stl_city, stl_county, st_charles, jeffco) %>%
  select(GEOID_ZCTA, cases) %>%
  filter(GEOID_ZCTA %in% regional_na == FALSE)

st_geometry(regional_full) <- NULL

regional_full %>%
  group_by(GEOID_ZCTA) %>%
  summarise(cases = sum(cases)) -> regional_full

region <- filter(region, GEOID_ZCTA %in% unique(regional_full$GEOID_ZCTA)) %>%
  left_join(., regional_full, by = "GEOID_ZCTA") %>%
  left_join(., pop, by = "GEOID_ZCTA") %>%
  mutate(case_rate = cases/total_pop*1000) %>%
  select(-total_pop)

region <- left_join(region, build_pop_zip(county = "regional"), by = "GEOID_ZCTA")

### Combine Geometries
region <- rbind(region, regional_partials)

### Write Data
st_write(region, "data/zip/daily_snapshot_regional.geojson", delete_dsn = TRUE)

### Clean-up
rm(region, regional_full, regional_partials, regional_na, pop)
rm(jeffco, st_charles, stl_city, stl_county)
rm(process_zip, wrangle_zip, build_pop_zip)

