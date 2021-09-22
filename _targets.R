library(targets)
library(tarchetypes)
library(tibble)
suppressPackageStartupMessages(library(dplyr))

options(tidyverse.quiet = TRUE)
tar_option_set(packages = c("cowplot",
                            "dataRetrieval",
                            "lubridate",
                            "rnaturalearth",
                            "tidyverse",
                            "urbnmapr"))

# Load functions needed by targets below
source("1_fetch/src/find_oldest_sites.R")
source("1_fetch/src/get_site_data.R")
source("2_process/src/tally_site_obs.R")
source("3_visualize/src/map_sites.R")
source("3_visualize/src/plot_site_data.R")

# Configuration
states <- c('WI', 'MN', 'MI', 'IL', 'IN', 'IA')
parameter <- c('00060')

# Targets
list(
  # Identify oldest sites
  tar_target(oldest_active_sites, find_oldest_sites(states, parameter)),

  # PULL SITE DATA HERE
  tar_map(
    values = tibble(state_abb = states) %>%
      mutate(state_plot_files = sprintf("3_visualize/out/timeseries_%s.png",
                                        state_abb)),
    tar_target(nwis_inventory,
      filter(oldest_active_sites, state_cd == state_abb)),
    tar_target(nwis_data,
      get_site_data(site_info = nwis_inventory,
                    state = state_abb,
                    parameter = parameter)),
    tar_target(site_tallies,
      tally_site_obs(nwis_data)),
    tar_target(plot_sites,
      plot_site_data(out_file = state_plot_files,
                     site_data = nwis_data,
                     parameter = parameter)),
    names = state_abb
  ),

  # Map oldest sites
  tar_target(
    site_map_png,
    map_sites("3_visualize/out/site_map.png", oldest_active_sites),
    format = "file"
  )
)
