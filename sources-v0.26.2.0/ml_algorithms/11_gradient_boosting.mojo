"""
Author: Ahmet Aksoy
Date: 2026-03-24
Mojo version: 0.26.2 | Python 3.12 | Ubuntu

Gradient Boosting Regressor — Pure Mojo Implementation
=======================================================

Gradient Boosting builds an ensemble of weak learners (shallow trees)
sequentially. Each new tree fits the residuals (errors) of all
previous trees combined.

Algorithm:
  1. Initialize prediction with mean(y).
  2. For t = 1..n_estimators:
     a. Compute residuals: r_i = y_i - F_{t-1}(x_i)
     b. Fit a shallow decision tree to residuals
     c. Update: F_t(x) = F_{t-1}(x) + lr * tree_t(x)

Loss: MSE = (1/n) * Σ(y - F(x))²
Negative gradient of MSE = residuals = y - F(x).

Demo 1: Regression — house price prediction.
Demo 2: Compare baseline, n_estimators effect.
"""

from std.math import sqrt


# ------------------------------------------------------------------ #
# Helpers
# ------------------------------------------------------------------ #

fn mean_of_indices(y: List[Float64], indices: List[Int]) -> Float64:
    """Compute mean of y at given indices."""
    if len(indices) == 0:
        return 0.0
    var s: Float64 = 0.0
    for i in range(len(indices)):
        s += y[indices[i]]
    return s / Float64(len(indices))


fn best_split_threshold(x: List[Float64], y: List[Float64],
                         indices: List[Int]) -> Float64:
    """Find threshold minimizing weighted variance. Returns threshold."""
    var n        = len(indices)
    var best_thr = x[indices[0]]
    var best_var = 1.0e38

    for i in range(n):
        var thr       = x[indices[i]]
        var ls: Float64 = 0.0
        var rs: Float64 = 0.0
        var ln = 0
        var rn = 0
        for j in range(n):
            if x[indices[j]] <= thr:
                ls += y[indices[j]]
                ln += 1
            else:
                rs += y[indices[j]]
                rn += 1
        if ln == 0 or rn == 0:
            continue
        var lm = ls / Float64(ln)
        var rm = rs / Float64(rn)
        var lv: Float64 = 0.0
        var rv: Float64 = 0.0
        for j in range(n):
            if x[indices[j]] <= thr:
                var d = y[indices[j]] - lm
                lv += d * d
            else:
                var d = y[indices[j]] - rm
                rv += d * d
        var tv = (lv + rv) / Float64(n)
        if tv < best_var:
            best_var = tv
            best_thr = thr
    return best_thr


fn build_tree(x: List[Float64], y: List[Float64],
              indices: List[Int], depth: Int,
              max_depth: Int, min_samples: Int,
              mut thresholds: List[Float64],
              mut lefts     : List[Int],
              mut rights    : List[Int],
              mut values    : List[Float64]) -> Int:
    """
    Recursively build regression tree into parallel lists.
    Returns index of created node.
    Leaf nodes have threshold = -1e38.
    """
    var pred = mean_of_indices(y, indices)

    if depth >= max_depth or len(indices) < min_samples:
        thresholds.append(-1e38)
        lefts.append(-1)
        rights.append(-1)
        values.append(pred)
        return len(thresholds) - 1

    var thr = best_split_threshold(x, y, indices)

    var left_idx  = List[Int]()
    var right_idx = List[Int]()
    for i in range(len(indices)):
        if x[indices[i]] <= thr:
            left_idx.append(indices[i])
        else:
            right_idx.append(indices[i])

    if len(left_idx) == 0 or len(right_idx) == 0:
        thresholds.append(-1e38)
        lefts.append(-1)
        rights.append(-1)
        values.append(pred)
        return len(thresholds) - 1

    thresholds.append(thr)
    lefts.append(-1)
    rights.append(-1)
    values.append(pred)
    var node_idx = len(thresholds) - 1

    var li = build_tree(x, y, left_idx,  depth + 1,
                        max_depth, min_samples,
                        thresholds, lefts, rights, values)
    var ri = build_tree(x, y, right_idx, depth + 1,
                        max_depth, min_samples,
                        thresholds, lefts, rights, values)
    lefts[node_idx]  = li
    rights[node_idx] = ri
    return node_idx


fn predict_one_tree(thresholds: List[Float64],
                    lefts     : List[Int],
                    rights    : List[Int],
                    values    : List[Float64],
                    xq        : Float64) -> Float64:
    """Predict using one regression tree."""
    var idx = 0
    var go  = thresholds[idx] > -1e37
    while go:
        if xq <= thresholds[idx]:
            idx = lefts[idx]
        else:
            idx = rights[idx]
        go = thresholds[idx] > -1e37
    return values[idx]


