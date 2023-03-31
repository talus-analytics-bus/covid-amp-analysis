
# setup -------------------------------------------------------------------

library(tidyverse)
library(sf)
library(lubridate)
library(maps)
library(sp)
library(tigris)
library(gridExtra)
library(stringr)


# read in data ------------------------------------------------------------

# RAW AIRTABLE DATA

full_airtable <- 
  read_csv('data/raw/all_airtable_rows.csv') %>% 
  
  # fix col names
  rename_all(
    funs(
      str_to_lower(.) %>% 
        str_replace_all(., ' ','_'))) %>% 
  rename('authorizing_local_area'
         = 'authorizing_local_area_(e.g.,_county,_city)_names_-_linked_to_local_area_database',
         'affected_local_area' 
         = "affected_local_area_(e.g.,_county,_city)_names_-_linked_to_local_area_database",
         'aff_state_names' = 'aff_state_names_(lookup)',
         'auth_state_names' = 'auth_state_names_(lookup)') %>% 
  mutate_all(funs(str_remove_all(., "\\['|\\']"))) %>% 
  
  #remove NPG
  filter('policy/law_type' != 'Non-policy guidance') %>%
  
  # remove any rows missing key info
  drop_na('policy_category',
          'policy_description',
          'authorizing_country_iso',
          'policy/law_name')

write_csv(full_airtable, 'data/processed/full_airtable_cleaned.csv')

# Shapefile read ins/Total maps -------------------------------------------

# COUNTRIES

# countries shapefile 

countries <- 
  st_read('data/spatial/ne_10m_admin_0_countries/ne_10m_admin_0_countries.shp')

# adjust full airtable to show total number of policies per country

number_rows_per_country <- 
  full_airtable %>% 
  filter(authorizing_level_of_government == 'Country') %>% 
  count(authorizing_country_iso) %>% 
  merge(x = countries,
        y = ., 
        by.x = 'ADM0_A3', 
        by.y = 'authorizing_country_iso')
  
# generate simple maps
  
country_totals_map <- 
  number_rows_per_country %>% 
  ggplot() +
  geom_sf(aes(fill = n)) + 
  # scale_fill_viridis_c() +
  theme_minimal() +
  theme(axis.text.x = element_blank(),
        axis.text.y = element_blank(),
        axis.ticks = element_blank(),
        rect = element_blank(),
        panel.background = element_rect(fill = "white"),
        panel.grid.major = element_line(color = "white")) +
  scale_fill_gradient2(limits = c(0,1100))

# STATES

# us states shapefile (pulled from US Census, tigris package)

us_states <- 
  states(cb = TRUE, resolution = "20m") %>%
  shift_geometry()
# <- st_read('data/spatial/states/cb_2018_us_state_500k.shp') %>% 
#   st_transform(crs = 5070) %>% 
#   st_simplify(dTolerance = 10000) %>% 


number_rows_per_us_state <- 
  
  # filter to only US states, with state level authorization
  
  full_airtable %>% 
  filter(authorizing_country_iso == 'USA',
    authorizing_level_of_government == 'State/Province (Intermediate area)') %>% 
  
  # count number of rows per state
  
  count(auth_state_names) %>% 
  
  # merge with spatial data

  left_join(us_states, 
        by = c('auth_state_names' = 'NAME')) %>% 
  
  st_as_sf()

usa_totals_map <- 
  number_rows_per_us_state %>% 
  ggplot() +
  geom_sf(aes(fill = n)) + 
  # scale_fill_viridis_c() + 
  theme_minimal() +
  theme(axis.text.x = element_blank(),
        axis.text.y = element_blank(),
        axis.ticks = element_blank(),
        rect = element_blank(),
        panel.background = element_rect(fill = "white"),
        panel.grid.major = element_line(color = "white")) +
  scale_fill_gradient2(limits = c(0,1100))

# COMBINE USA & COUNTRY MAPS

grid.arrange(usa_totals_map, country_totals_map)
  

# making comparative charts -------------------------------------------------------

# comparing numbers of policies per category

cat_and_subcat_US_states <- 
  full_airtable %>% 
  filter(authorizing_country_iso == 'USA',
         authorizing_level_of_government == 'State/Province (Intermediate area)') %>%
  select(unique_id, policy_category, policy_subcategory) %>%
  count(policy_category) %>% 
  ggplot() +
  
  # code for just policy category
  geom_col(aes(x = policy_category,
               y = n),
           fill = "#63C5DA") +
  labs(x = '', 
       y = 'Total Number of Policies Available',
       title = 'Total Number of Policies per Category',
       subtitle = 'US States & Territories',
       caption = 'Source: COVID AMP, Georgetown University Center for Global Health Science and Security') +
  coord_flip() +
  # use code below if trying to split out by subcategory
  # geom_bar(aes (x = policy_category,
  #               fill = as.factor(policy_subcategory))) +
  theme(
        plot.title = element_text(color = "#000000", size = 15, face = 'bold',
                                  hjust = -0.25),
        plot.subtitle = element_text(face = "bold", color = '#808080',
                                     hjust = -0.15),
        plot.caption = element_text(face = "italic", size = 5),
        axis.title.x = element_text(color = "#000000", size = 10, face = "bold"),
        axis.text = element_text(size = 8),
        
        # get rid of ggplot background
        panel.grid.minor = element_blank(),
        panel.background = element_blank()) +
  scale_x_discrete(labels = function(x) str_wrap(x, width = 20))

