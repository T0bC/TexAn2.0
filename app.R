# Source UI modules
source("R/ui/modules/pages/ui_load_data.R")
source("R/ui/modules/pages/ui_median.R")

# Source server modules
source("R/server/modules/pages/server_load_data.R")
source("R/server/modules/pages/server_median.R")

# Load required packages
library(shiny)
library(shinyBS)
library(openxlsx)
library(DT)
library(DataExplorer)
library(summarytools)

app_ui <- shiny::fluidPage(
  shiny::titlePanel("TexAn 2.0"),
  shiny::tabsetPanel(
    shiny::tabPanel("Load Data", UI_load_data("load_data_id")),
    shiny::tabPanel("Median Analysis", UI_median("median_id")),
    shiny::tabPanel("Plotting", "TODO: Add plotting UI."),
    shiny::tabPanel("Reporting", "TODO: Add reporting UI.")
  )
)

app_server <- function(input, output, session) {
  # Register module servers
  loaded_data <- server_load_data("load_data_id")
  server_median("median_id", loaded_data = loaded_data)

  # TODO: Register additional module servers.
}

shiny::shinyApp(ui = app_ui, server = app_server)
