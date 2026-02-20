box::use(
  rhino,
)

box::use(
  app/logic/error_handling,
)

# =============================================================================
# Pure logic functions for LDA / QDA
# No Shiny dependencies allowed in this file.
# =============================================================================

#' Validate inputs before LDA/QDA computation
#'
#' Checks that measurement columns exist, a grouping column is
#' selected, and the grouping column has at least 2 levels.
#' Warns (but does not fail) if any group has fewer observations
#' than variables (n < p).
#'
#' @param columns Character vector of selected measurement column names
#' @param data Data frame to validate against
#' @param grouping_col Character, name of the grouping column
#' @return List with $valid (logical), $error (app_error or NULL),
#'   and $warnings (character vector, may be empty)
#' @export
validate_inputs <- function(columns, data, grouping_col) {
  warnings <- character(0)

  if (is.null(columns) || length(columns) == 0) {
    rhino$log$warn("LDA: no measurement columns selected")
    return(list(
      valid = FALSE,
      error = error_handling$simple_error(
        message = "Please select at least one measurement column.",
        operation_name = "lda_validate_inputs"
      ),
      warnings = warnings
    ))
  }

  missing <- setdiff(columns, names(data))
  if (length(missing) > 0) {
    rhino$log$warn(
      "LDA: columns not found: {paste(missing, collapse = ', ')}"
    )
    return(list(
      valid = FALSE,
      error = error_handling$simple_error(
        message = paste(
          "Columns not found in data:",
          paste(missing, collapse = ", ")
        ),
        operation_name = "lda_validate_inputs"
      ),
      warnings = warnings
    ))
  }

  if (is.null(grouping_col) || length(grouping_col) == 0 ||
      grouping_col == "") {
    rhino$log$warn("LDA: no grouping column selected")
    return(list(
      valid = FALSE,
      error = error_handling$simple_error(
        message = paste(
          "Please select a grouping column.",
          "LDA/QDA requires a categorical variable",
          "to define the groups."
        ),
        operation_name = "lda_validate_inputs"
      ),
      warnings = warnings
    ))
  }

  if (!(grouping_col %in% names(data))) {
    rhino$log$warn(
      "LDA: grouping column not found: {grouping_col}"
    )
    return(list(
      valid = FALSE,
      error = error_handling$simple_error(
        message = paste(
          "Grouping column not found in data:",
          grouping_col
        ),
        operation_name = "lda_validate_inputs"
      ),
      warnings = warnings
    ))
  }

  groups <- as.character(data[[grouping_col]])
  unique_groups <- unique(groups[!is.na(groups)])
  n_groups <- length(unique_groups)

  if (n_groups < 2) {
    rhino$log$warn(
      "LDA: grouping column '{grouping_col}' has",
      " {n_groups} level(s), need >= 2"
    )
    return(list(
      valid = FALSE,
      error = error_handling$simple_error(
        message = paste0(
          "Grouping column '", grouping_col,
          "' has ", n_groups, " unique level(s). ",
          "LDA/QDA requires at least 2 groups."
        ),
        operation_name = "lda_validate_inputs"
      ),
      warnings = warnings
    ))
  }

  # Warn if any group has fewer observations than variables
  group_counts <- table(groups)
  p <- length(columns)
  small_groups <- names(group_counts)[group_counts < p]
  if (length(small_groups) > 0) {
    warn_msg <- paste0(
      "Some groups have fewer observations than ",
      "variables (n < p = ", p, "): ",
      paste(
        small_groups,
        paste0("(n=", group_counts[small_groups], ")"),
        collapse = ", "
      ),
      ". LDA may fail or overfit. Consider using ",
      "PCA scores as input to reduce dimensionality."
    )
    rhino$log$warn("LDA: {warn_msg}")
    warnings <- c(warnings, warn_msg)
  }

  rhino$log$info(
    "LDA: validation passed ({length(columns)} columns,",
    " grouping='{grouping_col}', {n_groups} groups)"
  )

  list(valid = TRUE, error = NULL, warnings = warnings)
}

