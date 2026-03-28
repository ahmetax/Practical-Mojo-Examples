"""
Author: Ahmet Aksoy
Date: 2026-03-21
Mojo version: 0.26.2 | Python 3.12 | Ubuntu

Gaussian Naive Bayes — Pure Mojo Implementation
================================================

Naive Bayes is a probabilistic classifier based on Bayes' theorem
with the "naive" assumption that features are conditionally independent.

Bayes' theorem:
  P(class | x) ∝ P(x | class) × P(class)

Gaussian assumption (for continuous features):
  P(x_i | class) = (1 / sqrt(2π σ²)) × exp(-(x_i - μ)² / (2σ²))

Training (per class, per feature):
  - Compute prior  : P(class) = count(class) / n
  - Compute mean   : μ = mean(x_i | class)
  - Compute variance: σ² = var(x_i | class)

Prediction:
  log P(class | x) = log P(class) + Σ log P(x_i | class)
  (use log-sum to avoid underflow)

Demo dataset: Iris flower classification
  x1: petal length (cm)
  x2: petal width  (cm)
  y : 0=Setosa, 1=Versicolor, 2=Virginica.
"""

from std.math import sqrt, log, exp


# ------------------------------------------------------------------ #
# Helper functions
# ------------------------------------------------------------------ #

comptime PI = 3.141592653589793


fn mean(data: List[Float64]) -> Float64:
    """Compute mean of a list."""
    var total: Float64 = 0.0
    for i in range(len(data)):
        total += data[i]
    return total / Float64(len(data))


fn variance(data: List[Float64], mu: Float64) -> Float64:
    """Compute variance given precomputed mean."""
    var total: Float64 = 0.0
    for i in range(len(data)):
        var diff = data[i] - mu
        total += diff * diff
    return total / Float64(len(data))


fn gaussian_log_prob(x: Float64, mu: Float64, var_: Float64) -> Float64:
    """
    Log probability of x under Gaussian(mu, var_).
    log P(x) = -0.5 * log(2π σ²) - (x - μ)² / (2σ²).
    """
    var eps: Float64 = 1e-9   # avoid log(0)
    var v = var_ + eps
    return -0.5 * log(2.0 * PI * v) - ((x - mu) * (x - mu)) / (2.0 * v)


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
    var factor = 1.0
    for _ in range(decimals):
        factor *= 10.0
    var rounded  = Int(val * factor + 0.5)
    var int_part = rounded // Int(factor)
    var dec_part = rounded  % Int(factor)
    var dec_str  = String(dec_part)
    while len(dec_str) < decimals:
        dec_str = "0" + dec_str
    return String(int_part) + "." + dec_str


fn accuracy(y_true: List[Int], y_pred: List[Int]) -> Float64:
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


# ------------------------------------------------------------------ #
# Gaussian Naive Bayes
# ------------------------------------------------------------------ #

