box::use(
  bsicons,
  bslib,
  shiny,
)

box::use(
  app/view/components/sidebar_tabs,
)

#' @export
ui <- function(id) {
  ns <- shiny$NS(id)

  sidebar_tabs$tab_layout(
    ns = ns,
    sidebar_id = "sidebar_tabs",
    tabs = list(
      sidebar_tabs$create_tab(
        icon = "sliders",
        tooltip_text = "Grouping",
        value = "grouping_tab",
        shiny$h6(class = "text-muted mb-3", "Grouping"),
        shiny$helpText("Grouping settings will go here.")
      ),
      sidebar_tabs$create_tab(
        icon = "funnel",
        tooltip_text = "Filter",
        value = "filter_tab",
        shiny$h6(class = "text-muted mb-3", "Quality Filter"),
        shiny$helpText("Quality filter settings will go here.")
      )
    ),
    main_content = shiny$uiOutput(ns("main_content"))
  )
}

#' @export
server <- function(id, input_data, data_version) {
  shiny$moduleServer(id, function(input, output, session) {
    ns <- session$ns

    output$main_content <- shiny$renderUI({
      shiny$tags$div(
        class = "d-flex align-items-center justify-content-center",
        style = "min-height: 400px;",
        shiny$tags$div(
          class = "text-center text-muted",
          shiny$tags$h4("Median Calculation"),
          shiny$tags$p("This module is under construction.")
        )
      )
    })

    invisible(NULL)
  })
}
