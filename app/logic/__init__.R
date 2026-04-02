# Logic: application code independent from Shiny.
# https://go.appsilon.com/rhino-project-structure
#
# Submodule structure:
#   shared/       - Cross-cutting utilities (error_handling, column_utils,
#                   data_utils, logging, settings)
#   load_data/    - Data loading and example dataset logic
#   summary/      - Summary statistics computation
#   cluster/      - Cluster analysis
#   lda/          - Linear Discriminant Analysis
#   median/       - Median calculation and quality filtering
#   pca/          - Principal Component Analysis
#   plotting/     - Scatter plots and data visualisation
#   prediction/   - Model prediction
#   preprocessing/ - NA handling, normalisation, skewness transforms
#   statistics/   - Parametric, non-parametric, and robust tests
