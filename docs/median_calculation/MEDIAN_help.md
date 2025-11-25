When you want to calculate the median of multiple measurements, you need to select the columns that define the **data grouping**. You can choose multiple columns for this purpose, and the median value is calculated for each group. Please refer to the **Example Data** below.

#### Example 1

Here’s an example. Let’s say you have a table with the columns `ID`, `SAMPLE`, `GROUP`, `TREATMENT`, `SEX`, `MEASUREM`, `Quality` and a `value` column. You want to calculate the median of the repeated measurement values which are defined as such in the `MEASUREM` column. To calculate the median correctly, you could select at the `ID` column. If you don't have an column like this, you'll have to **select all meaningful columns** which identifies your grouping structure. In the *Example Data* you would select `SAMPLE`, `GROUP`, `TREATMENT` and `SEX`, since this would separate the groups meaningful or in the same way as by selecting `ID`.

The algorithm then finds the columns that *differs* within the selected grouping (`MEASUREM` in this case), displays them in a popup message and removes them from the data set. If there is a column in the popup message that is important to retain, or should not be different within your grouping scenario, check your data or select it as well.

**Why Are Some Columns Removed?**

Columns that are not selected for grouping but have **varying levels** within the active group are removed. This is because these columns may not be relevant for further analysis. They introduce variability within the group that is not accounted for when calculating the median. The algorithm is calculating the median of values, and therefore some rows are merged. If we merge cells we expect them to have the same information, right? If they don't have the same information then we can not merge them.

* Imagine in the Sample Data there would be a `DEVICE` column. In this column the name of the measurement device is defined like *Camera-A* or *Camera-B*. And for some reason measurement 1 was taken with Camera-A and measurement 2 with Camera-B, then this would (in this example) not be a meaningful grouping parameter. And since it isn't relevant for the statistical analysis then we may remove this column, or you include it, if this is a relevant information.

::: {style="border:1px solid black; padding: 10px; color: red; font-size: 0.9em"}
Remember, the goal is to calculate the median for each group of data. If a column introduces variability within a group but is not included in the grouping definition, it could distort the calculation of the median. If you do not want a column to be deleted, you should select it when defining the data grouping. This is especially important if you expect that this column meaningfully divides the data into groups.
:::

#### Example 2

Let’s say you want to calculate the median for the `SEX` for each `GROUP` and `TREATMENT` combination. In this case, you would select `GROUP` and `TREATMENT` as your grouping columns.

Here’s why the `ID`, `MEASUREM`, and `SEX` columns are not relevant in this context:

-   `ID`: This column is used to identify individual samples. However, when you’re calculating the median for each GROUP and TREATMENT combination, you’re looking at the data at a higher level. The individual sample IDs are not relevant because you’re not comparing individual samples, but groups of samples.
-   `MEASUREM`: This column contains the repeated measurements on the same samples. Again, since you’re looking at the data at the group level, these individual measurements are not relevant. You’re interested in the median measurement for each `SEX`, not the individual measurements.
-   `SEX`: This might seem counterintuitive, since you’re calculating the median for `SEX`. However, once you’ve calculated the median, the original `SEX` values are no longer needed. The median gives you a summary of the `SEX` distribution for each group, so the individual `SEX` values are not relevant for further analysis.
