box::use(
  ggplot2,
  ggiraph,
  packcircles,
  rhino,
)

box::use(
  app/logic/error_handling,
)

# =============================================================================
# Variable contribution circle-packed plot
# No Shiny dependencies allowed in this file.
# Legacy plots (bar chart, overview dot plot) are in var_contrib_legacy.R
# =============================================================================

#' Error parser for variable contribution plot errors
#'
#' @param error_msg Character, the original error message
#' @param operation_name Character, name of the operation
#' @return Character, user-friendly error message
#' @export
var_contrib_error_parser <- function(error_msg,
                                     operation_name =
                                       "Variable Contribution Plot") {
  if (grepl(
    "dimension|dim|not found",
    error_msg, ignore.case = TRUE
  )) {
    paste0(
      operation_name,
      ": Invalid dimension selection.",
      " Please check available components."
    )
  } else if (grepl(
    "NULL|missing|pca_result",
    error_msg, ignore.case = TRUE
  )) {
    paste0(
      operation_name,
      ": No PCA result available.",
      " Please compute PCA first."
    )
  } else {
    paste0(operation_name, " failed: ", error_msg)
  }
}


#' Create a circle-packed variable contribution plot
#'
#' For each PCA dimension, variables are shown as non-overlapping
#' circles. Circle size is proportional to cos2 (quality of
#' representation). Y-axis shows contribution (%). Faceted by
#' dimension.
#'
#' @param pca_result PCA result list (the $result field from run_pca)
#' @param display_ncp Integer, number of dimensions to show
#' @param show_title Logical, whether to show the plot title
#' @return List with $success, $result (ggplot) or $error
#' @export
create_var_contrib_circles_plot <- function(pca_result,
                                            display_ncp = 5L,
                                            show_title = TRUE) {
  error_context <- list(display_ncp = display_ncp)

  error_handling$safe_execute(
    expr = {
      if (is.null(pca_result)) stop("pca_result is NULL")

      contrib <- pca_result$var$contrib
      cos2 <- pca_result$var$cos2
      n_dims <- min(display_ncp, ncol(contrib))
      dims <- colnames(contrib)[seq_len(n_dims)]
      eig <- pca_result$eig
      threshold <- expected_average(pca_result)

      # Build circle data per dimension
      all_circles <- lapply(seq_along(dims), function(i) {
        dim <- dims[i]
        dim_idx <- which(rownames(eig) == dim)
        var_pct <- if (length(dim_idx) == 1) {
          eig[dim_idx, "variance.percent"]
        } else {
          NA_real_
        }
        dim_label <- if (!is.na(var_pct)) {
          sprintf("%s (%.1f%%)", dim, var_pct)
        } else {
          dim
        }

        vals <- contrib[, dim]
        cos2_vals <- cos2[, dim]
        vars <- rownames(contrib)

        # Uniform radius for all circles
        uniform_r <- 10.0
        radii <- rep(uniform_r, length(cos2_vals))

        # Use circleRepelLayout with random x starts
        # so repulsion spreads circles horizontally
        set.seed(42 + i)
        n_vars <- length(vals)
        input_df <- data.frame(
          x = stats::runif(n_vars, -10, 10),
          y = vals,
          radius = radii
        )
        # Constrain y so circles stay near true contrib
        y_pad <- max(radii) * 2
        y_range <- range(vals)
        layout <- packcircles$circleRepelLayout(
          input_df,
          xlim = c(-30, 30),
          ylim = c(
            y_range[1] - y_pad,
            y_range[2] + y_pad
          ),
          xysizecols = c(1, 2, 3),
          sizetype = "radius",
          maxiter = 2000,
          wrap = FALSE
        )
        packed <- layout$layout

        # Build circle vertices for polygon drawing
        vertices <- packcircles$circleLayoutVertices(
          packed, npoints = 50
        )

        # Map circle id back to variable info
        circle_data <- data.frame(
          variable = vars,
          contrib = packed[, 2],
          cos2 = cos2_vals,
          radius = packed[, 3],
          cx = packed[, 1],
          cy = packed[, 2],
          dim = dim,
          dim_label = dim_label,
          stringsAsFactors = FALSE
        )
        circle_data$tooltip <- sprintf(
          paste0(
            "<b>%s</b><br/>%s",
            "<br/>Contribution: %.2f%%",
            "<br/>cos\u00b2: %.4f"
          ),
          circle_data$variable,
          circle_data$dim_label,
          vals,
          cos2_vals
        )
        circle_data$data_id <- paste0(
          "vcc_", circle_data$variable, "_", dim
        )

        vertices$dim_label <- dim_label
        vertices$variable <- vars[vertices$id]
        vertices$cos2 <- cos2_vals[vertices$id]
        vertices$tooltip <- circle_data$tooltip[vertices$id]
        vertices$data_id <- circle_data$data_id[vertices$id]

        list(
          circles = circle_data,
          vertices = vertices
        )
      })

      # Combine across dimensions
      circle_df <- do.call(
        rbind, lapply(all_circles, `[[`, "circles")
      )
      vert_df <- do.call(
        rbind, lapply(all_circles, `[[`, "vertices")
      )

      # Preserve dimension order
      dim_label_levels <- unique(circle_df$dim_label)
      circle_df$dim_label <- factor(
        circle_df$dim_label, levels = dim_label_levels
      )
      vert_df$dim_label <- factor(
        vert_df$dim_label, levels = dim_label_levels
      )

      p <- ggplot2$ggplot() +
        ggiraph$geom_polygon_interactive(
          data = vert_df,
          ggplot2$aes(
            x = x, y = y, group = interaction(
              dim_label, id
            ),
            fill = cos2,
            tooltip = tooltip,
            data_id = data_id
          ),
          color = "black",
          alpha = 0.85,
          linewidth = 0.4
        ) +
        ggplot2$scale_fill_viridis_c(
          option = "C",
          limits = c(0, 1),
          name = expression(cos^2)
        ) +
        ggiraph$geom_text_interactive(
          data = circle_df,
          ggplot2$aes(
            x = cx, y = cy,
            label = variable,
            tooltip = tooltip,
            data_id = data_id
          ),
          size = 3,
          color = "#333333"
        ) +
        ggplot2$geom_hline(
          yintercept = threshold,
          linetype = "dashed",
          color = "grey40",
          linewidth = 0.5
        ) +
        ggplot2$facet_wrap(
          ~ dim_label, nrow = 1,
          strip.position = "bottom"
        ) +
        ggplot2$coord_fixed() +
        var_contrib_theme() +
        ggplot2$theme(
          legend.position = "right",
          axis.title = ggplot2$element_text(size = 10),
          axis.text.y = ggplot2$element_text(size = 8),
          panel.grid.major.y = ggplot2$element_line(),
          panel.grid.minor = ggplot2$element_blank(),
          axis.text.x = ggplot2$element_blank(),
          axis.ticks.x = ggplot2$element_blank(),
          strip.placement = "outside",
          strip.text = ggplot2$element_text(
            size = 8, face = "bold"
          )
        ) +
        ggplot2$labs(
          x = NULL,
          y = "Contribution (%)"
        )

      p
    },
    operation_name = "Variable Contribution Circles Plot",
    context = error_context,
    error_parser = var_contrib_error_parser
  )
}


# =============================================================================
# Internal helpers (not exported)
# =============================================================================

#' Compute expected average contribution (100/p %)
expected_average <- function(pca_result) {
  p <- nrow(pca_result$var$contrib)
  100 / p
}

#' Theme for variable contribution chart
var_contrib_theme <- function() {
  ggplot2$theme_minimal() +
    ggplot2$theme(
      plot.title = ggplot2$element_text(
        hjust = 0.5, size = 14, face = "bold"
      ),
      axis.title = ggplot2$element_text(size = 12),
      axis.text = ggplot2$element_text(size = 10),
      legend.position = "bottom",
      legend.text = ggplot2$element_text(size = 10),
      panel.grid.major.y = ggplot2$element_blank(),
      panel.grid.minor = ggplot2$element_blank()
    )
}
