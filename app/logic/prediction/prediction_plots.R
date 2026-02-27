box::use(
  ggiraph,
  ggplot2,
  rhino,
  stats,
)

box::use(
  app/logic/error_handling,
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
#' @return List with $success, $result (ggplot) or $error
#' @export
create_prediction_overlay_plot <- function(
    bundle, prediction_result, unknown_data,
    dim_x, dim_y, meta_col = NULL) {
  error_handling$safe_execute(
    expr = {
      analysis_type <- bundle$analysis_type

      p <- switch(
        analysis_type,
        pca = build_pca_overlay(
          bundle, prediction_result,
          unknown_data, dim_x, dim_y, meta_col
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

#' Build PCA overlay: training PC scores + unknown scores
build_pca_overlay <- function(bundle, pred_result,
                              unknown_data, dim_x,
                              dim_y, meta_col) {
  # Training scores from used_data via model predict
  model <- bundle$model
  used_data <- bundle$used_data
  numeric_cols <- bundle$numeric_cols
  train_numeric <- used_data[
    , numeric_cols, drop = FALSE
  ]
  train_scores <- as.data.frame(
    stats$predict(model, train_numeric)
  )

  # Build training data frame
  train_df <- data.frame(
    x = train_scores[[dim_x]],
    y = train_scores[[dim_y]],
    type = "Training",
    stringsAsFactors = FALSE
  )

  # Build grouping if available
  if (
    !is.null(bundle$group_col) &&
    bundle$group_col %in% names(used_data)
  ) {
    train_df$group <- as.character(
      used_data[[bundle$group_col]]
    )
  } else {
    train_df$group <- "Training"
  }

  # Unknown scores
  unknown_scores <- pred_result$scores
  unknown_df <- data.frame(
    x = unknown_scores[[dim_x]],
    y = unknown_scores[[dim_y]],
    type = "Unknown",
    group = "Unknown",
    stringsAsFactors = FALSE
  )

  # Add labels from metadata
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
  train_df$label <- ""

  combined <- rbind(train_df, unknown_df)
  combined$group <- factor(combined$group)
  combined$type <- factor(
    combined$type, levels = c("Training", "Unknown")
  )

  build_overlay_ggplot(
    combined, dim_x, dim_y,
    paste0("PCA \u2014 ", dim_x, " vs ", dim_y)
  )
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
