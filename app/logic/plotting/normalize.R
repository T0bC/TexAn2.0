box::use(
  rhino,
)

# =============================================================================
# Pure logic functions for data normalization via bestNormalize
# No Shiny dependencies allowed in this file.
# =============================================================================

#' Normalize selected measurement columns using bestNormalize
#'
#' Only transforms columns where the proportion of non-normal groups
#' exceeds the threshold. Adds `{col}_normalized` columns; outlier-flagged
#' rows get NA in the normalized column.
#'
#' @param data Data frame with measurement and flag columns
#' @param measure_cols Character vector of measurement column names to consider
#' @param normality_results Named list of data frames from
#'   assumption_checks$check_normality(), keyed by measure_col name
#' @param threshold Numeric 0-1, proportion of non-normal groups required
#'   to trigger transformation
#' @param outlier_col_suffix Character, suffix for outlier flag columns
#'   (default "_outlier")
#' @param trimmed_col_suffix Character, suffix for trimmed flag columns
#'   (default "_trimmed")
#' @return List with:
#'   \itemize{
#'     \item \code{$data} — data frame with added \code{{col}_normalized}
#'       columns
#'     \item \code{$transform_info} — data frame with columns:
#'       column, method, n_transformed
#'   }
#' @export
normalize_columns <- function(data, measure_cols, normality_results,
                              threshold = 0.5,
                              outlier_col_suffix = "_outlier",
                              trimmed_col_suffix = "_trimmed") {
  transform_info <- data.frame(
    column        = character(0),
    method        = character(0),
    n_transformed = integer(0),
    stringsAsFactors = FALSE
  )

  for (col in measure_cols) {
    norm_df <- normality_results[[col]]
    if (is.null(norm_df)) next

    # Check if this column needs transformation
    if (!needs_transformation(norm_df, threshold)) {
      rhino$log$info(
        "Normalize: '{col}' passes normality threshold, skipping"
      )
      next
    }

    # Build exclusion mask (outliers + trimmed)
    outlier_col <- paste0(col, outlier_col_suffix)
    trimmed_col <- paste0(col, trimmed_col_suffix)

    excluded <- rep(FALSE, nrow(data))
    if (outlier_col %in% names(data)) {
      excluded <- excluded | data[[outlier_col]]
    }
    if (trimmed_col %in% names(data)) {
      excluded <- excluded | data[[trimmed_col]]
    }

    # Get clean values (non-excluded, non-NA)
    clean_idx <- which(!excluded & !is.na(data[[col]]))
    clean_values <- data[[col]][clean_idx]

    if (length(clean_values) < 3) {
      rhino$log$warn(
        "Normalize: '{col}' has < 3 clean values, skipping"
      )
      next
    }

    # Fit bestNormalize on clean values
    result <- fit_best_normalize(clean_values)
    if (is.null(result)) {
      rhino$log$warn(
        "Normalize: bestNormalize failed for '{col}', skipping"
      )
      next
    }

    # Create the normalized column
    norm_col_name <- paste0(col, "_normalized")
    data[[norm_col_name]] <- NA_real_
    data[[norm_col_name]][clean_idx] <- result$transformed_values

    method_name <- result$method
    rhino$log$info(
      "Normalize: '{col}' transformed via {method_name} ",
      "({length(clean_values)} values)"
    )

    transform_info <- rbind(transform_info, data.frame(
      column        = col,
      method        = method_name,
      n_transformed = length(clean_values),
      stringsAsFactors = FALSE
    ))
  }

  list(
    data           = data,
    transform_info = transform_info
  )
}


#' Get a human-readable transformation label for a column
#'
#' @param transform_info Data frame from normalize_columns()$transform_info
#' @param col Character, the measurement column name
#' @return Character string, e.g. "Yeo-Johnson" or NULL if not transformed
#' @export
get_transform_label <- function(transform_info, col) {
  if (is.null(transform_info) || nrow(transform_info) == 0) {
    return(NULL)
  }
  row <- transform_info[transform_info$column == col, ]
  if (nrow(row) == 0) return(NULL)
  row$method[1]
}


# =============================================================================
# Internal helpers
# =============================================================================

#' Check if a column needs transformation based on normality results
#' @param normality_df Data frame from check_normality()
#' @param threshold Numeric 0-1
#' @return Logical
needs_transformation <- function(normality_df, threshold) {
  valid <- normality_df[!is.na(normality_df$normal) &
                          normality_df$normal != "identical values", ]
  if (nrow(valid) == 0) return(FALSE)
  n_non_normal <- sum(valid$normal == "no")
  proportion <- n_non_normal / nrow(valid)
  proportion > threshold
}


#' Fit bestNormalize and return transformed values + method name
#'
#' Runs bestNormalize::bestNormalize() in a safe environment.
#'
#' @param values Numeric vector of clean values
#' @return List with transformed_values and method, or NULL on failure
fit_best_normalize <- function(values) {
  tryCatch({
    # bestNormalize uses formula interface internally;
    # evaluate in globalenv to avoid box module isolation issues
    bn_result <- eval(
      bquote(bestNormalize::bestNormalize(.(values), quiet = TRUE)),
      envir = new.env(parent = globalenv())
    )

    transformed <- stats::predict(bn_result)
    method <- class(bn_result$chosen_transform)[1]

    list(
      transformed_values = as.numeric(transformed),
      method             = method
    )
  }, error = function(e) {
    rhino$log$warn(
      "bestNormalize error: {conditionMessage(e)}"
    )
    NULL
  })
}
