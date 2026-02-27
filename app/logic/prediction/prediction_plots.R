box::use(
  ggiraph,
  ggplot2,
  rhino,
  stats,
)

box::use(
  app/logic/error_handling,
  app/logic/pca/biplot[create_biplot],
  app/logic/pca/pca[build_pca_result, build_ind_meta],
)

# =============================================================================
# Prediction overlay plots
# No Shiny dependencies allowed in this file.
# =============================================================================

#' Create a prediction overlay plot
#'
#' Recreates the training plot from bundled data and
#' overlays unknown sample predictions with distinct
#' visual encoding.
#'
#' @param bundle The prediction bundle
#' @param prediction_result Result from predict_unknown()
#' @param unknown_data Original unknown data frame
#'   (for metadata / labels)
#' @param dim_x Character, x-axis dimension name
#' @param dim_y Character, y-axis dimension name
#' @param meta_col Character or NULL, metadata column
#'   to use as unknown labels
#' @param group_cols Character vector or NULL, metadata
#'   columns for grouping training data (PCA only)
#' @param show_convex_hull Logical, use convex hull
#'   instead of 95% ellipse (PCA only)
#' @param point_alpha Character or numeric, point alpha
#'   for PCA biplot ("Contribution" or fixed, PCA only)
#' @param point_size Character or numeric, point size
#'   for PCA biplot ("Contribution" or fixed, PCA only)
#' @param layer Character, biplot layer: "individuals",
#'   "variables", or "combined" (PCA only)
#' @return List with $success, $result (ggplot) or $error
#' @export
create_prediction_overlay_plot <- function(
    bundle, prediction_result, unknown_data,
    dim_x, dim_y, meta_col = NULL,
    group_cols = NULL,
    show_convex_hull = FALSE,
    point_alpha = 0.5,
    point_size = 2.5,
    layer = "individuals") {
  error_handling$safe_execute(
    expr = {
      analysis_type <- bundle$analysis_type

      p <- switch(
        analysis_type,
        pca = build_pca_overlay(
          bundle, prediction_result,
          unknown_data, dim_x, dim_y, meta_col,
          group_cols = group_cols,
          show_convex_hull = show_convex_hull,
          point_alpha = point_alpha,
          point_size = point_size,
          layer = layer
        ),
        lda = build_ld_overlay(
          bundle, prediction_result,
          unknown_data, dim_x, dim_y, meta_col
        ),
        mda = build_ld_overlay(
          bundle, prediction_result,
          unknown_data, dim_x, dim_y, meta_col
        ),
        qda = build_qda_overlay(
          bundle, prediction_result,
          unknown_data, dim_x, dim_y, meta_col
        ),
        stop(paste0(
          "Unsupported analysis type: '",
          analysis_type, "'"
        ))
      )

      rhino$log$info(
        "Prediction plot: ",
        "{toupper(analysis_type)} overlay created"
      )

      p
    },
    operation_name = "Prediction Overlay Plot",
    error_parser = error_handling$default_error_parser
  )
}


# =============================================================================
# Internal helpers (not exported)
# =============================================================================

