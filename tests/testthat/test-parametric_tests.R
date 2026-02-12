box::use(
  testthat[describe, expect_equal, expect_true, expect_false, it],
)

box::use(
  app/logic/error_handling,
  app/logic/statistics/parametric_tests,
)

# =============================================================================
# Helper: create test data with multiple groups and a numeric measure
# =============================================================================

make_oneway_data <- function(n_per_group = 20, n_groups = 3) {
  set.seed(42)
  groups <- rep(paste0("G", seq_len(n_groups)), each = n_per_group)
  values <- rnorm(
    n_per_group * n_groups,
    mean = rep(1:n_groups, each = n_per_group)
  )
  data.frame(
    group = groups,
    measure = values,
    stringsAsFactors = FALSE
  )
}

# =============================================================================
# perform_anova1way — happy path
# =============================================================================

describe("perform_anova1way", {
  it("returns a data frame with expected columns for valid 1-way data", {
    df <- make_oneway_data(n_per_group = 20, n_groups = 3)
    result <- parametric_tests$perform_anova1way(
      df = df,
      x_axis = "group",
      measure_col = "measure"
    )
    expect_true(is.data.frame(result))
    expect_equal(
      names(result),
      c("Effect", "Df", "SS", "MS", "F.Statistic", "p.value")
    )
    expect_equal(nrow(result), 1)
  })

  it("returns correct effect label", {
    df <- make_oneway_data(n_per_group = 20, n_groups = 3)
    result <- parametric_tests$perform_anova1way(
      df = df,
      x_axis = "group",
      measure_col = "measure"
    )
    expect_equal(result$Effect, "group")
  })

  it("returns numeric values in the result", {
    df <- make_oneway_data(n_per_group = 15, n_groups = 4)
    result <- parametric_tests$perform_anova1way(
      df = df,
      x_axis = "group",
      measure_col = "measure"
    )
    expect_true(is.numeric(result$F.Statistic))
    expect_true(is.numeric(result$p.value))
    expect_true(result$p.value >= 0 && result$p.value <= 1)
  })

  it("returns integer Df", {
    df <- make_oneway_data(n_per_group = 20, n_groups = 3)
    result <- parametric_tests$perform_anova1way(
      df = df,
      x_axis = "group",
      measure_col = "measure"
    )
    expect_true(is.integer(result$Df))
    expect_equal(result$Df, 2L)
  })

  it("works with 2 groups (minimum)", {
    df <- make_oneway_data(n_per_group = 15, n_groups = 2)
    result <- parametric_tests$perform_anova1way(
      df = df,
      x_axis = "group",
      measure_col = "measure"
    )
    expect_true(is.data.frame(result))
    expect_equal(nrow(result), 1)
    expect_equal(result$Df, 1L)
  })

  it("detects significant differences between groups", {
    set.seed(123)
    df <- data.frame(
      group = rep(c("Low", "High"), each = 30),
      measure = c(rnorm(30, mean = 0), rnorm(30, mean = 5)),
      stringsAsFactors = FALSE
    )
    result <- parametric_tests$perform_anova1way(
      df = df,
      x_axis = "group",
      measure_col = "measure"
    )
    expect_true(result$p.value < 0.05)
    expect_true(result$F.Statistic > 1)
  })
})

# =============================================================================
# perform_anova1way — validation errors
# =============================================================================

describe("perform_anova1way validation", {
  it("returns app_error when only 1 group exists", {
    df <- data.frame(
      group = rep("A", 10),
      measure = rnorm(10),
      stringsAsFactors = FALSE
    )
    result <- parametric_tests$perform_anova1way(
      df = df,
      x_axis = "group",
      measure_col = "measure"
    )
    expect_true(error_handling$is_app_error(result))
  })

  it("returns app_error when x_axis has 2 variables", {
    df <- make_oneway_data()
    df$group2 <- rep(c("X", "Y"), length.out = nrow(df))
    result <- parametric_tests$perform_anova1way(
      df = df,
      x_axis = c("group", "group2"),
      measure_col = "measure"
    )
    expect_true(error_handling$is_app_error(result))
  })
})

# =============================================================================
# perform_anova1way — bootstrap is silently ignored
# =============================================================================

describe("perform_anova1way ignores bootstrap", {
  it("returns same result regardless of bootstrap flag", {
    df <- make_oneway_data(n_per_group = 20, n_groups = 3)
    result_no_boot <- parametric_tests$perform_anova1way(
      df = df,
      x_axis = "group",
      measure_col = "measure",
      use_bootstrap = FALSE
    )
    result_with_boot <- parametric_tests$perform_anova1way(
      df = df,
      x_axis = "group",
      measure_col = "measure",
      use_bootstrap = TRUE,
      boot_samples = 10
    )
    expect_equal(result_no_boot, result_with_boot)
  })
})
