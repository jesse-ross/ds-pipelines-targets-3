library(targets)
library(tarchetypes)
library(tibble)
suppressPackageStartupMessages(library(dplyr))

options(tidyverse.quiet = TRUE)
tar_option_set(packages = c("cowplot",
                            "dataRetrieval",
                            "htmlwidgets",
                            "leaflet",
                            "leafpop",
                            "lubridate",
                            "retry",
                            "rnaturalearth",
                            "tidyverse",
                            "urbnmapr")
               )

# Load functions needed by targets below
source("1_fetch/src/find_oldest_sites.R")
source("1_fetch/src/get_site_data.R")
source("2_process/src/tally_site_obs.R")
source("2_process/src/summarize_targets.R")
source("3_visualize/src/map_sites.R")
source("3_visualize/src/map_timeseries.R")
source("3_visualize/src/plot_site_data.R")
source("3_visualize/src/plot_data_coverage.R")

# Configuration
states <- c('AL', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'DC', 'FL', 'GA', 'ID',
            'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD', 'MA', 'MI', 'MN',
            'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ', 'NM', 'NY', 'NC', 'ND',
            'OH', 'OK', 'OR', 'PA', 'RI', 'SC', 'SD', 'TN', 'TX', 'UT', 'VT',
            'VA', 'WA', 'WV', 'WI', 'WY', 'AK', 'HI', 'GU', 'PR')

parameter <- c('00060')

# Targets
list(
  # Identify oldest sites
  tar_target(oldest_active_sites, find_oldest_sites(states, parameter)),

  tar_target(
    nwis_inventory,
    oldest_active_sites %>%
      group_by(state_cd) %>%
      tar_group(),
    iteration = "group"
  ),

  tar_target(
    nwis_data,
    retry(
      get_site_data(site_info = nwis_inventory,
                    state = nwis_inventory$state_cd,
                    parameter = parameter),
      when = 'Ugh, the internet data transfer failed! Try again.',
      max_tries = 30),
    pattern = map(nwis_inventory)
  ),

  tar_target(
    site_tallies,
    tally_site_obs(nwis_data),
    pattern = map(nwis_data)
  ),

  tar_target(
    plot_sites_png,
    plot_site_data(out_file = sprintf("3_visualize/out/timeseries_%s.png",
                                        unique(sort(nwis_data$State))),
                   site_data = nwis_data,
                   parameter = parameter),
    format = "file",
    pattern = map(nwis_data)),

  # save hashes of per-state tallies
  tar_target(
    summary_state_timeseries_csv,
    command = summarize_targets('3_visualize/log/summary_state_timeseries.csv',
                                names(plot_sites_png)),
    format="file"
  ),

  # visualize the per-state coverage
  tar_target(
    per_state_coverage_png,
    plot_data_coverage(site_tallies,
                       out_file = "3_visualize/out/data_coverage.png",
                       parameter = parameter),
    format = "file"),

  # Map oldest sites
  tar_target(
    site_map_png,
    map_sites("3_visualize/out/site_map.png", oldest_active_sites),
    format = "file"
  ),

  # make an interactive map
  tar_target(
    interactive_state_summary_map_html,
    map_timeseries(site_info = oldest_active_sites,
                   plot_info_csv = summary_state_timeseries_csv,
                   out_file = "3_visualize/out/timeseries_map.html"),
    format = "file"
  )
)