#' Build PCA overlay: reuse create_biplot for training
#' data, then layer unknown scores on top.
build_pca_overlay <- function(bundle, pred_result,
                              unknown_data, dim_x,
                              dim_y, meta_col,
                              group_cols = NULL,
                              show_convex_hull = FALSE,
                              point_alpha = 0.5,
                              point_size = 2.5,
                              layer = "individuals") {
  # Reconstruct pca_result from bundle so we can
  # delegate to create_biplot (single source of truth)
  pca_result <- reconstruct_pca_result(bundle)

  # Render training biplot via the PCA module
  biplot_res <- create_biplot(
    pca_result = pca_result,
    dim_x = dim_x,
    dim_y = dim_y,
    layer = layer,
    group_cols = group_cols,
    show_convex_hull = show_convex_hull,
    point_alpha = point_alpha,
    point_size = point_size,
    show_title = FALSE
  )

  if (!biplot_res$success) {
    stop(biplot_res$error$message %||% "Biplot failed")
  }

  p <- biplot_res$result

  # Build unknown scores data frame
  unknown_scores <- pred_result$scores
  unknown_df <- data.frame(
    x = unknown_scores[[dim_x]],
    y = unknown_scores[[dim_y]],
    stringsAsFactors = FALSE
  )

  # Labels from metadata
  if (
    !is.null(meta_col) &&
    meta_col %in% names(unknown_data)
  ) {
    unknown_df$label <- as.character(
      unknown_data[[meta_col]]
    )
  } else {
    unknown_df$label <- paste0(
      "Unknown_", seq_len(nrow(unknown_df))
    )
  }

  # Tooltips for unknowns
  unknown_df$tooltip <- paste0(
    "<b>", unknown_df$label, "</b><br>",
    dim_x, ": ", round(unknown_df$x, 3), "<br>",
    dim_y, ": ", round(unknown_df$y, 3)
  )
  unknown_df$data_id <- paste0(
    "unknown_", seq_len(nrow(unknown_df))
  )

  # Layer unknown points (triangles) on top of biplot
  p <- p +
    ggiraph$geom_point_interactive(
      data = unknown_df,
      ggplot2$aes(
        x = x, y = y,
        tooltip = tooltip,
        data_id = data_id
      ),
      shape = 24,
      fill = "red",
      color = "black",
      stroke = 0.8,
      size = 4,
      alpha = 0.95
    )

  # Labels for unknown points — use pca_result coords
  # for y range (p$data is empty in multi-layer ggplot)
  train_y <- pca_result$ind$coord[, dim_y]
  y_range <- diff(range(
    c(unknown_df$y, train_y),
    na.rm = TRUE
  ))
  p <- p +
    ggplot2$geom_text(
      data = unknown_df,
      ggplot2$aes(
        x = x, y = y, label = label
      ),
      nudge_y = -y_range * 0.03,
      size = 2.8,
      color = "grey30",
      fontface = "italic"
    )

  # Add title and subtitle
  n_train <- nrow(bundle$used_data)
  n_unknown <- nrow(unknown_df)
  p <- p + ggplot2$ggtitle(
    label = paste0(
      "PCA Prediction \u2014 ",
      dim_x, " vs ", dim_y
    ),
    subtitle = paste0(
      n_train, " training + ",
      n_unknown, " unknown samples"
    )
  )

  p
}

#' Build LDA/MDA overlay: training LD scores + unknown
build_ld_overlay <- function(bundle, pred_result,
                             unknown_data, dim_x,
                             dim_y, meta_col) {
  # Training scores from bundle result
  model <- bundle$model
  used_data <- bundle$used_data
  numeric_cols <- bundle$numeric_cols
  train_numeric <- used_data[
    , numeric_cols, drop = FALSE
  ]

  # Get training LD scores
  is_mda <- bundle$analysis_type == "mda"
  if (is_mda) {
    train_scores_raw <- stats$predict(
      model, train_numeric, type = "variates"
    )
    train_scores <- as.data.frame(train_scores_raw)
    if (ncol(train_scores) > 0) {
      colnames(train_scores) <- paste0(
        "LD", seq_len(ncol(train_scores))
      )
    }
  } else {
    train_pred <- stats$predict(model, train_numeric)
    train_scores <- as.data.frame(train_pred$x)
  }

  # Build training data frame
  group_col <- bundle$group_col
  train_df <- data.frame(
    x = train_scores[[dim_x]],
    y = train_scores[[dim_y]],
    type = "Training",
    group = as.character(
      used_data[[group_col]]
    ),
    label = "",
    stringsAsFactors = FALSE
  )

  # Unknown scores
  unknown_scores <- pred_result$scores
  unknown_df <- data.frame(
    x = unknown_scores[[dim_x]],
    y = unknown_scores[[dim_y]],
    type = "Unknown",
    group = as.character(
      pred_result$predicted_class
    ),
    stringsAsFactors = FALSE
  )

  if (
    !is.null(meta_col) &&
    meta_col %in% names(unknown_data)
  ) {
    unknown_df$label <- as.character(
      unknown_data[[meta_col]]
    )
  } else {
    unknown_df$label <- paste0(
      "Unknown_", seq_len(nrow(unknown_df))
    )
  }

  combined <- rbind(train_df, unknown_df)
  combined$group <- factor(combined$group)
  combined$type <- factor(
    combined$type, levels = c("Training", "Unknown")
  )

  title <- paste0(
    toupper(bundle$analysis_type),
    " \u2014 ", dim_x, " vs ", dim_y
  )
  build_overlay_ggplot(combined, dim_x, dim_y, title)
}

