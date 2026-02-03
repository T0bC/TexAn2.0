# TexAn 2.0 Codebase Restructuring Script
# This script restructures the codebase from nested R/server/modules/pages/ and R/ui/modules/pages/
# to a flat R/server/{module}/ and R/ui/{module}/ hierarchy.
#
# Run from the project root: .\restructure_codebase.ps1

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot

Write-Host "=== TexAn 2.0 Codebase Restructuring ===" -ForegroundColor Cyan
Write-Host "Project Root: $ProjectRoot" -ForegroundColor Gray

# Phase 1: Create new directory structure
Write-Host "`n=== Phase 1: Creating Directory Structure ===" -ForegroundColor Yellow

$newDirs = @(
    "R/server/load_data",
    "R/server/median",
    "R/server/plotting",
    "R/server/summary_stats",
    "R/server/statistics",
    "R/server/pca",
    "R/ui/load_data",
    "R/ui/median",
    "R/ui/plotting",
    "R/ui/summary_stats",
    "R/ui/statistics",
    "R/ui/pca",
    "R/ui/components"
)

foreach ($dir in $newDirs) {
    $fullPath = Join-Path $ProjectRoot $dir
    if (-not (Test-Path $fullPath)) {
        New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
        Write-Host "  Created: $dir" -ForegroundColor Green
    } else {
        Write-Host "  Exists: $dir" -ForegroundColor Gray
    }
}

# Phase 2: Move files
Write-Host "`n=== Phase 2: Moving Files ===" -ForegroundColor Yellow