struct GaussianNB:
    """
    Gaussian Naive Bayes Classifier.

    Stores per-class statistics as parallel lists:
      class_prior[c]       : log P(class c)
      class_mean[c*nf + f] : mean of feature f for class c
      class_var [c*nf + f] : variance of feature f for class c.
    """
    var n_classes  : Int
    var n_features : Int
    var class_prior: List[Float64]   # log prior per class
    var class_mean : List[Float64]   # mean[c * n_features + f]
    var class_var  : List[Float64]   # var [c * n_features + f]

    fn __init__(out self, n_classes: Int = 3, n_features: Int = 2):
        self.n_classes   = n_classes
        self.n_features  = n_features
        self.class_prior = List[Float64]()
        self.class_mean  = List[Float64]()
        self.class_var   = List[Float64]()

    fn fit(mut self, x: List[List[Float64]], y: List[Int]):
        """Compute per-class priors, means and variances."""
        var n = len(y)

        # Reset
        self.class_prior = List[Float64]()
        self.class_mean  = List[Float64]()
        self.class_var   = List[Float64]()

        for c in range(self.n_classes):
            # Collect indices for class c
            var idx = List[Int]()
            for i in range(n):
                if y[i] == c:
                    idx.append(i)

            var nc = len(idx)

            # Log prior
            self.class_prior.append(log(Float64(nc) / Float64(n)))

            # Per-feature mean and variance
            for f in range(self.n_features):
                var feat_vals = List[Float64]()
                for i in range(nc):
                    feat_vals.append(x[idx[i]][f])
                var mu  = mean(feat_vals)
                var var_ = variance(feat_vals, mu)
                self.class_mean.append(mu)
                self.class_var.append(var_)

    fn predict_single(self, x_query: List[Float64]) -> Int:
        """Predict class for a single sample."""
        var best_class    = 0
        var best_log_prob = -1.0e38

        for c in range(self.n_classes):
            # Start with log prior
            var log_prob = self.class_prior[c]

            # Add log likelihood for each feature
            for f in range(self.n_features):
                var mu   = self.class_mean[c * self.n_features + f]
                var var_ = self.class_var [c * self.n_features + f]
                log_prob += gaussian_log_prob(x_query[f], mu, var_)

            if log_prob > best_log_prob:
                best_log_prob = log_prob
                best_class    = c

        return best_class

    fn predict(self, x: List[List[Float64]]) -> List[Int]:
        """Predict classes for a list of samples."""
        var preds = List[Int]()
        for i in range(len(x)):
            preds.append(self.predict_single(x[i]))
        return preds^

    fn predict_proba(self, x_query: List[Float64]) -> List[Float64]:
        """
        Return normalized probabilities for each class.
        Uses softmax over log probabilities.
        """
        var log_probs = List[Float64]()
        for c in range(self.n_classes):
            var lp = self.class_prior[c]
            for f in range(self.n_features):
                var mu   = self.class_mean[c * self.n_features + f]
                var var_ = self.class_var [c * self.n_features + f]
                lp += gaussian_log_prob(x_query[f], mu, var_)
            log_probs.append(lp)

        # Softmax: shift by max for numerical stability
        var max_lp = log_probs[0]
        for c in range(1, self.n_classes):
            if log_probs[c] > max_lp:
                max_lp = log_probs[c]

        var probs = List[Float64]()
        var total: Float64 = 0.0
        for c in range(self.n_classes):
            var p = exp(log_probs[c] - max_lp)
            probs.append(p)
            total += p

        for c in range(self.n_classes):
            probs[c] /= total

        return probs^

    fn print_params(self, class_names: List[String],
                    feature_names: List[String]):
        """Print learned parameters."""
        print("--- Learned Parameters ---")
        for c in range(self.n_classes):
            print("\nClass: " + class_names[c])
            print("  Log Prior: " + float_str(self.class_prior[c], 4))
            for f in range(self.n_features):
                var mu   = self.class_mean[c * self.n_features + f]
                var var_ = self.class_var [c * self.n_features + f]
                print("  " + feature_names[f] +
                      ": mean=" + float_str(mu, 3) +
                      ", var=" + float_str(var_, 4))


# ------------------------------------------------------------------ #
# Demo
# ------------------------------------------------------------------ #

