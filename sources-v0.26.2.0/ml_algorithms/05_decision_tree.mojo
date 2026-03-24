"""
Author: Ahmet Aksoy
Date: 2026-03-20
Mojo version: 0.26.2.0
AI: Claude Sonnet 4.6

Decision Tree Classifier — Pure Mojo Implementation
====================================================

A Decision Tree splits data recursively by finding the feature
and threshold that best separates the classes at each node.

Splitting criterion: Gini Impurity
  Gini(S) = 1 - Σ p_i²
  Lower Gini = purer node

Algorithm (recursive):
  1. If all samples same class -> leaf node
  2. If max depth reached      -> leaf node (majority class)
  3. Find best (feature, threshold) split minimizing weighted Gini
  4. Split data into left/right subsets
  5. Recurse on each subset

Node storage: parallel lists (avoids List[CustomStruct] Copyable issues)
  node_feature   : feature index (-1 = leaf)
  node_threshold : split threshold
  node_left      : left  child index (-1 = none)
  node_right     : right child index (-1 = none)
  node_pred      : majority class prediction
  node_gini      : Gini impurity
  node_samples   : number of samples

Demo dataset: Play Tennis (classic ML dataset)
  outlook     : 0=Sunny, 1=Overcast, 2=Rain
  temperature : 0=Hot,   1=Mild,     2=Cool
  humidity    : 0=High,  1=Normal
  wind        : 0=Weak,  1=Strong
  label       : 0=No Play, 1=Play
"""


# ------------------------------------------------------------------ #
# Helper functions
# ------------------------------------------------------------------ #

fn gini_impurity(labels: List[Int], indices: List[Int],
                 n_classes: Int) -> Float64:
    """Compute Gini impurity for a subset of labels."""
    var n = len(indices)
    if n == 0:
        return 0.0
    var counts = List[Int]()
    for _ in range(n_classes):
        counts.append(0)
    for i in range(n):
        counts[labels[indices[i]]] += 1
    var impurity: Float64 = 1.0
    for c in range(n_classes):
        var p = Float64(counts[c]) / Float64(n)
        impurity -= p * p
    return impurity


fn majority_class(labels: List[Int], indices: List[Int],
                  n_classes: Int) -> Int:
    """Return the most common class in a subset."""
    var counts = List[Int]()
    for _ in range(n_classes):
        counts.append(0)
    for i in range(len(indices)):
        counts[labels[indices[i]]] += 1
    var best = 0
    for c in range(1, n_classes):
        if counts[c] > counts[best]:
            best = c
    return best


fn all_same_class(labels: List[Int], indices: List[Int]) -> Bool:
    """Check if all samples in subset have the same label."""
    if len(indices) == 0:
        return True
    var first = labels[indices[0]]
    for i in range(1, len(indices)):
        if labels[indices[i]] != first:
            return False
    return True


fn unique_values(x: List[List[Int]], feature: Int,
                 indices: List[Int]) -> List[Int]:
    """Get unique values of a feature in a subset."""
    var seen = List[Int]()
    for i in range(len(indices)):
        var val = x[indices[i]][feature]
        var already = False
        for j in range(len(seen)):
            if seen[j] == val:
                already = True
                break
        if not already:
            seen.append(val)
    return seen^


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


fn make_sample(a: Int, b: Int, c: Int, d: Int) -> List[Int]:
    """Create a 4-feature vector."""
    var s = List[Int]()
    s.append(a); s.append(b); s.append(c); s.append(d)
    return s^


# ------------------------------------------------------------------ #
# Decision Tree — parallel list storage
# ------------------------------------------------------------------ #

