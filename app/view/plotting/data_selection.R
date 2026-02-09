box::use(
  bsicons,
  bslib,
  shiny,
)

box::use(
  app/view/components/sidebar_tabs,
)

#' Build the data selection sidebar tab UI
#' @param ns Namespace function from the parent module
#' @return A sidebar tab created via sidebar_tabs$create_tab()
#' @export
tab_ui <- function(ns) {
  sidebar_tabs$create_tab(
    icon = "sliders",
    tooltip_text = "Configuration",
    value = "config_tab",
    shiny$h6(class = "text-muted mb-3", "Configuration"),
    shiny$selectizeInput(
      inputId = ns("input1"),
      label = shiny$tags$span(
        "Select columns ",
        bslib$tooltip(
          bsicons$bs_icon("info-circle", class = "text-muted"),
          "Choose columns for plotting."
        )
      ),
      choices = NULL,
      multiple = TRUE,
      options = list(placeholder = "Select...")
    )
  )
}

#' Server logic for the data selection sidebar tab
#' @param input Shiny input object from parent module
#' @param output Shiny output object from parent module
#' @param session Shiny session object from parent module
#' @param input_data Reactive returning the current data frame
#' @param data_version Reactive returning the data version counter
#' @export
tab_server <- function(input, output, session, input_data,
                       data_version) {
  # Update input choices when data changes
  shiny$observe({
    data <- input_data()
    if (is.null(data)) return()
    shiny$updateSelectizeInput(
      session, "input1",
      choices = names(data),
      selected = NULL
    )
  })
}
