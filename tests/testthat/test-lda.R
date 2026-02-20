box::use(
  testthat[describe, expect_equal, expect_true, it],
)

box::use(
  app/logic/lda/lda,
)

# =============================================================================
# Helper: create test data
# =============================================================================

make_test_data <- function() {
  data.frame(
    species = rep(c("A", "B", "C"), each = 10),
    site = rep(c("X", "Y"), 15),
    m1 = rnorm(30),
    m2 = rnorm(30),
    m3 = rnorm(30),
    stringsAsFactors = FALSE
  )
}

# =============================================================================
# validate_inputs
# =============================================================================

describe("validate_inputs", {
  it("returns valid = TRUE for valid inputs", {
    data <- make_test_data()
    result <- lda$validate_inputs(
      c("m1", "m2", "m3"), data, "species"
    )
    expect_true(result$valid)
  })

  it("returns valid = FALSE when no columns selected", {
    data <- make_test_data()
    result <- lda$validate_inputs(NULL, data, "species")
    expect_true(!result$valid)
  })

  it("returns valid = FALSE for missing columns", {
    data <- make_test_data()
    result <- lda$validate_inputs(
      c("m1", "nonexistent"), data, "species"
    )
    expect_true(!result$valid)
  })

  it("returns valid = FALSE when no grouping column", {
    data <- make_test_data()
    result <- lda$validate_inputs(
      c("m1", "m2"), data, NULL
    )
    expect_true(!result$valid)
  })

  it("returns valid = FALSE for empty grouping column", {
    data <- make_test_data()
    result <- lda$validate_inputs(
      c("m1", "m2"), data, ""
    )
    expect_true(!result$valid)
  })

  it("returns valid = FALSE when grouping column not in data", {
    data <- make_test_data()
    result <- lda$validate_inputs(
      c("m1", "m2"), data, "nonexistent"
    )
    expect_true(!result$valid)
  })

  it("returns valid = FALSE when grouping has < 2 levels", {
    data <- make_test_data()
    data$species <- "A"
    result <- lda$validate_inputs(
      c("m1", "m2"), data, "species"
    )
    expect_true(!result$valid)
  })

  it("returns warnings when n < p for some groups", {
    data <- data.frame(
      species = c(rep("A", 2), rep("B", 20)),
      m1 = rnorm(22),
      m2 = rnorm(22),
      m3 = rnorm(22),
      m4 = rnorm(22),
      m5 = rnorm(22),
      stringsAsFactors = FALSE
    )
    result <- lda$validate_inputs(
      c("m1", "m2", "m3", "m4", "m5"),
      data, "species"
    )
    expect_true(result$valid)
    expect_true(length(result$warnings) > 0)
  })
})

# =============================================================================
# run_lda (stub)
# =============================================================================

describe("run_lda", {
  it("returns success = FALSE (stub)", {
    data <- make_test_data()
    result <- lda$run_lda(
      data, c("m1", "m2"), "species"
    )
    expect_true(!result$success)
  })
})

# =============================================================================
# run_qda (stub)
# =============================================================================

describe("run_qda", {
  it("returns success = FALSE (stub)", {
    data <- make_test_data()
    result <- lda$run_qda(
      data, c("m1", "m2"), "species"
    )
    expect_true(!result$success)
  })
})

# =============================================================================
# lda_error_parser
# =============================================================================

describe("lda_error_parser", {
  it("parses singular matrix errors", {
    msg <- lda$lda_error_parser(
      "matrix is singular", "LDA"
    )
    expect_true(grepl("singular", msg, ignore.case = TRUE))
  })

  it("parses NA errors", {
    msg <- lda$lda_error_parser(
      "data contains NA values", "LDA"
    )
    expect_true(grepl("missing", msg, ignore.case = TRUE))
  })

  it("returns generic message for unknown errors", {
    msg <- lda$lda_error_parser(
      "something unexpected", "LDA"
    )
    expect_true(grepl("failed", msg))
  })
})
