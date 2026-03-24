"""
Author: Ahmet Aksoy
Date: 2026-03-21
Mojo version: 0.26.2
AI: Claude Sonnet 4.6

Neural Network — Pure Mojo Implementation
==========================================

A feedforward neural network trained with backpropagation.

Architecture: Input -> Hidden -> Output
  - Input layer  : n_input  neurons
  - Hidden layer : n_hidden neurons + sigmoid activation
  - Output layer : 1 neuron + sigmoid activation (binary classification)

Forward pass:
  z1 = X  · W1 + b1   (hidden pre-activation)
  a1 = sigmoid(z1)    (hidden activation)
  z2 = a1 · W2 + b2   (output pre-activation)
  a2 = sigmoid(z2)    (output = prediction)

Loss: Binary Cross-Entropy
  L = -(1/n) * Σ [y*log(a2) + (1-y)*log(1-a2)]

Backpropagation:
  dL/dz2 = a2 - y
  dL/dW2 = a1.T · dz2
  dL/db2 = sum(dz2)
  dL/dz1 = (dz2 · W2.T) * sigmoid'(z1)
  dL/dW1 = X.T · dz1
  dL/db1 = sum(dz1)

Demo 1: XOR problem (non-linearly separable).
Demo 2: Iris binary classification (Setosa vs non-Setosa).
"""

from std.math import exp, log, sqrt


# ------------------------------------------------------------------ #
# Math helpers
# ------------------------------------------------------------------ #

fn sigmoid(z: Float64) -> Float64:
    """Sigmoid activation function: maps any real to (0, 1)."""
    return 1.0 / (1.0 + exp(-z))


fn sigmoid_deriv(a: Float64) -> Float64:
    """Derivative of sigmoid given its output a = sigmoid(z)."""
    return a * (1.0 - a)


fn clip(v: Float64, lo: Float64, hi: Float64) -> Float64:
    """Clip value to [lo, hi]."""
    if v < lo:
        return lo
    if v > hi:
        return hi
    return v


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
    var v = val
    if v < 0.0:
        sign = "-"
        v = -v
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
# Matrix operations (flat row-major storage)
# ------------------------------------------------------------------ #

fn mat_mul(A: List[Float64], B: List[Float64],
           m: Int, k: Int, n: Int) -> List[Float64]:
    """
    Matrix multiply A(m×k) × B(k×n) -> C(m×n).
    Flat row-major: A[i*k+j], B[i*n+j].
    """
    var C = List[Float64]()
    for _ in range(m * n):
        C.append(0.0)
    for i in range(m):
        for j in range(n):
            var s: Float64 = 0.0
            for p in range(k):
                s += A[i * k + p] * B[p * n + j]
            C[i * n + j] = s
    return C^


fn mat_add_bias(A: List[Float64], b: List[Float64],
                m: Int, n: Int) -> List[Float64]:
    """Add bias vector b(n) to each row of A(m×n)."""
    var C = List[Float64]()
    for i in range(m):
        for j in range(n):
            C.append(A[i * n + j] + b[j])
    return C^


fn mat_sigmoid(A: List[Float64]) -> List[Float64]:
    """Apply sigmoid element-wise."""
    var C = List[Float64]()
    for i in range(len(A)):
        C.append(sigmoid(A[i]))
    return C^


fn mat_transpose(A: List[Float64], m: Int, n: Int) -> List[Float64]:
    """Transpose A(m×n) -> A.T(n×m)."""
    var T = List[Float64]()
    for _ in range(n * m):
        T.append(0.0)
    for i in range(m):
        for j in range(n):
            T[j * m + i] = A[i * n + j]
    return T^


fn mat_scale(A: List[Float64], s: Float64) -> List[Float64]:
    """Scale matrix by scalar."""
    var C = List[Float64]()
    for i in range(len(A)):
        C.append(A[i] * s)
    return C^


fn mat_sub(A: List[Float64], B: List[Float64]) -> List[Float64]:
    """Element-wise subtraction A - B."""
    var C = List[Float64]()
    for i in range(len(A)):
        C.append(A[i] - B[i])
    return C^


fn mat_mul_elem(A: List[Float64], B: List[Float64]) -> List[Float64]:
    """Element-wise multiplication."""
    var C = List[Float64]()
    for i in range(len(A)):
        C.append(A[i] * B[i])
    return C^


fn col_sum(A: List[Float64], m: Int, n: Int) -> List[Float64]:
    """Sum each column of A(m×n) -> vector(n)."""
    var s = List[Float64]()
    for _ in range(n):
        s.append(0.0)
    for i in range(m):
        for j in range(n):
            s[j] += A[i * n + j]
    return s^


