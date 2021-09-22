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
mapped_by_state_targets <-  tar_map(
    values = tibble(state_abb = states) %>%
      mutate(state_plot_files = sprintf("3_visualize/out/timeseries_%s.png",
                                        state_abb)),
    names = state_abb,
    unlist = FALSE,
    tar_target(nwis_inventory,
      filter(oldest_active_sites, state_cd == state_abb)),
    tar_target(nwis_data,
      get_site_data(site_info = nwis_inventory,
                    state = state_abb,
                    parameter = parameter)),
    tar_target(site_tallies,
      tally_site_obs(nwis_data)),
    tar_target(plot_sites_png,
      plot_site_data(out_file = state_plot_files,
                     site_data = nwis_data,
                     parameter = parameter),
      format = "file",)
)

list(
  # Identify oldest sites
  tar_target(oldest_active_sites, find_oldest_sites(states, parameter)),

  # per-state inventories, tallies, and plots
  mapped_by_state_targets,

  # combine the per-state tallies
  tar_combine(obs_tallies,
              mapped_by_state_targets$site_tallies,
              command = combine_obs_tallies(!!!.x)),

  # save hashes of per-state tallies
  tar_combine(
    summary_state_timeseries_csv,
    mapped_by_state_targets$plot_sites_png,
    command = summarize_targets('3_visualize/log/summary_state_timeseries.csv', !!!.x),
    format="file"
  ),

  # visualize the per-state coverage
  tar_target(
    per_state_coverage_png,
    plot_data_coverage(obs_tallies,
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