fn mse(y_true: List[Float64], y_pred: List[Float64]) -> Float64:
    """Mean Squared Error."""
    var total: Float64 = 0.0
    for i in range(len(y_true)):
        var d = y_true[i] - y_pred[i]
        total += d * d
    return total / Float64(len(y_true))


fn rmse(y_true: List[Float64], y_pred: List[Float64]) -> Float64:
    """Root Mean Squared Error."""
    return sqrt(mse(y_true, y_pred))


fn r2_score(y_true: List[Float64], y_pred: List[Float64]) -> Float64:
    """R² score."""
    var y_mean: Float64 = 0.0
    for i in range(len(y_true)):
        y_mean += y_true[i]
    y_mean /= Float64(len(y_true))
    var ss_res: Float64 = 0.0
    var ss_tot: Float64 = 0.0
    for i in range(len(y_true)):
        var dr = y_true[i] - y_pred[i]
        var dt = y_true[i] - y_mean
        ss_res += dr * dr
        ss_tot += dt * dt
    if ss_tot == 0.0:
        return 1.0
    return 1.0 - ss_res / ss_tot


fn pad_left(s: String, width: Int) -> String:
    """Left-pad a string with spaces."""
    var result = s
    var i = len(result)
    while i < width:
        result = " " + result
        i += 1
    return result


fn float_str(val: Float64, decimals: Int) -> String:
    """Format float to fixed decimal places."""
    var sign = ""
    var v    = val
    if v < 0.0:
        sign = "-"
        v    = -v
    var factor = 1.0
    for _ in range(decimals):
        factor *= 10.0
    var rounded  = Int(v * factor + 0.5)
    var int_part = rounded // Int(factor)
    var dec_part = rounded  % Int(factor)
    var dec_str  = String(dec_part)
    while len(dec_str) < decimals:
        dec_str = "0" + dec_str
    return sign + String(int_part) + "." + dec_str


# ------------------------------------------------------------------ #
# Gradient Boosting Regressor
# ------------------------------------------------------------------ #

struct GradientBoosting:
    """
    Gradient Boosting Regressor.
    Sequentially fits shallow trees to residuals.
    Trees stored as parallel flat lists — no intermediate structs.
    """
    var n_estimators: Int
    var lr          : Float64
    var max_depth   : Int
    var base_pred   : Float64
    var loss_history: List[Float64]

    var tree_thresholds: List[List[Float64]]
    var tree_lefts     : List[List[Int]]
    var tree_rights    : List[List[Int]]
    var tree_values    : List[List[Float64]]

    fn __init__(out self, n_estimators: Int = 100,
                lr: Float64 = 0.1, max_depth: Int = 3):
        self.n_estimators    = n_estimators
        self.lr              = lr
        self.max_depth       = max_depth
        self.base_pred       = 0.0
        self.loss_history    = List[Float64]()
        self.tree_thresholds = List[List[Float64]]()
        self.tree_lefts      = List[List[Int]]()
        self.tree_rights     = List[List[Int]]()
        self.tree_values     = List[List[Float64]]()

    fn fit(mut self, x: List[Float64], y: List[Float64]):
        """Train gradient boosting model."""
        var n = len(x)

        self.tree_thresholds = List[List[Float64]]()
        self.tree_lefts      = List[List[Int]]()
        self.tree_rights     = List[List[Int]]()
        self.tree_values     = List[List[Float64]]()
        self.loss_history    = List[Float64]()

        # Initialize with mean
        var y_sum: Float64 = 0.0
        for i in range(n):
            y_sum += y[i]
        self.base_pred = y_sum / Float64(n)

        # Current predictions
        var F = List[Float64]()
        for _ in range(n):
            F.append(self.base_pred)

        var all_indices = List[Int]()
        for i in range(n):
            all_indices.append(i)

        for _ in range(self.n_estimators):
            # Residuals
            var residuals = List[Float64]()
            for i in range(n):
                residuals.append(y[i] - F[i])

            # Build tree into local lists
            var thresholds = List[Float64]()
            var lefts      = List[Int]()
            var rights     = List[Int]()
            var values     = List[Float64]()

            _ = build_tree(x, residuals, all_indices, 0,
                           self.max_depth, 2,
                           thresholds, lefts, rights, values)

            # Update predictions
            for i in range(n):
                F[i] += self.lr * predict_one_tree(
                    thresholds, lefts, rights, values, x[i]
                )

            # MSE loss
            var loss_val: Float64 = 0.0
            for i in range(n):
                var d = y[i] - F[i]
                loss_val += d * d
            self.loss_history.append(loss_val / Float64(n))

            # Store tree
            self.tree_thresholds.append(thresholds^)
            self.tree_lefts.append(lefts^)
            self.tree_rights.append(rights^)
            self.tree_values.append(values^)

    fn predict_single(self, xq: Float64) -> Float64:
        """Predict for a single input."""
        var result = self.base_pred
        for t in range(self.n_estimators):
            result += self.lr * predict_one_tree(
                self.tree_thresholds[t],
                self.tree_lefts[t],
                self.tree_rights[t],
                self.tree_values[t],
                xq
            )
        return result

    fn predict(self, x: List[Float64]) -> List[Float64]:
        """Predict for all inputs."""
        var preds = List[Float64]()
        for i in range(len(x)):
            preds.append(self.predict_single(x[i]))
        return preds^