struct DecisionTree:
    """
    Decision Tree Classifier using Gini Impurity.
    Nodes are stored as parallel lists to avoid
    List[CustomStruct] Copyable trait issues in Mojo 0.26.1.
    """
    var max_depth  : Int
    var min_samples: Int
    var n_classes  : Int
    var n_features : Int

    # Parallel node arrays — index i = node i
    var node_feature  : List[Int]
    var node_threshold: List[Int]
    var node_left     : List[Int]
    var node_right    : List[Int]
    var node_pred     : List[Int]
    var node_gini     : List[Float64]
    var node_samples  : List[Int]

    fn __init__(out self, max_depth: Int = 5,
                min_samples: Int = 1,
                n_classes: Int = 2,
                n_features: Int = 4):
        self.max_depth    = max_depth
        self.min_samples  = min_samples
        self.n_classes    = n_classes
        self.n_features   = n_features
        self.node_feature   = List[Int]()
        self.node_threshold = List[Int]()
        self.node_left      = List[Int]()
        self.node_right     = List[Int]()
        self.node_pred      = List[Int]()
        self.node_gini      = List[Float64]()
        self.node_samples   = List[Int]()

    fn _n_nodes(self) -> Int:
        """Return total number of nodes."""
        return len(self.node_feature)

    fn _is_leaf(self, idx: Int) -> Bool:
        """Return True if node idx is a leaf."""
        return self.node_feature[idx] == -1

    fn _add_node(mut self, feature: Int, threshold: Int,
                 pred: Int, gini: Float64, samples: Int) -> Int:
        """Append a new node and return its index."""
        self.node_feature.append(feature)
        self.node_threshold.append(threshold)
        self.node_left.append(-1)
        self.node_right.append(-1)
        self.node_pred.append(pred)
        self.node_gini.append(gini)
        self.node_samples.append(samples)
        return self._n_nodes() - 1

    fn _best_split_feature(self, x: List[List[Int]], y: List[Int],
                            indices: List[Int]) -> Int:
        """Return best feature index for splitting."""
        var best_f    = -1
        var best_gini = 1.0e9
        var n = len(indices)
        for f in range(self.n_features):
            var vals = unique_values(x, f, indices)
            for v in range(len(vals)):
                var thr   = vals[v]
                var left  = List[Int]()
                var right = List[Int]()
                for i in range(n):
                    if x[indices[i]][f] <= thr:
                        left.append(indices[i])
                    else:
                        right.append(indices[i])
                if len(left) == 0 or len(right) == 0:
                    continue
                var gl = gini_impurity(y, left,  self.n_classes)
                var gr = gini_impurity(y, right, self.n_classes)
                var wg = (Float64(len(left)) * gl +
                          Float64(len(right)) * gr) / Float64(n)
                if wg < best_gini:
                    best_gini = wg
                    best_f    = f
        return best_f

    fn _best_split_threshold(self, x: List[List[Int]], y: List[Int],
                              indices: List[Int], feature: Int) -> Int:
        """Return best threshold for a given feature."""
        var best_t    = -1
        var best_gini = 1.0e9
        var n = len(indices)
        var vals = unique_values(x, feature, indices)
        for v in range(len(vals)):
            var thr   = vals[v]
            var left  = List[Int]()
            var right = List[Int]()
            for i in range(n):
                if x[indices[i]][feature] <= thr:
                    left.append(indices[i])
                else:
                    right.append(indices[i])
            if len(left) == 0 or len(right) == 0:
                continue
            var gl = gini_impurity(y, left,  self.n_classes)
            var gr = gini_impurity(y, right, self.n_classes)
            var wg = (Float64(len(left)) * gl +
                      Float64(len(right)) * gr) / Float64(n)
            if wg < best_gini:
                best_gini = wg
                best_t    = thr
        return best_t

    fn _build(mut self, x: List[List[Int]], y: List[Int],
              indices: List[Int], depth: Int) -> Int:
        """Recursively build tree. Returns index of created node."""
        var g    = gini_impurity(y, indices, self.n_classes)
        var pred = majority_class(y, indices, self.n_classes)
        var ns   = len(indices)

        # Leaf conditions
        if depth >= self.max_depth or ns < self.min_samples or all_same_class(y, indices):
            return self._add_node(-1, -1, pred, g, ns)

        # Find best split
        var best_f = self._best_split_feature(x, y, indices)
        if best_f == -1:
            return self._add_node(-1, -1, pred, g, ns)
        var best_t = self._best_split_threshold(x, y, indices, best_f)
        if best_t == -1:
            return self._add_node(-1, -1, pred, g, ns)

        # Split indices
        var left  = List[Int]()
        var right = List[Int]()
        for i in range(ns):
            if x[indices[i]][best_f] <= best_t:
                left.append(indices[i])
            else:
                right.append(indices[i])

        # Reserve node slot
        var node_idx = self._add_node(best_f, best_t, pred, g, ns)

        # Build subtrees
        var left_idx  = self._build(x, y, left,  depth + 1)
        var right_idx = self._build(x, y, right, depth + 1)

        self.node_left[node_idx]  = left_idx
        self.node_right[node_idx] = right_idx
        return node_idx

    fn fit(mut self, x: List[List[Int]], y: List[Int]):
        """Build the decision tree from training data."""
        # Reset
        self.node_feature   = List[Int]()
        self.node_threshold = List[Int]()
        self.node_left      = List[Int]()
        self.node_right     = List[Int]()
        self.node_pred      = List[Int]()
        self.node_gini      = List[Float64]()
        self.node_samples   = List[Int]()

        var indices = List[Int]()
        for i in range(len(x)):
            indices.append(i)
        _ = self._build(x, y, indices, 0)

    fn predict_single(self, x_query: List[Int]) -> Int:
        """Predict class for a single sample."""
        var idx = 0
        var go  = not self._is_leaf(idx)
        while go:
            var f = self.node_feature[idx]
            var t = self.node_threshold[idx]
            if x_query[f] <= t:
                idx = self.node_left[idx]
            else:
                idx = self.node_right[idx]
            go = not self._is_leaf(idx)
        return self.node_pred[idx]

    fn predict(self, x: List[List[Int]]) -> List[Int]:
        """Predict classes for a list of samples."""
        var preds = List[Int]()
        for i in range(len(x)):
            preds.append(self.predict_single(x[i]))
        return preds^

    fn accuracy(self, y_true: List[Int], y_pred: List[Int]) -> Float64:
        """Compute accuracy (%)."""
        var correct = 0
        for i in range(len(y_true)):
            if y_true[i] == y_pred[i]:
                correct += 1
        return Float64(correct) / Float64(len(y_true)) * 100.0

    fn print_tree(self, node_idx: Int, depth: Int,
                  feature_names: List[String],
                  class_names: List[String]):
        """Print tree structure recursively."""
        var indent = String("")
        for _ in range(depth * 4):
            indent += " "
        if self._is_leaf(node_idx):
            print(indent + "-> Predict: " +
                  class_names[self.node_pred[node_idx]] +
                  " (n=" + String(self.node_samples[node_idx]) +
                  ", gini=" + float_str(self.node_gini[node_idx], 3) + ")")
        else:
            var fname = feature_names[self.node_feature[node_idx]]
            var tval  = String(self.node_threshold[node_idx])
            print(indent + "[" + fname + " <= " + tval + "]" +
                  "  (n=" + String(self.node_samples[node_idx]) +
                  ", gini=" + float_str(self.node_gini[node_idx], 3) + ")")
            print(indent + "  True:")
            self.print_tree(self.node_left[node_idx],
                            depth + 1, feature_names, class_names)
            print(indent + "  False:")
            self.print_tree(self.node_right[node_idx],
                            depth + 1, feature_names, class_names)


