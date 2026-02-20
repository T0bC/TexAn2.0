box::use(
  rhino,
)

box::use(
  app/logic/error_handling,
)

# =============================================================================
# Stratified train/test splitting for LDA/QDA
# No Shiny dependencies allowed in this file.
# =============================================================================

#' Create a stratified random train/test split
#'
#' Splits data so that each group in the grouping column
#' is represented proportionally in both train and test sets.
#' Uses base R sampling (no caret dependency).
#'
#' @param data Data frame to split
#' @param grouping_col Character, name of the grouping column
#' @param train_fraction Numeric in (0, 1), proportion for
#'   training set. Default 0.7 (70% train, 30% test).
#' @param seed Integer, random seed for reproducibility.
#'   NULL for no seed.
#' @return List with $success and $result containing
#'   $train_data, $test_data, $train_idx, $test_idx,
#'   $split_summary (data frame with per-group counts)
#' @export
create_stratified_split <- function(data, grouping_col,
                                    train_fraction = 0.7,
                                    seed = NULL) {
  error_handling$safe_execute(
    {
      if (
        train_fraction <= 0 || train_fraction >= 1
      ) {
        stop(
          "Train fraction must be between 0 and 1",
          " (exclusive)."
        )
      }

      grouping <- as.factor(data[[grouping_col]])
      levels_vec <- levels(grouping)

      if (!is.null(seed)) set.seed(seed)

      train_idx <- integer(0)

      for (lvl in levels_vec) {
        group_idx <- which(grouping == lvl)
        n_group <- length(group_idx)
        n_train <- max(
          1, round(n_group * train_fraction)
        )

        # Ensure at least 1 in test set too
        if (n_train >= n_group && n_group > 1) {
          n_train <- n_group - 1
        }

        sampled <- sample(group_idx, n_train)
        train_idx <- c(train_idx, sampled)
      }

      test_idx <- setdiff(
        seq_len(nrow(data)), train_idx
      )

      train_data <- data[train_idx, , drop = FALSE]
      test_data <- data[test_idx, , drop = FALSE]

      # Build summary
      train_groups <- table(
        grouping[train_idx]
      )
      test_groups <- table(
        grouping[test_idx]
      )
      split_summary <- data.frame(
        Group = levels_vec,
        Total = as.integer(table(grouping)),
        Train = as.integer(
          train_groups[levels_vec]
        ),
        Test = as.integer(
          test_groups[levels_vec]
        ),
        stringsAsFactors = FALSE
      )
      split_summary$`Train %` <- round(
        split_summary$Train /
          split_summary$Total * 100, 1
      )

      rhino$log$info(
        "LDA split: {nrow(train_data)} train,",
        " {nrow(test_data)} test",
        " ({length(levels_vec)} groups,",
        " seed={ifelse(is.null(seed), 'none',",
        " seed)})"
      )

      list(
        train_data = train_data,
        test_data = test_data,
        train_idx = train_idx,
        test_idx = test_idx,
        split_summary = split_summary
      )
    },
    operation_name = "Stratified Split"
  )
}
