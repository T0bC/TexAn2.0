box::use(
  openxlsx,
  rhino,
)

box::use(
  app/logic/settings[app_version],
)

# =============================================================================
# Pure logic functions for PCA result export
# No Shiny dependencies allowed in this file.
# =============================================================================

#' Export PCA results to a formatted Excel workbook
#'
#' Creates a multi-sheet Excel file with eigenvalues, variable
#' coordinates / contributions / cos2, and individual coordinates /
#' contributions / cos2.
#'
#' @param pca_result PCA result list from run_pca()
#'   (the $result field, not the wrapper)
#' @param file Path to save the Excel file
#' @return NULL (side effect: writes file)
#' @export
create_pca_excel <- function(pca_result, file) {
  wb <- openxlsx$createWorkbook()

  # Sheet 1: Eigenvalues
  eig <- as.data.frame(pca_result$eig)
  eig <- cbind(
    Component = rownames(eig),
    round(eig, 4)
  )
  rownames(eig) <- NULL
  names(eig) <- c(
    "Component", "Eigenvalue",
    "Variance (%)", "Cumulative Variance (%)"
  )
  add_sheet(wb, "Eigenvalues", eig)

  # Sheet 2: Variable Coordinates
  var_coord <- matrix_to_df(
    pca_result$var$coord, "Variable"
  )
  add_sheet(wb, "Variable Coordinates", var_coord)

  # Sheet 3: Variable Contributions
  var_contrib <- matrix_to_df(
    pca_result$var$contrib, "Variable"
  )
  add_sheet(wb, "Variable Contributions", var_contrib)

  # Sheet 4: Variable Cos2
  var_cos2 <- matrix_to_df(
    pca_result$var$cos2, "Variable"
  )
  add_sheet(wb, "Variable Cos2", var_cos2)

  # Individual metadata (if available)
  ind_meta <- pca_result$ind$meta

  # Sheet 5: Individual Coordinates
  ind_coord <- ind_matrix_to_df(
    pca_result$ind$coord, ind_meta
  )
  add_sheet(wb, "Individual Coordinates", ind_coord)

  # Sheet 6: Individual Contributions
  ind_contrib <- ind_matrix_to_df(
    pca_result$ind$contrib, ind_meta
  )
  add_sheet(wb, "Individual Contributions", ind_contrib)

  # Sheet 7: Individual Cos2
  ind_cos2 <- ind_matrix_to_df(
    pca_result$ind$cos2, ind_meta
  )
  add_sheet(wb, "Individual Cos2", ind_cos2)

  openxlsx$saveWorkbook(wb, file, overwrite = TRUE)

  rhino$log$info(
    "PCA export: Excel saved ({7} sheets)"
  )
}


#' Create a standardized RDS bundle for PCA export
#'
#' Builds the named list that the prediction module
#' expects when loading a PCA .rds file.
#'
#' @param pca_result PCA result list from run_pca()
#'   (the $result field, not the wrapper)
#' @param raw_data Data frame, original data before
#'   any transforms
#' @param used_data Data frame, data actually passed
#'   to prcomp (after transform + NA removal)
#' @param numeric_cols Character vector of measurement
#'   column names
#' @param meta_cols Character vector of metadata column
#'   names
#' @param transform_params List of per-column transform
#'   param lists (from transform_skewed), or empty list
#' @param settings List with skewness_correction,
#'   scale_method, etc.
#' @return Named list (the bundle)
#' @export
create_pca_bundle <- function(pca_result, raw_data,
                              used_data, numeric_cols,
                              meta_cols,
                              transform_params = list(),
                              settings = list()) {
  bundle <- list(
    analysis_type = "pca",
    model = pca_result$pca_obj,
    raw_data = raw_data,
    used_data = used_data,
    group_col = NULL,
    numeric_cols = numeric_cols,
    meta_cols = meta_cols,
    transform_params = transform_params,
    scale_params = NULL,
    settings = settings,
    data_source = "raw",
    app_version = app_version,
    created = Sys.time()
  )

  rhino$log$info(
    "PCA bundle: created ({length(numeric_cols)} vars,",
    " {nrow(used_data)} obs)"
  )

  bundle
}

# =============================================================================
# Internal helpers (not exported)
# =============================================================================

matrix_to_df <- function(mat, row_label = "Item") {
  df <- as.data.frame(mat)
  df <- cbind(Item = rownames(df), round(df, 4))
  rownames(df) <- NULL
  names(df)[1] <- row_label
  df
}

ind_matrix_to_df <- function(mat, meta) {
  df <- as.data.frame(round(mat, 4))
  if (!is.null(meta) && nrow(meta) == nrow(df) &&
      !("Row" %in% names(meta) && ncol(meta) == 1)) {
    # Prepend metadata columns before PCA dimensions
    df <- cbind(meta, df)
    rownames(df) <- NULL
  } else {
    df <- cbind(
      Individual = rownames(df), df
    )
    rownames(df) <- NULL
  }
  df
}

add_sheet <- function(wb, sheet_name, data) {
  openxlsx$addWorksheet(wb, sheet_name)
  openxlsx$writeData(wb, sheet_name, data)
  openxlsx$setColWidths(
    wb, sheet_name,
    cols = seq_len(ncol(data)),
    widths = "auto"
  )
}
