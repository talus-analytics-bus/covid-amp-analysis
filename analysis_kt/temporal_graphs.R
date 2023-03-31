
# setup -------------------------------------------------------------------

library(tidyverse)
library(sf)
library(lubridate)
library(maps)
library(sp)
library(tigris)
library(gridExtra)
library(stringr)
library(countrycode)


full_airtable <- read_csv('data/processed/full_airtable_cleaned.csv')


 # Clean Temporal Data -----------------------------------------------------

selected_temporal_data <- 
  full_airtable %>% 
  select(unique_id,
         authorizing_level_of_government,
         authorizing_country_iso,
         effective_start_date,
         policy_category, 
         policy_relaxing_or_restricting,
         policy_target) %>% 
  mutate(month = lubridate::month(effective_start_date),
         year = lubridate::year(effective_start_date)) %>% 
  mutate(month_year = make_date(year = year, month = month)) %>% 
  select(-year, -month) %>% 
  filter(month_year > '2019-11-01') %>% 
  arrange(month_year)

us_state_temporal <- 
  selected_temporal_data %>% 
  filter(authorizing_level_of_government == 'State/Province (Intermediate area)',
         authorizing_country_iso == 'USA',
         month_year < '2022-06-01')

global_national_temporal <- 
  selected_temporal_data %>% 
  filter(authorizing_level_of_government == 'Country',
         month_year < '2022-06-01')


# All policies over time by category --------------------------------------

# ALL POLICIES 
# full timeline (this takes forever to plot, avoid running)
ggplot(selected_temporal_data) +
  aes(x = effective_start_date,
      fill = as.factor(policy_category)) +
  geom_bar()

# by month (change data table to global_national_temporal for global data)
ggplot(us_state_temporal) +
  aes(x = month_year,
      fill = as.factor(policy_category)) +
  geom_bar() +
  theme(
    plot.title = element_text(color = "#000000", size = 15, face = 'bold',
                              hjust = 0),
    plot.subtitle = element_text(face = "bold", color = '#808080',
                                 hjust = 0),
    plot.caption = element_text(face = "italic", size = 5),
    axis.title.x = element_text(color = "#000000", size = 10, face = "bold"),
    panel.grid.minor = element_blank(),
    panel.background = element_blank(),
    legend.position="right",
    legend.text=element_text(size=8),
    legend.key.size = unit(0.3, 'cm'),
    legend.key.height = unit(0.3, 'cm'), #change legend key height
    legend.key.width = unit(0.3, 'cm'), #change legend key width
    legend.title = element_blank()) +
  labs(x = '', 
       y = 'Number of Unique Policies Catalogued',
       title = 'Total Number of Policies per Category Over Time',
       subtitle = 'United States (State Level)',
       caption = 'Source: COVID AMP, Georgetown University Center for Global Health Science and Security')



# Relaxing vs. Restricting ------------------------------------------------

# to get US States, just change which table you're piping in

global_national_temporal %>% 
  ggplot() +
  aes(x = month_year,
      fill = as.factor(policy_relaxing_or_restricting)) +
  geom_bar() +
  scale_fill_manual(values = c('#9EB8C5','#A3C585','#F14C20','#808080')) +
  theme(
    plot.title = element_text(color = "#000000", size = 15, face = 'bold',
                              hjust = 0),
    plot.subtitle = element_text(face = "bold", color = '#808080',
                                 hjust = 0),
    plot.caption = element_text(face = "italic", size = 5),
    axis.title.x = element_text(color = "#000000", size = 10, face = "bold"),
    panel.grid.minor = element_blank(),
    panel.background = element_blank(),
    legend.position="right",
    legend.text=element_text(size=8),
    legend.key.size = unit(0.3, 'cm'),
    legend.key.height = unit(0.3, 'cm'), #change legend key height
    legend.key.width = unit(0.3, 'cm'), #change legend key width
    legend.title = element_blank()) +
  labs(x = '', 
       y = 'Number of Unique Policies Catalogued',
       title = 'Total Number of Policies - Relaxing vs. Restricting',
       subtitle = 'Global (National Level)',
       caption = 'Source: COVID AMP, Georgetown University Center for Global Health Science and Security')

# Relaxing vs Restricting, Other removed as percentage

# to get US states, just change which table you pipe in

global_national_temporal %>% 
  filter(policy_relaxing_or_restricting != 'Other') %>% 
  ggplot() +
  aes(x = month_year,
      fill = as.factor(policy_relaxing_or_restricting)) +
  geom_bar(position="fill") +
  scale_fill_manual(values = c('#A3C585','#F14C20','#808080')) +
  theme(
    plot.title = element_text(color = "#000000", size = 15, face = 'bold',
                              hjust = 0),
    plot.subtitle = element_text(face = "bold", color = '#808080',
                                 hjust = 0),
    plot.caption = element_text(face = "italic", size = 5),
    axis.title.x = element_text(color = "#000000", size = 10, face = "bold"),
    panel.grid.minor = element_blank(),
    panel.background = element_blank(),
    legend.position="right",
    legend.text=element_text(size=8),
    legend.key.size = unit(0.3, 'cm'),
    legend.key.height = unit(0.3, 'cm'), #change legend key height
    legend.key.width = unit(0.3, 'cm'), #change legend key width
    legend.title = element_blank()) +
  labs(x = '', 
       y = 'Number of Unique Policies Catalogued',
       title = 'Total Number of Policies - Relaxing vs. Restricting',
       subtitle = 'Global (National Level)',
       caption = 'Source: COVID AMP, Georgetown University Center for Global Health Science and Security')



# plot the number of policies over time by relaxing or restricting
# by month
ggplot(selected_temporal_data) +
  aes(x = month_year,
      fill = as.factor(policy_relaxing_or_restricting)) +
  geom_bar() +
  scale_fill_manual(values = c('#9EB8C5','#A3C585','#F94C40','#808080'))

# by month as a percent
ggplot(selected_temporal_data) +
  aes(x = month_year,
      fill = as.factor(policy_relaxing_or_restricting)) +
  geom_bar(position="fill") +
  scale_fill_manual(values = c('#9EB8C5','#A3C585','#F14C20','#808080'))

# plot the number of policies over time by policy target population

# DATA IS NOT CLEANED FOR THIS YET, DO NOT RUN

# full timeline
# ggplot(selected_temporal_data) +
#   aes(x = effective_start_date,
#       fill = as.factor(policy_target)) +
#   geom_bar() + 
#   theme(legend.position="bottom",
#         legend.text=element_text(size=8),
#         legend.key.size = unit(0.5, 'cm'))
# 
# # by month
# ggplot(selected_temporal_data) +
#   aes(x = month_year,
#       fill = as.factor(policy_target)) +
#   geom_bar() +
#   theme(legend.position="bottom",
#         legend.text=element_text(size=8),
#         legend.key.size = unit(0.5, 'cm'))