fn main():
    print("=" * 62)
    print("  Gaussian Naive Bayes Classifier")
    print("  Demo: Iris Flower Classification")
    print("  Features: petal length (cm), petal width (cm)")
    print("  Classes : 0=Setosa, 1=Versicolor, 2=Virginica")
    print("=" * 62)

    # ── Dataset ───────────────────────────────────────────────── #
    var x_data = List[List[Float64]]()
    var y_data = List[Int]()

    # Setosa (label=0) — small petals
    x_data.append(make_point(1.4, 0.2)); y_data.append(0)
    x_data.append(make_point(1.3, 0.2)); y_data.append(0)
    x_data.append(make_point(1.5, 0.2)); y_data.append(0)
    x_data.append(make_point(1.4, 0.3)); y_data.append(0)
    x_data.append(make_point(1.7, 0.4)); y_data.append(0)
    x_data.append(make_point(1.5, 0.1)); y_data.append(0)
    x_data.append(make_point(1.6, 0.2)); y_data.append(0)
    x_data.append(make_point(1.1, 0.1)); y_data.append(0)
    x_data.append(make_point(1.2, 0.2)); y_data.append(0)
    x_data.append(make_point(1.5, 0.3)); y_data.append(0)

    # Versicolor (label=1) — medium petals
    x_data.append(make_point(4.7, 1.4)); y_data.append(1)
    x_data.append(make_point(4.5, 1.5)); y_data.append(1)
    x_data.append(make_point(4.9, 1.5)); y_data.append(1)
    x_data.append(make_point(4.0, 1.3)); y_data.append(1)
    x_data.append(make_point(4.6, 1.5)); y_data.append(1)
    x_data.append(make_point(4.5, 1.3)); y_data.append(1)
    x_data.append(make_point(4.7, 1.6)); y_data.append(1)
    x_data.append(make_point(3.3, 1.0)); y_data.append(1)
    x_data.append(make_point(4.6, 1.3)); y_data.append(1)
    x_data.append(make_point(3.9, 1.4)); y_data.append(1)

    # Virginica (label=2) — large petals
    x_data.append(make_point(6.0, 2.5)); y_data.append(2)
    x_data.append(make_point(5.1, 1.9)); y_data.append(2)
    x_data.append(make_point(5.9, 2.1)); y_data.append(2)
    x_data.append(make_point(5.6, 1.8)); y_data.append(2)
    x_data.append(make_point(5.8, 2.2)); y_data.append(2)
    x_data.append(make_point(6.6, 2.1)); y_data.append(2)
    x_data.append(make_point(6.3, 1.8)); y_data.append(2)
    x_data.append(make_point(6.1, 2.5)); y_data.append(2)
    x_data.append(make_point(6.4, 2.0)); y_data.append(2)
    x_data.append(make_point(5.6, 2.1)); y_data.append(2)

    var n = len(y_data)
    print("\nDataset  : " + String(n) + " samples (10 per class)")

    var class_names = List[String]()
    class_names.append("Setosa    ")
    class_names.append("Versicolor")
    class_names.append("Virginica ")

    var feature_names = List[String]()
    feature_names.append("petal_length")
    feature_names.append("petal_width ")

    # ── Train ─────────────────────────────────────────────────── #
    var model = GaussianNB(n_classes=3, n_features=2)
    model.fit(x_data, y_data)

    # ── Learned parameters ────────────────────────────────────── #
    model.print_params(class_names, feature_names)

    # ── Predictions ───────────────────────────────────────────── #
    var preds = model.predict(x_data)
    var acc   = accuracy(y_data, preds)

    print("\n--- Predictions vs Actual ---")
    print("PetalLen  PetalWid  Actual        Predicted     Correct?")
    print("-" * 60)

    for i in range(n):
        var pl      = float_str(x_data[i][0], 1)
        var pw      = float_str(x_data[i][1], 1)
        var act_s   = class_names[y_data[i]]
        var pred_s  = class_names[preds[i]]
        var correct = "Yes" if preds[i] == y_data[i] else "No "
        print(pad_left(pl, 7) + "   " +
              pad_left(pw, 7) + "   " +
              act_s + "   " + pred_s + "   " + correct)

    print("\nAccuracy: " + float_str(acc, 1) + "%")

    # ── Probability predictions ───────────────────────────────── #
    print("\n--- Class Probabilities for New Samples ---")
    print("PetalLen  PetalWid   P(Setosa)  P(Versi.)  P(Virgin.)  Predicted")
    print("-" * 72)

    var test_points = List[List[Float64]]()
    test_points.append(make_point(1.4, 0.2))   # clear Setosa
    test_points.append(make_point(4.5, 1.5))   # clear Versicolor
    test_points.append(make_point(5.8, 2.1))   # clear Virginica
    test_points.append(make_point(4.9, 1.8))   # boundary case
    test_points.append(make_point(3.5, 1.1))   # boundary case

    for i in range(len(test_points)):
        var pl    = float_str(test_points[i][0], 1)
        var pw    = float_str(test_points[i][1], 1)
        var probs = model.predict_proba(test_points[i])
        var pred  = model.predict_single(test_points[i])

        print(pad_left(pl, 7) + "   " +
              pad_left(pw, 7) + "   " +
              pad_left(float_str(probs[0], 4), 9) + "  " +
              pad_left(float_str(probs[1], 4), 9) + "  " +
              pad_left(float_str(probs[2], 4), 10) + "  " +
              class_names[pred])

    print("\nGaussian Naive Bayes completed.")
    print("=" * 62)
