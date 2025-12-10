#' Filter Logic Component
#'
#' Handles filter column selection, checkbox UI rendering, and filtered data reactive.
#'
#' Following the explicit dependency injection pattern:
#' - All dependencies are passed as explicit parameters
#' - No implicit scoping or global state access
#'
#' @name filter_logic
NULL


#' Create Filter Columns Reactive
#'
#' @param input Shiny input object from parent module
#'   - input$metaData: Selected descriptive columns
#'   - input$hideCols: Columns to hide from filtering
#' @return Reactive returning character vector of columns to show for filtering
create_filter_cols_reactive <- function(input) {
    shiny::reactive({
        selected <- input$metaData
        hidden <- input$hideCols
        if (is.null(selected)) return(character(0))
        selected[!selected %in% hidden]
    })
}


#' Create Filtered Data Reactive
#'
#' Filters data based on checkbox selections for each filter column.
#'
#' @param input Shiny input object from parent module
#'   - input[[col]]: Checkbox group selections for each filter column
#' @param median_data Reactive containing the median-processed data
#' @param filter_cols Reactive returning columns to filter on
#' @return Reactive returning filtered data frame
create_filtered_data_reactive <- function(input, median_data, filter_cols) {
    shiny::reactive({
        data <- median_data()
        shiny::req(data)
        
        cols <- filter_cols()
        if (length(cols) == 0) return(data)
        
        # Apply filters from each checkbox group
        for (col in cols) {
            selected_values <- input[[col]]
            if (!is.null(selected_values) && length(selected_values) > 0) {
                data <- data[data[[col]] %in% selected_values, , drop = FALSE]
            }
        }
        
        data
    })
}


#' Render Filter Checkboxes UI
#'
#' Creates dynamic checkbox groups for filtering based on selected columns.
#'
#' @param output Shiny output object from parent module
#' @param ns Namespace function from parent module (session$ns)
#' @param median_data Reactive containing the median-processed data
#' @param filter_cols Reactive returning columns to show for filtering
#' @return NULL (side effects only - registers output)
setup_filter_checkboxes_output <- function(output, ns, median_data, filter_cols) {
    output$checkboxes <- shiny::renderUI({
        data <- median_data()
        shiny::req(data)
        
        cols <- filter_cols()
        
        if (length(cols) == 0) {
            return(shiny::tags$p(
                class = "text-muted fst-italic small",
                "Select descriptive columns or unhide some to see filtering options."
            ))
        }
        
        # Split columns into two groups for side-by-side layout
        if (length(cols) > 1) {
            half <- ceiling(length(cols) / 2)
            cols1 <- cols[seq_len(half)]
            cols2 <- cols[-seq_len(half)]
            
            shiny::fluidRow(
                shiny::column(6, lapply(cols1, function(col) {
                    choices <- unique(data[[col]])
                    shiny::checkboxGroupInput(ns(col), label = col, choices = choices, selected = choices)
                })),
                shiny::column(6, lapply(cols2, function(col) {
                    choices <- unique(data[[col]])
                    shiny::checkboxGroupInput(ns(col), label = col, choices = choices, selected = choices)
                }))
            )
        } else {
            col <- cols[1]
            choices <- unique(data[[col]])
            shiny::checkboxGroupInput(ns(col), label = col, choices = choices, selected = choices)
        }
    })
}