fn bce_loss(y_pred: List[Float64], y_true: List[Float64]) -> Float64:
    """Binary cross-entropy loss."""
    var total: Float64 = 0.0
    var n = len(y_true)
    for i in range(n):
        var p = clip(y_pred[i], 1e-9, 1.0 - 1e-9)
        total += y_true[i] * log(p) + (1.0 - y_true[i]) * log(1.0 - p)
    return -total / Float64(n)


fn he_init(size: Int, fan_in: Int) -> List[Float64]:
    """
    He initialization: weights ~ N(0, sqrt(2/fan_in)).
    Uses a simple deterministic pseudo-random sequence.
    """
    var w   = List[Float64]()
    var std = sqrt(2.0 / Float64(fan_in))
    var x: Float64 = 0.5  # seed
    for _ in range(size):
        # LCG-based pseudo-random in (-1, 1)
        x = (x * 1664525.0 + 1013904223.0) % 4294967296.0
        var r = (x / 4294967296.0) * 2.0 - 1.0
        w.append(r * std)
    return w^


# ------------------------------------------------------------------ #
# Neural Network (2-layer: input -> hidden -> output)
# ------------------------------------------------------------------ #

struct NeuralNetwork:
    """
    Two-layer feedforward neural network for binary classification.
    Uses sigmoid activation in both hidden and output layers.
    Trained with mini-batch gradient descent and backpropagation.
    """
    var n_input : Int
    var n_hidden: Int
    var lr      : Float64
    var epochs  : Int

    # Weights and biases (flat row-major)
    var W1: List[Float64]   # (n_input  × n_hidden)
    var b1: List[Float64]   # (n_hidden)
    var W2: List[Float64]   # (n_hidden × 1)
    var b2: List[Float64]   # (1)

    var loss_history: List[Float64]

    fn __init__(out self, n_input: Int = 2, n_hidden: Int = 4,
                lr: Float64 = 0.1, epochs: Int = 5000):
        self.n_input  = n_input
        self.n_hidden = n_hidden
        self.lr       = lr
        self.epochs   = epochs

        # He initialization
        self.W1 = he_init(n_input * n_hidden, n_input)
        self.W2 = he_init(n_hidden * 1,       n_hidden)

        # Zero biases
        self.b1 = List[Float64]()
        self.b2 = List[Float64]()
        for _ in range(n_hidden):
            self.b1.append(0.0)
        self.b2.append(0.0)

        self.loss_history = List[Float64]()

    fn forward_hidden(self, X: List[Float64], n: Int) -> List[Float64]:
        """Compute hidden layer activations a1."""
        var z1  = mat_mul(X, self.W1, n, self.n_input, self.n_hidden)
        var z1b = mat_add_bias(z1, self.b1, n, self.n_hidden)
        return mat_sigmoid(z1b)

    fn forward_output(self, a1: List[Float64], n: Int) -> List[Float64]:
        """Compute output layer activations a2 given hidden activations a1."""
        var z2  = mat_mul(a1, self.W2, n, self.n_hidden, 1)
        var z2b = mat_add_bias(z2, self.b2, n, 1)
        return mat_sigmoid(z2b)

    fn fit(mut self, X: List[Float64], y: List[Float64], n: Int):
        """Train the network using backpropagation."""
        var inv_n = 1.0 / Float64(n)

        for _ in range(self.epochs):
            # ── Forward pass ──────────────────────────────────── #
            var a1 = self.forward_hidden(X, n)
            var a2 = self.forward_output(a1, n)

            # Loss
            var loss = bce_loss(a2, y)
            self.loss_history.append(loss)

            # ── Backpropagation ───────────────────────────────── #
            # Output layer gradient
            var dz2 = mat_sub(a2, y)                   # (n×1)

            # dW2 = a1.T · dz2
            var a1T = mat_transpose(a1, n, self.n_hidden)
            var dW2 = mat_mul(a1T, dz2, self.n_hidden, n, 1)
            dW2 = mat_scale(dW2, inv_n)

            # db2 = mean(dz2)
            var db2 = col_sum(dz2, n, 1)
            db2 = mat_scale(db2, inv_n)

            # Hidden layer gradient
            var W2T   = mat_transpose(self.W2, self.n_hidden, 1)
            var delta = mat_mul(dz2, W2T, n, 1, self.n_hidden)

            # sigmoid'(a1) = a1 * (1 - a1)
            var da1 = List[Float64]()
            for i in range(len(a1)):
                da1.append(sigmoid_deriv(a1[i]))
            var dz1 = mat_mul_elem(delta, da1)         # (n×n_hidden)

            # dW1 = X.T · dz1
            var XT  = mat_transpose(X, n, self.n_input)
            var dW1 = mat_mul(XT, dz1, self.n_input, n, self.n_hidden)
            dW1 = mat_scale(dW1, inv_n)

            # db1 = mean(dz1)
            var db1 = col_sum(dz1, n, self.n_hidden)
            db1 = mat_scale(db1, inv_n)

            # ── Update weights ────────────────────────────────── #
            for i in range(len(self.W2)):
                self.W2[i] -= self.lr * dW2[i]
            for i in range(len(self.b2)):
                self.b2[i] -= self.lr * db2[i]
            for i in range(len(self.W1)):
                self.W1[i] -= self.lr * dW1[i]
            for i in range(len(self.b1)):
                self.b1[i] -= self.lr * db1[i]

    fn predict(self, X: List[Float64], n: Int) -> List[Int]:
        """Predict binary classes for n samples."""
        var a1    = self.forward_hidden(X, n)
        var a2    = self.forward_output(a1, n)
        var preds = List[Int]()
        for i in range(n):
            preds.append(1 if a2[i] >= 0.5 else 0)
        return preds^

    fn predict_proba(self, X: List[Float64], n: Int) -> List[Float64]:
        """Return output probabilities for n samples."""
        var a1 = self.forward_hidden(X, n)
        return self.forward_output(a1, n)


