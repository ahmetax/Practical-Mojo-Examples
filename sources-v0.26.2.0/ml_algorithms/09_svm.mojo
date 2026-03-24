"""
Author: Ahmet Aksoy
Date: 2026-03-23
Mojo version: 0.26.2
AI: Claude Sonnet 4.6

Support Vector Machine (SVM) — Pure Mojo Implementation
========================================================

SVM finds the hyperplane that maximizes the margin between two classes.

Linear SVM model:
  f(x) = w · x + b
  Predict +1 if f(x) >= 0, else -1

Hinge loss (soft-margin SVM):
  L = (1/2)||w||² + C * Σ max(0, 1 - y_i * f(x_i))

Training via SGD:
  If y_i * f(x_i) >= 1 (correctly classified with margin):
    dw = w                  (regularization only)
    db = 0
  Else (margin violation):
    dw = w - C * y_i * x_i
    db = -C * y_i

  w = w - lr * dw
  b = b - lr * db

Multi-class: One-vs-Rest (OvR)
  Train one binary SVM per class.
  Predict: class with highest decision score f(x).

Demo 1: Binary — Setosa (1) vs non-Setosa (-1).
Demo 2: Multi-class OvR — Setosa, Versicolor, Virginica.
"""

from std.math import sqrt


# ------------------------------------------------------------------ #
# Helper functions
# ------------------------------------------------------------------ #

fn dot(w: List[Float64], x: List[Float64]) -> Float64:
    """Compute dot product of two vectors."""
    var result: Float64 = 0.0
    for i in range(len(w)):
        result += w[i] * x[i]
    return result


fn normalize(data: List[List[Float64]]) -> List[List[Float64]]:
    """
    Min-Max normalize each feature to [0, 1].
    Returns normalized data.
    """
    var n  = len(data)
    var nf = len(data[0])

    # Find min/max per feature
    var mins = List[Float64]()
    var maxs = List[Float64]()
    for f in range(nf):
        mins.append(data[0][f])
        maxs.append(data[0][f])
    for i in range(n):
        for f in range(nf):
            if data[i][f] < mins[f]:
                mins[f] = data[i][f]
            if data[i][f] > maxs[f]:
                maxs[f] = data[i][f]

    var result = List[List[Float64]]()
    for i in range(n):
        var row = List[Float64]()
        for f in range(nf):
            var rng = maxs[f] - mins[f]
            if rng == 0.0:
                row.append(0.0)
            else:
                row.append((data[i][f] - mins[f]) / rng)
        result.append(row^)
    return result^


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


fn accuracy_int(y_true: List[Int], y_pred: List[Int]) -> Float64:
    """Compute classification accuracy (%)."""
    var correct = 0
    for i in range(len(y_true)):
        if y_true[i] == y_pred[i]:
            correct += 1
    return Float64(correct) / Float64(len(y_true)) * 100.0


fn make_point(x1: Float64, x2: Float64) -> List[Float64]:
    """Create a 2D feature vector."""
    var p = List[Float64]()
    p.append(x1)
    p.append(x2)
    return p^


fn make_point4(x1: Float64, x2: Float64,
               x3: Float64, x4: Float64) -> List[Float64]:
    """Create a 4D feature vector."""
    var p = List[Float64]()
    p.append(x1); p.append(x2)
    p.append(x3); p.append(x4)
    return p^


# ------------------------------------------------------------------ #
# Linear SVM — Binary classifier (labels: +1 / -1)
# ------------------------------------------------------------------ #