# ------------------------------------------------------------------ #
# Demo
# ------------------------------------------------------------------ #

fn main():
    print("=" * 62)
    print("  Gradient Boosting Regressor")
    print("  Demo: House Price Prediction (m2 -> 1000 TL)")
    print("=" * 62)

    var x_raw = List[Float64]()
    x_raw.append(50.0);  x_raw.append(65.0);  x_raw.append(70.0)
    x_raw.append(80.0);  x_raw.append(85.0);  x_raw.append(90.0)
    x_raw.append(95.0);  x_raw.append(100.0); x_raw.append(110.0)
    x_raw.append(120.0); x_raw.append(130.0); x_raw.append(140.0)
    x_raw.append(150.0); x_raw.append(160.0); x_raw.append(180.0)
    x_raw.append(200.0); x_raw.append(220.0); x_raw.append(250.0)

    var y_raw = List[Float64]()
    y_raw.append(450.0);  y_raw.append(520.0);  y_raw.append(580.0)
    y_raw.append(620.0);  y_raw.append(680.0);  y_raw.append(720.0)
    y_raw.append(750.0);  y_raw.append(800.0);  y_raw.append(870.0)
    y_raw.append(950.0);  y_raw.append(1020.0); y_raw.append(1100.0)
    y_raw.append(1180.0); y_raw.append(1250.0); y_raw.append(1420.0)
    y_raw.append(1600.0); y_raw.append(1780.0); y_raw.append(2050.0)

    var n = len(x_raw)
    print("\nDataset : " + String(n) + " houses")

    # Baseline
    var y_sum: Float64 = 0.0
    for i in range(n):
        y_sum += y_raw[i]
    var y_mean = y_sum / Float64(n)
    var baseline = List[Float64]()
    for _ in range(n):
        baseline.append(y_mean)

    print("\n--- Baseline (mean = " + float_str(y_mean, 0) + "K TL) ---")
    print("RMSE : " + float_str(rmse(y_raw, baseline), 1))
    print("R2   : " + float_str(r2_score(y_raw, baseline), 4))

    # Gradient Boosting
    var model = GradientBoosting(n_estimators=100, lr=0.1, max_depth=3)
    model.fit(x_raw, y_raw)
    var gb_preds = model.predict(x_raw)

    print("\n--- Gradient Boosting (100 trees, lr=0.1, depth=3) ---")
    print("RMSE : " + float_str(rmse(y_raw, gb_preds), 1))
    print("R2   : " + float_str(r2_score(y_raw, gb_preds), 4))

    print("\n--- Predictions vs Actual ---")
    print("m2      Actual(K)  Predicted(K)  Error(%)")
    print("-" * 48)
    for i in range(n):
        var pred      = gb_preds[i]
        var actual    = y_raw[i]
        var error_pct = abs(pred - actual) / actual * 100.0
        print(pad_left(String(Int(x_raw[i])), 6) +
              pad_left(String(Int(actual)), 9) +
              pad_left(String(Int(pred)), 12) +
              pad_left(float_str(error_pct, 1), 8) + "%")

    print("\n--- Loss Curve (every 10 trees) ---")
    for i in range(0, len(model.loss_history), 10):
        print("Tree " + pad_left(String(i + 1), 4) + " : " +
              float_str(model.loss_history[i], 2))

    print("\n--- Effect of n_estimators ---")
    print("Trees   RMSE      R2")
    print("-" * 32)
    var tree_counts = List[Int]()
    tree_counts.append(1);   tree_counts.append(5)
    tree_counts.append(10);  tree_counts.append(50)
    tree_counts.append(100); tree_counts.append(200)
    for i in range(len(tree_counts)):
        var nt = tree_counts[i]
        var m  = GradientBoosting(n_estimators=nt, lr=0.1, max_depth=3)
        m.fit(x_raw, y_raw)
        var p  = m.predict(x_raw)
        print(pad_left(String(nt), 5) + "   " +
              pad_left(float_str(rmse(y_raw, p), 1), 7) + "   " +
              float_str(r2_score(y_raw, p), 4))

    print("\n--- New House Predictions ---")
    var test_sizes = List[Float64]()
    test_sizes.append(75.0);  test_sizes.append(115.0)
    test_sizes.append(175.0); test_sizes.append(300.0)
    for i in range(len(test_sizes)):
        var m2   = test_sizes[i]
        var pred = model.predict_single(m2)
        print(String(Int(m2)) + " m2  ->  " + String(Int(pred)) + "K TL")

    print("\nGradient Boosting completed.")
    print("=" * 62)
