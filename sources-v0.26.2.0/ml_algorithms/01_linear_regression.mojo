"""
Author: Ahmet Aksoy
Date: 2026-03-20
Mojo version: 0.26.2 | Python 3.12 | Ubuntu

Linear Regression — Pure Mojo Implementation
=============================================

Linear Regression models the linear relationship between one or more
independent variables and a continuous dependent variable.

Model:  y = w * x + b
        w: weight (slope)
        b: bias   (y-intercept)

Training: Optimize w and b using Gradient Descent
Loss:     MSE = (1/n) * Σ(y_pred - y_true)²

Gradients:
  dL/dw = (2/n) * Σ(y_pred - y_true) * x
  dL/db = (2/n) * Σ(y_pred - y_true)

Demo dataset: House price prediction
  x: area in square meters (m²)
  y: price in 1000 TL
"""


# ------------------------------------------------------------------ #
# Struct to hold normalization result
# ------------------------------------------------------------------ #

struct NormResult:
    """Result of Min-Max normalization."""
    var data   : List[Float64]
    var min_val: Float64
    var max_val: Float64

    fn __init__(out self, var data: List[Float64], min_val: Float64, max_val: Float64):
        self.data    = data^
        self.min_val = min_val
        self.max_val = max_val


# ------------------------------------------------------------------ #
# Helper functions
# ------------------------------------------------------------------ #

fn mean(data: List[Float64]) -> Float64:
    """Compute the mean of a list."""
    var total: Float64 = 0.0
    for i in range(len(data)):
        total += data[i]
    return total / Float64(len(data))


fn mse(y_true: List[Float64], y_pred: List[Float64]) -> Float64:
    """Compute Mean Squared Error."""
    var total: Float64 = 0.0
    var n = len(y_true)
    for i in range(n):
        var diff = y_pred[i] - y_true[i]
        total += diff * diff
    return total / Float64(n)


fn r2_score(y_true: List[Float64], y_pred: List[Float64]) -> Float64:
    """
    Compute R² (coefficient of determination).
    R² = 1 - SS_res / SS_tot
    1.0 = perfect prediction, 0.0 = as good as predicting the mean.
    """
    var y_mean = mean(y_true)
    var ss_res: Float64 = 0.0
    var ss_tot: Float64 = 0.0
    for i in range(len(y_true)):
        var diff_res = y_true[i] - y_pred[i]
        var diff_tot = y_true[i] - y_mean
        ss_res += diff_res * diff_res
        ss_tot += diff_tot * diff_tot
    if ss_tot == 0.0:
        return 1.0
    return 1.0 - (ss_res / ss_tot)


fn normalize(data: List[Float64]) -> NormResult:
    """
    Min-Max normalization: scale values to [0, 1].
    Helps gradient descent converge faster.
    """
    var min_val = data[0]
    var max_val = data[0]
    for i in range(len(data)):
        if data[i] < min_val:
            min_val = data[i]
        if data[i] > max_val:
            max_val = data[i]

    var normalized = List[Float64]()
    var range_val  = max_val - min_val
    for i in range(len(data)):
        if range_val == 0.0:
            normalized.append(0.0)
        else:
            normalized.append((data[i] - min_val) / range_val)

    return NormResult(normalized^, min_val, max_val)


fn pad_left(s: String, width: Int) -> String:
    """Left-pad a string with spaces to the given width."""
    var result = s
    var i = len(result)
    while i < width:
        result = " " + result
        i += 1
    return result


# ------------------------------------------------------------------ #
# Linear Regression — Gradient Descent
# ------------------------------------------------------------------ #

