# Non-Parametric Tests Implementation Plan

Implement Kruskal-Wallis (1-way) and ARTool ART (2/3-way) non-parametric omnibus tests following the existing `parametric_tests.R` config-based pattern, wired into the statistics module.

## New Dependencies

- **ARTool** — for Aligned Rank Transform (2-way, 3-way factorial designs)
- Add to `dependencies.R` and install into renv

## File: `app/logic/statistics/nonparametric_tests.R` (NEW)

Follows exact same structure as `parametric_tests.R`: config objects + `perform_*` wrappers calling `omnibus$run_omnibus_test()`.

### 1-Way: Kruskal-Wallis (`stats::kruskal.test`)

- **Config**: `kruskal1way_config`
- **Export**: `perform_kruskal1way(df, x_axis, measure_col, tr_value, use_bootstrap, boot_samples, boot_sample_size)`
- `tr_value`, bootstrap params accepted for interface consistency but **ignored** (like parametric)
- **Output columns** match parametric format:
  - `Effect`, `Df`, `H.Statistic`, `p.value` (1 row)
  - `H.Statistic` replaces `F.Statistic` (chi-squared statistic from Kruskal-Wallis)
  - `Df` = k-1 (groups minus 1)
  - No SS/MS columns (rank-based test doesn't produce these)

### 2-Way: ART (`ARTool::art` + `anova()`)

- **Config**: `art2way_config`
- **Export**: `perform_art2way(df, x_axis, measure_col, ...)`
- Bootstrap/trim params ignored
- `ARTool::art()` requires formula + data, then `anova()` on the art object gives F-tests per effect
- **Output columns**: `Effect`, `Df`, `Df.res`, `F.Statistic`, `p.value` (3 rows: A, B, A:B)
- Need `eval()` in `new.env(parent=globalenv())` workaround for `ARTool::art()` — same pattern as MDA (ARTool uses formula interface internally that may conflict with box module isolation)

### 3-Way: ART (`ARTool::art` + `anova()`)

- **Config**: `art3way_config`
- **Export**: `perform_art3way(df, x_axis, measure_col, ...)`
- Same approach as 2-way, just with 3 factors
- **Output columns**: `Effect`, `Df`, `Df.res`, `F.Statistic`, `p.value` (7 rows: A, B, C, A:B, A:C, B:C, A:B:C)

### Key Design Decisions

- **No bootstrap** for non-parametric tests (these are already distribution-free; bootstrap adds no value)
- **Output format** mirrors parametric: data.frame with `Effect` column + test statistics, directly consumable by existing `render_omnibus_result()`
- Error handling uses `error_handling$simple_error()` for validation, `error_handling$safe_execute()` with `stat_error_parser` for test execution — per `error_handling.md`
- All imports via `box::use()` with `$` access — per `instructions.md`

## Wiring Changes

### `app/view/statistics/statistics.R`

1. **Import** `nonparametric_tests` module (line ~10 area)
2. **Remove** `not_implemented` early return (lines 460-470) — replace with actual dispatch
3. **Add** `nonparametric` branch in the omnibus `lapply` (alongside robust/parametric, ~lines 491-573):
   - 1-way → `nonparametric_tests$perform_kruskal1way(...)`
   - 2-way → `nonparametric_tests$perform_art2way(...)`
   - 3-way → `nonparametric_tests$perform_art3way(...)`
4. **Post-hoc**: Set to `NULL` for now (post-hoc like Dunn's test is a separate follow-up task)
5. **Update** `render_omnibus_result()` header label: add `else if (approach == "nonparametric")` branch with appropriate label (e.g., "Non-Parametric 1-Way — Kruskal-Wallis", "Non-Parametric 2-Way — Aligned Rank Transform")

## Test File: `tests/testthat/test-nonparametric_tests.R` (NEW)

Mirrors `test-parametric_tests.R` structure:

- **1-way happy path**: returns data.frame, correct columns, correct effect label, numeric values, valid p-value
- **1-way validation**: wrong number of grouping vars → app_error, <2 groups → app_error
- **2-way happy path**: returns data.frame with 3 rows (A, B, A:B), correct effect labels
- **2-way validation**: wrong number of factors, <2 levels
- **3-way happy path**: returns data.frame with 7 rows, correct effect labels
- **3-way validation**: wrong number of factors, <2 levels
- Uses `describe`/`it` from testthat, `box::use` imports per `instructions.md`

## Out of Scope (Future Tasks)

- Non-parametric **post-hoc** tests (Dunn's test for 1-way, ART contrasts for 2/3-way)
- Non-parametric **Cliff's Delta** equivalent effect sizes
- Report generation for non-parametric results
