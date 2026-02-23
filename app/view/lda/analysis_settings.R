box::use(
  bsicons,
  bslib,
  rhino,
  shiny,
)

box::use(
  app/view/components/sidebar_tabs,
)

#' @export
tab_ui <- function(ns) {
  sidebar_tabs$create_tab(
    icon = "gear",
    tooltip_text = "Analysis Settings",
    value = "settings_tab",
    shiny$h6(
      class = "text-muted mb-3",
      "Analysis Settings"
    ),
    # Analysis type: LDA vs QDA
    shiny$radioButtons(
      inputId = ns("analysis_type"),
      label = shiny$tags$span(
        "Analysis Type ",
        bslib$tooltip(
          bsicons$bs_icon(
            "info-circle", class = "text-muted"
          ),
          paste(
            "LDA assumes equal covariance matrices",
            "across groups. QDA allows each group",
            "to have its own covariance matrix.",
            "MDA models each group as a mixture",
            "of Gaussians for flexible boundaries.",
            "QDA/MDA require more observations."
          )
        )
      ),
      choices = list(
        "LDA (Linear)" = "lda",
        "QDA (Quadratic)" = "qda",
        "MDA (Mixture)" = "mda"
      ),
      selected = "lda"
    ),
    shiny$tags$hr(),
    # Estimation method (LDA only)
    shiny$conditionalPanel(
      condition = paste0(
        "input['", ns("analysis_type"),
        "'] == 'lda'"
      ),
      shiny$selectInput(
        inputId = ns("method"),
        label = shiny$tags$span(
          "Estimation Method ",
          bslib$tooltip(
            bsicons$bs_icon(
              "info-circle", class = "text-muted"
            ),
            paste(
              "'moment': standard estimators of",
              "mean and variance.",
              "'mle': maximum likelihood estimators.",
              "'mve': minimum volume ellipsoid",
              "(robust).",
              "'t': robust estimates based on a",
              "t-distribution."
            )
          )
        ),
        choices = list(
          "Moment (standard)" = "moment",
          "MLE" = "mle",
          "MVE (robust)" = "mve",
          "t-distribution (robust)" = "t"
        ),
        selected = "moment"
      )
    ),
    # QDA method (QDA only — subset of LDA methods)
    shiny$conditionalPanel(
      condition = paste0(
        "input['", ns("analysis_type"),
        "'] == 'qda'"
      ),
      shiny$selectInput(
        inputId = ns("qda_method"),
        label = shiny$tags$span(
          "Estimation Method ",
          bslib$tooltip(
            bsicons$bs_icon(
              "info-circle", class = "text-muted"
            ),
            paste(
              "'moment': standard estimators of",
              "mean and variance.",
              "'mle': maximum likelihood estimators.",
              "'mve': minimum volume ellipsoid",
              "(robust).",
              "'t': robust estimates based on a",
              "t-distribution."
            )
          )
        ),
        choices = list(
          "Moment (standard)" = "moment",
          "MLE" = "mle",
          "MVE (robust)" = "mve",
          "t-distribution (robust)" = "t"
        ),
        selected = "moment"
      )
    ),
    # MDA settings (MDA only)
    shiny$conditionalPanel(
      condition = paste0(
        "input['", ns("analysis_type"),
        "'] == 'mda'"
      ),
      shiny$numericInput(
        inputId = ns("mda_subclasses"),
        label = shiny$tags$span(
          "Subclasses per group ",
          bslib$tooltip(
            bsicons$bs_icon(
              "info-circle", class = "text-muted"
            ),
            paste(
              "Number of Gaussian subclasses per",
              "group. More subclasses allow more",
              "flexible within-group distributions",
              "but require more observations."
            )
          )
        ),
        value = 3,
        min = 1,
        max = 20,
        step = 1
      ),
      shiny$numericInput(
        inputId = ns("mda_iter"),
        label = shiny$tags$span(
          "Max EM iterations ",
          bslib$tooltip(
            bsicons$bs_icon(
              "info-circle", class = "text-muted"
            ),
            paste(
              "Maximum number of EM algorithm",
              "iterations. Increase if the model",
              "has not converged."
            )
          )
        ),
        value = 5,
        min = 1,
        max = 100,
        step = 1
      )
    ),
    # Prior probabilities
    shiny$radioButtons(
      inputId = ns("prior"),
      label = shiny$tags$span(
        "Prior Probabilities ",
        bslib$tooltip(
          bsicons$bs_icon(
            "info-circle", class = "text-muted"
          ),
          paste(
            "Proportional: uses class proportions",
            "from the training set.",
            "Equal: assigns equal probability to",
            "each group."
          )
        )
      ),
      choices = list(
        "Proportional (default)" = "proportional",
        "Equal" = "equal"
      ),
      selected = "proportional"
    ),
    # Validation method
    shiny$radioButtons(
      inputId = ns("validation_method"),
      label = shiny$tags$span(
        "Validation ",
        bslib$tooltip(
          bsicons$bs_icon(
            "info-circle", class = "text-muted"
          ),
          paste(
            "None: fit model on all data",
            "(resubstitution accuracy only).",
            "LOO-CV: leave-one-out",
            "cross-validation — each observation",
            "is predicted using a model trained",
            "on all other observations.",
            "Train/Test Split: stratified random",
            "split for predictive evaluation."
          )
        )
      ),
      choices = list(
        "None (fit only)" = "none",
        "Leave-one-out CV" = "loo_cv",
        "Train / Test Split" = "split"
      ),
      selected = "none"
    ),
    # Train/test split settings
    shiny$conditionalPanel(
      condition = paste0(
        "input['", ns("validation_method"),
        "'] == 'split'"
      ),
      shiny$tags$div(
        class = "ms-2 ps-2 border-start",
        shiny$sliderInput(
          inputId = ns("train_fraction"),
          label = shiny$tags$span(
            "Training set size ",
            bslib$tooltip(
              bsicons$bs_icon(
                "info-circle",
                class = "text-muted"
              ),
              paste(
                "Fraction of data used for training.",
                "The rest is held out for testing.",
                "Split is stratified by the grouping",
                "variable to preserve class proportions."
              )
            )
          ),
          min = 0.5,
          max = 0.9,
          value = 0.7,
          step = 0.05,
          post = ""
        ),
        shiny$numericInput(
          inputId = ns("split_seed"),
          label = shiny$tags$span(
            "Random seed ",
            bslib$tooltip(
              bsicons$bs_icon(
                "info-circle",
                class = "text-muted"
              ),
              paste(
                "Set a seed for reproducible splits.",
                "Use the same seed to get the same",
                "train/test partition each time."
              )
            )
          ),
          value = 42,
          min = 1,
          step = 1
        )
      )
    ),
    shiny$tags$hr(),
    # Advanced settings (collapsed)
    bslib$accordion(
      id = ns("advanced_accordion"),
      open = FALSE,
      bslib$accordion_panel(
        title = shiny$tags$small(
          class = "text-muted",
          "Advanced settings"
        ),
        value = "advanced_settings",
        # Tolerance
        shiny$numericInput(
          inputId = ns("tol"),
          label = shiny$tags$span(
            "Tolerance ",
            bslib$tooltip(
              bsicons$bs_icon(
                "info-circle",
                class = "text-muted"
              ),
              paste(
                "Tolerance for singularity detection.",
                "Variables whose variance is less",
                "than tol^2 will be rejected."
              )
            )
          ),
          value = 1.0e-4,
          min = 0,
          max = 1,
          step = 1.0e-5
        ),
        # Nu (degrees of freedom, only for method = "t")
        shiny$conditionalPanel(
          condition = paste0(
            "(input['", ns("analysis_type"),
            "'] == 'lda' && input['",
            ns("method"), "'] == 't') || ",
            "(input['", ns("analysis_type"),
            "'] == 'qda' && input['",
            ns("qda_method"), "'] == 't')"
          ),
          shiny$numericInput(
            inputId = ns("nu"),
            label = shiny$tags$span(
              "Nu (degrees of freedom) ",
              bslib$tooltip(
                bsicons$bs_icon(
                  "info-circle",
                  class = "text-muted"
                ),
                paste(
                  "Degrees of freedom for the",
                  "t-distribution method.",
                  "Lower values give more robust",
                  "estimates. Typical range: 3-10."
                )
              )
            ),
            value = 5,
            min = 1,
            max = 100,
            step = 1
          )
        )
      )
    )
  )
}

