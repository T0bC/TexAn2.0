box::use(
  rhino,
  stats,
  WRS2,
)

box::use(
  app/logic/error_handling,
  app/logic/statistics/omnibus,
)

# =============================================================================
# Robust ANOVA tests using trimmed means (Welch-Yuen family).
# Currently: t1way. Later: t2way, t3way.
# No Shiny dependencies allowed in this file.
# =============================================================================

# =============================================================================
# t1way — One-Way Robust ANOVA
# =============================================================================

#' t1way test configuration
#'
#' Config object consumed by omnibus$run_omnibus_test().
#' Defines all hooks for the one-way robust trimmed-means ANOVA.
t1way_config <- list(
  name = "t1way",

  result_cols = c(
    "F_statistic", "df1", "df2", "Effect_Size", "p_value"
  ),

  validate = function(df, x_axis) {
    if (length(x_axis) != 1) {
      return(error_handling$simple_error(
        message = "t1way requires exactly one grouping variable.",
        operation_name = "t1way_validate",
        context = list(n_grouping_vars = length(x_axis))
      ))
    }
    n_groups <- length(unique(df[[x_axis[1]]]))
    if (n_groups < 2) {
      return(error_handling$simple_error(
        message = paste0(
          "t1way requires at least 2 groups, found ",
          n_groups, "."
        ),
        operation_name = "t1way_validate",
        context = list(
          grouping = x_axis[1],
          n_groups = n_groups
        )
      ))
    }
    NULL
  },

  build_context = function(df, x_axis, measure_col,
                           tr_value, use_bootstrap) {
    list(
      measure = measure_col,
      grouping = x_axis[1],
      n_groups = length(unique(df[[x_axis[1]]])),
      n_observations = nrow(df),
      trim = tr_value,
      bootstrap = use_bootstrap
    )
  },

  build_formula = function(measure_col, x_axis) {
    stats$as.formula(
      paste0("`", measure_col, "` ~ `", x_axis[1], "`")
    )
  },

  run_test = function(formula_obj, data, tr_value) {
    vars <- all.vars(formula_obj)[-1]
    conversion <- omnibus$safe_factor_conversion(data, vars)
    if (!conversion$success) {
      stop(conversion$error$message)
    }
    WRS2$t1way(
      formula = formula_obj,
      data = conversion$data,
      tr = tr_value
    )
  },

  extract_results = function(out) {
    c(out$test, out$df1, out$df2, out$effsize, out$p.value)
  },

  format_results = function(results, x_axis, use_bootstrap) {
    if (use_bootstrap) {
      omnibus$format_bootstrap_results(results)
    } else {
      results[] <- lapply(
        results,
        function(x) signif(x, 3)
      )
      results
    }
  }
)


#' Perform One-Way Robust ANOVA (Welch-Yuen t1way)
#'
#' Uses WRS2::t1way with trimmed means. Supports optional bootstrap.
#'
#' @param df Data frame containing the data
#' @param x_axis Character, single grouping column name
#' @param measure_col Character, measurement column name
#' @param tr_value Numeric, trim proportion (0-0.5)
#' @param use_bootstrap Logical, whether to use bootstrap
#' @param boot_samples Integer, number of bootstrap samples
#' @param boot_sample_size Integer or NULL, bootstrap sample size per group
#' @return Data frame with test results, or structured app_error
#' @export
perform_t1way <- function(df, x_axis, measure_col,
                          tr_value,
                          use_bootstrap = FALSE,
                          boot_samples = 599,
                          boot_sample_size = NULL) {
  rhino$log$info(
    "t1way: starting for measure='{measure_col}',",
    " grouping='{x_axis[1]}',",
    " bootstrap={use_bootstrap}"
  )

  omnibus$run_omnibus_test(
    df = df,
    x_axis = x_axis,
    measure_col = measure_col,
    tr_value = tr_value,
    use_bootstrap = use_bootstrap,
    boot_samples = boot_samples,
    boot_sample_size = boot_sample_size,
    config = t1way_config
  )
}
