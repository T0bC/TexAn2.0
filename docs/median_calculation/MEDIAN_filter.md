Before calculating medians, you can filter the data based on quality measurements and grouping columns (such as sample ID) - OPTIONAL.

* choose a quality column containing values that represent measurement quality (e.g., 1 = very good, 4 = bad, or percentages, -  0.75 or 75).
* select one or more values considered bad quality. All other values will be kept as good data.
* Optionally, define grouping columns to organize repeated measurements for the same sample or condition.

**How filtering works:**

* The app checks each group for bad and good values.
* If only bad values are found in a group, they are retained.
* If both good and bad are present, only the good ones are kept.

**How median calculation works:**

* Medians are computed for measurement columns within each group.
* Columns that vary within the same group and aren't selected for grouping will be removed, since they can't reliably describe the group.

For step-by-step examples and best practices, check the help section.