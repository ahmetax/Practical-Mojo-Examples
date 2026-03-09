"""
Author: Ahmet Aksoy
Date: 2026-03-08
Revision Date: 2026-03-08
Mojo version no: 0.26.1
AI: Claude Sonnet 4.6

Description:
    Time series analysis in Mojo using NumPy via PythonObject.

    Simulates a server CPU usage dataset (24 hours, one reading per minute)
    and applies three common analysis techniques:

      1. Moving average    — smooth out short-term fluctuations to reveal trend
      2. Z-score detection — flag readings that deviate significantly from mean
      3. IQR detection     — flag readings outside the interquartile range
                             More robust than Z-score for skewed distributions.

    Both anomaly detection methods are widely used in monitoring systems,
    IoT sensor data, financial data, and log analysis.

    A synthetic dataset is generated at runtime — no external file needed.
    Results are saved to /tmp/cpu_analysis.csv for further inspection.

    NumPy slice operations are delegated to ts_helpers.py since
    multi-dimensional slicing is not directly supported in Mojo.

    Both files must be in the same directory:
      numpy_timeseries.mojo
      ts_helpers.py

Requirements:
    pip install numpy
"""

from python import Python, PythonObject


fn generate_cpu_data(helpers: PythonObject) raises -> PythonObject:
    """
    Generate synthetic CPU usage data for 24 hours (1440 minutes).
    The signal has three components:
      - Base load: a slow sinusoidal pattern (daily cycle)
      - Random noise: normal variation in CPU usage
      - Injected spikes: sudden anomalies at known positions.

    Returns a 1D NumPy float64 array of values in range [0, 100].
    """
    np: PythonObject = Python.import_module("numpy")

    var n_points: Int = 1440  # 24 hours x 60 minutes

    # Time axis: 0 to 2*pi covers one full daily cycle
    t: PythonObject = np.linspace(0, Python.evaluate("2 * 3.14159265"), n_points)

    # Base load: oscillates between ~20% and ~60%
    base: PythonObject  = 40.0 + 20.0 * np.sin(t)

    # Random noise: standard deviation of 5%
    np.random.seed(42)
    noise: PythonObject = np.random.normal(0, 5, n_points)

    # Combine base + noise, clip to valid CPU range [0, 100]
    data: PythonObject = np.clip(base + noise, 0, 100)

    # Inject anomalous spikes at known positions
    # These simulate sudden load spikes (e.g. backup jobs, traffic bursts)
    helpers.set_values(data, 200,  95.0)   # spike at minute 200
    helpers.set_values(data, 201,  98.0)
    helpers.set_values(data, 202,  97.0)
    helpers.set_values(data, 600,   2.0)   # sudden drop at minute 600
    helpers.set_values(data, 601,   1.5)
    helpers.set_values(data, 900,  96.0)   # another spike at minute 900
    helpers.set_values(data, 901,  99.0)
    helpers.set_values(data, 902,  97.5)

    print("Generated", n_points, "data points (24h CPU usage simulation).")
    print("  Injected spikes at minutes: 200-202, 600-601, 900-902")
    return data


fn moving_average(helpers: PythonObject, data: PythonObject, window: Int) raises -> PythonObject:
    """
    Compute the moving average of a time series using a sliding window.

    Each output value is the mean of the surrounding `window` data points.
    This smooths out noise while preserving the underlying trend.

    Larger window -> smoother curve, but lags more behind sudden changes.
    Smaller window -> more responsive, but noisier.

    Uses np.convolve() with a uniform kernel for efficiency.
    The 'valid' mode returns only points where the window fully overlaps,
    so the result is shorter than the input by (window - 1) points.
    """
    np: PythonObject = Python.import_module("numpy")

    # Uniform kernel: each element contributes equally to the average
    kernel: PythonObject = np.ones(window) / window
    smoothed: PythonObject = np.convolve(data, kernel, mode="valid")

    print("Moving average computed.")
    print("  Window size :", window, "minutes")
    print("  Input length:", Int(Float64(String(len(data)))))
    print("  Output length:", Int(Float64(String(len(smoothed)))))
    return smoothed


fn detect_anomalies_zscore(data: PythonObject, threshold: Float64) raises -> PythonObject:
    """
    Detect anomalies using the Z-score method.

    Z-score measures how many standard deviations a point is from the mean:
      z = (x - mean) / std

    Points with |z| > threshold are flagged as anomalies.
    Common threshold values: 2.0 (loose), 2.5 (moderate), 3.0 (strict).

    Assumes the data is approximately normally distributed.
    Less effective for heavily skewed data — use IQR method instead.

    Returns a boolean array: True where anomalies are detected.
    """
    np: PythonObject = Python.import_module("numpy")

    mean: PythonObject   = np.mean(data)
    std: PythonObject    = np.std(data)
    z_scores: PythonObject = np.abs((data - mean) / std)
    anomalies: PythonObject = z_scores > threshold

    var count: Int = Int(Float64(String(np.sum(anomalies))))
    var mean_val: Float64 = Float64(String(mean))
    var std_val: Float64  = Float64(String(std))

    print("Z-score anomaly detection.")
    print("  Mean     :", mean_val)
    print("  Std dev  :", std_val)
    print("  Threshold: |z| >", threshold)
    print("  Anomalies found:", count)
    return anomalies