struct LinearSVM:
    """
    Binary Linear SVM trained with SGD on hinge loss.
    Labels must be +1 or -1.
    """
    var n_features: Int
    var lr        : Float64   # learning rate
    var C         : Float64   # regularization strength
    var epochs    : Int
    var w         : List[Float64]
    var b         : Float64
    var loss_history: List[Float64]

    fn __init__(out self, n_features: Int = 2,
                lr: Float64 = 0.01, C: Float64 = 1.0,
                epochs: Int = 1000):
        self.n_features   = n_features
        self.lr           = lr
        self.C            = C
        self.epochs       = epochs
        self.b            = 0.0
        self.loss_history = List[Float64]()
        self.w = List[Float64]()
        for _ in range(n_features):
            self.w.append(0.0)

    fn fit(mut self, x: List[List[Float64]], y: List[Int]):
        """Train SVM using SGD on hinge loss with shuffling."""
        var n = len(x)
        self.loss_history = List[Float64]()

        var order = List[Int]()
        for i in range(n):
            order.append(i)

        for epoch in range(self.epochs):
            # Shuffle
            var seed: UInt64 = UInt64(epoch + 1)
            for i in range(n - 1):
                seed = seed * 6364136223846793005 + 1442695040888963407
                var j   = i + Int(seed % UInt64(n - i))
                var tmp = order[i]
                order[i] = order[j]
                order[j] = tmp

            var lr_t       = self.lr / (1.0 + 0.01 * Float64(epoch))
            var total_loss : Float64 = 0.0

            for si in range(n):
                var i      = order[si]
                var yi     = Float64(y[i])   # +1 or -1
                var fx     = dot(self.w, x[i]) + self.b
                var margin = yi * fx
                total_loss += max(0.0, 1.0 - margin)

                if margin >= 1.0:
                    # Only L2 regularization: w = w - lr * w/n
                    for j in range(self.n_features):
                        self.w[j] = self.w[j] * (1.0 - lr_t / Float64(n))
                else:
                    # Hinge gradient: w = w - lr*(w/n - C*yi*xi)
                    for j in range(self.n_features):
                        self.w[j] = self.w[j] * (1.0 - lr_t / Float64(n)) + lr_t * self.C * yi * x[i][j]
                    self.b = self.b + lr_t * self.C * yi

            var reg: Float64 = 0.0
            for j in range(self.n_features):
                reg += self.w[j] * self.w[j]
            total_loss = 0.5 * reg + self.C * total_loss / Float64(n)
            self.loss_history.append(total_loss)

    fn decision_score(self, x_query: List[Float64]) -> Float64:
        """Return raw decision score f(x) = w·x + b."""
        return dot(self.w, x_query) + self.b

    fn predict_single(self, x_query: List[Float64]) -> Int:
        """Predict binary label (+1 or -1)."""
        if self.decision_score(x_query) >= 0.0:
            return 1
        return -1

    fn predict(self, x: List[List[Float64]]) -> List[Int]:
        """Predict labels for all samples."""
        var preds = List[Int]()
        for i in range(len(x)):
            preds.append(self.predict_single(x[i]))
        return preds^


# ------------------------------------------------------------------ #
# Multi-class SVM — One-vs-Rest
# ------------------------------------------------------------------ #

struct MultiSVM:
    """
    Multi-class SVM using One-vs-Rest strategy.
    Trains one binary SVM per class.
    Predicts class with highest decision score.
    """
    var n_classes : Int
    var n_features: Int
    var lr        : Float64
    var C         : Float64
    var epochs    : Int

    # Per-class weights and biases (flat storage)
    # w[c * n_features + f] = weight for class c, feature f
    var weights: List[Float64]
    var biases : List[Float64]

    fn __init__(out self, n_classes: Int = 3, n_features: Int = 2,
                lr: Float64 = 0.01, C: Float64 = 1.0,
                epochs: Int = 1000):
        self.n_classes  = n_classes
        self.n_features = n_features
        self.lr         = lr
        self.C          = C
        self.epochs     = epochs
        self.weights    = List[Float64]()
        self.biases     = List[Float64]()
        for _ in range(n_classes * n_features):
            self.weights.append(0.0)
        for _ in range(n_classes):
            self.biases.append(0.0)

    fn fit(mut self, x: List[List[Float64]], y: List[Int]):
        """Train one binary SVM per class (One-vs-Rest)."""
        var n = len(x)

        # Reset weights
        for i in range(len(self.weights)):
            self.weights[i] = 0.0
        for i in range(len(self.biases)):
            self.biases[i] = 0.0

        for c in range(self.n_classes):
            # Build binary labels: +1 if class c, -1 otherwise
            var y_bin = List[Int]()
            for i in range(n):
                if y[i] == c:
                    y_bin.append(1)
                else:
                    y_bin.append(-1)

            # SGD training for class c with shuffled order
            var order = List[Int]()
            for i in range(n):
                order.append(i)

            for epoch in range(self.epochs):
                # Fisher-Yates shuffle for order
                var seed: UInt64 = UInt64(epoch + c * 1000 + 1)
                for i in range(n - 1):
                    seed = seed * 6364136223846793005 + 1442695040888963407
                    var j = i + Int(seed % UInt64(n - i))
                    var tmp = order[i]
                    order[i] = order[j]
                    order[j] = tmp

                # Decaying learning rate
                var lr_t = self.lr / (1.0 + 0.01 * Float64(epoch))

                for si in range(n):
                    var i   = order[si]
                    var yi  = Float64(y_bin[i])
                    var fx  = Float64(0.0)
                    for f in range(self.n_features):
                        fx += self.weights[c * self.n_features + f] * x[i][f]
                    fx += self.biases[c]
                    var margin = yi * fx

                    if margin >= 1.0:
                        for f in range(self.n_features):
                            self.weights[c * self.n_features + f] *= (
                                1.0 - lr_t / Float64(n)
                            )
                    else:
                        for f in range(self.n_features):
                            self.weights[c * self.n_features + f] = (
                                self.weights[c * self.n_features + f] *
                                (1.0 - lr_t / Float64(n)) +
                                lr_t * self.C * yi * x[i][f]
                            )
                        self.biases[c] = self.biases[c] + lr_t * self.C * yi

    fn decision_score(self, c: Int,
                      x_query: List[Float64]) -> Float64:
        """Return decision score for class c."""
        var score: Float64 = self.biases[c]
        for f in range(self.n_features):
            score += self.weights[c * self.n_features + f] * x_query[f]
        return score

    fn predict_single(self, x_query: List[Float64]) -> Int:
        """Predict class with highest decision score."""
        var best_c     = 0
        var best_score = self.decision_score(0, x_query)
        for c in range(1, self.n_classes):
            var score = self.decision_score(c, x_query)
            if score > best_score:
                best_score = score
                best_c     = c
        return best_c

    fn predict(self, x: List[List[Float64]]) -> List[Int]:
        """Predict classes for all samples."""
        var preds = List[Int]()
        for i in range(len(x)):
            preds.append(self.predict_single(x[i]))
        return preds^


