box::use(
  MASS,
  rhino,
  stats,
)

box::use(
  app/logic/error_handling,
)

# =============================================================================
# Pure logic functions for skewness detection and transformation
# No Shiny dependencies allowed in this file.
# =============================================================================

#' Compute Fisher's skewness for a numeric vector
#'
#' Uses the adjusted Fisher-Pearson formula:
#' g1 = (n / ((n-1)(n-2))) * sum(((x - mean) / sd)^3)
#'
#' @param x Numeric vector (NAs removed upstream)
#' @return Numeric scalar, skewness value
compute_skewness <- function(x) {
  n <- length(x)
  if (n < 3) return(NA_real_)
  m <- mean(x)
  s <- stats$sd(x)
  if (s == 0) return(NA_real_)
  adjusted <- (n / ((n - 1) * (n - 2))) *
    sum(((x - m) / s)^3)
  adjusted
}

#' Detect skewness in measurement columns
#'
#' Computes per-column skewness and classifies each column
#' as "left" (negative skewness), "right" (positive skewness),
#' or "symmetric" (abs(skewness) <= threshold).
#'
#' @param data Data frame
#' @param measurement_cols Character vector of measurement column names
#' @param threshold Numeric, absolute skewness above which a column
#'   is flagged as skewed. Default 1.0.
#' @return Data frame with columns: column, skewness, abs_skewness,
#'   direction ("left", "right", "symmetric"), is_skewed (logical).
#'   Sorted by abs_skewness descending.
#' @export
detect_skewness <- function(data, measurement_cols,
                            threshold = 1.0) {
  if (length(measurement_cols) == 0) {
    return(data.frame(
      column = character(0),
      skewness = numeric(0),
      abs_skewness = numeric(0),
      direction = character(0),
      is_skewed = logical(0),
      stringsAsFactors = FALSE
    ))
  }

  skew_vals <- vapply(
    measurement_cols,
    function(col) compute_skewness(data[[col]]),
    numeric(1)
  )

  abs_vals <- abs(skew_vals)
  direction <- ifelse(
    is.na(skew_vals), "symmetric",
    ifelse(
      abs_vals <= threshold, "symmetric",
      ifelse(skew_vals < 0, "left", "right")
    )
  )
  is_skewed <- !is.na(skew_vals) & abs_vals > threshold

  result <- data.frame(
    column = measurement_cols,
    skewness = round(skew_vals, 3),
    abs_skewness = round(abs_vals, 3),
    direction = direction,
    is_skewed = is_skewed,
    stringsAsFactors = FALSE
  )
  result <- result[order(-result$abs_skewness), ]
  rownames(result) <- NULL
  result
}

#' Transform skewed columns to reduce skewness
#'
#' Applies log or Box-Cox transformation to columns flagged
#' as skewed by detect_skewness(). Left-skewed columns are
#' reflected before transformation. Symmetric columns are
#' left untouched.
#'
#' @param data Data frame (full, including metadata columns)
#' @param measurement_cols Character vector of measurement column names
#' @param skew_result Data frame from detect_skewness()
#' @param method Character, transformation method:
#'   "auto" (try log, fall back to Box-Cox),
#'   "log", "boxcox", "none".
#' @return List with $success, $result or $error.
#'   $result contains $data, $transformed_cols (data frame),
#'   $skipped_cols (character vector).
#' @export
transform_skewed <- function(data, measurement_cols,
                             skew_result,
                             method = "auto") {
  error_handling$safe_execute(
    expr = {
      skewed <- skew_result[skew_result$is_skewed, ]

      if (nrow(skewed) == 0 || method == "none") {
        rhino$log$info(
          "Skewness: no columns to transform",
          " (method={method})"
        )
        return(list(
          data = data,
          transformed_cols = data.frame(
            column = character(0),
            direction = character(0),
            method_used = character(0),
            skewness_before = numeric(0),
            skewness_after = numeric(0),
            stringsAsFactors = FALSE
          ),
          skipped_cols = character(0)
        ))
      }

      result_data <- data
      transformed <- list()
      skipped <- character(0)

      for (i in seq_len(nrow(skewed))) {
        col_name <- skewed$column[i]
        direction <- skewed$direction[i]
        skew_before <- skewed$skewness[i]
        x <- result_data[[col_name]]

        transform_res <- try_transform_column(
          x, direction, method
        )

        if (is.null(transform_res)) {
          skipped <- c(skipped, col_name)
          rhino$log$warn(
            "Skewness: skipped '{col_name}'",
            " (could not transform)"
          )
          next
        }

        result_data[[col_name]] <- transform_res$values
        skew_after <- compute_skewness(
          transform_res$values
        )

        transformed[[length(transformed) + 1]] <- list(
          column = col_name,
          direction = direction,
          method_used = transform_res$method_used,
          skewness_before = skew_before,
          skewness_after = round(skew_after, 3)
        )

        rhino$log$info(
          "Skewness: transformed '{col_name}'",
          " ({direction}, {transform_res$method_used},",
          " {skew_before} -> {round(skew_after, 3)})"
        )
      }

      transformed_df <- if (length(transformed) > 0) {
        do.call(rbind, lapply(transformed, as.data.frame,
                              stringsAsFactors = FALSE))
      } else {
        data.frame(
          column = character(0),
          direction = character(0),
          method_used = character(0),
          skewness_before = numeric(0),
          skewness_after = numeric(0),
          stringsAsFactors = FALSE
        )
      }

      n_transformed <- nrow(transformed_df)
      n_skipped <- length(skipped)
      rhino$log$info(
        "Skewness: {n_transformed} columns transformed,",
        " {n_skipped} skipped"
      )

      list(
        data = result_data,
        transformed_cols = transformed_df,
        skipped_cols = skipped
      )
    },
    operation_name = "Skewness Correction",
    error_parser = skewness_error_parser
  )
}

