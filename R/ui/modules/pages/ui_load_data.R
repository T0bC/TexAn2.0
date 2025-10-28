UI_load_data <- function(id) {
    ns <- shiny::NS(id)

    shiny::tagList(
        shiny::h2("Load Data"),
        shiny::wellPanel(
            shiny::fileInput(ns("data_file"), "Upload dataset"),
            shiny::actionButton(ns("load_btn"), "Load", class = "btn-primary")
    ),
    shiny::p("TODO: Implement data preview and validation outputs.")
    )
}
