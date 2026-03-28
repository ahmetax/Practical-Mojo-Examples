"""
Author: Ahmet Aksoy
Date: 2026-03-20
Mojo version: 0.26.2 | Python 3.12 | Ubuntu

Logistic Regression — Pure Mojo Implementation
===============================================

Logistic Regression is a classification algorithm that predicts the
probability of a binary outcome (0 or 1).

Model:  z      = w * x + b
        y_pred = sigmoid(z) = 1 / (1 + e^(-z))

Decision boundary: y_pred >= 0.5 -> class 1, else class 0

Training: Gradient Descent on Binary Cross-Entropy loss
Loss:     BCE = -(1/n) * Σ [y*log(p) + (1-y)*log(1-p)]

Gradients:
  dL/dw = (1/n) * Σ (y_pred - y_true) * x
  dL/db = (1/n) * Σ (y_pred - y_true)

Demo dataset: Exam pass/fail prediction
  x: study hours
  y: 1 = pass, 0 = fail
"""

import std.math as math


# ------------------------------------------------------------------ #
# Struct to hold normalization result
# ------------------------------------------------------------------ #

struct NormResult:
    """Result of Min-Max normalization."""
    var data   : List[Float64]
    var min_val: Float64
    var max_val: Float64

    fn __init__(out self, var data: List[Float64],
                min_val: Float64, max_val: Float64):
        self.data    = data^
        self.min_val = min_val
        self.max_val = max_val


# ------------------------------------------------------------------ #
# Helper functions
# ------------------------------------------------------------------ #

fn sigmoid(z: Float64) -> Float64:
    """Sigmoid activation: maps any real number to (0, 1)."""
    return 1.0 / (1.0 + math.exp(-z))


fn clip(val: Float64, lo: Float64, hi: Float64) -> Float64:
    """Clip value to [lo, hi] to avoid log(0) in BCE loss."""
    if val < lo:
        return lo
    if val > hi:
        return hi
    return val


fn binary_cross_entropy(y_true: List[Float64],
                         y_pred: List[Float64]) -> Float64:
    """
    Binary Cross-Entropy loss.
    BCE = -(1/n) * Σ [y*log(p) + (1-y)*log(1-p)]  
    .
    """
    var total: Float64 = 0.0
    var n = len(y_true)
    for i in range(n):
        var p   = clip(y_pred[i], 1e-9, 1.0 - 1e-9)
        var y   = y_true[i]
        total  += y * math.log(p) + (1.0 - y) * math.log(1.0 - p)
    return -total / Float64(n)


fn normalize(data: List[Float64]) -> NormResult:
    """Min-Max normalization: scale values to [0, 1]."""
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


fn accuracy(y_true: List[Float64], y_pred: List[Float64]) -> Float64:
    """Compute classification accuracy."""
    var correct: Int = 0
    for i in range(len(y_true)):
        var predicted_class: Float64 = 1.0 if y_pred[i] >= 0.5 else 0.0
        if predicted_class == y_true[i]:
            correct += 1
    return Float64(correct) / Float64(len(y_true)) * 100.0


fn pad_left(s: String, width: Int) -> String:
    """Left-pad a string with spaces."""
    var result = s
    var i = len(result)
    while i < width:
        result = " " + result
        i += 1
    return result


fn float_str(val: Float64, decimals: Int) -> String:
    """Format float to fixed decimal places (simple version)."""
    var factor = 1.0
    for _ in range(decimals):
        factor *= 10.0
    var rounded = Int(val * factor + 0.5)
    var int_part = rounded // Int(factor)
    var dec_part = rounded  % Int(factor)
    var dec_str  = String(dec_part)
    while len(dec_str) < decimals:
        dec_str = "0" + dec_str
    return String(int_part) + "." + dec_str


# ------------------------------------------------------------------ #
# Logistic Regression — Gradient Descent
# ------------------------------------------------------------------ #

struct LogisticRegression:
    """
    Binary Logistic Regression classifier.
    Trained using Gradient Descent on Binary Cross-Entropy loss.
    """
    var weight      : Float64
    var bias        : Float64
    var lr          : Float64
    var epochs      : Int
    var loss_history: List[Float64]

    fn __init__(out self, lr: Float64 = 0.1, epochs: Int = 1000):
        self.weight       = 0.0
        self.bias         = 0.0
        self.lr           = lr
        self.epochs       = epochs
        self.loss_history = List[Float64]()

    fn fit(mut self, x: List[Float64], y: List[Float64]):
        """Train the model using Gradient Descent."""
        var n = Float64(len(x))

        for _ in range(self.epochs):
            # Forward pass — sigmoid(w*x + b)
            var y_pred = List[Float64]()
            for i in range(len(x)):
                y_pred.append(sigmoid(self.weight * x[i] + self.bias))

            # Compute and record BCE loss
            var loss = binary_cross_entropy(y, y_pred)
            self.loss_history.append(loss)

            # Compute gradients
            var dw: Float64 = 0.0
            var db: Float64 = 0.0
            for i in range(len(x)):
                var error = y_pred[i] - y[i]
                dw += error * x[i]
                db += error
            dw /= n
            db /= n

            # Update weights
            self.weight -= self.lr * dw
            self.bias   -= self.lr * db

    fn predict_proba(self, x: Float64) -> Float64:
        """Return the predicted probability for a single input."""
        return sigmoid(self.weight * x + self.bias)

    fn predict(self, x: List[Float64]) -> List[Float64]:
        """Return predicted probabilities for a list of inputs."""
        var preds = List[Float64]()
        for i in range(len(x)):
            preds.append(sigmoid(self.weight * x[i] + self.bias))
        return preds^

    fn predict_class(self, x: Float64) -> Int:
        """Return the predicted class (0 or 1) for a single input."""
        return 1 if self.predict_proba(x) >= 0.5 else 0