#' Build QDA overlay via companion LDA projection
build_qda_overlay <- function(bundle, pred_result,
                              unknown_data, dim_x,
                              dim_y, meta_col) {
  # Use companion LDA scores for training
  if (is.null(bundle$lda_scores)) {
    stop(paste(
      "QDA bundle does not contain companion LDA",
      "scores for visualization."
    ))
  }

  train_scores <- bundle$lda_scores
  group_col <- bundle$group_col
  used_data <- bundle$used_data

  train_df <- data.frame(
    x = train_scores[[dim_x]],
    y = train_scores[[dim_y]],
    type = "Training",
    group = as.character(
      used_data[[group_col]]
    ),
    label = "",
    stringsAsFactors = FALSE
  )

  # Unknown LD scores (from companion LDA predict)
  unknown_scores <- pred_result$scores
  if (is.null(unknown_scores)) {
    stop(paste(
      "No LD scores available for unknowns.",
      "QDA companion LDA projection failed."
    ))
  }

  unknown_df <- data.frame(
    x = unknown_scores[[dim_x]],
    y = unknown_scores[[dim_y]],
    type = "Unknown",
    group = as.character(
      pred_result$predicted_class
    ),
    stringsAsFactors = FALSE
  )

  if (
    !is.null(meta_col) &&
    meta_col %in% names(unknown_data)
  ) {
    unknown_df$label <- as.character(
      unknown_data[[meta_col]]
    )
  } else {
    unknown_df$label <- paste0(
      "Unknown_", seq_len(nrow(unknown_df))
    )
  }

  combined <- rbind(train_df, unknown_df)
  combined$group <- factor(combined$group)
  combined$type <- factor(
    combined$type, levels = c("Training", "Unknown")
  )

  title <- paste0(
    "QDA \u2014 ", dim_x, " vs ", dim_y,
    " (LDA projection)"
  )
  build_overlay_ggplot(combined, dim_x, dim_y, title)
}


#' Reconstruct a pca_result structure from a bundle
#'
#' Uses the stored prcomp model and training data to
#' rebuild the same structure that create_biplot expects.
reconstruct_pca_result <- function(bundle) {
  model <- bundle$model
  used_data <- bundle$used_data
  numeric_cols <- bundle$numeric_cols
  meta_cols <- bundle$meta_cols %||% character(0)
  n <- nrow(used_data)
  p <- length(numeric_cols)
  ncp <- min(p, n - 1)

  result <- build_pca_result(model, ncp, n, p)
  result$pca_obj <- model
  result$ind$meta <- build_ind_meta(
    used_data, meta_cols, n
  )
  result
}

#' Build the combined ggplot with training + unknown
build_overlay_ggplot <- function(combined, dim_x,
                                 dim_y, title) {
  train_data <- combined[combined$type == "Training", ]
  unknown_data <- combined[combined$type == "Unknown", ]

  # Tooltip for unknowns
  unknown_data$tooltip <- paste0(
    "<b>", unknown_data$label, "</b><br>",
    "Predicted: ", unknown_data$group, "<br>",
    dim_x, ": ", round(unknown_data$x, 3), "<br>",
    dim_y, ": ", round(unknown_data$y, 3)
  )
  unknown_data$data_id <- paste0(
    "unknown_", seq_len(nrow(unknown_data))
  )

  p <- ggplot2$ggplot() +
    # Training points (circles, semi-transparent)
    ggplot2$geom_point(
      data = train_data,
      ggplot2$aes(
        x = x, y = y, fill = group
      ),
      shape = 21,
      color = "white",
      stroke = 0.4,
      size = 2.5,
      alpha = 0.4
    ) +
    # Training confidence ellipses
    ggplot2$stat_ellipse(
      data = train_data,
      ggplot2$aes(
        x = x, y = y, color = group
      ),
      level = 0.95,
      linetype = "dashed",
      linewidth = 0.5,
      show.legend = FALSE
    ) +
    # Unknown points (triangles, fully opaque)
    ggiraph$geom_point_interactive(
      data = unknown_data,
      ggplot2$aes(
        x = x, y = y,
        fill = group,
        tooltip = tooltip,
        data_id = data_id
      ),
      shape = 24,
      color = "black",
      stroke = 0.8,
      size = 4,
      alpha = 0.95
    ) +
    ggplot2$labs(
      x = dim_x,
      y = dim_y,
      fill = "Group",
      title = title,
      subtitle = paste0(
        nrow(train_data), " training + ",
        nrow(unknown_data), " unknown samples"
      )
    ) +
    ggplot2$theme_minimal(base_size = 12) +
    ggplot2$theme(
      legend.position = "right",
      plot.title = ggplot2$element_text(
        face = "bold", size = 13
      ),
      plot.subtitle = ggplot2$element_text(
        color = "grey40", size = 10
      ),
      panel.grid.minor = ggplot2$element_blank()
    )

  p
}
