# Created by use_targets().
# Follow the comments below to fill in this target script.
# Then follow the manual to check and run the pipeline:
#   https://books.ropensci.org/targets/walkthrough.html#inspect-the-pipeline # nolint

# Load packages required to define the pipeline:
library(targets)
library(tarchetypes) # Load other packages as needed. # nolint

# Set target options:
tar_option_set(
  packages = desc::desc_get_deps()$package[-1], # packages that your targets need to run
  format = "rds" # default storage format
  # Set other options as needed.
)

# tar_make_clustermq() configuration (okay to leave alone):
options(clustermq.scheduler = "multicore")

# tar_make_future() configuration (okay to leave alone):
# Install packages {{future}}, {{future.callr}}, and {{future.batchtools}} to allow use_targets() to configure tar_make_future() options.

# Run the R scripts in the R/ folder with your custom functions:
tar_source()
# source("other_functions.R") # Source other scripts as needed. # nolint

# Replace the target list below with your own:
list(
  tar_target(
    name = file,
    command = "data/lipidomics.csv",
    format = "file"
  ),
  tar_target(
    name = lipidomics,
    command = readr::read_csv(file, show_col_types = FALSE)
  ),
  tar_target(
    name = df_stats_by_metabolite,
    command = descriptive_stats(lipidomics)
  ),
  tar_target(
    name = fig_gender_by_class,
    command = plot_count_stats(lipidomics)
  ),
  tar_target(
    name = fig_metabolite_distribution,
    command = plot_distributions(lipidomics)
  ),
  tar_render(
    name = report_rmd,
    path = here::here("doc/report.Rmd")
  ),
  tar_target(
    name = df_model_estimates,
    command = calculate_estimates(lipidomics)
  ),
  tar_target(
    name = fig_model_estimates,
    command = plot_estimates(df_model_estimates)
  )
)
