box::use(
  bsicons,
  bslib,
  shiny,
)

box::use(
  app/view/components/sidebar_tabs,
)

#' @export
tab_ui <- function(ns) {
  sidebar_tabs$create_tab(
    icon = "sliders",
    tooltip_text = "Settings",
    value = "options_tab",
    shiny$h6(class = "text-muted mb-3", "Analysis Settings"),
    # Solve for selector
    shiny$radioButtons(
      inputId = ns("solve_for"),
      label = "Solve for:",
      choices = list(
        "Sample Size" = "sample_size",
        "Power" = "power",
        "Minimum Detectable Effect" = "mde"
      ),
      selected = "sample_size"
    ),
    shiny$tags$hr(),
    # Alpha level
    shiny$numericInput(
      inputId = ns("alpha"),
      label = shiny$tags$span(
        "Significance Level (\u03b1) ",
        bslib$tooltip(
          bsicons$bs_icon("info-circle", class = "text-muted"),
          "Type I error rate. Common values: 0.05, 0.01"
        )
      ),
      value = 0.05,
      min = 0.001,
      max = 0.5,
      step = 0.01
    ),
    # Power target (conditional)
    shiny$conditionalPanel(
      condition = "input.solve_for != 'power'",
      ns = ns,
      shiny$numericInput(
        inputId = ns("power_target"),
        label = shiny$tags$span(
          "Target Power (1-\u03b2) ",
          bslib$tooltip(
            bsicons$bs_icon("info-circle", class = "text-muted"),
            "Probability of detecting a true effect. Common: 0.80, 0.90"
          )
        ),
        value = 0.80,
        min = 0.5,
        max = 0.99,
        step = 0.05
      )
    ),
    # N per group (conditional)
    shiny$conditionalPanel(
      condition = "input.solve_for != 'sample_size'",
      ns = ns,
      shiny$numericInput(
        inputId = ns("n_per_group"),
        label = shiny$tags$span(
          "Sample Size per Group ",
          bslib$tooltip(
            bsicons$bs_icon("info-circle", class = "text-muted"),
            "Number of observations in each group/cell."
          )
        ),
        value = 20,
        min = 2,
        step = 1
      )
    ),
    shiny$tags$hr(),
    # Statistical approach
    shiny$radioButtons(
      inputId = ns("approach"),
      label = "Statistical Approach:",
      choices = list(
        "Parametric (ANOVA)" = "parametric",
        "Robust (Trimmed Means)" = "robust",
        "Non-Parametric (Kruskal-Wallis)" = "nonparametric"
      ),
      selected = "parametric"
    ),
    # Simulation settings (conditional)
    shiny$conditionalPanel(
      condition = "input.approach != 'parametric'",
      ns = ns,
      shiny$tags$div(
        class = "mt-2 p-2 border rounded bg-light",
        shiny$tags$small(
          class = "text-muted d-block mb-2",
          bsicons$bs_icon("cpu", class = "me-1"),
          "Simulation-based power estimation"
        ),
        shiny$numericInput(
          inputId = ns("n_sim"),
          label = "Simulation Iterations:",
          value = 1000,
          min = 100,
          max = 10000,
          step = 100
        ),
        shiny$tags$small(
          class = "text-muted",
          "More iterations = more accurate but slower."
        )
      )
    )
  )
}

#' @export
tab_server <- function(input, output, session) {
  # Return reactive with current options
  shiny$reactive({
    list(
      solve_for = input$solve_for %||% "sample_size",
      alpha = input$alpha %||% 0.05,
      power_target = input$power_target %||% 0.80,
      n_per_group = input$n_per_group %||% 20,
      approach = input$approach %||% "parametric",
      n_sim = input$n_sim %||% 1000
    )
  })
}
