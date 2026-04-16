box::use(
  testthat[describe, expect_equal, expect_true, expect_false, it],
)

box::use(
  app/logic/shared/error_handling,
  app/logic/power/dummy_data,
)

# =============================================================================
# Helper: create minimal valid group params
# =============================================================================

make_group_params <- function() {
  list(
    group_means = c(G1 = 1, G2 = 2, G3 = 3),
    group_sd = 1,
    n_per_group = 20,
    distribution = "normal"
  )
}

# =============================================================================
# simulate_group_data — happy path
# =============================================================================

describe("simulate_group_data", {
  it("returns a data frame with correct column names and row count", {
    params <- make_group_params()
    df <- dummy_data$simulate_group_data(
      group_means = params$group_means,
      group_sd = params$group_sd,
      n_per_group = params$n_per_group,
      distribution = params$distribution,
      seed = 42
    )

    expect_true(is.data.frame(df))
    expect_equal(nrow(df), 3 * 20)
    expect_true("group" %in% names(df) || any(grepl("G", names(df))))
    expect_true("measure" %in% names(df))
  })

  it("log-normal distribution produces all-positive values", {
    params <- make_group_params()
    params$group_means <- c(G1 = 5, G2 = 10, G3 = 15)
    df <- dummy_data$simulate_group_data(
      group_means = params$group_means,
      group_sd = 2,
      n_per_group = 50,
      distribution = "lognormal",
      seed = 42
    )

    expect_true(all(df$measure > 0))
  })

  it("exponential distribution produces all-positive values", {
    params <- make_group_params()
    params$group_means <- c(G1 = 5, G2 = 10, G3 = 15)
    df <- dummy_data$simulate_group_data(
      group_means = params$group_means,
      group_sd = 2,
      n_per_group = 50,
      distribution = "exponential",
      seed = 42
    )

    expect_true(all(df$measure > 0))
  })

  it("reproduces same data with same set.seed", {
    params <- make_group_params()
    df1 <- dummy_data$simulate_group_data(
      group_means = params$group_means,
      group_sd = params$group_sd,
      n_per_group = params$n_per_group,
      distribution = params$distribution,
      seed = 123
    )
    df2 <- dummy_data$simulate_group_data(
      group_means = params$group_means,
      group_sd = params$group_sd,
      n_per_group = params$n_per_group,
      distribution = params$distribution,
      seed = 123
    )

    expect_equal(df1$measure, df2$measure)
  })

  it("returns app error when SD <= 0", {
    params <- make_group_params()
    result <- dummy_data$simulate_group_data(
      group_means = params$group_means,
      group_sd = 0,
      n_per_group = params$n_per_group,
      distribution = params$distribution,
      seed = 42
    )

    expect_true(error_handling$is_app_error(result))
  })

  it("returns app error when SD is negative", {
    params <- make_group_params()
    result <- dummy_data$simulate_group_data(
      group_means = params$group_means,
      group_sd = -1,
      n_per_group = params$n_per_group,
      distribution = params$distribution,
      seed = 42
    )

    expect_true(error_handling$is_app_error(result))
  })
})

# =============================================================================
# simulate_group_data — with factor structure
# =============================================================================

describe("simulate_group_data with factor_structure", {
  it("creates correct factor columns for single factor", {
    factor_structure <- list(
      list(name = "Material", levels = c("Mat_A", "Mat_B", "Mat_C"))
    )
    group_means <- c(Mat_A = 1, Mat_B = 2, Mat_C = 3)

    df <- dummy_data$simulate_group_data(
      group_means = group_means,
      group_sd = 1,
      n_per_group = 10,
      distribution = "normal",
      factor_structure = factor_structure,
      measure_name = "Strength",
      seed = 42
    )

    expect_true("Material" %in% names(df))
    expect_true("Strength" %in% names(df))
    expect_equal(nrow(df), 30)
  })

  it("uses custom measure name", {
    params <- make_group_params()
    df <- dummy_data$simulate_group_data(
      group_means = params$group_means,
      group_sd = params$group_sd,
      n_per_group = params$n_per_group,
      distribution = params$distribution,
      measure_name = "Hardness",
      seed = 42
    )

    expect_true("Hardness" %in% names(df))
  })
})

# =============================================================================
# extract_pilot_stats
# =============================================================================

describe("extract_pilot_stats", {
  it("extracts correct group means and pooled SD from pilot data", {
    set.seed(42)
    pilot_data <- data.frame(
      group = rep(c("A", "B", "C"), each = 20),
      value = c(
        rnorm(20, mean = 10, sd = 2),
        rnorm(20, mean = 15, sd = 2),
        rnorm(20, mean = 20, sd = 2)
      )
    )

    result <- dummy_data$extract_pilot_stats(
      data = pilot_data,
      factor_cols = "group",
      measure_col = "value"
    )

    expect_true(is.list(result))
    expect_equal(length(result$group_means), 3)
    expect_true(result$pooled_sd > 0)
    expect_equal(length(result$group_names), 3)
  })

  it("returns error for missing measure column", {
    pilot_data <- data.frame(
      group = c("A", "B"),
      value = c(1, 2)
    )

    result <- dummy_data$extract_pilot_stats(
      data = pilot_data,
      factor_cols = "group",
      measure_col = "nonexistent"
    )

    expect_true(error_handling$is_app_error(result))
  })
})