# Define file moves as hashtable: source -> destination
$fileMoves = @{
    # Server main files
    "R/server/modules/pages/server_load_data.R" = "R/server/load_data/server_load_data.R"
    "R/server/modules/pages/server_median.R" = "R/server/median/server_median.R"
    "R/server/modules/pages/server_plotting.R" = "R/server/plotting/server_plotting.R"
    "R/server/modules/pages/server_summary_stats.R" = "R/server/summary_stats/server_summary_stats.R"
    "R/server/modules/pages/server_statistics.R" = "R/server/statistics/server_statistics.R"
    "R/server/modules/pages/server_pca.R" = "R/server/pca/server_pca.R"
    
    # Load data sub-modules
    "R/server/modules/pages/load_data/file_upload.R" = "R/server/load_data/file_upload.R"
    "R/server/modules/pages/load_data/data_preview.R" = "R/server/load_data/data_preview.R"
    "R/server/modules/pages/load_data/missing_values_plot.R" = "R/server/load_data/missing_values_plot.R"
    "R/server/modules/pages/load_data/data_summary.R" = "R/server/load_data/data_summary.R"
    
    # Median sub-modules (server logic only)
    "R/server/modules/pages/median/help_modal.R" = "R/server/median/help_modal.R"
    "R/server/modules/pages/median/median_params.R" = "R/server/median/median_params.R"
    "R/server/modules/pages/median/median_table.R" = "R/server/median/median_table.R"
    "R/server/modules/pages/median/quality_filter_logic.R" = "R/server/median/quality_filter_logic.R"
    
    # Median UI files -> R/ui/median/
    "R/server/modules/pages/median/grouping_ui.R" = "R/ui/median/grouping_ui.R"
    "R/server/modules/pages/median/quality_filter_ui.R" = "R/ui/median/quality_filter_ui.R"
    
    # Plotting sub-modules (server logic only)
    "R/server/modules/pages/plotting/plot_scatter.R" = "R/server/plotting/plot_scatter.R"
    "R/server/modules/pages/plotting/plot_renderer.R" = "R/server/plotting/plot_renderer.R"
    "R/server/modules/pages/plotting/data_processing.R" = "R/server/plotting/data_processing.R"
    "R/server/modules/pages/plotting/filter_logic.R" = "R/server/plotting/filter_logic.R"
    "R/server/modules/pages/plotting/input_updaters.R" = "R/server/plotting/input_updaters.R"
    "R/server/modules/pages/plotting/reactive_params.R" = "R/server/plotting/reactive_params.R"
    "R/server/modules/pages/plotting/color_pickers.R" = "R/server/plotting/color_pickers.R"
    "R/server/modules/pages/plotting/download_handler.R" = "R/server/plotting/download_handler.R"
    
    # Plotting UI files -> R/ui/plotting/
    "R/server/modules/pages/plotting/plots_ui.R" = "R/ui/plotting/plots_ui.R"
    "R/server/modules/pages/plotting/ui_tab_data_selection.R" = "R/ui/plotting/ui_tab_data_selection.R"
    "R/server/modules/pages/plotting/ui_tab_filter.R" = "R/ui/plotting/ui_tab_filter.R"
    "R/server/modules/pages/plotting/ui_tab_processing.R" = "R/ui/plotting/ui_tab_processing.R"
    "R/server/modules/pages/plotting/ui_tab_style.R" = "R/ui/plotting/ui_tab_style.R"
    
    # Summary stats sub-modules
    "R/server/modules/pages/summary_stats/summary_utils.R" = "R/server/summary_stats/summary_utils.R"
    "R/server/modules/pages/summary_stats/sidebar_logic.R" = "R/server/summary_stats/sidebar_logic.R"
    "R/server/modules/pages/summary_stats/summary_tables.R" = "R/server/summary_stats/summary_tables.R"
    
    # Statistics sub-modules (server logic only)
    "R/server/modules/pages/statistics/sidebar_logic.R" = "R/server/statistics/sidebar_logic.R"
    "R/server/modules/pages/statistics/statistics_output.R" = "R/server/statistics/statistics_output.R"
    "R/server/modules/pages/statistics/statistics_report.R" = "R/server/statistics/statistics_report.R"
    
    # Statistics UI files -> R/ui/statistics/
    "R/server/modules/pages/statistics/ui_tab_adjustments.R" = "R/ui/statistics/ui_tab_adjustments.R"
    "R/server/modules/pages/statistics/ui_tab_bootstrap.R" = "R/ui/statistics/ui_tab_bootstrap.R"
    "R/server/modules/pages/statistics/ui_tab_options.R" = "R/ui/statistics/ui_tab_options.R"
    
    # PCA sub-modules (server logic only)
    "R/server/modules/pages/pca/correlation_plot.R" = "R/server/pca/correlation_plot.R"
    "R/server/modules/pages/pca/kmo_computation.R" = "R/server/pca/kmo_computation.R"
    "R/server/modules/pages/pca/kmo_results.R" = "R/server/pca/kmo_results.R"
    "R/server/modules/pages/pca/optimal_components.R" = "R/server/pca/optimal_components.R"
    "R/server/modules/pages/pca/optimal_components_results.R" = "R/server/pca/optimal_components_results.R"
    "R/server/modules/pages/pca/pca_computation.R" = "R/server/pca/pca_computation.R"
    "R/server/modules/pages/pca/pca_results.R" = "R/server/pca/pca_results.R"
    "R/server/modules/pages/pca/pca_utils.R" = "R/server/pca/pca_utils.R"
    
    # PCA UI files -> R/ui/pca/
    "R/server/modules/pages/pca/ui_tab_actions.R" = "R/ui/pca/ui_tab_actions.R"
    "R/server/modules/pages/pca/ui_tab_data_selection.R" = "R/ui/pca/ui_tab_data_selection.R"
    "R/server/modules/pages/pca/ui_tab_plotting_controls.R" = "R/ui/pca/ui_tab_plotting_controls.R"
    
    # Main UI files
    "R/ui/modules/pages/ui_load_data.R" = "R/ui/load_data/ui_load_data.R"
    "R/ui/modules/pages/ui_median.R" = "R/ui/median/ui_median.R"
    "R/ui/modules/pages/ui_plotting.R" = "R/ui/plotting/ui_plotting.R"
    "R/ui/modules/pages/ui_summary_stats.R" = "R/ui/summary_stats/ui_summary_stats.R"
    "R/ui/modules/pages/ui_statistics.R" = "R/ui/statistics/ui_statistics.R"
    "R/ui/modules/pages/ui_pca.R" = "R/ui/pca/ui_pca.R"
    
    # Component files
    "R/ui/modules/components/settings_modal.R" = "R/ui/components/settings_modal.R"
    "R/ui/modules/components/error_display.R" = "R/ui/components/error_display.R"
}

$movedCount = 0
foreach ($source in $fileMoves.Keys) {
    $sourcePath = Join-Path $ProjectRoot $source
    $destPath = Join-Path $ProjectRoot $fileMoves[$source]
    
    if (Test-Path $sourcePath) {
        Move-Item -Path $sourcePath -Destination $destPath -Force
        Write-Host "  Moved: $source -> $($fileMoves[$source])" -ForegroundColor Green
        $movedCount++
    } else {
        Write-Host "  Not found: $source" -ForegroundColor Red
    }
}
Write-Host "  Total files moved: $movedCount" -ForegroundColor Cyan

# Phase 3: Update source() paths in files
Write-Host "`n=== Phase 3: Updating source() Paths ===" -ForegroundColor Yellow

