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
    # Distribution selector (moved up for logical flow)
    shiny$selectInput(
      inputId = ns("distribution"),
      label = shiny$tags$span(
        "Distribution Shape ",
        bslib$tooltip(
          bsicons$bs_icon("info-circle", class = "text-muted"),
          paste(
            "Assumed distribution for power simulation.",
            "Non-normal distributions use Monte Carlo simulation."
          )
        )
      ),
      choices = list(
        "Normal" = "normal",
        "Log-normal" = "lognormal",
        "Exponential" = "exponential"
      ),
      selected = "normal"
    ),
    shiny$tags$hr(),
    # Effect type toggle (dynamic based on distribution)
    shiny$uiOutput(ns("effect_type_ui")),
    shiny$tags$hr(),
    # Input mode toggle (server-side rendered based on effective effect_type)
    shiny$uiOutput(ns("input_mode_ui")),
    # Effect inputs (server-side rendered based on effective effect_type)
    shiny$uiOutput(ns("effect_inputs_ui"))
  )
}

#' @export
tab_server <- function(input, output, session, design_reactive = NULL) {
  ns <- session$ns

  # --- Effect type selector (dynamic based on distribution) ---
  output$effect_type_ui <- shiny$renderUI({
    distribution <- input$distribution %||% "normal"

    if (distribution != "normal") {
      # Non-normal: force raw mode with explanation
      shiny$tags$div(
        shiny$tags$div(
          class = "alert alert-info py-2 small",
          bsicons$bs_icon("info-circle", class = "me-1"),
          paste0(
            "Standardized effect sizes (Cohen's f) are only valid for normal distributions. ",
            "Using raw distribution parameters for ", distribution, " data."
          )
        ),
        shiny$tags$strong(class = "small text-muted", "Input Method: Raw Parameters")
      )
    } else {
      shiny$radioButtons(
        inputId = ns("effect_type"),
        label = "Input Method:",
        choices = list(
          "Standardized (Cohen's f)" = "standardized",
          "Raw (Group Parameters)" = "raw"
        ),
        selected = input$effect_type %||% "standardized"
      )
    }
  })

  # --- Compute effective effect_type (for server-side UI decisions) ---
  effective_effect_type <- shiny$reactive({
    distribution <- input$distribution %||% "normal"
    if (distribution != "normal") {
      "raw"
    } else {
      input$effect_type %||% "standardized"
    }
  })

  # --- Input mode toggle (server-side rendered) ---
  output$input_mode_ui <- shiny$renderUI({
    effect_type <- effective_effect_type()

    if (effect_type == "raw") {
      shiny$tagList(
        shiny$radioButtons(
          inputId = ns("input_mode"),
          label = shiny$tags$span(
            "Input Statistics ",
            bslib$tooltip(
              bsicons$bs_icon("info-circle", class = "text-muted"),
              "Choose how to specify group parameters based on available data."
            )
          ),
          choices = list(
            "Mean + SD" = "mean_sd",
            "Median + IQR" = "median_iqr"
          ),
          selected = input$input_mode %||% "mean_sd",
          inline = TRUE
        ),
        shiny$tags$hr()
      )
    } else {
      NULL
    }
  })

  # --- Effect inputs (server-side rendered based on effective effect_type) ---
  output$effect_inputs_ui <- shiny$renderUI({
    effect_type <- effective_effect_type()

    if (effect_type == "standardized") {
      shiny$uiOutput(ns("standardized_inputs"))
    } else {
      shiny$uiOutput(ns("raw_inputs"))
    }
  })

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

  # --- Raw effect size inputs (group means + SD or median + IQR) ---
  output$raw_inputs <- shiny$renderUI({
    design <- if (!is.null(design_reactive)) design_reactive() else NULL
    input_mode <- input$input_mode %||% "mean_sd"
    distribution <- input$distribution %||% "normal"

    if (is.null(design) || is.null(design$factors) ||
        length(design$factors) == 0) {
      return(shiny$tags$div(
        class = "text-muted small",
        "Define factors and levels in the Design tab first."
      ))
    }

    # Generate all group combinations
    groups <- generate_group_combinations(design$factors)

    # Determine labels based on input mode and distribution
    if (input_mode == "mean_sd") {
      loc_label <- "Mean:"
      spread_label <- if (distribution == "exponential") {
        NULL
      } else {
        "SD:"
      }
      loc_default <- function(i) i
      spread_default <- 1
      loc_min <- if (distribution %in% c("lognormal", "exponential")) 0.01 else NA_real_
    } else {
      loc_label <- "Median:"
      spread_label <- "IQR:"
      loc_default <- function(i) i
      spread_default <- 1
      loc_min <- if (distribution %in% c("lognormal", "exponential")) 0.01 else NA_real_
    }

    group_inputs <- lapply(seq_along(groups), function(i) {
      group_name <- groups[i]

      # Build input fields
      loc_input <- shiny$numericInput(
        inputId = ns(paste0("loc_", i)),
        label = loc_label,
        value = loc_default(i),
        min = loc_min,
        step = 0.1
      )

      if (!is.null(spread_label)) {
        spread_input <- shiny$numericInput(
          inputId = ns(paste0("spread_", i)),
          label = spread_label,
          value = spread_default,
          min = 0.01,
          step = 0.1
        )
        row_content <- shiny$fluidRow(
          shiny$column(6, loc_input),
          shiny$column(6, spread_input)
        )
      } else {
        # Exponential with mean_sd: only mean needed
        row_content <- loc_input
      }

      shiny$tags$div(
        class = "mb-2 p-2 border rounded",
        shiny$tags$strong(class = "small", group_name),
        row_content
      )
    })

    # Build description text
    desc_text <- if (input_mode == "mean_sd") {
      if (distribution == "exponential") {
        "Enter expected mean for each group (SD = mean for exponential):"
      } else {
        "Enter expected mean and SD for each group:"
      }
    } else {
      "Enter expected median and IQR for each group:"
    }

    shiny$tags$div(
      shiny$tags$p(class = "small text-muted mb-2", desc_text),
      shiny$tagList(group_inputs)
    )
  })

  # --- Return reactive with current effect parameters ---
  effect_params <- shiny$reactive({
    distribution <- input$distribution %||% "normal"
    # Force raw mode for non-normal distributions
    effect_type <- if (distribution != "normal") {
      "raw"
    } else {
      input$effect_type %||% "standardized"
    }
    input_mode <- input$input_mode %||% "mean_sd"
    design <- if (!is.null(design_reactive)) design_reactive() else NULL

    if (effect_type == "standardized") {
      n_ways <- design$n_ways %||% 1

      if (n_ways == 1) {
        list(
          effect_type = "standardized",
          effect_size = input$cohens_f %||% 0.25,
          distribution = distribution,
          input_mode = "mean_sd"
        )
      } else {
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
          distribution = distribution,
          input_mode = "mean_sd"
        )
      }
    } else {
      # Raw mode: collect group parameters based on input_mode
      # Guard against NULL design
      if (is.null(design) || is.null(design$factors) ||
          length(design$factors) == 0) {
        return(list(
          effect_type = "raw",
          input_mode = input_mode,
          group_means = c(1, 2),
          group_sd = c(1, 1),
          distribution = distribution
        ))
      }

      groups <- generate_group_combinations(design$factors)
      n_groups <- length(groups)

      if (input_mode == "mean_sd") {
        means <- sapply(seq_len(n_groups), function(i) {
          input[[paste0("loc_", i)]] %||% i
        })
        sds <- if (distribution == "exponential") {
          # For exponential, SD = mean
          means
        } else {
          sapply(seq_len(n_groups), function(i) {
            input[[paste0("spread_", i)]] %||% 1
          })
        }
        names(means) <- groups

        list(
          effect_type = "raw",
          input_mode = "mean_sd",
          group_means = means,
          group_sd = sds,
          distribution = distribution
        )
      } else {
        # median_iqr mode
        medians <- sapply(seq_len(n_groups), function(i) {
          input[[paste0("loc_", i)]] %||% i
        })
        iqrs <- sapply(seq_len(n_groups), function(i) {
          input[[paste0("spread_", i)]] %||% 1
        })
        names(medians) <- groups

        list(
          effect_type = "raw",
          input_mode = "median_iqr",
          group_medians = medians,
          group_iqr = iqrs,
          distribution = distribution
        )
      }
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

# Internal separator for multi-way group names (must match dummy_data.R)
GROUP_SEP <- ":::"

# --- Helper: generate all group combinations ---
generate_group_combinations <- function(factors) {
  if (is.null(factors) || length(factors) == 0) return(character(0))

  if (length(factors) == 1) {
    return(factors[[1]]$levels)
  }

  level_lists <- lapply(factors, function(f) f$levels)
  grid <- expand.grid(level_lists, stringsAsFactors = FALSE)
  apply(grid, 1, paste, collapse = GROUP_SEP)
}
