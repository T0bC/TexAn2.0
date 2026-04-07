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
- **Median Results Table**: Interactive table with median values per group, featuring:
  - **Excel-style column filters**: Dropdown filters on each metadata column to select specific groups (e.g., filter `SEX` to "Male" only, or select specific `SAMPLE_ID`s)
  - **"Select All" links**: Quick selection controls above each filter dropdown
- **Download**: Export the filtered/median-aggregated data as an XLSX file

**Analysis Pipeline**: Filters applied in the results table affect downstream modules — use column filters to subset data (e.g., remove specific individuals or select only certain groups) before proceeding to analysis.

Columns that vary within groups (e.g., measurement-specific metadata) are automatically removed during aggregation and listed in the summary.

##### Excel-Style Column Filtering

The results table includes interactive column filters that function like Excel's AutoFilter:

- **Metadata columns** (grouping columns, constant descriptive columns): Multi-select dropdowns to include/exclude specific values
- **Use cases**:
  - Remove specific individuals by deselecting `SAMPLE_ID` values
  - Filter to specific groups (e.g., `SEX` = "Male" only, or `SITE` = "Site_A")
  - Create custom subsets for downstream analysis
- **Propagation**: Active filters affect the data passed to downstream modules — only visible rows are included in the analysis pipeline
- **Convenience**: Click **All** above any filter to quickly select all values; individual items can then be unchecked

This filtering is independent of the quality filter and applies after median calculation, allowing flexible data subsetting without reprocessing.