# Define path replacements (old -> new)
$pathReplacements = @{
    # UI modules paths
    'R/ui/modules/pages/ui_load_data.R' = 'R/ui/load_data/ui_load_data.R'
    'R/ui/modules/pages/ui_median.R' = 'R/ui/median/ui_median.R'
    'R/ui/modules/pages/ui_plotting.R' = 'R/ui/plotting/ui_plotting.R'
    'R/ui/modules/pages/ui_summary_stats.R' = 'R/ui/summary_stats/ui_summary_stats.R'
    'R/ui/modules/pages/ui_statistics.R' = 'R/ui/statistics/ui_statistics.R'
    'R/ui/modules/pages/ui_pca.R' = 'R/ui/pca/ui_pca.R'
    
    # Component paths
    'R/ui/modules/components/settings_modal.R' = 'R/ui/components/settings_modal.R'
    'R/ui/modules/components/error_display.R' = 'R/ui/components/error_display.R'
    
    # Server main module paths
    'R/server/modules/pages/server_load_data.R' = 'R/server/load_data/server_load_data.R'
    'R/server/modules/pages/server_median.R' = 'R/server/median/server_median.R'
    'R/server/modules/pages/server_plotting.R' = 'R/server/plotting/server_plotting.R'
    'R/server/modules/pages/server_summary_stats.R' = 'R/server/summary_stats/server_summary_stats.R'
    'R/server/modules/pages/server_statistics.R' = 'R/server/statistics/server_statistics.R'
    'R/server/modules/pages/server_pca.R' = 'R/server/pca/server_pca.R'
    
    # Load data sub-module paths
    'R/server/modules/pages/load_data/file_upload.R' = 'R/server/load_data/file_upload.R'
    'R/server/modules/pages/load_data/data_preview.R' = 'R/server/load_data/data_preview.R'
    'R/server/modules/pages/load_data/missing_values_plot.R' = 'R/server/load_data/missing_values_plot.R'
    'R/server/modules/pages/load_data/data_summary.R' = 'R/server/load_data/data_summary.R'
    
    # Median sub-module paths
    'R/server/modules/pages/median/help_modal.R' = 'R/server/median/help_modal.R'
    'R/server/modules/pages/median/grouping_ui.R' = 'R/ui/median/grouping_ui.R'
    'R/server/modules/pages/median/quality_filter_ui.R' = 'R/ui/median/quality_filter_ui.R'
    'R/server/modules/pages/median/quality_filter_logic.R' = 'R/server/median/quality_filter_logic.R'
    'R/server/modules/pages/median/median_table.R' = 'R/server/median/median_table.R'
    'R/server/modules/pages/median/median_params.R' = 'R/server/median/median_params.R'
    
    # Plotting sub-module paths (server)
    'R/server/modules/pages/plotting/plot_scatter.R' = 'R/server/plotting/plot_scatter.R'
    'R/server/modules/pages/plotting/plot_renderer.R' = 'R/server/plotting/plot_renderer.R'
    'R/server/modules/pages/plotting/data_processing.R' = 'R/server/plotting/data_processing.R'
    'R/server/modules/pages/plotting/filter_logic.R' = 'R/server/plotting/filter_logic.R'
    'R/server/modules/pages/plotting/input_updaters.R' = 'R/server/plotting/input_updaters.R'
    'R/server/modules/pages/plotting/reactive_params.R' = 'R/server/plotting/reactive_params.R'
    'R/server/modules/pages/plotting/color_pickers.R' = 'R/server/plotting/color_pickers.R'
    'R/server/modules/pages/plotting/download_handler.R' = 'R/server/plotting/download_handler.R'
    
    # Plotting sub-module paths (UI)
    'R/server/modules/pages/plotting/plots_ui.R' = 'R/ui/plotting/plots_ui.R'
    'R/server/modules/pages/plotting/ui_tab_data_selection.R' = 'R/ui/plotting/ui_tab_data_selection.R'
    'R/server/modules/pages/plotting/ui_tab_filter.R' = 'R/ui/plotting/ui_tab_filter.R'
    'R/server/modules/pages/plotting/ui_tab_processing.R' = 'R/ui/plotting/ui_tab_processing.R'
    'R/server/modules/pages/plotting/ui_tab_style.R' = 'R/ui/plotting/ui_tab_style.R'
    
    # Summary stats sub-module paths
    'R/server/modules/pages/summary_stats/summary_utils.R' = 'R/server/summary_stats/summary_utils.R'
    'R/server/modules/pages/summary_stats/sidebar_logic.R' = 'R/server/summary_stats/sidebar_logic.R'
    'R/server/modules/pages/summary_stats/summary_tables.R' = 'R/server/summary_stats/summary_tables.R'
    
    # Statistics sub-module paths (server)
    'R/server/modules/pages/statistics/sidebar_logic.R' = 'R/server/statistics/sidebar_logic.R'
    'R/server/modules/pages/statistics/statistics_output.R' = 'R/server/statistics/statistics_output.R'
    'R/server/modules/pages/statistics/statistics_report.R' = 'R/server/statistics/statistics_report.R'
    
    # Statistics sub-module paths (UI)
    'R/server/modules/pages/statistics/ui_tab_adjustments.R' = 'R/ui/statistics/ui_tab_adjustments.R'
    'R/server/modules/pages/statistics/ui_tab_bootstrap.R' = 'R/ui/statistics/ui_tab_bootstrap.R'
    'R/server/modules/pages/statistics/ui_tab_options.R' = 'R/ui/statistics/ui_tab_options.R'
    
    # PCA sub-module paths (server)
    'R/server/modules/pages/pca/pca_utils.R' = 'R/server/pca/pca_utils.R'
    'R/server/modules/pages/pca/kmo_results.R' = 'R/server/pca/kmo_results.R'
    'R/server/modules/pages/pca/kmo_computation.R' = 'R/server/pca/kmo_computation.R'
    'R/server/modules/pages/pca/pca_computation.R' = 'R/server/pca/pca_computation.R'
    'R/server/modules/pages/pca/correlation_plot.R' = 'R/server/pca/correlation_plot.R'
    'R/server/modules/pages/pca/pca_results.R' = 'R/server/pca/pca_results.R'
    'R/server/modules/pages/pca/optimal_components.R' = 'R/server/pca/optimal_components.R'
    'R/server/modules/pages/pca/optimal_components_results.R' = 'R/server/pca/optimal_components_results.R'
    
    # PCA sub-module paths (UI)
    'R/server/modules/pages/pca/ui_tab_actions.R' = 'R/ui/pca/ui_tab_actions.R'
    'R/server/modules/pages/pca/ui_tab_data_selection.R' = 'R/ui/pca/ui_tab_data_selection.R'
    'R/server/modules/pages/pca/ui_tab_plotting_controls.R' = 'R/ui/pca/ui_tab_plotting_controls.R'
}