# ------------------------------------------------------------------ #
# Demo
# ------------------------------------------------------------------ #

fn main():
    print("=" * 62)
    print("  Support Vector Machine (SVM)")
    print("  Demo 1: Binary — Setosa vs non-Setosa")
    print("  Demo 2: Multi-class OvR — 3 Iris classes")
    print("=" * 62)

    # ── Dataset (4 features: sepal_len, sepal_wid, petal_len, petal_wid) ── #
    var x_raw = List[List[Float64]]()
    var y3    = List[Int]()

    # Setosa (0)
    x_raw.append(make_point4(5.1,3.5,1.4,0.2)); y3.append(0)
    x_raw.append(make_point4(4.9,3.0,1.4,0.2)); y3.append(0)
    x_raw.append(make_point4(4.7,3.2,1.3,0.2)); y3.append(0)
    x_raw.append(make_point4(4.6,3.1,1.5,0.2)); y3.append(0)
    x_raw.append(make_point4(5.0,3.6,1.4,0.2)); y3.append(0)
    x_raw.append(make_point4(5.4,3.9,1.7,0.4)); y3.append(0)
    x_raw.append(make_point4(4.6,3.4,1.4,0.3)); y3.append(0)
    x_raw.append(make_point4(5.0,3.4,1.5,0.2)); y3.append(0)
    x_raw.append(make_point4(4.4,2.9,1.4,0.2)); y3.append(0)
    x_raw.append(make_point4(4.9,3.1,1.5,0.1)); y3.append(0)
    # Versicolor (1)
    x_raw.append(make_point4(7.0,3.2,4.7,1.4)); y3.append(1)
    x_raw.append(make_point4(6.4,3.2,4.5,1.5)); y3.append(1)
    x_raw.append(make_point4(6.9,3.1,4.9,1.5)); y3.append(1)
    x_raw.append(make_point4(5.5,2.3,4.0,1.3)); y3.append(1)
    x_raw.append(make_point4(6.5,2.8,4.6,1.5)); y3.append(1)
    x_raw.append(make_point4(5.7,2.8,4.5,1.3)); y3.append(1)
    x_raw.append(make_point4(6.3,3.3,4.7,1.6)); y3.append(1)
    x_raw.append(make_point4(4.9,2.4,3.3,1.0)); y3.append(1)
    x_raw.append(make_point4(6.6,2.9,4.6,1.3)); y3.append(1)
    x_raw.append(make_point4(5.2,2.7,3.9,1.4)); y3.append(1)
    # Virginica (2)
    x_raw.append(make_point4(6.3,3.3,6.0,2.5)); y3.append(2)
    x_raw.append(make_point4(5.8,2.7,5.1,1.9)); y3.append(2)
    x_raw.append(make_point4(7.1,3.0,5.9,2.1)); y3.append(2)
    x_raw.append(make_point4(6.3,2.9,5.6,1.8)); y3.append(2)
    x_raw.append(make_point4(6.5,3.0,5.8,2.2)); y3.append(2)
    x_raw.append(make_point4(7.6,3.0,6.6,2.1)); y3.append(2)
    x_raw.append(make_point4(4.9,2.5,4.5,1.7)); y3.append(2)
    x_raw.append(make_point4(7.3,2.9,6.3,1.8)); y3.append(2)
    x_raw.append(make_point4(6.7,2.5,5.8,1.8)); y3.append(2)
    x_raw.append(make_point4(7.2,3.6,6.1,2.5)); y3.append(2)

    var n  = len(y3)
    var x  = normalize(x_raw)
    print("\nDataset : " + String(n) + " samples, 4 features (normalized)")
    print("Features: sepal_len, sepal_wid, petal_len, petal_wid")

    # ── Demo 1: Binary SVM ────────────────────────────────────── #
    print("\n--- Demo 1: Binary SVM (Setosa=+1, others=-1) ---")

    var y_bin = List[Int]()
    for i in range(n):
        if y3[i] == 0:
            y_bin.append(1)
        else:
            y_bin.append(-1)

    var svm = LinearSVM(n_features=4, lr=0.1, C=1.0, epochs=1000)
    svm.fit(x, y_bin)

    var bin_preds = svm.predict(x)
    var correct   = 0
    for i in range(n):
        if bin_preds[i] == y_bin[i]:
            correct += 1
    var bin_acc = Float64(correct) / Float64(n) * 100.0

    print("Accuracy : " + float_str(bin_acc, 1) + "%")
    print("Weights  : w0=" + float_str(svm.w[0], 4) +
          "  w1=" + float_str(svm.w[1], 4) +
          "  w2=" + float_str(svm.w[2], 4) +
          "  w3=" + float_str(svm.w[3], 4))
    print("Bias     : b=" + float_str(svm.b, 4))

    print("\nLoss curve (every 100 epochs):")
    for i in range(0, len(svm.loss_history), 100):
        print("  Epoch " + pad_left(String(i), 4) + " : " +
              float_str(svm.loss_history[i], 4))

    # ── Demo 2: Multi-class OvR SVM ──────────────────────────── #
    print("\n--- Demo 2: Multi-class SVM (One-vs-Rest) ---")

    var msvm = MultiSVM(n_classes=3, n_features=4,
                        lr=0.1, C=10.0, epochs=1000)
    msvm.fit(x, y3)

    var multi_preds = msvm.predict(x)
    var multi_acc   = accuracy_int(y3, multi_preds)

    var class_names = List[String]()
    class_names.append("Setosa    ")
    class_names.append("Versicolor")
    class_names.append("Virginica ")

    print("Accuracy : " + float_str(multi_acc, 1) + "%")

    print("\nPetalLen  PetalWid  Actual        Predicted     Correct?")
    print("-" * 62)
    for i in range(n):
        var pl      = float_str(x_raw[i][0], 1)
        var pw      = float_str(x_raw[i][1], 1)
        var actual  = class_names[y3[i]]
        var pred    = class_names[multi_preds[i]]
        var correct_s = "Yes" if multi_preds[i] == y3[i] else "No "
        print(pad_left(pl, 7) + "   " +
              pad_left(pw, 7) + "   " +
              actual + "   " + pred + "   " + correct_s)

    # ── Decision scores for new samples ──────────────────────── #
    print("\n--- New Sample Predictions ---")
    print("SepalL SepalW PetalL PetalW  ->  Score0  Score1  Score2  Class")
    print("-" * 68)

    var test_raw = List[List[Float64]]()
    test_raw.append(make_point4(5.1, 3.5, 1.4, 0.2))  # Setosa
    test_raw.append(make_point4(6.4, 3.2, 4.5, 1.5))  # Versicolor
    test_raw.append(make_point4(7.1, 3.0, 5.9, 2.1))  # Virginica
    test_raw.append(make_point4(6.0, 2.9, 4.5, 1.5))  # boundary

    var tx = normalize(test_raw)

    for i in range(len(test_raw)):
        var s0   = msvm.decision_score(0, tx[i])
        var s1   = msvm.decision_score(1, tx[i])
        var s2   = msvm.decision_score(2, tx[i])
        var pred = msvm.predict_single(tx[i])
        print(float_str(test_raw[i][0],1) + "  " +
              float_str(test_raw[i][1],1) + "  " +
              float_str(test_raw[i][2],1) + "  " +
              float_str(test_raw[i][3],1) + "    " +
              pad_left(float_str(s0,3),7) + " " +
              pad_left(float_str(s1,3),7) + " " +
              pad_left(float_str(s2,3),7) + "  " +
              class_names[pred])

    # ── Effect of C (regularization) ─────────────────────────── #
    print("\n--- Effect of C (regularization) ---")
    print("C        Accuracy")
    print("-" * 22)
    var c_values = List[Float64]()
    c_values.append(0.01)
    c_values.append(0.1)
    c_values.append(1.0)
    c_values.append(10.0)
    c_values.append(100.0)
    for i in range(len(c_values)):
        var cv = c_values[i]
        var m  = MultiSVM(n_classes=3, n_features=4,
                          lr=0.1, C=cv, epochs=1000)
        m.fit(x, y3)
        var p  = m.predict(x)
        var a  = accuracy_int(y3, p)
        print(pad_left(float_str(cv, 2), 8) +
              "   " + float_str(a, 1) + "%")

    print("\nSVM completed.")
    print("=" * 62)
