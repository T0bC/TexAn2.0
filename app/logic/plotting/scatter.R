box::use(
  app/logic/plotting/plot_factory,
  app/logic/plotting/plot_helpers,
)

# =============================================================================
# Public API (backward compatibility wrapper)
# =============================================================================

#' Create an interactive scatter plot for a single measurement variable
#'
#' DEPRECATED: This function delegates to plot_factory$create_plot().
#' New code should use plot_factory$create_plot(type = "scatter", ...) directly.
#'
#' Pure logic function — no Shiny dependencies.
#' Uses ggiraph for interactivity and legendry for nested X-axis labels.
#'
#' @param data Data frame containing the data to plot
#' @param x_cols Character vector of column name(s) for X-axis
#' @param y_col Character string of column name for Y-axis (measurement)
#' @param color_map Named character vector mapping group names to hex colors
#' @param shape_map Named integer vector mapping group names to shape values
#' @param color_cols Character vector of column name(s) for color grouping.
#'   Defaults to x_cols when NULL.
#' @param tooltip_cols Character vector of additional column names for tooltip
#' @param point_style List: size, spread (jitter width), alpha, shape_cols
#' @param processing List: trim_percent, outlier_enabled, outlier_method,
#'   outlier_factor, bootstrap_samples
#' @param grid_legend List: legend_position, h_grid, v_grid,
#'   top_right_borders, show_median, show_sd, aspect_ratio
#' @param stat_line_style List: median_thickness, median_width,
#'   sd_thickness, sd_width
#' @param axis_style List: tick_length, line_thickness
#' @param factor_order Optional named list of custom factor level orderings.
#'   Keys are column names, values are character vectors of ordered levels.
#' @return A ggplot2 object (ready for ggiraph::girafe)
#' @export
create_scatter_plot <- function(data,
                                x_cols,
                                y_col,
                                color_map = NULL,
                                shape_map = NULL,
                                color_cols = NULL,
                                tooltip_cols = NULL,
                                point_style = list(),
                                processing = list(),
                                grid_legend = list(),
                                stat_line_style = list(),
                                axis_style = list(),
                                factor_order = NULL) {
  # Delegate to factory with scatter type
  plot_factory$create_plot(
    plot_type       = "scatter",
    data            = data,
    x_cols          = x_cols,
    y_col           = y_col,
    color_map       = color_map,
    shape_map       = shape_map,
    color_cols      = color_cols,
    tooltip_cols    = tooltip_cols,
    point_style     = point_style,
    processing      = processing,
    grid_legend     = grid_legend,
    stat_line_style = stat_line_style,
    axis_style      = axis_style,
    factor_order    = factor_order
  )
}


#' Create an empty placeholder plot with a message
#'
#' @param message Character string to display
#' @return A ggplot2 object
#' @export
create_empty_plot <- function(message = "No data to display") {
  plot_helpers$create_empty_plot(message)
}


#' Build tooltip HTML for each data point
#'
#' @param data Data frame (must contain .is_trimmed, .is_outlier columns)
#' @param x_var Name of x variable in data
#' @param x_label Display label for x axis
#' @param y_col Name of y column
#' @param tooltip_cols Additional columns to include
#' @return Character vector of tooltip HTML strings
#' @export
build_tooltip_text <- function(data, x_var, x_label, y_col,
                               tooltip_cols = NULL) {
  plot_helpers$build_tooltip_text(data, x_var, x_label, y_col, tooltip_cols)
}
