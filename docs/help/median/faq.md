#### Frequently Asked Questions

<details>
<summary>Why are some columns removed during median calculation?</summary>

Descriptive columns (UPPERCASE names like `SAMPLE_ID`, `SITE`) that **vary within groups** are automatically removed. This happens because:

- Median calculation aggregates multiple rows into one per group
- A column like `MEASUREMENT_TYPE` might differ for each row within a sample
- It is impossible to assign a single value to the aggregated row

**Solution**: Only columns that are constant within your grouping level will be retained. If you need to preserve varying metadata, use a different grouping level or process data in separate batches.

</details>

<details>
<summary>What is the difference between grouping and not grouping?</summary>

| Mode | Behavior | Use Case |
|------|----------|----------|
| **No grouping** | Quality filter only; returns all filtered rows | Review/filter data without aggregation |
| **With grouping** | Calculates median per group; one row per unique group combination | Summarize replicate measurements per sample |

Example: If you have 5 measurements per sample and group by `SAMPLE_ID`, the result will have one row per sample with median values across the 5 replicates.

</details>

<details>
<summary>How does group-aware quality filtering work?</summary>

When grouping is enabled, the filter preserves groups that have only low-quality measurements:

- **Group with good + bad values**: Bad rows removed, group retained with good values only
- **Group with only bad values**: Entire group kept intact (not removed from dataset)

This prevents losing samples entirely when all their measurements happen to be low quality. Without grouping, bad rows are simply deleted.

</details>

<details>
<summary>My quality column is not detected correctly</summary>

Quality column auto-detection may misclassify in these cases:

- **Integer codes (1, 2, 3, 4, 5) with >10 unique values**: Treated as numeric instead of categorical
- **Percentage stored as 0-100 with few unique values**: May be detected as categorical

**Workaround**: The filter interface will still work — just select the appropriate values or threshold manually. The detection is for convenience only.

</details>

<details>
<summary>What threshold should I use for quality filtering?</summary>

Guidelines by quality column type:

| Type | Typical Good Threshold | Interpretation |
|------|----------------------|----------------|
| **Percentage (0-1)** | ≥0.8 | 80% or higher quality |
| **Percentage (0-100)** | ≥80 | 80% or higher quality |
| **Numeric (e.g., signal-to-noise)** | Domain-specific | Higher values = better quality |
| **Categorical (grades)** | Exclude known bad grades | e.g., exclude "Poor", "Failed" |

When in doubt, compare the distribution of quality values in your data preview to identify a natural cutoff.

</details>

<details>
<summary>Why is the median result table empty?</summary>

Possible causes:

- **No measurement columns**: Check that your data has mixed-case column names (e.g., `Asfc`, not `ASFC`)
- **All values filtered out**: Quality filter too aggressive; check filter settings
- **No numeric data after filtering**: All rows removed by quality or grouping constraints

Check the Processing Summary for messages about what was filtered or removed.

</details>

<details>
<summary>Can I group by measurement columns?</summary>

No — grouping is limited to **descriptive columns** (UPPERCASE names). Measurement columns contain the values being aggregated, so they cannot define the groups.

If you need to group by a measurement-derived category, create a categorical version in your source data (e.g., `SIZE_CATEGORY` with values "Small"/"Medium"/"Large" derived from a numeric measurement).

</details>

<details>
<summary>How are missing values (NA) handled in median calculation?</summary>

- **Median calculation**: `median(x, na.rm = TRUE)` — NAs are ignored per group
- **Quality filtering**: NAs in the quality column are treated as **bad values** (below threshold)
- **Result**: If all values in a group are NA, the median will be NA for that measurement

</details>

<details>
<summary>The downloaded file does not match what I see in the table</summary>

The download button exports the **DT-filtered data** — meaning any active column filters in the table are applied to the export. To download all data:

1. Clear all column filters in the table header (select all values in each dropdown)
2. Click **Download Filtered Data**

The downloaded file will match the currently visible table rows.

</details>

<details>
<summary>Can I use multiple quality columns?</summary>

No — only one quality column can be selected at a time. To combine multiple quality criteria:

1. Pre-filter your data externally, or
2. Create a composite quality score in your source data (e.g., `OVERALL_QUALITY` derived from multiple metrics)

</details>
