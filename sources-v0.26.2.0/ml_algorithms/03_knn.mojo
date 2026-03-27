"""
Author: Ahmet Aksoy
Date: 2026-03-20
Mojo version: 0.26.2 | Python 3.12 | Ubuntu
AI: Claude Sonnet 4.6

K-Nearest Neighbors (KNN) — Pure Mojo Implementation
=====================================================

KNN is a simple, non-parametric classification algorithm.
It requires no training — it memorizes the entire dataset and
makes predictions by finding the K closest training samples.

Algorithm:
  1. Compute distance from query point to all training points
  2. Select the K nearest neighbors
  3. Return the majority class among those K neighbors

Distance metrics:
  Euclidean : sqrt(Σ(x1_i - x2_i)²)
  Manhattan : Σ|x1_i - x2_i|

Demo dataset: Iris flower classification (2 features)
  x1: petal length (cm)
  x2: petal width  (cm)
  y : 0 = Setosa, 1 = Versicolor, 2 = Virginica
"""

import std.math as math


# ------------------------------------------------------------------ #
# Distance functions
# ------------------------------------------------------------------ #

fn euclidean(x1: List[Float64], x2: List[Float64]) -> Float64:
    """Euclidean distance between two points."""
    var total: Float64 = 0.0
    for i in range(len(x1)):
        var diff = x1[i] - x2[i]
        total += diff * diff
    return math.sqrt(total)


fn manhattan(x1: List[Float64], x2: List[Float64]) -> Float64:
    """Manhattan distance between two points."""
    var total: Float64 = 0.0
    for i in range(len(x1)):
        total += abs(x1[i] - x2[i])
    return total


# ------------------------------------------------------------------ #
# Sort two parallel lists (distances + labels) by distance
# ------------------------------------------------------------------ #

fn sort_by_dist(mut dists: List[Float64], mut labels: List[Int]):
    """Insertion sort by distance ascending, keeping labels in sync."""
    var n = len(dists)
    for i in range(1, n):
        var key_dist  = dists[i]
        var key_label = labels[i]
        var j = i - 1
        while j >= 0 and dists[j] > key_dist:
            dists[j + 1]  = dists[j]
            labels[j + 1] = labels[j]
            j -= 1
        dists[j + 1]  = key_dist
        labels[j + 1] = key_label


fn majority_vote(labels: List[Int], num_classes: Int) -> Int:
    """Return the most frequent label."""
    var counts = List[Int]()
    for _ in range(num_classes):
        counts.append(0)
    for i in range(len(labels)):
        counts[labels[i]] += 1
    var best_class = 0
    var best_count = counts[0]
    for c in range(1, num_classes):
        if counts[c] > best_count:
            best_count = counts[c]
            best_class = c
    return best_class


fn accuracy(y_true: List[Int], y_pred: List[Int]) -> Float64:
    """Compute classification accuracy (%)."""
    var correct = 0
    for i in range(len(y_true)):
        if y_true[i] == y_pred[i]:
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


fn class_name(label: Int) -> String:
    """Return class name for a label."""
    if label == 0:
        return "Setosa    "
    if label == 1:
        return "Versicolor"
    return "Virginica "


fn make_point(x1: Float64, x2: Float64) -> List[Float64]:
    """Create a 2D feature vector."""
    var p = List[Float64]()
    p.append(x1)
    p.append(x2)
    return p^


# ------------------------------------------------------------------ #
# KNN Classifier
# ------------------------------------------------------------------ #

struct KNNClassifier:
    """
    K-Nearest Neighbors Classifier.
    Supports Euclidean and Manhattan distance metrics.
    Uses two parallel lists (dists + labels) to avoid
    custom struct Copyable issues.
    """
    var k          : Int
    var metric     : String
    var num_classes: Int
    var x_train    : List[List[Float64]]
    var y_train    : List[Int]

    fn __init__(out self, k: Int = 3,
                metric: String = "euclidean",
                num_classes: Int = 3):
        self.k           = k
        self.metric      = metric
        self.num_classes = num_classes
        self.x_train     = List[List[Float64]]()
        self.y_train     = List[Int]()

    fn fit(mut self,
           x: List[List[Float64]],
           y: List[Int]):
        """Store training data (KNN has no actual training step)."""
        # Copy data element by element to avoid implicit copy error
        self.x_train = List[List[Float64]]()
        self.y_train = List[Int]()
        for i in range(len(x)):
            var row = List[Float64]()
            for j in range(len(x[i])):
                row.append(x[i][j])
            self.x_train.append(row^)
            self.y_train.append(y[i])

    fn predict_single(self, x_query: List[Float64]) -> Int:
        """Predict the class for a single query point."""
        var dists  = List[Float64]()
        var labels = List[Int]()
        for i in range(len(self.x_train)):
            var dist: Float64
            if self.metric == "manhattan":
                dist = manhattan(x_query, self.x_train[i])
            else:
                dist = euclidean(x_query, self.x_train[i])
            dists.append(dist)
            labels.append(self.y_train[i])

        sort_by_dist(dists, labels)

        var k_labels = List[Int]()
        for i in range(self.k):
            k_labels.append(labels[i])

        return majority_vote(k_labels, self.num_classes)

    fn predict(self, x: List[List[Float64]]) -> List[Int]:
        """Predict classes for a list of query points."""
        var preds = List[Int]()
        for i in range(len(x)):
            preds.append(self.predict_single(x[i]))
        return preds^


