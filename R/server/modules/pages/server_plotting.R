#' Server logic for the Plotting page
#'
#' @param id Module namespace ID
#' @param median_data Reactive containing the median-processed data from server_median
#' @param data_version Reactive integer that increments when new data is loaded
#' @return NULL (side effects only)
server_plotting <- function(id, median_data, data_version) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns
        
        # Source column utilities
        source("R/utils/column_utils.R", local = TRUE)
        
        # Reset all inputs when new data is loaded
        if (!is.null(data_version)) {
            shiny::observeEvent(data_version(), {
                shiny::updateSelectizeInput(session, "metaData", selected = character(0))
                shiny::updateSelectizeInput(session, "measureVar", selected = character(0))
                shiny::updateSelectizeInput(session, "hideCols", selected = character(0))
                shiny::updateSelectizeInput(session, "xAxis", selected = character(0))
                shiny::updateSelectizeInput(session, "tooltip", selected = character(0))
                shiny::updateSliderInput(session, "trim_slider", value = 0)
            }, ignoreInit = TRUE)
        }
        
        # Reactive: check if descriptive columns are selected
        has_descriptive_selection <- shiny::reactive({
            !is.null(input$metaData) && length(input$metaData) > 0
        })
        
        # Reactive: get descriptive columns (strict pattern: uppercase + underscores only)
        descriptive_cols <- shiny::reactive({
            shiny::req(median_data())
            get_descriptive_cols(median_data())
        })
        
        # Reactive: get measurement columns
        measurement_cols <- shiny::reactive({
            shiny::req(median_data())
            get_measurement_cols(median_data())
        })
        
        # Update metaData choices when data changes
        shiny::observe({
            cols <- descriptive_cols()
            shiny::updateSelectizeInput(
                session, "metaData",
                choices = cols,
                selected = input$metaData
            )
        })
        
        # Render column options UI (Step 2) - only when descriptive columns selected
        output$column_options_ui <- shiny::renderUI({
            if (!has_descriptive_selection()) {
                return(shiny::tags$p(
                    class = "text-muted fst-italic small",
                    "Select at least one descriptive column to continue..."
                ))
            }
            
            shiny::tagList(
                shiny::tags$hr(),
                shiny::h5("2. Configure Plot Options"),
                # Measurement and Hide columns row
                shiny::fluidRow(
                    shiny::column(
                        6,
                        shiny::selectizeInput(
                            inputId = ns("measureVar"),
                            label = shiny::tags$span(
                                "Measurement: ",
                                bslib::tooltip(
                                    bsicons::bs_icon("info-circle", class = "text-muted"),
                                    "Select columns containing measurements to plot."
                                )
                            ),
                            choices = measurement_cols(),
                            selected = input$measureVar,
                            multiple = TRUE,
                            options = list(placeholder = "Select...")
                        )
                    ),
                    shiny::column(
                        6,
                        shiny::selectizeInput(
                            inputId = ns("hideCols"),
                            label = shiny::tags$span(
                                "Hide from filter: ",
                                bslib::tooltip(
                                    bsicons::bs_icon("info-circle", class = "text-muted"),
                                    "Hide columns from filtering but keep for hover info."
                                )
                            ),
                            choices = input$metaData,
                            selected = input$hideCols[input$hideCols %in% input$metaData],
                            multiple = TRUE,
                            options = list(placeholder = "Select...")
                        )
                    )
                ),
                # X-Axis and Tooltip row
                shiny::fluidRow(
                    shiny::column(
                        6,
                        shiny::selectizeInput(
                            inputId = ns("xAxis"),
                            label = shiny::tags$span(
                                "X-Axis: ",
                                bslib::tooltip(
                                    bsicons::bs_icon("info-circle", class = "text-muted"),
                                    "Select up to 3 columns for the X-Axis. Also used in statistics."
                                )
                            ),
                            choices = input$metaData,
                            selected = input$xAxis[input$xAxis %in% input$metaData],
                            multiple = TRUE,
                            options = list(placeholder = "Select...", maxItems = 3)
                        )
                    ),
                    shiny::column(
                        6,
                        shiny::selectizeInput(
                            inputId = ns("tooltip"),
                            label = shiny::tags$span(
                                "Tooltip info: ",
                                bslib::tooltip(
                                    bsicons::bs_icon("info-circle", class = "text-muted"),
                                    "Select columns to display when hovering over plot points."
                                )
                            ),
                            choices = input$metaData,
                            selected = input$tooltip[input$tooltip %in% input$metaData],
                            multiple = TRUE,
                            options = list(placeholder = "Select...")
                        )
                    )
                )
            )
        })
        
        # Reactive: columns to show for filtering (metaData minus hideCols)
        filter_cols <- shiny::reactive({
            selected <- input$metaData
            hidden <- input$hideCols
            if (is.null(selected)) return(character(0))
            selected[!selected %in% hidden]
        })
        
        # Render filter section UI (Step 3) - only when descriptive columns selected
        output$filter_section_ui <- shiny::renderUI({
            if (!has_descriptive_selection()) return(NULL)
            
            data <- median_data()
            shiny::req(data)
            
            cols <- filter_cols()
            
            # Build checkboxes
            checkboxes_ui <- if (length(cols) == 0) {
                shiny::tags$p(
                    class = "text-muted fst-italic small",
                    "All descriptive columns are hidden from filtering."
                )
            } else if (length(cols) > 1) {
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
            
            shiny::tagList(
                shiny::tags$hr(),
                shiny::h5("3. Filter Data"),
                checkboxes_ui
            )
        })
        
        # Render trimming section UI (Step 4) - only when descriptive columns selected
        output$trimming_section_ui <- shiny::renderUI({
            if (!has_descriptive_selection()) return(NULL)
            
            shiny::tagList(
                shiny::tags$hr(),
                shiny::h5("4. Data Trimming"),
                shiny::sliderInput(
                    inputId = ns("trim_slider"),
                    label = shiny::tags$span(
                        "Trimming Value: ",
                        bslib::tooltip(
                            bsicons::bs_icon("info-circle", class = "text-muted"),
                            paste0(
                                "Data trimming removes a percentage of the highest and lowest values ",
                                "to reduce the impact of outliers."
                            )
                        )
                    ),
                    min = 0,
                    max = 100,
                    value = 0,
                    step = 1
                )
            )
        })
        
        # Render download section UI - only when descriptive columns selected
        output$download_section_ui <- shiny::renderUI({
            if (!has_descriptive_selection()) return(NULL)
            
            shiny::tagList(
                shiny::tags$hr(),
                shiny::downloadButton(
                    outputId = ns("downloadData"),
                    label = "Download Filtered Data",
                    class = "btn-primary btn-sm w-100"
                )
            )
        })
        
        # Placeholder for plots output
        output$plots <- shiny::renderUI({
            if (!has_descriptive_selection()) {
                return(bslib::card(
                    bslib::card_header("Plots"),
                    bslib::card_body(
                        shiny::tags$p(
                            class = "text-muted",
                            "Select descriptive columns in the sidebar to begin configuring your plots."
                        )
                    )
                ))
            }
            
            bslib::card(
                bslib::card_header("Plots"),
                bslib::card_body(
                    shiny::p("Plot output will appear here once server logic is implemented.")
                )
            )
        })
    })
}
