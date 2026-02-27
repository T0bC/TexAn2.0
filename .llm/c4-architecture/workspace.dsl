workspace "TexAn 2.0" "Texture Analysis application for archaeological and material-science research. Built with R/Shiny (Rhino framework), providing a multi-tab analytical pipeline: data loading, median calculation, plotting, summary statistics, PCA, LDA/MDA, and cluster analysis." {

    model {
        // =====================================================================
        // People
        // =====================================================================
        researcher = person "Researcher" "An archaeologist or material scientist who uploads measurement data and performs texture analysis."

        // =====================================================================
        // Primary Software System
        // =====================================================================
        texan = softwareSystem "TexAn 2.0" "Interactive Shiny web application for texture analysis: median calculation, plotting, summary statistics, PCA, LDA/MDA, and cluster analysis." {

            // -----------------------------------------------------------------
            // Containers
            // -----------------------------------------------------------------
            ui = container "Shiny UI" "Browser-based single-page application with tabbed navigation (bslib page_navbar). Renders interactive plots (ggiraph, plotly) and data tables (DT)." "R / bslib / Shiny" "WebBrowser"

            appServer = container "Shiny Server" "Orchestrates the reactive data pipeline across all analysis modules. Manages tab visibility and inter-module data flow via reactive values." "R / Rhino / Shiny" {

                // -- Orchestration --
                group "Orchestration" {
                    mainModule = component "Main Module" "Top-level Shiny module (app/main.R). Wires all sub-modules, manages reactive data pipeline and tab visibility." "R / Shiny moduleServer"
                }

                // -- Data Ingestion --
                group "Data Ingestion" {
                    loadDataModule = component "Load Data Module" "Handles file upload (CSV/XLSX), column type detection, data preview, and example dataset loading." "R / Shiny"
                    exampleData = component "Example Data" "Provides bundled example datasets for quick exploration." "R"
                }

                // -- Median Pipeline --
                group "Median Pipeline" {
                    medianModule = component "Median Module" "Computes grouped medians across measurement columns. Optionally filters and reshapes data before downstream analysis." "R / Shiny"
                }

                // -- Plotting & Diagnostics --
                group "Plotting & Diagnostics" {
                    plottingModule = component "Plotting Module" "Creates interactive box/violin/scatter plots. Handles outlier detection, trimming, data normalization (bestNormalize), and assumption checks (Shapiro-Wilk, Levene)." "R / ggplot2 / ggiraph"
                    assumptionChecks = component "Assumption Checks" "Runs Shapiro-Wilk normality tests per group and manual Levene's test. Produces diagnostic banners." "R"
                    normalize = component "Normalize" "Applies bestNormalize transformations (pooled). Appends _normalized columns preserving raw data." "R / bestNormalize"
                }

                // -- Summary & Statistics --
                group "Summary & Statistics" {
                    summaryModule = component "Summary Module" "Generates descriptive summary tables for selected measurement columns. Supports transformed-data summaries." "R / summarytools / DT"
                    statisticsModule = component "Statistics Module" "Performs parametric and non-parametric statistical tests (t-test, ANOVA, Kruskal-Wallis, pairwise comparisons). Exports results." "R / WRS2 / stats"
                }

                // -- Multivariate Analysis --
                group "Multivariate Analysis" {
                    pcaModule = component "PCA Module" "Principal Component Analysis with configurable scaling, NA handling, biplots (2D/3D), scree plots, and loading tables." "R / stats / plotly / ggiraph"
                    ldaModule = component "LDA Module" "Linear Discriminant Analysis and Mixture Discriminant Analysis (MDA). Includes LOO cross-validation, posterior probabilities, and score plots." "R / MASS / mda"
                    clusterModule = component "Cluster Module" "Cluster analysis: k-means, hierarchical, DBSCAN. Hopkins statistic, optimal cluster estimation, heatmaps, and cluster biplots." "R / cluster / dbscan / heatmaply"
                }

                // -- Shared Utilities --
                group "Shared Utilities" {
                    columnUtils = component "Column Utils" "Shared helpers for column type detection and selection across modules." "R"
                    errorHandling = component "Error Handling" "Centralized safe-execution wrappers (tryCatch-based) and error parsing for user-friendly messages." "R"
                    dataUtils = component "Data Utils" "Generic data manipulation helpers used across modules." "R"
                    skewnessTransform = component "Skewness Transform" "Applies skewness-based transformations for PCA/LDA/Cluster pre-processing." "R / e1071"
                    settings = component "Settings" "Manages application-wide settings (theme, defaults)." "R / bslib"
                    logging = component "Logging" "Configures per-session logging using Rhino's logging infrastructure." "R / rhino / cli"
                }

                // -- UI Utilities --
                group "UI Utilities" {
                    components = component "Reusable UI Components" "Shared sidebar tabs, card wrappers, and other reusable Shiny UI building blocks." "R / bslib"
                    errorDisplay = component "Error Display" "Renders user-friendly error/warning banners in the UI." "R / shiny / htmltools"
                    helpModal = component "Help Modal" "Context-sensitive help dialog that adapts to the currently active tab." "R / markdown"
                    settingsModal = component "Settings Modal" "Global settings dialog for theme toggling and application preferences." "R / bslib"
                }
            }

            staticAssets = container "Static Assets" "Client-side JavaScript (tab disabling, plot resize), CSS (SCSS compiled), example data files, and images." "JS / SCSS / Static Files"

            // No external database – data lives in-session reactive values
        }

        // =====================================================================
        // External Systems
        // =====================================================================
        fileSystem = softwareSystem "User File System" "Local files (CSV, XLSX) uploaded by the researcher for analysis." "External"

        // =====================================================================
        // Relationships: People -> System
        // =====================================================================
        researcher -> texan "Uploads data and performs texture analysis using" "Web Browser"

        // Relationships: People -> Containers
        researcher -> ui "Interacts with tabs, uploads files, configures analysis parameters" "HTTPS"

        // Relationships: Containers
        ui -> appServer "Sends user inputs and receives rendered outputs" "Shiny Reactive Protocol / WebSocket"
        appServer -> staticAssets "Serves JavaScript, CSS, and static files to the browser" "HTTP"
        ui -> staticAssets "Loads client-side JS and CSS" "HTTP"

        // Relationships: System -> External
        texan -> fileSystem "Reads uploaded CSV/XLSX data files from" "File Upload"

        // =================================================================
        // Component-level relationships
        // =================================================================

        // -- Main orchestration --
        mainModule -> loadDataModule "Initializes and receives uploaded data from" "Reactive"
        mainModule -> medianModule "Passes raw data; receives median-filtered data" "Reactive"
        mainModule -> plottingModule "Passes plotting_data; receives plotting_result (axes, measures, processed data)" "Reactive"
        mainModule -> summaryModule "Passes processed data + plotting selections" "Reactive"
        mainModule -> statisticsModule "Passes processed data + plotting config" "Reactive"
        mainModule -> pcaModule "Passes plotting_data; receives pca_result" "Reactive"
        mainModule -> ldaModule "Passes plotting_data + pca_result; receives lda_result" "Reactive"
        mainModule -> clusterModule "Passes plotting_data + pca_result + lda_result" "Reactive"
        mainModule -> helpModal "Passes active_page for context-sensitive help" "Reactive"
        mainModule -> settingsModal "Initializes settings module" "Reactive"

        // -- Data flow pipeline --
        loadDataModule -> exampleData "Loads bundled example datasets from" "Function Call"
        loadDataModule -> medianModule "Provides input_data and data_version" "Reactive"
        medianModule -> plottingModule "Provides median-filtered data (or raw fallback)" "Reactive"
        plottingModule -> summaryModule "Provides x_axis, measure_cols, normalize_enabled, transform_info" "Reactive"
        plottingModule -> statisticsModule "Provides x_axis, measure_cols, trim_percent, plot_objects, normalize/transform info" "Reactive"
        pcaModule -> ldaModule "Provides pca_result (scores, loadings)" "Reactive"
        pcaModule -> clusterModule "Provides pca_result for dimensionality reduction" "Reactive"
        ldaModule -> clusterModule "Provides lda_result (discriminant scores)" "Reactive"

        // -- Plotting internals --
        plottingModule -> assumptionChecks "Runs normality and homogeneity diagnostics" "Function Call"
        plottingModule -> normalize "Applies data transformations" "Function Call"

        // -- Shared utility usage --
        loadDataModule -> columnUtils "Detects column types" "Function Call"
        loadDataModule -> errorHandling "Wraps file-parsing in safe execution" "Function Call"
        medianModule -> columnUtils "Identifies measurement columns" "Function Call"
        medianModule -> errorHandling "Wraps median computation" "Function Call"
        plottingModule -> columnUtils "Column selection helpers" "Function Call"
        plottingModule -> errorHandling "Wraps plot generation" "Function Call"
        plottingModule -> dataUtils "Data manipulation helpers" "Function Call"
        summaryModule -> columnUtils "Column lookup" "Function Call"
        summaryModule -> errorHandling "Wraps summary generation" "Function Call"
        statisticsModule -> errorHandling "Wraps statistical tests" "Function Call"
        pcaModule -> columnUtils "Column selection" "Function Call"
        pcaModule -> errorHandling "Wraps PCA computation" "Function Call"
        pcaModule -> skewnessTransform "Pre-processing transforms" "Function Call"
        ldaModule -> columnUtils "Column selection" "Function Call"
        ldaModule -> errorHandling "Wraps LDA/MDA computation" "Function Call"
        ldaModule -> skewnessTransform "Pre-processing transforms" "Function Call"
        clusterModule -> columnUtils "Column selection" "Function Call"
        clusterModule -> errorHandling "Wraps clustering" "Function Call"
        clusterModule -> skewnessTransform "Pre-processing transforms" "Function Call"
        skewnessTransform -> errorHandling "Wraps transform operations" "Function Call"

        // -- UI utility usage --
        loadDataModule -> components "Uses sidebar tab layout" "UI Include"
        loadDataModule -> errorDisplay "Renders error banners" "UI Include"
        medianModule -> components "Uses sidebar tab layout" "UI Include"
        medianModule -> errorDisplay "Renders error banners" "UI Include"
        plottingModule -> components "Uses sidebar tab layout" "UI Include"
        plottingModule -> errorDisplay "Renders error banners" "UI Include"
        summaryModule -> components "Uses sidebar tab layout" "UI Include"
        summaryModule -> errorDisplay "Renders error banners" "UI Include"
        statisticsModule -> components "Uses sidebar tab layout" "UI Include"
        statisticsModule -> errorDisplay "Renders error banners" "UI Include"
        pcaModule -> components "Uses sidebar tab layout" "UI Include"
        pcaModule -> errorDisplay "Renders error banners" "UI Include"
        ldaModule -> components "Uses sidebar tab layout" "UI Include"
        ldaModule -> errorDisplay "Renders error banners" "UI Include"
        clusterModule -> components "Uses sidebar tab layout" "UI Include"
        clusterModule -> errorDisplay "Renders error banners" "UI Include"
        settingsModal -> settings "Reads and writes app settings" "Function Call"
        errorDisplay -> errorHandling "Formats error messages" "Function Call"

        // =================================================================
        // Deployment
        // =================================================================
        deploymentEnvironment "Production" {
            deploymentNode "Docker Host" "Server running the containerized application" "Linux" {
                deploymentNode "Docker Container" "rocker/r-ver:4.5.2 base image with system libraries" "Docker" {
                    deploymentNode "Shiny Server" "R process serving the app on port 3838" "shiny::runApp" {
                        containerInstance ui
                        containerInstance appServer
                        containerInstance staticAssets
                    }
                }
            }
        }
    }

    views {
        // Level 1: System Context
        systemContext texan "SystemContext" "System Context diagram for TexAn 2.0" {
            include *
            autoLayout
        }

        // Level 2: Container
        container texan "Containers" "Container diagram showing Shiny UI, Server, and Static Assets" {
            include *
            autoLayout
        }

        // Level 3: Component – App Server internals
        component appServer "Components" "Component diagram showing all Shiny modules and shared utilities inside the App Server" {
            include *
            autoLayout lr 300 100
        }

        // Dynamic: Data analysis pipeline flow
        dynamic appServer "DataPipeline" "Shows the main data analysis pipeline from upload to cluster analysis" {
            mainModule -> loadDataModule "1. Initializes data ingestion"
            loadDataModule -> medianModule "2. Provides input_data and data_version"
            medianModule -> plottingModule "3. Provides median-filtered data (or raw fallback)"
            plottingModule -> summaryModule "4. Provides x_axis, measure_cols, normalize_enabled, transform_info"
            plottingModule -> statisticsModule "5. Provides plotting config and processed data"
            mainModule -> pcaModule "6. Passes plotting_data for PCA"
            pcaModule -> ldaModule "7. Provides pca_result (scores, loadings)"
            pcaModule -> clusterModule "8. Provides pca_result for dimensionality reduction"
            ldaModule -> clusterModule "9. Provides lda_result (discriminant scores)"
            autoLayout lr
        }

        styles {
            element "Person" {
                shape Person
                background #08427B
                color #ffffff
            }
            element "Software System" {
                background #1168BD
                color #ffffff
            }
            element "Container" {
                background #438DD5
                color #ffffff
            }
            element "Component" {
                background #85BBF0
                color #000000
            }
            element "Database" {
                shape Cylinder
            }
            element "WebBrowser" {
                shape WebBrowser
            }
            element "External" {
                background #999999
                color #ffffff
            }
        }
    }

}