# comparing types of policies (this is not formatted)

relax_restrict_US_states <- 
  full_airtable %>% 
  filter(authorizing_country_iso == 'USA',
         authorizing_level_of_government == 'State/Province (Intermediate area)') %>%
  select(unique_id, policy_category, policy_relaxing_or_restricting) %>% 
  ggplot() +
  geom_bar(aes (x = policy_category,
                fill = as.factor(policy_relaxing_or_restricting))) +
  theme(legend.position="bottom",
        legend.text=element_text(size=8),
        legend.key.size = unit(0.5, 'cm')) +
  coord_flip()


cat_totals_unfiltered <- 
  full_airtable %>% 
  select(unique_id, policy_category, policy_subcategory) %>%
  count(policy_category) %>% 
  ggplot() +
  
  # code for just policy category
  geom_col(aes(x = policy_category,
               y = n),
           fill = "#63C5DA") +
  labs(x = '', 
       y = 'Total Number of Policies Available',
       title = 'Total Number of Policies per Category',
       subtitle = 'All policies in the database',
       caption = 'Source: COVID AMP, Georgetown University Center for Global Health Science and Security') +
  coord_flip() +
  # use code below if trying to split out by subcategory
  # geom_bar(aes (x = policy_category,
  #               fill = as.factor(policy_subcategory))) +
  theme(
    # legend.position="bottom",
    #     legend.text=element_text(size=4),
    #     legend.key.size = unit(0.1, 'cm'),
    plot.title = element_text(color = "#000000", size = 15, face = 'bold',
                              hjust = -0.25),
    plot.subtitle = element_text(face = "bold", color = '#808080',
                                 hjust = -0.15),
    plot.caption = element_text(face = "italic", size = 5),
    axis.title.x = element_text(color = "#000000", size = 10, face = "bold"),
    # axis.title.y = element_text(angle = 0, 
    #                             margin = margin(r = -30, 
    #                                             l = 5,
    #                                             t = -10,
    #                                             b = 10),
    #                             color = "#000000", size = 5, face = "bold"),
    axis.text = element_text(size = 8),
    
    # get rid of ggplot background
    #panel.grid.major = element_blank(), 
    panel.grid.minor = element_blank(),
    panel.background = element_blank()) +
  scale_x_discrete(labels = function(x) str_wrap(x, width = 20))

cat_totals_country <- 
  full_airtable %>% 
  filter(authorizing_country_iso != 'USA',
         authorizing_level_of_government == 'Country') %>%
  select(unique_id, policy_category, policy_subcategory) %>%
  count(policy_category) %>% 
  ggplot() +
  
  # code for just policy category
  geom_col(aes(x = policy_category,
               y = n),
           fill = "#63C5DA") +
  labs(x = '', 
       y = 'Total Number of Policies Available',
       title = 'Total Number of Policies per Category',
       subtitle = 'Countries (National Level)',
       caption = 'Source: COVID AMP, Georgetown University Center for Global Health Science and Security') +
  coord_flip() +
  # use code below if trying to split out by subcategory
  # geom_bar(aes (x = policy_category,
  #               fill = as.factor(policy_subcategory))) +
  theme(
    # legend.position="bottom",
    #     legend.text=element_text(size=4),
    #     legend.key.size = unit(0.1, 'cm'),
    plot.title = element_text(color = "#000000", size = 15, face = 'bold',
                              hjust = -0.25),
    plot.subtitle = element_text(face = "bold", color = '#808080',
                                 hjust = -0.15),
    plot.caption = element_text(face = "italic", size = 5),
    axis.title.x = element_text(color = "#000000", size = 10, face = "bold"),
    # axis.title.y = element_text(angle = 0, 
    #                             margin = margin(r = -30, 
    #                                             l = 5,
    #                                             t = -10,
    #                                             b = 10),
    #                             color = "#000000", size = 5, face = "bold"),
    axis.text = element_text(size = 8),
    
    # get rid of ggplot background
    #panel.grid.major = element_blank(), 
    panel.grid.minor = element_blank(),
    panel.background = element_blank()) +
  scale_x_discrete(labels = function(x) str_wrap(x, width = 20))

# comparing types of policies

relax_restrict_US_states <- 
  full_airtable %>% 
  filter(authorizing_country_iso == 'USA',
         authorizing_level_of_government == 'State/Province (Intermediate area)') %>%
  select(unique_id, policy_category, policy_relaxing_or_restricting) %>% 
  ggplot() +
  geom_bar(aes (x = policy_category,
                fill = as.factor(policy_relaxing_or_restricting))) +
  theme(legend.position="bottom",
        legend.text=element_text(size=8),
        legend.key.size = unit(0.5, 'cm')) +
  coord_flip()


# heat map! split apart by rows -------------------------------------------

# policy cat vs. policy target
selected_temporal_data %>% 
  separate_rows(policy_target, sep = ",") %>% 
  select(policy_category, policy_target, unique_id) %>% 
  count(policy_category, policy_target) %>% 
  ggplot(aes(policy_target, policy_category, fill= n)) + 
  geom_raster()

# relax restrict vs. policy cat
selected_temporal_data %>% 
  select(policy_relaxing_or_restricting, policy_category) %>% 
  count(policy_relaxing_or_restricting, policy_category) %>% 
  ggplot(aes(policy_relaxing_or_restricting, policy_category, fill= n)) + 
  geom_raster() +
  geom_text(aes(label = n))