# Files that need source() path updates
$filesToUpdate = @(
    "app.R",
    "R/server/plotting/server_plotting.R",
    "R/server/statistics/server_statistics.R",
    "R/server/summary_stats/server_summary_stats.R",
    "R/server/pca/server_pca.R",
    "R/ui/plotting/ui_plotting.R",
    "R/ui/statistics/ui_statistics.R",
    "R/ui/pca/ui_pca.R"
)

foreach ($file in $filesToUpdate) {
    $filePath = Join-Path $ProjectRoot $file
    
    if (Test-Path $filePath) {
        $content = Get-Content $filePath -Raw
        $originalContent = $content
        
        foreach ($oldPath in $pathReplacements.Keys) {
            $newPath = $pathReplacements[$oldPath]
            $content = $content -replace [regex]::Escape($oldPath), $newPath
        }
        
        if ($content -ne $originalContent) {
            Set-Content -Path $filePath -Value $content -NoNewline
            Write-Host "  Updated: $file" -ForegroundColor Green
        } else {
            Write-Host "  No changes: $file" -ForegroundColor Gray
        }
    } else {
        Write-Host "  Not found: $file" -ForegroundColor Red
    }
}

# Phase 4: Cleanup empty directories
Write-Host "`n=== Phase 4: Cleaning Up Empty Directories ===" -ForegroundColor Yellow

$dirsToRemove = @(
    "R/server/modules/pages/load_data",
    "R/server/modules/pages/median",
    "R/server/modules/pages/plotting",
    "R/server/modules/pages/summary_stats",
    "R/server/modules/pages/statistics",
    "R/server/modules/pages/pca",
    "R/server/modules/pages",
    "R/server/modules",
    "R/ui/modules/pages",
    "R/ui/modules/components",
    "R/ui/modules"
)

foreach ($dir in $dirsToRemove) {
    $fullPath = Join-Path $ProjectRoot $dir
    if (Test-Path $fullPath) {
        $items = Get-ChildItem $fullPath -Force
        if ($items.Count -eq 0) {
            Remove-Item $fullPath -Force
            Write-Host "  Removed empty: $dir" -ForegroundColor Green
        } else {
            Write-Host "  Not empty (skipped): $dir" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  Already gone: $dir" -ForegroundColor Gray
    }
}

Write-Host "`n=== Restructuring Complete ===" -ForegroundColor Cyan
Write-Host "Run 'shiny::runApp()' to verify the app starts correctly." -ForegroundColor White