# ------------------------------------------------------------------ #
# Demo
# ------------------------------------------------------------------ #

fn main():
    print("=" * 60)
    print("  Logistic Regression — Gradient Descent")
    print("  Demo: Exam Pass/Fail Prediction")
    print("=" * 60)

    # Dataset — (study hours, pass=1/fail=0)
    var x_raw = List[Float64]()
    x_raw.append(0.5); x_raw.append(1.0); x_raw.append(1.5)
    x_raw.append(2.0); x_raw.append(2.5); x_raw.append(3.0)
    x_raw.append(3.5); x_raw.append(4.0); x_raw.append(4.5)
    x_raw.append(5.0); x_raw.append(5.5); x_raw.append(6.0)
    x_raw.append(6.5); x_raw.append(7.0); x_raw.append(7.5)
    x_raw.append(8.0); x_raw.append(8.5); x_raw.append(9.0)
    x_raw.append(9.5); x_raw.append(10.0)

    var y_raw = List[Float64]()
    y_raw.append(0.0); y_raw.append(0.0); y_raw.append(0.0)
    y_raw.append(0.0); y_raw.append(0.0); y_raw.append(0.0)
    y_raw.append(0.0); y_raw.append(1.0); y_raw.append(0.0)
    y_raw.append(1.0); y_raw.append(1.0); y_raw.append(1.0)
    y_raw.append(1.0); y_raw.append(1.0); y_raw.append(1.0)
    y_raw.append(1.0); y_raw.append(1.0); y_raw.append(1.0)
    y_raw.append(1.0); y_raw.append(1.0)

    var n = len(x_raw)
    print("\nDataset   : " + String(n) + " students")
    print("Features  : study hours (0.5 - 10.0)")
    print("Labels    : 0 = fail, 1 = pass")

    # Normalize features (labels stay 0/1)
    var xn = normalize(x_raw)

    # Train
    var model = LogisticRegression(lr=0.5, epochs=2000)
    model.fit(xn.data, y_raw)

    # Evaluate
    var y_pred = model.predict(xn.data)
    var acc    = accuracy(y_raw, y_pred)
    var final_loss = model.loss_history[len(model.loss_history) - 1]

    print("\n--- Training Results ---")
    print("Epochs        : " + String(model.epochs))
    print("Learning Rate : " + String(model.lr))
    print("Final BCE Loss: " + String(final_loss))
    print("Accuracy      : " + float_str(acc, 1) + "%")

    print("\n--- Model Parameters (normalized space) ---")
    print("Weight (w) : " + String(model.weight))
    print("Bias   (b) : " + String(model.bias))

    # Predictions vs actual
    print("\n--- Predictions vs Actual ---")
    print("Hours   Actual   P(pass)   Predicted   Correct?")
    print("-" * 52)

    for i in range(n):
        var prob      = y_pred[i]
        var pred_cls  = 1 if prob >= 0.5 else 0
        var actual    = Int(y_raw[i])
        var correct   = "Yes" if pred_cls == actual else "No "
        var prob_str  = float_str(prob, 3)

        var h_str = pad_left(float_str(x_raw[i], 1), 5)
        var a_str = pad_left(String(actual),           7)
        var p_str = pad_left(prob_str,                 9)
        var c_str = pad_left(String(pred_cls),        10)

        print(h_str + a_str + p_str + c_str + "     " + correct)

    # Decision boundary
    var x_range = xn.max_val - xn.min_val
    # Find hours where P(pass) = 0.5 → sigmoid(w*x_norm + b) = 0.5
    # → w*x_norm + b = 0 → x_norm = -b/w
    var boundary_norm  = -model.bias / model.weight
    var boundary_hours = boundary_norm * x_range + xn.min_val
    print("\n--- Decision Boundary ---")
    print("P(pass) = 0.5 at study hours: " +
          float_str(boundary_hours, 2) + "h")
    print("Study less -> likely FAIL")
    print("Study more -> likely PASS")

    # New predictions
    print("\n--- New Predictions ---")
    var test_hours = List[Float64]()
    test_hours.append(2.0)
    test_hours.append(4.0)
    test_hours.append(5.5)
    test_hours.append(7.0)
    test_hours.append(9.0)

    for i in range(len(test_hours)):
        var h      = test_hours[i]
        var h_norm = (h - xn.min_val) / x_range
        var prob   = model.predict_proba(h_norm)
        var cls    = model.predict_class(h_norm)
        var label  = "PASS" if cls == 1 else "FAIL"
        print(float_str(h, 1) + "h  ->  P(pass)=" +
              float_str(prob, 3) + "  ->  " + label)

    # Loss curve
    print("\n--- Loss Curve (every 200 epochs) ---")
    var step = 200
    for i in range(0, len(model.loss_history), step):
        print("Epoch " + pad_left(String(i), 5) + " : " +
              String(model.loss_history[i]))

    print("\nLogistic Regression completed.")
    print("=" * 60)