# ------------------------------------------------------------------ #
# Demo helpers
# ------------------------------------------------------------------ #

fn accuracy(y_true: List[Int], y_pred: List[Int]) -> Float64:
    """Compute classification accuracy (%)."""
    var correct = 0
    for i in range(len(y_true)):
        if y_true[i] == y_pred[i]:
            correct += 1
    return Float64(correct) / Float64(len(y_true)) * 100.0


fn make_X(rows: List[List[Float64]], n: Int, nf: Int) -> List[Float64]:
    """Flatten 2D list to row-major flat matrix."""
    var X = List[Float64]()
    for i in range(n):
        for j in range(nf):
            X.append(rows[i][j])
    return X^


fn make_row(a: Float64, b: Float64) -> List[Float64]:
    """Create a 2-element row."""
    var r = List[Float64]()
    r.append(a)
    r.append(b)
    return r^


# ------------------------------------------------------------------ #
# Demo 1: XOR problem
# ------------------------------------------------------------------ #

fn demo_xor():
    print("=" * 55)
    print("  Demo 1: XOR Problem")
    print("  Network: 2 -> 4 -> 1")
    print("=" * 55)
    print("\n  XOR truth table:")
    print("  x1  x2  y")
    print("   0   0  0")
    print("   0   1  1")
    print("   1   0  1")
    print("   1   1  0")

    # Dataset
    var rows = List[List[Float64]]()
    rows.append(make_row(0.0, 0.0))
    rows.append(make_row(0.0, 1.0))
    rows.append(make_row(1.0, 0.0))
    rows.append(make_row(1.0, 1.0))

    var y_list = List[Float64]()
    y_list.append(0.0); y_list.append(1.0)
    y_list.append(1.0); y_list.append(0.0)

    var y_int = List[Int]()
    y_int.append(0); y_int.append(1)
    y_int.append(1); y_int.append(0)

    var n  = 4
    var nf = 2
    var X  = make_X(rows, n, nf)

    # Train
    var model = NeuralNetwork(
        n_input=2, n_hidden=4, lr=0.5, epochs=10000
    )
    model.fit(X, y_list, n)

    # Results
    var preds = model.predict(X, n)
    var probs = model.predict_proba(X, n)
    var acc   = accuracy(y_int, preds)

    print("\n--- Results ---")
    print("x1  x2   y   P(y=1)  Pred  OK?")
    print("-" * 36)
    for i in range(n):
        var x1 = String(Int(rows[i][0]))
        var x2 = String(Int(rows[i][1]))
        var yi = String(y_int[i])
        var pb = float_str(probs[i], 4)
        var pr = String(preds[i])
        var ok = "Yes" if preds[i] == y_int[i] else "No "
        print(" " + x1 + "   " + x2 + "   " + yi +
              "   " + pb + "   " + pr + "   " + ok)

    print("\nAccuracy : " + float_str(acc, 1) + "%")
    print("Final Loss: " +
          float_str(model.loss_history[len(model.loss_history)-1], 6))

    print("\n--- Loss Curve (every 1000 epochs) ---")
    for i in range(0, len(model.loss_history), 1000):
        print("Epoch " + pad_left(String(i), 5) + " : " +
              float_str(model.loss_history[i], 6))


