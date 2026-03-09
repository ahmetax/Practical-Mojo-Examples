"""
Author: Ahmet Aksoy
Date: 2026-03-08
Revision Date: 2026-03-08
Mojo version no: 0.26.1
AI: Claude Sonnet 4.6

Description:
    Data preprocessing for machine learning in Mojo using NumPy via PythonObject.

    Simulates a house price dataset with mixed feature types:
      - Numeric   : area (m2), age (years), distance to center (km), price
      - Categorical: neighborhood (A/B/C), condition (poor/fair/good/excellent)

    Four preprocessing steps are demonstrated:
      1. Missing value handling  — detect and fill NaN values
      2. Min-Max normalization   — scale features to [0, 1] range
      3. Z-score standardization — scale to mean=0, std=1
      4. One-hot encoding        — convert categorical to numeric columns

    These steps are standard in ML pipelines before feeding data to
    models like linear regression, SVM, or neural networks.
    Most models perform better (or require) normalized/standardized input.

    Results are saved to /tmp/ as separate CSV files for each step.

    NumPy slice and index operations are delegated to ml_helpers.py.

    Both files must be in the same directory:
      numpy_ml_preprocessing.mojo
      ml_helpers.py

Requirements:
    pip install numpy
"""

from python import Python, PythonObject


fn generate_dataset(helpers: PythonObject) raises -> PythonObject:
    """
    Generate a synthetic house price dataset as a NumPy float64 array.

    Columns (all numeric for NumPy storage):
      0: area_m2       — living area in square meters (50-200)
      1: age_years     — building age in years (0-50)
      2: distance_km   — distance to city center (1-30)
      3: price_1000    — price in thousands of currency units
      4: neighborhood  — encoded as 0=A, 1=B, 2=C
      5: condition     — encoded as 0=poor, 1=fair, 2=good, 3=excellent

    Ten rows with realistic value ranges.
    Two rows contain missing values (NaN) to demonstrate imputation.
    """
    np: PythonObject = Python.import_module("numpy")

    # area, age, distance, price, neighborhood, condition
    raw: PythonObject = np.array(Python.evaluate("""[
        [120.0, 10.0,  5.0, 450.0, 2.0, 3.0],
        [85.0,  25.0, 12.0, 280.0, 1.0, 1.0],
        [200.0,  3.0,  2.0, 820.0, 2.0, 3.0],
        [60.0,  40.0, 20.0, 150.0, 0.0, 0.0],
        [150.0, 15.0,  8.0, 520.0, 1.0, 2.0],
        [95.0,  30.0, 15.0, 240.0, 0.0, 1.0],
        [175.0,  5.0,  3.0, 680.0, 2.0, 3.0],
        [70.0,  35.0, 25.0, 180.0, 0.0, 0.0],
        [130.0, 20.0, 10.0, 390.0, 1.0, 2.0],
        [110.0, 12.0,  7.0, 410.0, 2.0, 2.0]
    ]"""), dtype=np.float64)

    # Inject NaN values to simulate missing data
    helpers.set_nan(raw, 1, 2)   # row 1, distance missing
    helpers.set_nan(raw, 5, 3)   # row 5, price missing

    print("Dataset generated: 10 rows x 6 columns.")
    print("  Columns: area_m2, age_years, distance_km, price_1000,")
    print("           neighborhood (0=A/1=B/2=C), condition (0-3)")
    print("  NaN injected at: row 1 col 2 (distance), row 5 col 3 (price)")
    return raw


