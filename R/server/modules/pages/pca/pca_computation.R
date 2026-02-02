#' PCA Computation Handler
#'
#' Handles KMO computation with validation and progress feedback.
#'
#' @param input Shiny input object from parent module
#'   - input$measureVar: Selected measurement columns
#'   - input$scale_data: Whether to scale data
#' @param median_data Reactive containing the source data
#' @param pca_state ReactiveValues to store computation results
#' @return NULL (side effects only)
handle_pca_computation <- function(input, median_data, pca_state) {
    shiny::observeEvent(input$compute_pca_button, {
        data <- median_data()
        measure_cols <- input$measureVar
        
        # Validation
        if (is.null(data)) {
            pca_state$kmo_result <- simple_error(
                "No data available. Please load data first.",
                operation_name = "PCA Validation"
            )
            return()
        }
        
        if (is.null(measure_cols) || length(measure_cols) < 2) {
            pca_state$kmo_result <- simple_error(
                "Please select at least 2 measurement columns for PCA.",
                operation_name = "PCA Validation"
            )
            return()
        }
        
        # Compute with progress
        shiny::withProgress(message = "Computing KMO measures...", {
            # Prepare data: subset, remove NA rows, optionally scale
            prep_result <- prepare_pca_data(
                data = data,
                measure_cols = measure_cols,
                scale = isTRUE(input$scale_data)
            )
            
            prepared_data <- prep_result$data
            
            # Check if we have enough data after NA removal
            if (nrow(prepared_data) < 2) {
                pca_state$kmo_result <- simple_error(
                    "Not enough complete observations after removing rows with missing values.",
                    operation_name = "PCA Validation",
                    context = list(
                        original_rows = prep_result$original_rows,
                        rows_removed = prep_result$rows_removed,
                        remaining_rows = nrow(prepared_data)
                    )
                )
                return()
            }
            
            shiny::incProgress(0.3)
            
            kmo_result <- calculate_kmo(prepared_data)
            
            # Add info about removed rows to KMO result if any were removed
            if (!is_app_error(kmo_result) && prep_result$rows_removed > 0) {
                kmo_result$rows_removed <- prep_result$rows_removed
                kmo_result$original_rows <- prep_result$original_rows
            }
            
            shiny::incProgress(0.7)
            
            pca_state$kmo_result <- kmo_result
            pca_state$prepared_data <- prepared_data
            pca_state$last_computation <- Sys.time()
        })
    })
}
