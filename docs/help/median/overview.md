#### Median Calculation

Calculate median values for measurement columns, with optional quality filtering and grouping to aggregate data by sample structure.

##### Grouping Configuration

Select one or more **descriptive columns** (e.g., `SAMPLE_ID`, `SPECIES`, `SITE`) to define how measurements are aggregated:

- **Without grouping**: Filtered data is returned as-is (no median calculation)
- **With grouping**: Medians are computed per unique group combination
- Multiple grouping columns create hierarchical groupings (e.g., Site + Period)

The info panel shows the number of unique groups identified and average rows per group.

##### Quality Filtering

Optionally filter out low-quality measurements before median calculation:

- Select a **quality column** from the dropdown (or choose "None" to skip filtering)
- The system auto-detects quality column type and presents appropriate filter controls:
  - **Categorical**: Select specific "bad" quality values to exclude
  - **Numeric/Percentage**: Set a minimum threshold (values below are excluded)

##### Results Output

After configuration, the main panel displays:

- **Processing Summary**: Grouping columns applied, any columns removed, and quality filter status
- **Median Results Table**: Interactive table with median values per group, featuring Excel-style column filters on metadata columns (e.g., select specific `SAMPLE_ID`s or filter `SEX` to "Male" only)
- **Download**: Export the filtered/median-aggregated data as an XLSX file

**Analysis Pipeline**: Column filters applied in the results table happen after median calculation and affect the data passed to downstream modules — use them to subset data before proceeding to analysis.

Columns that vary within groups (e.g., measurement-specific metadata) are automatically removed during aggregation and listed in the summary.
