box::use(
  testthat[describe, expect_equal, expect_true, expect_false, expect_null, it],
)

box::use(
  app/logic/shared/error_handling,
  app/logic/power/validate,
)

# =============================================================================
# Helper: create minimal valid params
# =============================================================================

make_valid_params <- function() {
  list(
    solve_for = "sample_size",
    alpha = 0.05,
    power_target = 0.80,
    n_per_group = 20,
    effect_type = "standardized",
    effect_size = 0.25,
    group_means = NULL,
    group_sd = NULL,
    n_groups = 3
  )
}

# =============================================================================
# validate_power_inputs — happy path
# =============================================================================

describe("validate_power_inputs", {
  it("passes for a fully valid params list", {
    params <- make_valid_params()
    result <- validate$validate_power_inputs(params)

    expect_null(result)
  })

  it("returns error when alpha is outside (0,1) - too high", {
    params <- make_valid_params()
    params$alpha <- 1.0
    result <- validate$validate_power_inputs(params)

    expect_true(error_handling$is_app_error(result))
  })

  it("returns error when alpha is outside (0,1) - too low", {
    params <- make_valid_params()
    params$alpha <- 0
    result <- validate$validate_power_inputs(params)

    expect_true(error_handling$is_app_error(result))
  })

  it("returns error when alpha is negative", {
    params <- make_valid_params()
    params$alpha <- -0.05
    result <- validate$validate_power_inputs(params)

    expect_true(error_handling$is_app_error(result))
  })

  it("returns error when target power is outside (0,1) - too high", {
    params <- make_valid_params()
    params$power_target <- 1.0
    result <- validate$validate_power_inputs(params)

    expect_true(error_handling$is_app_error(result))
  })

  it("returns error when target power is outside (0,1) - too low", {
    params <- make_valid_params()
    params$power_target <- 0
    result <- validate$validate_power_inputs(params)

    expect_true(error_handling$is_app_error(result))
  })

  it("returns error when N < 2 in solve-for-power mode", {
    params <- make_valid_params()
    params$solve_for <- "power"
    params$n_per_group <- 1
    result <- validate$validate_power_inputs(params)

    expect_true(error_handling$is_app_error(result))
  })

  it("returns error when N < 2 in solve-for-mde mode", {
    params <- make_valid_params()
    params$solve_for <- "mde"
    params$n_per_group <- 1
    result <- validate$validate_power_inputs(params)

    expect_true(error_handling$is_app_error(result))
  })

  it("does not require N for sample_size mode", {
    params <- make_valid_params()
    params$solve_for <- "sample_size"
    params$n_per_group <- NULL
    result <- validate$validate_power_inputs(params)

    expect_null(result)
  })

  it("returns error when effect size is missing in standardized mode", {
    params <- make_valid_params()
    params$effect_size <- NULL
    result <- validate$validate_power_inputs(params)

    expect_true(error_handling$is_app_error(result))
  })

  it("returns error when effect size is zero in standardized mode", {
    params <- make_valid_params()
    params$effect_size <- 0
    result <- validate$validate_power_inputs(params)

    expect_true(error_handling$is_app_error(result))
  })

  it("returns error when effect size is negative in standardized mode", {
    params <- make_valid_params()
    params$effect_size <- -0.25
    result <- validate$validate_power_inputs(params)

    expect_true(error_handling$is_app_error(result))
  })

  it("returns error when fewer than 2 groups are defined", {
    params <- make_valid_params()
    params$n_groups <- 1
    result <- validate$validate_power_inputs(params)

    expect_true(error_handling$is_app_error(result))
  })

  it("returns error when n_groups is NULL", {
    params <- make_valid_params()
    params$n_groups <- NULL
    result <- validate$validate_power_inputs(params)

    expect_true(error_handling$is_app_error(result))
  })

  it("returns error when SD <= 0 in raw-input mode", {
    params <- make_valid_params()
    params$effect_type <- "raw"
    params$group_means <- c(1, 2, 3)
    params$group_sd <- 0
    result <- validate$validate_power_inputs(params)

    expect_true(error_handling$is_app_error(result))
  })

  it("returns error when SD is negative in raw-input mode", {
    params <- make_valid_params()
    params$effect_type <- "raw"
    params$group_means <- c(1, 2, 3)
    params$group_sd <- -1
    result <- validate$validate_power_inputs(params)

    expect_true(error_handling$is_app_error(result))
  })

  it("returns error when group_means missing in raw-input mode", {
    params <- make_valid_params()
    params$effect_type <- "raw"
    params$group_means <- NULL
    params$group_sd <- 1
    result <- validate$validate_power_inputs(params)

    expect_true(error_handling$is_app_error(result))
  })

  it("returns error when fewer than 2 group_means in raw-input mode", {
    params <- make_valid_params()
    params$effect_type <- "raw"
    params$group_means <- c(1)
    params$group_sd <- 1
    result <- validate$validate_power_inputs(params)

    expect_true(error_handling$is_app_error(result))
  })

  it("passes for valid raw-input mode params", {
    params <- make_valid_params()
    params$effect_type <- "raw"
    params$group_means <- c(1, 2, 3)
    params$group_sd <- 1
    result <- validate$validate_power_inputs(params)

    expect_null(result)
  })
})

# =============================================================================
# validate_design_structure
# =============================================================================

describe("validate_design_structure", {
  it("passes for valid single-factor design", {
    factors <- list(
      list(name = "Material", levels = c("A", "B", "C"))
    )
    result <- validate$validate_design_structure(factors)

    expect_null(result)
  })

  it("passes for valid 2-way design", {
    factors <- list(
      list(name = "Material", levels = c("A", "B")),
      list(name = "Treatment", levels = c("X", "Y"))
    )
    result <- validate$validate_design_structure(factors)

    expect_null(result)
  })

  it("passes for valid 3-way design", {
    factors <- list(
      list(name = "Material", levels = c("A", "B")),
      list(name = "Treatment", levels = c("X", "Y")),
      list(name = "Condition", levels = c("1", "2"))
    )
    result <- validate$validate_design_structure(factors)

    expect_null(result)
  })

  it("returns error for empty factors list", {
    result <- validate$validate_design_structure(list())

    expect_true(error_handling$is_app_error(result))
  })

  it("returns error for NULL factors", {
    result <- validate$validate_design_structure(NULL)

    expect_true(error_handling$is_app_error(result))
  })

  it("returns error for more than 3 factors", {
    factors <- list(
      list(name = "A", levels = c("1", "2")),
      list(name = "B", levels = c("1", "2")),
      list(name = "C", levels = c("1", "2")),
      list(name = "D", levels = c("1", "2"))
    )
    result <- validate$validate_design_structure(factors)

    expect_true(error_handling$is_app_error(result))
  })

  it("returns error for factor with empty name", {
    factors <- list(
      list(name = "", levels = c("A", "B"))
    )
    result <- validate$validate_design_structure(factors)

    expect_true(error_handling$is_app_error(result))
  })

  it("returns error for factor with NULL name", {
    factors <- list(
      list(name = NULL, levels = c("A", "B"))
    )
    result <- validate$validate_design_structure(factors)

    expect_true(error_handling$is_app_error(result))
  })

  it("returns error for factor with fewer than 2 levels", {
    factors <- list(
      list(name = "Material", levels = c("A"))
    )
    result <- validate$validate_design_structure(factors)

    expect_true(error_handling$is_app_error(result))
  })

  it("returns error for factor with NULL levels", {
    factors <- list(
      list(name = "Material", levels = NULL)
    )
    result <- validate$validate_design_structure(factors)

    expect_true(error_handling$is_app_error(result))
  })
})