fn handle_missing_values(helpers: PythonObject, data: PythonObject) raises -> PythonObject:
    """
    Detect and fill missing values (NaN) with the column mean.

    Mean imputation is the simplest strategy:
    replace each NaN with the average of the non-missing values
    in the same column. Suitable for numeric features with low
    percentage of missing values.

    Other strategies (not shown here):
      - Median imputation   : better for skewed distributions
      - Mode imputation     : for categorical features
      - Model-based filling : KNN or regression imputation
    """
    np: PythonObject = Python.import_module("numpy")

    var n_cols: Int = Int(Float64(String(data.shape[1])))
    filled: PythonObject = data.copy()

    print("Missing value imputation (strategy: column mean).")
    for col in range(n_cols):
        column: PythonObject = helpers.get_column(filled, col)
        nan_mask: PythonObject = np.isnan(column)
        var n_missing: Int = Int(Float64(String(np.sum(nan_mask))))

        if n_missing > 0:
            # Compute mean ignoring NaN values
            col_mean: PythonObject = np.nanmean(column)
            var mean_val: Float64  = Float64(String(col_mean))
            helpers.fill_nan(filled, col, mean_val)
            print("  Column", col, ": filled", n_missing, "NaN(s) with mean =", mean_val)

    return filled


fn minmax_normalize(helpers: PythonObject, data: PythonObject) raises -> PythonObject:
    """
    Apply Min-Max normalization to numeric columns (0-3).

    Formula: x_norm = (x - min) / (max - min)

    Result: all values in [0, 1] range.
    Preserves the relative distribution shape.

    Best for: algorithms sensitive to feature scale
    (KNN, SVM, neural networks).

    Categorical columns (4, 5) are left unchanged.
    """
    np: PythonObject = Python.import_module("numpy")

    normalized: PythonObject = data.copy()

    # Only normalize numeric columns 0-3
    print("Min-Max normalization applied to columns 0-3.")
    for col in range(4):
        column: PythonObject  = helpers.get_column(normalized, col)
        col_min: PythonObject = np.min(column)
        col_max: PythonObject = np.max(column)
        var mn: Float64 = Float64(String(col_min))
        var mx: Float64 = Float64(String(col_max))
        helpers.set_column(normalized, col, (column - col_min) / (col_max - col_min))
        print("  Column", col, ": min =", mn, " max =", mx)

    return normalized


fn zscore_standardize(helpers: PythonObject, data: PythonObject) raises -> PythonObject:
    """
    Apply Z-score standardization to numeric columns (0-3).

    Formula: x_std = (x - mean) / std

    Result: mean=0, std=1 for each column.
    Values typically fall in [-3, +3] range.

    Best for: algorithms that assume normally distributed input
    (linear regression, logistic regression, PCA).

    Unlike Min-Max, not bounded to [0, 1] — outliers remain visible.
    Categorical columns (4, 5) are left unchanged.
    """
    np: PythonObject = Python.import_module("numpy")

    standardized: PythonObject = data.copy()

    print("Z-score standardization applied to columns 0-3.")
    for col in range(4):
        column: PythonObject   = helpers.get_column(standardized, col)
        col_mean: PythonObject = np.mean(column)
        col_std: PythonObject  = np.std(column)
        var mean_val: Float64  = Float64(String(col_mean))
        var std_val: Float64   = Float64(String(col_std))
        helpers.set_column(standardized, col, (column - col_mean) / col_std)
        print("  Column", col, ": mean =", mean_val, " std =", std_val)

    return standardized


