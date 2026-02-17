box::use(
  bsicons,
  bslib,
  rhino,
  shiny,
)

box::use(
  app/view/components/sidebar_tabs,
)

#' @export
tab_ui <- function(ns) {
  sidebar_tabs$create_tab(
    icon = "play-circle",
    tooltip_text = "Actions",
    value = "actions_tab",
    shiny$h6(class = "text-muted mb-3", "Actions"),
    shiny$helpText(
      paste(
        "Configure additional actions and exports for your",
        "clustering analysis results."
      )
    ),
    # Export options
    shiny$tags$label(
      class = "control-label",
      "Export Options ",
      bslib$tooltip(
        bsicons$bs_icon(
          "info-circle", class = "text-muted"
        ),
        "Choose how to export your clustering results."
      )
    ),
    shiny$checkboxInput(
      inputId = ns("export_clusters"),
      label = "Export cluster assignments",
      value = TRUE
    ),
    shiny$checkboxInput(
      inputId = ns("export_plots"),
      label = "Export clustering plots",
      value = TRUE
    ),
    shiny$checkboxInput(
      inputId = ns("export_summary"),
      label = "Export cluster summary statistics",
      value = TRUE
    ),
    shiny$tags$hr(),
    # Advanced options
    shiny$tags$label(
      class = "control-label",
      "Advanced Options ",
      bslib$tooltip(
        bsicons$bs_icon(
          "info-circle", class = "text-muted"
        ),
        "Additional configuration for advanced users."
      )
    ),
    shiny$checkboxInput(
      inputId = ns("verbose_output"),
      label = "Show detailed computation logs",
      value = FALSE
    ),
    shiny$checkboxInput(
      inputId = ns("save_intermediate"),
      label = "Save intermediate results",
      value = FALSE
    )
  )
}

#' Server logic for the Cluster actions sidebar tab
#'
#' Handles additional actions and export options.
#'
#' @param input Shiny input object from parent module
#' @param output Shiny output object from parent module
#' @param session Shiny session object from parent module
#' @param input_data Reactive returning the current data frame
#' @param data_version Reactive returning the data version counter
#' @export
tab_server <- function(input, output, session,
                       input_data, data_version) {
  # Reset action settings when new data is loaded
  shiny$observeEvent(data_version(), {
    rhino$log$info(
      "Cluster actions: reset for new data"
    )
    # Reset to default values
    shiny$updateCheckboxInput(
      session, "export_clusters",
      value = TRUE
    )
    shiny$updateCheckboxInput(
      session, "export_plots",
      value = TRUE
    )
    shiny$updateCheckboxInput(
      session, "export_summary",
      value = TRUE
    )
    shiny$updateCheckboxInput(
      session, "verbose_output",
      value = FALSE
    )
    shiny$updateCheckboxInput(
      session, "save_intermediate",
      value = FALSE
    )
  }, ignoreInit = TRUE)

  # Log action changes for debugging
  shiny$observe({
    if (input$verbose_output) {
      rhino$log$info(
        "Cluster actions: verbose output enabled"
      )
    }
  })

  shiny$observe({
    if (input$save_intermediate) {
      rhino$log$info(
        "Cluster actions: intermediate results saving enabled"
      )
    }
  })
}
