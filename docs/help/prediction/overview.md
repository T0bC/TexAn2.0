## Prediction

The **Prediction** tab allows you to apply a previously trained model to new (unknown) data.

### Workflow

1. **Upload a model bundle** (.rds) — exported from the PCA, LDA, QDA, or MDA tab. The bundle contains the trained model, preprocessing parameters, and training data summary.
2. **Upload unknown data** (CSV or Excel) — the file must contain the same measurement columns used during training.
3. Click **Run Prediction** to preprocess the unknown data using the stored parameters and generate predictions.

### What the bundle contains

- The fitted model object (prcomp, lda, qda, or mda)
- Skewness transformation parameters (if applied during training)
- Scaling parameters (center/scale values)
- Training data and column metadata
- Analysis type and app version

### Supported analysis types

| Type | Output |
|------|--------|
| **PCA** | PC scores for unknown samples projected into the training PC space |
| **LDA** | Predicted class, posterior probabilities, LD scores |
| **MDA** | Predicted class, posterior probabilities, discriminant variates |
| **QDA** | Predicted class, posterior probabilities, LD scores (via companion LDA) |

### Overlay plot

The interactive plot shows training samples (circles, semi-transparent) with the unknown samples overlaid (triangles, opaque). Confidence ellipses from the training data are preserved. Hover over unknown points to see predicted class and coordinates.

### Validation

Before prediction, the module checks:

- All required measurement columns are present
- Columns are numeric
- Value ranges are within plausible bounds (warns if unknowns exceed training range by >20%)

### Downloads

- **Excel** — prediction results table (sample labels, predicted class, posteriors, scores)
- **SVG / PNG** — overlay plot
