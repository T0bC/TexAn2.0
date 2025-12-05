# Filter UI rendering and data filtering logic
# This file defines a function that renders filter UI elements and handles data filtering
#
# @param output Shiny output object
# @param loaded_data Reactive containing the loaded data from the Load Data tab
# @param filter_data_1_id Character string for the first filter output ID
# @param filter_data_2_id Character string for the second filter output ID
# @param input Shiny input object (for accessing filter selections)
# @param filtered_data ReactiveVal to store the filtered data
# @param session Shiny session object (for namespacing inputs)
# @return NULL (side effects: creates filter UI outputs and updates filtered_data)

# Source column utilities
source("R/utils/column_utils.R", local = TRUE)

render_filter_ui <- function(output, loaded_data, filter_data_1_id, filter_data_2_id, 
                              input, filtered_data, session) {
    ns <- session$ns
    
    # Reactive to get descriptive columns for filtering
    descriptive_cols <- shiny::reactive({
        shiny::req(loaded_data())
        data <- loaded_data()
        # Use the short version which includes columns with numbers if they have few unique values
        get_descriptive_cols_short(data, threshold = 20)
    })
    
    # Render first filter UI - column selection dropdown
    output[[filter_data_1_id]] <- shiny::renderUI({
        shiny::req(loaded_data())
        
        cols <- descriptive_cols()
        
        if (length(cols) == 0) {
            return(shiny::tags$p(
                class = "text-warning",
                "No descriptive columns found. Check column naming conventions."
            ))
        }
        
        shiny::tagList(
            shiny::selectInput(
                inputId = ns("filter1_column"),
                label = "Filter by column:",
                choices = c("Select column..." = "", cols),
                selected = ""
            ),
            shiny::uiOutput(ns("filter1_values"))
        )
    })
    
    # Render filter 1 value selection based on selected column
    output$filter1_values <- shiny::renderUI({
        shiny::req(input$filter1_column)
        shiny::req(input$filter1_column != "")
        
        data <- loaded_data()
        col <- input$filter1_column
        
        # Get unique values for the selected column
        unique_vals <- sort(unique(as.character(data[[col]])))
        
        shiny::selectInput(
            inputId = ns("filter1_value"),
            label = paste0("Select ", col, " value:"),
            choices = c("All" = "", unique_vals),
            selected = ""
        )
    })

    # Render second filter UI - column selection dropdown
    output[[filter_data_2_id]] <- shiny::renderUI({
        shiny::req(loaded_data())
        
        cols <- descriptive_cols()
        
        if (length(cols) == 0) {
            return(NULL)
        }
        
        # Exclude the first filter column from second filter options
        available_cols <- cols
        if (!is.null(input$filter1_column) && input$filter1_column != "") {
            available_cols <- setdiff(cols, input$filter1_column)
        }
        
        if (length(available_cols) == 0) {
            return(shiny::tags$p(
                class = "text-muted",
                shiny::tags$em("No additional columns available for filtering.")
            ))
        }
        
        shiny::tagList(
            shiny::selectInput(
                inputId = ns("filter2_column"),
                label = "Additional filter (optional):",
                choices = c("None" = "", available_cols),
                selected = ""
            ),
            shiny::uiOutput(ns("filter2_values"))
        )
    })
    
    # Render filter 2 value selection based on selected column
    output$filter2_values <- shiny::renderUI({
        shiny::req(input$filter2_column)
        shiny::req(input$filter2_column != "")
        
        data <- loaded_data()
        col <- input$filter2_column
        
        # Get unique values for the selected column (from already filtered data if filter1 is active)
        if (!is.null(input$filter1_column) && input$filter1_column != "" &&
            !is.null(input$filter1_value) && input$filter1_value != "") {
            data <- data[data[[input$filter1_column]] == input$filter1_value, , drop = FALSE]
        }
        
        unique_vals <- sort(unique(as.character(data[[col]])))
        
        shiny::selectInput(
            inputId = ns("filter2_value"),
            label = paste0("Select ", col, " value:"),
            choices = c("All" = "", unique_vals),
            selected = ""
        )
    })

    # Observe changes to filters and update filtered_data
    shiny::observe({
        shiny::req(loaded_data())

        data <- loaded_data()

        # Apply first filter if selected
        if (!is.null(input$filter1_column) && input$filter1_column != "" &&
            !is.null(input$filter1_value) && input$filter1_value != "") {
            data <- data[data[[input$filter1_column]] == input$filter1_value, , drop = FALSE]
        }
        
        # Apply second filter if selected
        if (!is.null(input$filter2_column) && input$filter2_column != "" &&
            !is.null(input$filter2_value) && input$filter2_value != "") {
            data <- data[data[[input$filter2_column]] == input$filter2_value, , drop = FALSE]
        }

        filtered_data(data)
    })
}
