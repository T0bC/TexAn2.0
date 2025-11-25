We provide a mechanism to filter and analyze your data based on the quality of measurements. You may have to carry out the filtering **before the median** calculation. 

You will need to specify a **column** that represents the **quality** of each measurement. The quality column should contain indicators of `good` and `bad` measurements. For instance, you might use `1` to represent good measurements and `2` to represent poor ones. The qualtiy can also be expressed as a percentage value either in the form of `0.75` or `75`. Please have a look at the example data further down in this help section.

Additionally, you should specify a **grouping column**, which is often the unique sample ID, or a combination of multiple columns which then define the structure of the research design. This is particularly useful when a single sample has multiple associated measurements. If you don't have an unique sample ID or your data is by design more complex, than select those descriptive columns which separates the data into the smallest meaningful structure (*Read the example below carefully*).

The filtering algorithm works as follows:

1.  Grouping: The data is grouped based on the selected grouping column(s). This is done to handle samples with multiple measurements or complicated sub groups.
2.  Filtering: Within each group, the algorithm checks the *quality* of measurements. If a group contains both good and bad measurements, the bad ones are filtered out. However, if all measurements in a group are bad, they are retained. This is based on the principle that having some data, even of poor quality, is better than having no data at all.

#### Example

Consider a data-set with the following columns: `ID`, `SAMPLE`,  `GROUP`, `TREATMENT`, `SEX`, `MEASUREM`, `QUALITY`, and `value`. Each row in this data-set represents a unique measurement, and the `QUALITY` column indicates the quality of each measurement. For instance, a `QUALITY` value of `1` might represent a good measurement, while a `QUALITY` value of `2` might represent a poor one. 

For the algorithm to work correctly when you have groups in your data you have to **select at least one column** which *identifies* the groups. In this case the smallest meaningful structure identifier would be the `ID` column. If you don't have a column like this, then you would have to select a collection of descriptive columns. For instance `SAMPLE`, `GROUP`, `TREATMENT` and `SEX` (leave `MEASUREM`, because it would not meaningful divide the measurements into a group, right? - Have a look at the **Example Data** below).

Now we will exercise the actual **filtering**:

Let’s take a look at the two examples, `A5` and `A7`. 
* We have two measurements, both with a `QUALITY` value of `2`. In this case, since all measurements for `A5` are of poor quality, they are all retained in the data-set. This is based on the principle that having some data, even of poor quality, is better than having no data at all.

* On the other hand, for `A7`, let’s assume we have multiple measurements, some with a `QUALITY` value of `1` (good) and others with a `QUALITY` value of `2` (poor). In this case, the algorithm will filter out the poor measurements and only keep the good ones.

This filtering process is applied group-wise, meaning it is done separately for each unique `ID` or grouping column collection. This ensures that the quality of measurements is considered within the context of each unique sample or experiment, rather than across the entire data-set.

Remember, the specific values used to indicate good and bad measurements (`1` and `2` in this example) depend on what you have in your actual `QUALITY` column.