# ------------------------------------------------------------------ #
# Demo
# ------------------------------------------------------------------ #

fn main():
    print("=" * 60)
    print("  Decision Tree Classifier -- Gini Impurity")
    print("  Demo: Play Tennis Dataset")
    print("=" * 60)
    print("\nFeature encoding:")
    print("  outlook     : 0=Sunny, 1=Overcast, 2=Rain")
    print("  temperature : 0=Hot,   1=Mild,     2=Cool")
    print("  humidity    : 0=High,  1=Normal")
    print("  wind        : 0=Weak,  1=Strong")
    print("  label       : 0=No Play, 1=Play")

    var x_data = List[List[Int]]()
    var y_data = List[Int]()

    x_data.append(make_sample(0,0,0,0)); y_data.append(0)
    x_data.append(make_sample(0,0,0,1)); y_data.append(0)
    x_data.append(make_sample(1,0,0,0)); y_data.append(1)
    x_data.append(make_sample(2,1,0,0)); y_data.append(1)
    x_data.append(make_sample(2,2,1,0)); y_data.append(1)
    x_data.append(make_sample(2,2,1,1)); y_data.append(0)
    x_data.append(make_sample(1,2,1,1)); y_data.append(1)
    x_data.append(make_sample(0,1,0,0)); y_data.append(0)
    x_data.append(make_sample(0,2,1,0)); y_data.append(1)
    x_data.append(make_sample(2,1,1,0)); y_data.append(1)
    x_data.append(make_sample(0,1,1,1)); y_data.append(1)
    x_data.append(make_sample(1,1,0,1)); y_data.append(1)
    x_data.append(make_sample(1,0,1,0)); y_data.append(1)
    x_data.append(make_sample(2,1,0,1)); y_data.append(0)

    var n = len(y_data)
    var play_count = 0
    for i in range(n):
        if y_data[i] == 1:
            play_count += 1
    print("\nDataset : " + String(n) + " days")
    print("Play    : " + String(play_count))
    print("No Play : " + String(n - play_count))

    var feature_names = List[String]()
    feature_names.append("outlook")
    feature_names.append("temperature")
    feature_names.append("humidity")
    feature_names.append("wind")

    var class_names = List[String]()
    class_names.append("No Play")
    class_names.append("Play   ")

    var model = DecisionTree(
        max_depth=5, min_samples=1, n_classes=2, n_features=4
    )
    model.fit(x_data, y_data)
    print("\nTree nodes: " + String(model._n_nodes()))

    print("\n--- Decision Tree Structure ---")
    model.print_tree(0, 0, feature_names, class_names)

    var preds = model.predict(x_data)
    var acc   = model.accuracy(y_data, preds)

    var outlook_names = List[String]()
    outlook_names.append("Sunny   ")
    outlook_names.append("Overcast")
    outlook_names.append("Rain    ")

    print("\n--- Predictions vs Actual ---")
    print("Outlook     Temp  Hum  Wind  Actual    Predicted  OK?")
    print("-" * 57)
    for i in range(n):
        var out_s  = outlook_names[x_data[i][0]]
        var temp_s = pad_left(String(x_data[i][1]), 4)
        var hum_s  = pad_left(String(x_data[i][2]), 4)
        var win_s  = pad_left(String(x_data[i][3]), 4)
        var act_s  = pad_left(class_names[y_data[i]], 9)
        var pre_s  = pad_left(class_names[preds[i]],  9)
        var ok_s   = "Yes" if preds[i] == y_data[i] else "No "
        print(out_s + temp_s + hum_s + win_s +
              "  " + act_s + "  " + pre_s + "  " + ok_s)
    print("\nAccuracy: " + float_str(acc, 1) + "%")

    print("\n--- Accuracy vs Max Depth ---")
    print("Depth   Nodes   Accuracy")
    print("-" * 28)
    for d in range(1, 7):
        var m = DecisionTree(
            max_depth=d, min_samples=1, n_classes=2, n_features=4
        )
        m.fit(x_data, y_data)
        var p = m.predict(x_data)
        var a = m.accuracy(y_data, p)
        print(pad_left(String(d), 5) +
              pad_left(String(m._n_nodes()), 8) +
              "   " + float_str(a, 1) + "%")

    print("\n--- New Day Predictions ---")
    print("Outlook     Temp  Hum  Wind  ->  Decision")
    print("-" * 45)
    var test_data = List[List[Int]]()
    test_data.append(make_sample(0, 1, 1, 0))
    test_data.append(make_sample(2, 2, 1, 1))
    test_data.append(make_sample(1, 0, 0, 1))
    test_data.append(make_sample(0, 0, 0, 1))

    for i in range(len(test_data)):
        var out_s  = outlook_names[test_data[i][0]]
        var temp_s = pad_left(String(test_data[i][1]), 4)
        var hum_s  = pad_left(String(test_data[i][2]), 4)
        var win_s  = pad_left(String(test_data[i][3]), 4)
        var pred   = model.predict_single(test_data[i])
        print(out_s + temp_s + hum_s + win_s +
              "  ->  " + class_names[pred])

    print("\nDecision Tree completed.")
    print("=" * 60)
