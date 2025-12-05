# Median table rendering logic
# This file defines a function that calculates and renders the median results table
#
# @param output Shiny output object
# @param output_id Character string for the output ID (e.g., "medianTable")
# @param filtered_data ReactiveVal containing the filtered data
# @param median_results ReactiveVal to store the calculated median results
# @return NULL (side effects: creates output$medianTable and updates median_results)

# Source column utilities
source("R/utils/column_utils.R", local = TRUE)

render_median_table <- function(output, output_id, filtered_data, median_results) {
    output[[output_id]] <- DT::renderDataTable({
        shiny::req(filtered_data())

        data <- filtered_data()

        # Get measurement columns using the utility function
        measurement_cols <- get_measurement_cols(data)
        
        # Filter to only numeric measurement columns
        measurement_cols <- measurement_cols[sapply(measurement_cols, function(col) {
            is.numeric(data[[col]])
        })]

        if (length(measurement_cols) == 0) {
            # No measurement columns found
            results <- data.frame(
                Message = "No measurement columns found in the filtered data."
            )
            median_results(NULL)
        } else {
            # Calculate medians for measurement columns
            medians <- sapply(data[, measurement_cols, drop = FALSE], median, na.rm = TRUE)
            
            # Calculate additional statistics
            n_values <- sapply(data[, measurement_cols, drop = FALSE], function(x) sum(!is.na(x)))
            means <- sapply(data[, measurement_cols, drop = FALSE], mean, na.rm = TRUE)
            sds <- sapply(data[, measurement_cols, drop = FALSE], sd, na.rm = TRUE)

            results <- data.frame(
                Column = names(medians),
                N = as.integer(n_values),
                Median = round(as.numeric(medians), 4),
                Mean = round(as.numeric(means), 4),
                SD = round(as.numeric(sds), 4),
                stringsAsFactors = FALSE
            )
            
            # Store results
            median_results(results)
        }

        # Create DataTable with options
        DT::datatable(
            results,
            options = list(
                pageLength = 25,
                lengthMenu = list(c(10, 25, 50, 100, -1), c("10", "25", "50", "100", "All")),
                scrollX = TRUE,
                dom = "Blfrtip"
            ),
            rownames = FALSE
        )
    })
}