# ------------------------------------------------------------------ #
# Demo
# ------------------------------------------------------------------ #

fn main():
    print("=" * 65)
    print("  K-Nearest Neighbors (KNN) Classifier")
    print("  Demo: Iris Flower Classification")
    print("  Features: petal length, petal width")
    print("  Classes : 0=Setosa, 1=Versicolor, 2=Virginica")
    print("=" * 65)

    # ── Dataset ───────────────────────────────────────────────── #
    var x_data = List[List[Float64]]()
    var y_data = List[Int]()

    # Setosa (label=0)
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

    # Versicolor (label=1)
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

    # Virginica (label=2)
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
    print("Features : petal length (cm), petal width (cm)")

    # ── Accuracy vs K ─────────────────────────────────────────── #
    print("\n--- Accuracy vs K (Euclidean) ---")
    print("K     Accuracy")
    print("-" * 20)

    for k in range(1, 8):
        var model = KNNClassifier(k=k, metric="euclidean", num_classes=3)
        model.fit(x_data, y_data)
        var preds = model.predict(x_data)
        var acc   = accuracy(y_data, preds)
        print("K=" + String(k) + "   " + float_str(acc, 1) + "%")

    # ── Main model: K=3 ───────────────────────────────────────── #
    print("\n--- Predictions (K=3, Euclidean) ---")
    print("PetalLen  PetalWid  Actual        Predicted     Correct?")
    print("-" * 62)

    var model = KNNClassifier(k=3, metric="euclidean", num_classes=3)
    model.fit(x_data, y_data)
    var preds = model.predict(x_data)
    var acc   = accuracy(y_data, preds)

    for i in range(n):
        var pl      = float_str(x_data[i][0], 1)
        var pw      = float_str(x_data[i][1], 1)
        var actual  = class_name(y_data[i])
        var pred    = class_name(preds[i])
        var correct = "Yes" if preds[i] == y_data[i] else "No "
        print(pad_left(pl, 7) + "   " +
              pad_left(pw, 7) + "   " +
              actual + "   " + pred + "   " + correct)

    print("\nAccuracy (K=3, Euclidean): " + float_str(acc, 1) + "%")

    # ── Euclidean vs Manhattan ────────────────────────────────── #
    print("\n--- Euclidean vs Manhattan (K=3) ---")
    var model_m = KNNClassifier(k=3, metric="manhattan", num_classes=3)
    model_m.fit(x_data, y_data)
    var preds_m = model_m.predict(x_data)
    var acc_m   = accuracy(y_data, preds_m)
    print("Euclidean : " + float_str(acc,   1) + "%")
    print("Manhattan : " + float_str(acc_m, 1) + "%")

    # ── New predictions ───────────────────────────────────────── #
    print("\n--- New Flower Predictions (K=3) ---")
    print("PetalLen  PetalWid  ->  Predicted")
    print("-" * 40)

    var test_points = List[List[Float64]]()
    test_points.append(make_point(1.3, 0.2))
    test_points.append(make_point(4.5, 1.4))
    test_points.append(make_point(5.8, 2.0))
    test_points.append(make_point(3.8, 1.2))
    test_points.append(make_point(5.0, 1.7))

    for i in range(len(test_points)):
        var pl   = float_str(test_points[i][0], 1)
        var pw   = float_str(test_points[i][1], 1)
        var pred = model.predict_single(test_points[i])
        print(pad_left(pl, 7) + "   " +
              pad_left(pw, 7) + "   ->  " + class_name(pred))

    print("\nKNN Classification completed.")
    print("=" * 65)
