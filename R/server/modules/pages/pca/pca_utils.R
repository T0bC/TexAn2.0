#' PCA Utility Functions
#'
#' Provides data preparation utilities for PCA analysis.

#' Prepare data for PCA analysis
#'
#' Subsets to measurement columns, removes rows with any NA values,
#' and optionally scales the data. The cleaned data is used for all
#' subsequent PCA calculations (KMO, correlation plot, etc.).
#'
#' @param data Data frame with measurement columns
#' @param measure_cols Character vector of column names to include
#' @param scale Logical, whether to scale the data
#' @return List with:
#'   - data: Data frame with selected columns, NA rows removed, optionally scaled
#'   - rows_removed: Number of rows removed due to NA values
#'   - original_rows: Original number of rows
prepare_pca_data <- function(data, measure_cols, scale = TRUE) {
    pca_data <- data[, measure_cols, drop = FALSE]
    original_rows <- nrow(pca_data)
    
    # Remove rows with any NA in measurement columns
    complete_rows <- complete.cases(pca_data)
    pca_data <- pca_data[complete_rows, , drop = FALSE]
    rows_removed <- original_rows - nrow(pca_data)
    
    if (scale && nrow(pca_data) > 0) {
        pca_data <- as.data.frame(scale(pca_data))
    }
    
    list(
        data = pca_data,
        rows_removed = rows_removed,
        original_rows = original_rows
    )
}
