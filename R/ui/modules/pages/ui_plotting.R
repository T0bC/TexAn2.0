#' UI for the Plotting page
#'
#' @param id Module namespace ID
#' @return A bslib layout_sidebar UI element
UI_plotting <- function(id) {
    ns <- shiny::NS(id)

    bslib::layout_sidebar(
        sidebar = bslib::sidebar(
            title = "Plot Configuration",
            width = 350,

            # Step 1: Select Descriptive Columns (always visible)
            shiny::h5("1. Select Descriptive Columns"),
            shiny::selectizeInput(
                inputId = ns("metaData"),
                label = shiny::tags$span(
                    "Descriptive: ",
                    bslib::tooltip(
                        bsicons::bs_icon("info-circle", class = "text-muted"),
                        paste0(
                            "Select columns that describe the data, such as the ",
                            "sample ID, treatment, etc., that are important for your analysis. ",
                            "You can then filter the data using the checkboxes."
                        )
                    )
                ),
                choices = NULL,
                multiple = TRUE,
                options = list(placeholder = "Select descriptive columns...")
            ),
            
            # Step 2: Additional column options (rendered dynamically after step 1)
            shiny::uiOutput(ns("column_options_ui")),
            
            # Step 3: Filter Data (rendered dynamically after step 1)
            shiny::uiOutput(ns("filter_section_ui")),

            # Step 4: Trimming Section (rendered dynamically after step 1)
            shiny::uiOutput(ns("trimming_section_ui")),

            # Download Section (rendered dynamically after step 1)
            shiny::uiOutput(ns("download_section_ui"))
        ),

        # Main content area - plots will be rendered here
        shiny::uiOutput(ns("plots"))
    )
}