#' Server logic for the LDA analysis settings sidebar tab
#'
#' Handles analysis type and parameter settings.
#' Resets to defaults when new data is loaded.
#'
#' @param input Shiny input object from parent module
#' @param output Shiny output object from parent module
#' @param session Shiny session object from parent module
#' @param data_version Reactive returning the data version counter
#' @export
tab_server <- function(input, output, session,
                       data_version) {
  shiny$observeEvent(data_version(), {
    rhino$log$info(
      "LDA analysis_settings: reset for new data"
    )
    shiny$updateRadioButtons(
      session, "analysis_type", selected = "lda"
    )
    shiny$updateSelectInput(
      session, "method", selected = "moment"
    )
    shiny$updateSelectInput(
      session, "qda_method", selected = "moment"
    )
    shiny$updateRadioButtons(
      session, "prior", selected = "proportional"
    )
    shiny$updateRadioButtons(
      session, "validation_method", selected = "none"
    )
    shiny$updateSliderInput(
      session, "train_fraction", value = 0.7
    )
    shiny$updateNumericInput(
      session, "split_seed", value = 42
    )
    shiny$updateNumericInput(
      session, "tol", value = 1.0e-4
    )
    shiny$updateNumericInput(
      session, "nu", value = 5
    )
    shiny$updateNumericInput(
      session, "mda_subclasses", value = 3
    )
    shiny$updateNumericInput(
      session, "mda_iter", value = 5
    )
  }, ignoreInit = TRUE)
}