# ------------------------------------------------------------------ #
# Demo 2: Iris — Setosa vs non-Setosa
# ------------------------------------------------------------------ #

fn demo_iris():
    print("\n" + "=" * 55)
    print("  Demo 2: Iris Binary Classification")
    print("  Setosa (0) vs non-Setosa (1)")
    print("  Network: 2 -> 6 -> 1")
    print("=" * 55)

    var rows = List[List[Float64]]()
    var y_list = List[Float64]()
    var y_int  = List[Int]()

    # Setosa — label 0
    var setosa = List[List[Float64]]()
    setosa.append(make_row(1.4, 0.2)); setosa.append(make_row(1.3, 0.2))
    setosa.append(make_row(1.5, 0.2)); setosa.append(make_row(1.4, 0.3))
    setosa.append(make_row(1.7, 0.4)); setosa.append(make_row(1.5, 0.1))
    setosa.append(make_row(1.6, 0.2)); setosa.append(make_row(1.1, 0.1))
    setosa.append(make_row(1.2, 0.2)); setosa.append(make_row(1.5, 0.3))

    for i in range(len(setosa)):
        var row_s = List[Float64]()
        row_s.append(setosa[i][0])
        row_s.append(setosa[i][1])
        rows.append(row_s^)
        y_list.append(0.0)
        y_int.append(0)

    # Versicolor — label 1
    var versi = List[List[Float64]]()
    versi.append(make_row(4.7, 1.4)); versi.append(make_row(4.5, 1.5))
    versi.append(make_row(4.9, 1.5)); versi.append(make_row(4.0, 1.3))
    versi.append(make_row(4.6, 1.5)); versi.append(make_row(4.5, 1.3))
    versi.append(make_row(4.7, 1.6)); versi.append(make_row(3.3, 1.0))
    versi.append(make_row(4.6, 1.3)); versi.append(make_row(3.9, 1.4))

    for i in range(len(versi)):
        var row_v = List[Float64]()
        row_v.append(versi[i][0])
        row_v.append(versi[i][1])
        rows.append(row_v^)
        y_list.append(1.0)
        y_int.append(1)

    # Virginica — label 1
    var virgi = List[List[Float64]]()
    virgi.append(make_row(6.0, 2.5)); virgi.append(make_row(5.1, 1.9))
    virgi.append(make_row(5.9, 2.1)); virgi.append(make_row(5.6, 1.8))
    virgi.append(make_row(5.8, 2.2)); virgi.append(make_row(6.6, 2.1))
    virgi.append(make_row(6.3, 1.8)); virgi.append(make_row(6.1, 2.5))
    virgi.append(make_row(6.4, 2.0)); virgi.append(make_row(5.6, 2.1))

    for i in range(len(virgi)):
        var row_g = List[Float64]()
        row_g.append(virgi[i][0])
        row_g.append(virgi[i][1])
        rows.append(row_g^)
        y_list.append(1.0)
        y_int.append(1)

    var n  = len(y_int)
    var nf = 2

    # Normalize features to [0,1]
    var x1_min: Float64 = 1.1; var x1_max: Float64 = 6.6
    var x2_min: Float64 = 0.1; var x2_max: Float64 = 2.5
    for i in range(n):
        rows[i][0] = (rows[i][0] - x1_min) / (x1_max - x1_min)
        rows[i][1] = (rows[i][1] - x2_min) / (x2_max - x2_min)

    var X = make_X(rows, n, nf)

    # Train
    var model = NeuralNetwork(
        n_input=2, n_hidden=6, lr=0.3, epochs=5000
    )
    model.fit(X, y_list, n)

    var preds = model.predict(X, n)
    var acc   = accuracy(y_int, preds)

    print("\nDataset  : " + String(n) + " samples")
    print("Accuracy : " + float_str(acc, 1) + "%")
    print("Final Loss: " +
          float_str(model.loss_history[len(model.loss_history)-1], 6))

    print("\n--- Loss Curve (every 500 epochs) ---")
    for i in range(0, len(model.loss_history), 500):
        print("Epoch " + pad_left(String(i), 5) + " : " +
              float_str(model.loss_history[i], 6))

    # Errors
    var errors = 0
    for i in range(n):
        if preds[i] != y_int[i]:
            errors += 1
    if errors == 0:
        print("\nAll samples classified correctly.")
    else:
        print("\nMisclassified: " + String(errors))


# ------------------------------------------------------------------ #
# Main
# ------------------------------------------------------------------ #

fn main():
    demo_xor()
    demo_iris()
    print("\nNeural Network completed.")
