#' Perform summary statistics.
#'
#' @param data Lipidomics dataset.
#'
#' @return A data.frame/tibble.
descriptive_stats <- function(data) {
  data %>%
    dplyr::group_by(metabolite) %>%
    dplyr::summarise(across(value, list(
      mean = mean,
      sd = sd,
      median = median,
      iqr = IQR
    ))) %>%
    dplyr::mutate(across(tidyselect::where(is.numeric), round, digits = 1))
}

#' Make plot of gender by class.
#'
#' @param data Lipidomics dataset.
#'
#' @return A ggplot object.
plot_count_stats <- function(data) {
  data %>%
    dplyr::distinct(code, gender, class) %>%
    ggplot2::ggplot(aes(x = class, fill = gender)) +
    ggplot2::geom_bar(position = "dodge")
}

#' Make plot of distributions by metabolites.
#'
#' @param data Lipiddomics dataset.
#'
#' @return A ggplot object.
plot_distributions <- function(data) {
  data %>%
    ggplot2::ggplot(aes(x = value)) +
    ggplot2::geom_histogram() +
    ggplot2::facet_wrap(vars(metabolite), scales = "free")
}

#' Convert column value to strings into snakecase.
#'
#' @param data Data with string columns.
#' @param cols Columns to convert into snakecase.
#'
#' @return A data.frame.
column_values_to_snakecase <- function(data, cols) {
  data %>%
    dplyr::mutate(dplyr::across({{ cols }}, snakecase::to_snake_case))
}

#' Convert data.frame from long to wide.
#'
#' @param data Lipidomics dataset.
#' @param values_fn Take the mean value.
#'
#' @return A data.frame in wide format
metabolites_to_wider <- function(data, values_fn = mean) {
  data %>%
    dplyr::mutate(metabolite = snakecase::to_snake_case(metabolite)) %>%
    tidyr::pivot_wider(
      names_from = metabolite,
      values_from = value,
      values_fn = values_fn,
      names_prefix = "metabolite_"
    )
}

#' A transformation recipe to pre-process the data.
#'
#' @param data The lipidomics dataset.
#' @param metabolite_variable The column of the metabolite variable.
#'
#' @return
#'
create_recipe_spec <- function(data, metabolite_variable) {
  recipes::recipe(data) %>%
    recipes::update_role({{ metabolite_variable }}, age, gender, new_role = "predictor") %>%
    recipes::update_role(class, new_role = "outcome") %>%
    recipes::step_normalize(tidyselect::starts_with("metabolite_"))
}

#' Create a workflow object of the model and transformations.
#'
#' @param model_specs The model specs
#' @param recipe_specs The recipe specs
#'
#' @return A workflow object
#'
create_model_workflow <- function(model_specs, recipe_specs) {
  workflows::workflow() %>%
    workflows::add_model(model_specs) %>%
    workflows::add_recipe(recipe_specs)
}

#' Create a tidy output of the model results.
#'
#' @param workflow_fitted_model The model workflow object that has been fitted.
#'
#' @return A data frame.
#'
tidy_model_output <- function(workflow_fitted_model) {
  workflow_fitted_model %>%
    workflows::extract_fit_parsnip() %>%
    broom::tidy(exponentiate = TRUE)
}

#' Convert the long form dataset into a list of wide form data frames.
#'
#' @param data The lipidomics dataset.
#'
#' @return A list of data frames.
#'
split_by_metabolite <- function(data) {
  data %>%
    column_values_to_snakecase(metabolite) %>%
    dplyr::group_split(metabolite) %>%
    purrr::map(metabolites_to_wider)
}

#' Generate the results of a model
#'
#' @param data The lipidomics dataset.
#'
#' @return A data frame.
#'
generate_model_results <- function(data) {
  create_model_workflow(
    parsnip::logistic_reg() %>%
      parsnip::set_engine("glm"),
    data %>%
      create_recipe_spec(tidyselect::starts_with("metabolite_"))
  ) %>%
    parsnip::fit(data) %>%
    tidy_model_output()
}

#' Add the original metabolite names (not as snakecase) to the model results.
#'
#' @param model_results The data frame with the model results.
#' @param data The original lipidomics dataset.
#'
#' @return A data frame.
#'
add_original_metabolite_names <- function(model_results, data) {
  data %>%
    dplyr::mutate(term = metabolite) %>%
    column_values_to_snakecase(term) %>%
    dplyr::mutate(term = stringr::str_c("metabolite_", term)) %>%
    dplyr::distinct(term, metabolite) %>%
    dplyr::right_join(model_results, by = "term")
}

#' Calculate the estimates for the model for each metabolite.
#'
#' @param data The lipidomics dataset.
#'
#' @return A data frame.
#'
calculate_estimates <- function(data) {
  data %>%
    column_values_to_snakecase(metabolite) %>%
    dplyr::group_split(metabolite) %>%
    purrr::map(metabolites_to_wider) %>%
    purrr::map_dfr(generate_model_results) %>%
    dplyr::filter(stringr::str_detect(term, "metabolite_")) %>%
    add_original_metabolite_names(data)
}

#' Plot the estimates and standard errors of the model results.
#'
#' @param results The model estimate results.
#'
#' @return A ggplot2 figure.
#'
plot_estimates <- function(results) {
  results %>%
    ggplot2::ggplot(ggplot2::aes(
      x = estimate, y = metabolite,
      xmin = estimate - std.error,
      xmax = estimate + std.error
    )) +
    ggplot2::geom_pointrange() +
    ggplot2::coord_fixed(xlim = c(0, 5))
}
