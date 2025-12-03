server_median <- function(id, loaded_data) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns

        # Shared reactive values for median calculation
        filtered_data <- shiny::reactiveVal(NULL)
        median_results <- shiny::reactiveVal(NULL)

        # Source modular component functions
        source("R/server/modules/pages/median/help_modal.R", local = TRUE)
        source("R/server/modules/pages/median/filter_ui.R", local = TRUE)
        source("R/server/modules/pages/median/median_table.R", local = TRUE)
        source("R/server/modules/pages/median/filtering_message.R", local = TRUE)

        # Initialize modular components with explicit parameters
        # Following the explicit dependency injection pattern from memory...

        # Help button handler - requires input and session
        handle_help_button(
            input = input,
            session = session
        )

        # Filter UI renderer - requires output, loaded data, and filter inputs
        render_filter_ui(
            output = output,
            loaded_data = loaded_data,
            filter_data_1_id = "filterData1",
            filter_data_2_id = "filterData2",
            input = input,
            filtered_data = filtered_data
        )

        # Median table renderer - requires output and filtered data
        render_median_table(
            output = output,
            output_id = "medianTable",
            filtered_data = filtered_data,
            median_results = median_results
        )

        # Filtering message renderer - requires output and filtered data
        render_filtering_message(
            output = output,
            output_id = "filteringMessage2",
            filtered_data = filtered_data
        )

        # Return reactive with median results
        shiny::reactive({
            median_results()
        })
    })
}