fn detect_anomalies_iqr(data: PythonObject, factor: Float64) raises -> PythonObject:
    """
    Detect anomalies using the Interquartile Range (IQR) method.

    IQR = Q3 - Q1  (the middle 50% of the data)
    Lower fence = Q1 - factor * IQR
    Upper fence = Q3 + factor * IQR

    Points outside the fences are flagged as anomalies.
    Standard factor is 1.5 (Tukey's method). Use 3.0 for extreme outliers only.

    More robust than Z-score for skewed or non-normal distributions
    because it is based on percentiles rather than mean/std.

    Returns a boolean array: True where anomalies are detected.
    """
    np: PythonObject = Python.import_module("numpy")

    q1: PythonObject    = np.percentile(data, 25)
    q3: PythonObject    = np.percentile(data, 75)
    iqr: PythonObject   = q3 - q1
    lower: PythonObject = q1 - factor * iqr
    upper: PythonObject = q3 + factor * iqr

    anomalies: PythonObject = (data < lower) | (data > upper)

    var count: Int       = Int(Float64(String(np.sum(anomalies))))
    var q1_val: Float64  = Float64(String(q1))
    var q3_val: Float64  = Float64(String(q3))
    var iqr_val: Float64 = Float64(String(iqr))
    var lo_val: Float64  = Float64(String(lower))
    var hi_val: Float64  = Float64(String(upper))

    print("IQR anomaly detection.")
    print("  Q1:", q1_val, " Q3:", q3_val, " IQR:", iqr_val)
    print("  Lower fence:", lo_val, " Upper fence:", hi_val)
    print("  Factor     :", factor)
    print("  Anomalies found:", count)
    return anomalies


fn print_anomaly_minutes(helpers: PythonObject, anomalies: PythonObject, label: String) raises -> None:
    """
    Print the minute indices where anomalies were detected.
    Confirms that detection found the injected spikes.
    """
    np: PythonObject = Python.import_module("numpy")

    indices: PythonObject = np.where(anomalies)[0]
    var count: Int = Int(Float64(String(len(indices))))

    print("  Anomaly minutes (", label, ") — total:", count)
    # Print first 15 at most to keep output readable
    var show: Int = count if count < 15 else 15
    for i in range(show):
        var minute: Int = Int(Float64(String(helpers.get_value(indices, i))))
        var marker: String = " <-- injected" if (
            (minute >= 200 and minute <= 202) or
            (minute >= 600 and minute <= 601) or
            (minute >= 900 and minute <= 902)
        ) else ""
        print("    minute", minute, marker)
    if count > 15:
        print("    ... and", count - 15, "more")


fn save_results(helpers: PythonObject, data: PythonObject,
                z_anomalies: PythonObject, iqr_anomalies: PythonObject,
                path: String) raises -> None:
    """
    Save the time series and anomaly flags to a CSV file.
    Columns: minute, cpu_usage, zscore_anomaly, iqr_anomaly.
    """
    builtins: PythonObject = Python.import_module("builtins")
    np: PythonObject       = Python.import_module("numpy")

    var n: Int = Int(Float64(String(len(data))))
    var f: PythonObject = builtins.open(path, "w")
    f.write("minute,cpu_usage,zscore_anomaly,iqr_anomaly\n")

    for i in range(n):
        var minute: String  = String(i)
        var cpu: String     = String(Float64(String(helpers.get_value(data, i))))
        var z_flag: String  = String(Bool(helpers.get_value(z_anomalies, i)))
        var iq_flag: String = String(Bool(helpers.get_value(iqr_anomalies, i)))
        f.write(minute + "," + cpu + "," + z_flag + "," + iq_flag + "\n")

    f.close()
    print("Results saved to:", path)


fn main() raises:
    var sys: PythonObject = Python.import_module("sys")
    sys.path.insert(0, ".")
    var helpers: PythonObject = Python.import_module("ts_helpers")

    print("=== Generating CPU Time Series Data ===")
    print()
    var data: PythonObject = generate_cpu_data(helpers)

    print()
    print("=== Moving Average (window = 15 min) ===")
    print()
    var smoothed: PythonObject = moving_average(helpers, data, 15)

    print()
    print("=== Anomaly Detection: Z-score (threshold = 2.5) ===")
    print()
    var z_anomalies: PythonObject = detect_anomalies_zscore(data, 2.5)
    print_anomaly_minutes(helpers, z_anomalies, "z-score")

    print()
    print("=== Anomaly Detection: IQR (factor = 1.5) ===")
    print()
    var iqr_anomalies: PythonObject = detect_anomalies_iqr(data, 1.5)
    print_anomaly_minutes(helpers, iqr_anomalies, "IQR")

    print()
    print("=== Saving Results ===")
    print()
    save_results(helpers, data, z_anomalies, iqr_anomalies,
                 "/tmp/cpu_analysis.csv")