struct LinearRegression:
    """
    Single-variable Linear Regression model.
    Trained using Gradient Descent.
    """
    var weight      : Float64
    var bias        : Float64
    var lr          : Float64
    var epochs      : Int
    var loss_history: List[Float64]

    fn __init__(out self, lr: Float64 = 0.01, epochs: Int = 1000):
        self.weight       = 0.0
        self.bias         = 0.0
        self.lr           = lr
        self.epochs       = epochs
        self.loss_history = List[Float64]()

    fn fit(mut self, x: List[Float64], y: List[Float64]):
        """Train the model using Gradient Descent."""
        var n = Float64(len(x))

        for _ in range(self.epochs):
            # Forward pass — compute predictions
            var y_pred = List[Float64]()
            for i in range(len(x)):
                y_pred.append(self.weight * x[i] + self.bias)

            # Compute and record loss
            var loss = mse(y, y_pred)
            self.loss_history.append(loss)

            # Compute gradients
            var dw: Float64 = 0.0
            var db: Float64 = 0.0
            for i in range(len(x)):
                var error = y_pred[i] - y[i]
                dw += error * x[i]
                db += error
            dw = (2.0 / n) * dw
            db = (2.0 / n) * db

            # Update weights
            self.weight -= self.lr * dw
            self.bias   -= self.lr * db

    fn predict_single(self, x: Float64) -> Float64:
        """Predict the output for a single input value."""
        return self.weight * x + self.bias

    fn predict(self, x: List[Float64]) -> List[Float64]:
        """Predict outputs for a list of input values."""
        var preds = List[Float64]()
        for i in range(len(x)):
            preds.append(self.weight * x[i] + self.bias)
        return preds^


# ------------------------------------------------------------------ #
# Demo
# ------------------------------------------------------------------ #

fn main():
    print("=" * 60)
    print("  Linear Regression — Gradient Descent")
    print("  Demo: House Price Prediction (m2 -> 1000 TL)")
    print("=" * 60)

    # Dataset — (area m2, price 1000 TL)
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
    print("Area    : 50 - 250 m2")
    print("Price   : 450K - 2050K TL")

    # Normalize features and labels
    var xn = normalize(x_raw)
    var yn = normalize(y_raw)

    # Train the model
    var model = LinearRegression(lr=0.1, epochs=2000)
    model.fit(xn.data, yn.data)

    # Evaluate
    var y_pred_norm = model.predict(xn.data)
    var r2          = r2_score(yn.data, y_pred_norm)
    var final_loss  = model.loss_history[len(model.loss_history) - 1]

    print("\n--- Training Results ---")
    print("Epochs        : " + String(model.epochs))
    print("Learning Rate : " + String(model.lr))
    print("Final Loss    : " + String(final_loss))
    print("R2 Score      : " + String(r2))

    print("\n--- Model Parameters (normalized space) ---")
    print("Weight (w) : " + String(model.weight))
    print("Bias   (b) : " + String(model.bias))

    # Predictions vs actual
    print("\n--- Predictions vs Actual ---")
    print("m2      Actual(K TL)  Predicted(K TL)  Error(%)")
    print("-" * 55)

    var y_range = yn.max_val - yn.min_val
    var x_range = xn.max_val - xn.min_val

    for i in range(n):
        var pred_norm = model.predict_single(xn.data[i])
        var pred_real = pred_norm * y_range + yn.min_val
        var real      = y_raw[i]
        var error_pct = abs(pred_real - real) / real * 100.0

        var m2_str   = pad_left(String(Int(x_raw[i])),  6)
        var real_str = pad_left(String(Int(real)),      12)
        var pred_str = pad_left(String(Int(pred_real)), 15)
        var err_str  = pad_left(String(Int(error_pct)),  6)

        print(m2_str + real_str + pred_str + err_str + "%")

    # New predictions
    print("\n--- New Predictions ---")
    var test_sizes = List[Float64]()
    test_sizes.append(75.0)
    test_sizes.append(115.0)
    test_sizes.append(175.0)
    test_sizes.append(300.0)

    for i in range(len(test_sizes)):
        var m2        = test_sizes[i]
        var m2_norm   = (m2 - xn.min_val) / x_range
        var pred_norm = model.predict_single(m2_norm)
        var pred_real = pred_norm * y_range + yn.min_val
        print(String(Int(m2)) + " m2  ->  " +
              String(Int(pred_real)) + "K TL")

    # Loss curve summary
    print("\n--- Loss Curve (every 200 epochs) ---")
    var step = 200
    for i in range(0, len(model.loss_history), step):
        print("Epoch " + pad_left(String(i), 5) + " : " +
              String(model.loss_history[i]))

    print("\nLinear Regression completed.")
    print("=" * 60)
