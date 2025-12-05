# Filtering message rendering logic
# This file defines a function that displays a message about the current filtering state
#
# @param output Shiny output object
# @param output_id Character string for the output ID (e.g., "filteringMessage2")
# @param filtered_data ReactiveVal containing the filtered data
# @param loaded_data Reactive containing the original loaded data
# @param input Shiny input object (for accessing filter selections)
# @return NULL (side effects: creates output$filteringMessage2)

# Source column utilities
source("R/utils/column_utils.R", local = TRUE)

render_filtering_message <- function(output, output_id, filtered_data, loaded_data = NULL, input = NULL) {
    output[[output_id]] <- shiny::renderUI({
        shiny::req(filtered_data())

        data <- filtered_data()
        
        # Get measurement column count
        measurement_cols <- get_measurement_cols(data)
        measurement_cols <- measurement_cols[sapply(measurement_cols, function(col) {
            is.numeric(data[[col]])
        })]
        
        # Build filter description
        filter_parts <- c()
        if (!is.null(input)) {
            if (!is.null(input$filter1_column) && input$filter1_column != "" &&
                !is.null(input$filter1_value) && input$filter1_value != "") {
                filter_parts <- c(filter_parts, 
                                  paste0(input$filter1_column, " = ", input$filter1_value))
            }
            if (!is.null(input$filter2_column) && input$filter2_column != "" &&
                !is.null(input$filter2_value) && input$filter2_value != "") {
                filter_parts <- c(filter_parts, 
                                  paste0(input$filter2_column, " = ", input$filter2_value))
            }
        }
        
        filter_text <- if (length(filter_parts) > 0) {
            paste("Filters applied:", paste(filter_parts, collapse = ", "))
        } else {
            "No filters applied (showing all data)"
        }
        
        # Calculate original row count if available
        original_rows <- if (!is.null(loaded_data)) nrow(loaded_data()) else NULL

        # Create a message about the filtered data
        shiny::tagList(
            shiny::tags$hr(),
            shiny::tags$div(
                class = "alert alert-info",
                shiny::tags$p(
                    shiny::tags$strong("Data Summary: "),
                    if (!is.null(original_rows)) {
                        sprintf("%d of %d rows selected", nrow(data), original_rows)
                    } else {
                        sprintf("%d rows", nrow(data))
                    }
                ),
                shiny::tags$p(
                    shiny::tags$strong("Measurement columns: "),
                    sprintf("%d numeric columns for median calculation", length(measurement_cols))
                ),
                shiny::tags$p(
                    shiny::tags$em(filter_text)
                )
            )
        )
    })
}