#' Error parser for skewness transformation errors
#'
#' @param error_msg Character, the original error message
#' @param operation_name Character, name of the operation
#' @return Character, user-friendly error message
#' @export
skewness_error_parser <- function(
    error_msg,
    operation_name = "Skewness Correction") {
  if (grepl(
    "constant|zero variance",
    error_msg, ignore.case = TRUE
  )) {
    paste0(
      operation_name,
      ": Some columns have zero variance",
      " and cannot be transformed."
    )
  } else if (grepl(
    "non-numeric|not numeric",
    error_msg, ignore.case = TRUE
  )) {
    paste0(
      operation_name,
      ": All measurement columns must be numeric."
    )
  } else {
    paste0(operation_name, " failed: ", error_msg)
  }
}

# =============================================================================
# Internal helpers (not exported)
# =============================================================================

#' Try to transform a single column
#'
#' @param x Numeric vector
#' @param direction "left" or "right"
#' @param method "auto", "log", or "boxcox"
#' @return List with $values and $method_used, or NULL on failure
try_transform_column <- function(x, direction, method) {
  # For left-skewed data, reflect first
  if (direction == "left") {
    reflected <- max(x, na.rm = TRUE) + 1 - x
    result <- try_transform_positive(
      reflected, method
    )
    if (is.null(result)) return(NULL)
    # Reverse the reflection so the ordering is preserved
    result$values <- -(result$values -
      max(result$values, na.rm = TRUE))
    result$method_used <- paste0(
      "reflect+", result$method_used
    )
    return(result)
  }

  # Right-skewed: transform directly
  try_transform_positive(x, method)
}

#' Apply transformation to a (positive-shifted) vector
#'
#' @param x Numeric vector
#' @param method "auto", "log", or "boxcox"
#' @return List with $values and $method_used, or NULL
try_transform_positive <- function(x, method) {
  if (method == "log" || method == "auto") {
    log_result <- try_log_transform(x)
    if (!is.null(log_result)) {
      return(log_result)
    }
    if (method == "log") return(NULL)
  }

  if (method == "boxcox" || method == "auto") {
    bc_result <- try_boxcox_transform(x)
    if (!is.null(bc_result)) {
      return(bc_result)
    }
  }

  NULL
}

#' Try log1p transformation
#'
#' Shifts data so minimum is 0, then applies log1p.
#'
#' @param x Numeric vector
#' @return List with $values and $method_used, or NULL
try_log_transform <- function(x) {
  tryCatch(
    {
      min_val <- min(x, na.rm = TRUE)
      shifted <- x - min_val
      transformed <- log1p(shifted)
      if (any(is.na(transformed) | is.infinite(transformed))) {
        return(NULL)
      }
      list(values = transformed, method_used = "log")
    },
    error = function(e) NULL
  )
}

#' Try Box-Cox transformation
#'
#' Estimates optimal lambda via MASS::boxcox, then applies
#' the power transformation. Requires strictly positive data.
#'
#' @param x Numeric vector
#' @return List with $values and $method_used, or NULL
try_boxcox_transform <- function(x) {
  tryCatch(
    {
      # Shift to strictly positive
      min_val <- min(x, na.rm = TRUE)
      shifted <- if (min_val <= 0) {
        x - min_val + 1
      } else {
        x
      }

      # Estimate lambda using MASS::boxcox
      # Suppress the plot output
      n <- length(shifted)
      dummy_y <- shifted
      dummy_df <- data.frame(
        y = dummy_y,
        x_dummy = seq_len(n)
      )
      bc <- suppressWarnings(
        utils::capture.output(
          bc_obj <- MASS$boxcox(
            stats$lm(y ~ 1, data = dummy_df),
            plotit = FALSE
          )
        )
      )
      lambda <- bc_obj$x[which.max(bc_obj$y)]

      # Apply Box-Cox transformation
      transformed <- if (abs(lambda) < 1e-6) {
        log(shifted)
      } else {
        (shifted^lambda - 1) / lambda
      }

      if (any(
        is.na(transformed) | is.infinite(transformed)
      )) {
        return(NULL)
      }

      list(
        values = transformed,
        method_used = paste0(
          "boxcox(lambda=", round(lambda, 2), ")"
        )
      )
    },
    error = function(e) NULL
  )
}
