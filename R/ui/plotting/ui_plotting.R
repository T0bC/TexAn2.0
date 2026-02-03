#' UI for the Plotting page
#'
#' Orchestrates all plotting UI components.
#' Tab components are sourced from R/ui/plotting/
#'
#' @param id Module namespace ID
#' @return A bslib layout_sidebar UI element
UI_plotting <- function(id) {
    ns <- shiny::NS(id)
    
    # Source UI tab components
    source("R/ui/plotting/ui_tab_data_selection.R", local = TRUE)
    source("R/ui/plotting/ui_tab_filter.R", local = TRUE)
    source("R/ui/plotting/ui_tab_processing.R", local = TRUE)
    source("R/ui/plotting/ui_tab_style.R", local = TRUE)

    shiny::tagList(
        # Initialize window size reporting with namespaced IDs
        shiny::tags$script(shiny::HTML(sprintf(
            "$(document).on('shiny:connected', function() { initializeWindowSize('%s', '%s'); });",
            ns("plots"),
            ns("windowSize")
        ))),
        bslib::layout_sidebar(
            sidebar = bslib::sidebar(
                title = NULL,
                class = "plotting-sidebar",
                
                # Horizontal tabs with icons only
                bslib::navset_tab(
                    id = ns("sidebar_tabs"),
                    create_data_selection_tab(ns),
                    create_filter_tab(ns),
                    create_processing_tab(ns),
                    create_style_tab(ns)
                ),
                
                # Download button at bottom (always visible)
                shiny::tags$hr(),
                shiny::downloadButton(
                    outputId = ns("downloadData"),
                    label = "Download Filtered Data",
                    class = "btn-primary btn-sm w-100"
                )
            ),

            # Main content area - plots will be rendered here
            shiny::uiOutput(ns("plots"))
        )
    )
}
