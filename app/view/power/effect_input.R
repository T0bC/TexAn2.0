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
    icon = "rulers",
    tooltip_text = "Effect Size",
    value = "effect_tab",
    shiny$h6(class = "text-muted mb-3", "Effect Size Input"),
    # Effect type toggle
    shiny$radioButtons(
      inputId = ns("effect_type"),
      label = "Input Method:",
      choices = list(
        "Standardized (Cohen's d/f)" = "standardized",
        "Raw (Group Means + SD)" = "raw"
      ),
      selected = "standardized"
    ),
    shiny$tags$hr(),
    # Conditional panels for each input type
    shiny$conditionalPanel(
      condition = "input.effect_type == 'standardized'",
      ns = ns,
      shiny$uiOutput(ns("standardized_inputs"))
    ),
    shiny$conditionalPanel(
      condition = "input.effect_type == 'raw'",
      ns = ns,
      shiny$uiOutput(ns("raw_inputs"))
    ),
    shiny$tags$hr(),
    # Distribution selector
    shiny$selectInput(
      inputId = ns("distribution"),
      label = shiny$tags$span(
        "Distribution ",
        bslib$tooltip(
          bsicons$bs_icon("info-circle", class = "text-muted"),
          paste(
            "Assumed distribution for simulated data.",
            "Normal is standard for parametric tests."
          )
        )
      ),
      choices = list(
        "Normal" = "normal",
        "Log-normal" = "lognormal",
        "Exponential" = "exponential"
      ),
      selected = "normal"
    )
  )
}

#' @export
tab_server <- function(input, output, session, design_reactive = NULL) {
  ns <- session$ns

  # --- Standardized effect size inputs ---
  output$standardized_inputs <- shiny$renderUI({
    design <- if (!is.null(design_reactive)) design_reactive() else NULL
    n_ways <- design$n_ways %||% 1

    if (n_ways == 1) {
      # 1-way: Cohen's f
      shiny$tags$div(
        shiny$numericInput(
          inputId = ns("cohens_f"),
          label = shiny$tags$span(
            "Cohen's f ",
            bslib$tooltip(
              bsicons$bs_icon("info-circle", class = "text-muted"),
              paste(
                "Effect size for ANOVA.",
                "Small: 0.10, Medium: 0.25, Large: 0.40"
              )
            )
          ),
          value = 0.25,
          min = 0.01,
          max = 2,
          step = 0.05
        ),
        shiny$tags$div(
          class = "small text-muted",
          "Benchmarks: Small=0.10, Medium=0.25, Large=0.40"
        )
      )
    } else {
      # Multi-way: effect sizes per term
      factors <- design$factors
      terms <- generate_effect_terms(factors)

      term_inputs <- lapply(seq_along(terms), function(i) {
        term <- terms[i]
        shiny$numericInput(
          inputId = ns(paste0("effect_", i)),
          label = paste0("f for ", term, ":"),
          value = 0.25,
          min = 0.01,
          max = 2,
          step = 0.05
        )
      })

      shiny$tags$div(
        shiny$tags$p(
          class = "small text-muted mb-2",
          "Enter effect size (Cohen's f) for each term:"
        ),
        shiny$tagList(term_inputs)
      )
    }
  })

  # --- Raw effect size inputs (group means + SD) ---
  output$raw_inputs <- shiny$renderUI({
    design <- if (!is.null(design_reactive)) design_reactive() else NULL

    if (is.null(design) || is.null(design$factors) ||
        length(design$factors) == 0) {
      return(shiny$tags$div(
        class = "text-muted small",
        "Define factors and levels in the Design tab first."
      ))
    }

    # Generate all group combinations
    groups <- generate_group_combinations(design$factors)

    group_inputs <- lapply(seq_along(groups), function(i) {
      group_name <- groups[i]
      shiny$tags$div(
        class = "mb-2 p-2 border rounded",
        shiny$tags$strong(class = "small", group_name),
        shiny$fluidRow(
          shiny$column(
            6,
            shiny$numericInput(
              inputId = ns(paste0("mean_", i)),
              label = "Mean:",
              value = i,
              step = 0.1
            )
          ),
          shiny$column(
            6,
            shiny$numericInput(
              inputId = ns(paste0("sd_", i)),
              label = "SD:",
              value = 1,
              min = 0.01,
              step = 0.1
            )
          )
        )
      )
    })

    shiny$tags$div(
      shiny$tags$p(
        class = "small text-muted mb-2",
        "Enter expected mean and SD for each group:"
      ),
      shiny$tagList(group_inputs)
    )
  })

  # --- Return reactive with current effect parameters ---
  effect_params <- shiny$reactive({
    effect_type <- input$effect_type %||% "standardized"
    design <- if (!is.null(design_reactive)) design_reactive() else NULL

    if (effect_type == "standardized") {
      n_ways <- design$n_ways %||% 1

      if (n_ways == 1) {
        list(
          effect_type = "standardized",
          effect_size = input$cohens_f %||% 0.25,
          distribution = input$distribution %||% "normal"
        )
      } else {
        # Collect all effect terms
        factors <- design$factors
        terms <- generate_effect_terms(factors)
        effects <- sapply(seq_along(terms), function(i) {
          input[[paste0("effect_", i)]] %||% 0.25
        })
        names(effects) <- terms

        list(
          effect_type = "standardized",
          effect_size = max(effects),
          effect_terms = effects,
          distribution = input$distribution %||% "normal"
        )
      }
    } else {
      # Raw mode: collect group means and SDs
      groups <- generate_group_combinations(design$factors)
      n_groups <- length(groups)

      means <- sapply(seq_len(n_groups), function(i) {
        input[[paste0("mean_", i)]] %||% i
      })
      sds <- sapply(seq_len(n_groups), function(i) {
        input[[paste0("sd_", i)]] %||% 1
      })

      names(means) <- groups

      list(
        effect_type = "raw",
        group_means = means,
        group_sd = sds,
        distribution = input$distribution %||% "normal"
      )
    }
  })

  effect_params
}

# --- Helper: generate effect terms for factorial designs ---
generate_effect_terms <- function(factors) {
  if (is.null(factors) || length(factors) == 0) return(character(0))

  factor_names <- sapply(factors, function(f) f$name)
  n <- length(factor_names)

  terms <- factor_names

  if (n >= 2) {
    for (i in 1:(n - 1)) {
      for (j in (i + 1):n) {
        terms <- c(terms, paste(factor_names[i], factor_names[j], sep = " x "))
      }
    }
  }

  if (n == 3) {
    terms <- c(terms, paste(factor_names, collapse = " x "))
  }

  terms
}

# --- Helper: generate all group combinations ---
generate_group_combinations <- function(factors) {
  if (is.null(factors) || length(factors) == 0) return(character(0))

  if (length(factors) == 1) {
    return(factors[[1]]$levels)
  }

  level_lists <- lapply(factors, function(f) f$levels)
  grid <- expand.grid(level_lists, stringsAsFactors = FALSE)
  apply(grid, 1, paste, collapse = "_")
}