#' Run Linear Discriminant Analysis (stub)
#'
#' Placeholder that will call MASS::lda() once implemented.
#'
#' @param data Data frame (cleaned, optionally scaled)
#' @param columns Character vector of measurement column names
#' @param grouping_col Character, name of the grouping column
#' @param prior Character, "proportional" or "equal"
#' @param tol Numeric, tolerance for singularity detection
#' @param method Character, estimation method
#' @param cv Logical, leave-one-out cross-validation
#' @param nu Numeric, degrees of freedom for method = "t"
#' @param meta_cols Character vector of metadata column names
#' @return List with $success, $result or $error
#' @export
run_lda <- function(data, columns, grouping_col,
                    prior = "proportional", tol = 1.0e-4,
                    method = "moment", cv = FALSE,
                    nu = NULL, meta_cols = character(0)) {
  rhino$log$info(
    "LDA: run_lda called (stub) — ",
    "{length(columns)} columns, grouping='{grouping_col}'"
  )
  list(
    success = FALSE,
    error = error_handling$simple_error(
      message = paste(
        "LDA computation is not yet implemented.",
        "The UI scaffold is in place."
      ),
      operation_name = "LDA"
    )
  )
}

#' Run Quadratic Discriminant Analysis (stub)
#'
#' Placeholder that will call MASS::qda() once implemented.
#'
#' @param data Data frame (cleaned, optionally scaled)
#' @param columns Character vector of measurement column names
#' @param grouping_col Character, name of the grouping column
#' @param prior Character, "proportional" or "equal"
#' @param tol Numeric, tolerance for singularity detection
#' @param method Character, estimation method
#' @param cv Logical, leave-one-out cross-validation
#' @param nu Numeric, degrees of freedom for method = "t"
#' @param meta_cols Character vector of metadata column names
#' @return List with $success, $result or $error
#' @export
run_qda <- function(data, columns, grouping_col,
                    prior = "proportional", tol = 1.0e-4,
                    method = "moment", cv = FALSE,
                    nu = NULL, meta_cols = character(0)) {
  rhino$log$info(
    "LDA: run_qda called (stub) — ",
    "{length(columns)} columns, grouping='{grouping_col}'"
  )
  list(
    success = FALSE,
    error = error_handling$simple_error(
      message = paste(
        "QDA computation is not yet implemented.",
        "The UI scaffold is in place."
      ),
      operation_name = "QDA"
    )
  )
}

#' Error parser for LDA/QDA-specific errors
#'
#' @param error_msg Character, the original error message
#' @param operation_name Character, name of the operation
#' @return Character, user-friendly error message
#' @export
lda_error_parser <- function(error_msg,
                             operation_name = "LDA") {
  if (grepl(
    "singular|rank deficien",
    error_msg, ignore.case = TRUE
  )) {
    paste0(
      operation_name,
      ": Within-group covariance matrix is singular.",
      " Some variables may be constant within groups",
      " or highly collinear.",
      " Try reducing dimensionality via PCA first."
    )
  } else if (grepl(
    "\\bNA\\b|missing|NaN",
    error_msg, ignore.case = TRUE
  )) {
    paste0(
      operation_name,
      ": Data contains missing values.",
      " Please handle missing data first."
    )
  } else if (grepl(
    "group|level|factor",
    error_msg, ignore.case = TRUE
  )) {
    paste0(
      operation_name,
      ": Problem with grouping variable.",
      " Ensure it has at least 2 levels",
      " with sufficient observations each."
    )
  } else if (grepl("numeric", error_msg, ignore.case = TRUE)) {
    paste0(
      operation_name,
      ": All measurement columns must be numeric."
    )
  } else if (grepl(
    "variables.*constant|zero variance",
    error_msg, ignore.case = TRUE
  )) {
    paste0(
      operation_name,
      ": Some variables have zero within-group variance.",
      " Remove constant columns or use PCA scores."
    )
  } else {
    paste0(operation_name, " failed: ", error_msg)
  }
}