fn one_hot_encode(helpers: PythonObject, data: PythonObject) raises -> PythonObject:
    """
    One-hot encode the categorical columns (4=neighborhood, 5=condition).

    One-hot encoding replaces a categorical column with N binary columns,
    one per category. This avoids implying ordinal relationships between
    categories (e.g. A < B < C is not meaningful for neighborhoods).

    Neighborhood (col 4): 0=A, 1=B, 2=C  -> 3 binary columns
    Condition    (col 5): 0-3             -> 4 binary columns

    The original categorical columns are dropped from the result.
    Final shape: 10 rows x (4 numeric + 3 neighborhood + 4 condition) = 11 columns.
    """
    np: PythonObject = Python.import_module("numpy")

    # Keep only numeric columns 0-3
    numeric: PythonObject = helpers.get_columns(data, 0, 4)

    # One-hot encode neighborhood (col 4): 3 categories
    neighborhood: PythonObject = helpers.get_column(data, 4)
    n_hood_cols: PythonObject  = helpers.one_hot(neighborhood, 3)

    # One-hot encode condition (col 5): 4 categories
    condition: PythonObject    = helpers.get_column(data, 5)
    cond_cols: PythonObject    = helpers.one_hot(condition, 4)

    # Concatenate all columns horizontally
    result: PythonObject = np.concatenate(
        Python.evaluate("lambda a, b, c: (a, b, c)")(numeric, n_hood_cols, cond_cols),
        axis=1
    )

    var n_rows: Int = Int(Float64(String(result.shape[0])))
    var n_cols: Int = Int(Float64(String(result.shape[1])))
    print("One-hot encoding applied.")
    print("  Neighborhood: 1 column -> 3 binary columns (A, B, C)")
    print("  Condition   : 1 column -> 4 binary columns (poor, fair, good, excellent)")
    print("  Final shape :", n_rows, "rows x", n_cols, "columns")
    return result


fn save_csv(helpers: PythonObject, data: PythonObject,
            header: String, path: String) raises -> None:
    """Save a NumPy 2D array to a CSV file with the given header."""
    builtins: PythonObject = Python.import_module("builtins")

    var n_rows: Int = Int(Float64(String(data.shape[0])))
    var n_cols: Int = Int(Float64(String(data.shape[1])))
    var f: PythonObject = builtins.open(path, "w")
    f.write(header + "\n")

    for r in range(n_rows):
        var row_parts = List[String]()
        for c in range(n_cols):
            var val: Float64 = Float64(String(helpers.get_element(data, r, c)))
            row_parts.append(String(val))
        var line: String = ""
        for i in range(len(row_parts)):
            if i > 0:
                line += ","
            line += row_parts[i]
        f.write(line + "\n")

    f.close()
    print("Saved to:", path)


fn main() raises:
    var sys: PythonObject = Python.import_module("sys")
    sys.path.insert(0, ".")
    var helpers: PythonObject = Python.import_module("ml_helpers")

    print("=== Generating Dataset ===")
    print()
    var raw: PythonObject = generate_dataset(helpers)

    print()
    print("=== Handling Missing Values ===")
    print()
    var filled: PythonObject = handle_missing_values(helpers, raw)
    save_csv(helpers, filled,
        "area_m2,age_years,distance_km,price_1000,neighborhood,condition",
        "/tmp/ml_filled.csv")

    print()
    print("=== Min-Max Normalization ===")
    print()
    var normalized: PythonObject = minmax_normalize(helpers, filled)
    save_csv(helpers, normalized,
        "area_m2,age_years,distance_km,price_1000,neighborhood,condition",
        "/tmp/ml_normalized.csv")

    print()
    print("=== Z-score Standardization ===")
    print()
    var standardized: PythonObject = zscore_standardize(helpers, filled)
    save_csv(helpers, standardized,
        "area_m2,age_years,distance_km,price_1000,neighborhood,condition",
        "/tmp/ml_standardized.csv")

    print()
    print("=== One-Hot Encoding ===")
    print()
    var encoded: PythonObject = one_hot_encode(helpers, filled)
    save_csv(helpers, encoded,
        "area_m2,age_years,distance_km,price_1000,hood_A,hood_B,hood_C,cond_poor,cond_fair,cond_good,cond_excellent",
        "/tmp/ml_encoded.csv")

    print()
    print("=== All done! Output files in /tmp/ ===")
    print("  ml_filled.csv      — after missing value imputation")
    print("  ml_normalized.csv  — after Min-Max normalization")
    print("  ml_standardized.csv— after Z-score standardization")
    print("  ml_encoded.csv     — after one-hot encoding")
