"""
Author: Ahmet Aksoy
Date: 2026-03-23
Mojo version: 0.26.2 | Python 3.12 | Ubuntu

Random Forest Classifier — Pure Mojo Implementation
====================================================

Random Forest is an ensemble of Decision Trees trained on random
subsets of the data and features (bagging + feature randomization).

Algorithm:
  For each tree t = 1..n_trees:
    1. Bootstrap sample: draw n samples with replacement
    2. Build Decision Tree with max_features random features at each split
    3. Store tree nodes in parallel flat lists

  Prediction:
    Run sample through all trees, take majority vote.

Node storage: parallel flat lists per tree.
  tree_features[t][node]   : split feature (-1 = leaf)
  tree_thresholds[t][node] : split threshold
  tree_lefts[t][node]      : left child index
  tree_rights[t][node]     : right child index
  tree_preds[t][node]      : majority class prediction

Demo: Iris flower classification (3 classes, 2 features).
"""

from std.math import sqrt


# ------------------------------------------------------------------ #
# LCG pseudo-random (pure functions, no struct needed)
# ------------------------------------------------------------------ #

fn lcg_next(state: UInt64) -> UInt64:
    """Return next LCG state."""
    return state * 6364136223846793005 + 1442695040888963407


fn lcg_int(mut state: UInt64, n: Int) -> Int:
    """Return pseudo-random Int in [0, n) and advance state."""
    state = lcg_next(state)
    return Int(state % UInt64(n))


# ------------------------------------------------------------------ #
# Gini helpers
# ------------------------------------------------------------------ #

fn gini_impurity(labels: List[Int], indices: List[Int],
                 n_classes: Int) -> Float64:
    """Compute Gini impurity for a subset."""
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
    """Check if all samples share the same label."""
    if len(indices) == 0:
        return True
    var first = labels[indices[0]]
    for i in range(1, len(indices)):
        if labels[indices[i]] != first:
            return False
    return True


# ------------------------------------------------------------------ #
# Tree builder — free functions (avoids struct destroy issues)
# ------------------------------------------------------------------ #

fn best_feature(x: List[List[Float64]], y: List[Int],
                indices: List[Int], n_classes: Int,
                n_features: Int, max_features: Int,
                mut rng_state: UInt64) -> Int:
    """Find best split feature using random feature subset."""
    var best_f    = -1
    var best_gini = 1.0e9
    var n         = len(indices)

    # Random feature subset via Fisher-Yates partial shuffle
    var feat_idx = List[Int]()
    for f in range(n_features):
        feat_idx.append(f)
    var mf = min(max_features, n_features)
    for i in range(mf):
        var j   = i + lcg_int(rng_state, n_features - i)
        var tmp = feat_idx[i]
        feat_idx[i] = feat_idx[j]
        feat_idx[j] = tmp

    for fi in range(mf):
        var f    = feat_idx[fi]
        var seen = List[Float64]()
        for i in range(n):
            var val   = x[indices[i]][f]
            var found = False
            for s in range(len(seen)):
                if seen[s] == val:
                    found = True
                    break
            if not found:
                seen.append(val)

        for v in range(len(seen)):
            var thr   = seen[v]
            var left  = List[Int]()
            var right = List[Int]()
            for i in range(n):
                if x[indices[i]][f] <= thr:
                    left.append(indices[i])
                else:
                    right.append(indices[i])
            if len(left) == 0 or len(right) == 0:
                continue
            var gl = gini_impurity(y, left,  n_classes)
            var gr = gini_impurity(y, right, n_classes)
            var wg = (Float64(len(left)) * gl +
                      Float64(len(right)) * gr) / Float64(n)
            if wg < best_gini:
                best_gini = wg
                best_f    = f
    return best_f


fn best_threshold(x: List[List[Float64]], y: List[Int],
                  indices: List[Int], feature: Int,
                  n_classes: Int) -> Float64:
    """Find best threshold for a given feature."""
    var best_t    = 0.0
    var best_gini = 1.0e9
    var n         = len(indices)
    var seen      = List[Float64]()
    for i in range(n):
        var val   = x[indices[i]][feature]
        var found = False
        for s in range(len(seen)):
            if seen[s] == val:
                found = True
                break
        if not found:
            seen.append(val)

    for v in range(len(seen)):
        var thr   = seen[v]
        var left  = List[Int]()
        var right = List[Int]()
        for i in range(n):
            if x[indices[i]][feature] <= thr:
                left.append(indices[i])
            else:
                right.append(indices[i])
        if len(left) == 0 or len(right) == 0:
            continue
        var gl = gini_impurity(y, left,  n_classes)
        var gr = gini_impurity(y, right, n_classes)
        var wg = (Float64(len(left)) * gl +
                  Float64(len(right)) * gr) / Float64(n)
        if wg < best_gini:
            best_gini = wg
            best_t    = thr
    return best_t


fn build_tree(x: List[List[Float64]], y: List[Int],
              indices: List[Int], depth: Int,
              max_depth: Int, min_samples: Int,
              n_classes: Int, n_features: Int,
              max_features: Int, mut rng_state: UInt64,
              mut feats: List[Int],
              mut threshs: List[Float64],
              mut lefts: List[Int],
              mut rights: List[Int],
              mut preds: List[Int]) -> Int:
    """
    Recursively build one tree into parallel lists.
    Returns the index of the created node.
    """
    var pred = majority_class(y, indices, n_classes)

    # Leaf conditions
    if (depth >= max_depth or
        len(indices) < min_samples or
        all_same_class(y, indices)):
        feats.append(-1)
        threshs.append(0.0)
        lefts.append(-1)
        rights.append(-1)
        preds.append(pred)
        return len(feats) - 1

    var bf = best_feature(x, y, indices, n_classes,
                          n_features, max_features, rng_state)
    if bf == -1:
        feats.append(-1)
        threshs.append(0.0)
        lefts.append(-1)
        rights.append(-1)
        preds.append(pred)
        return len(feats) - 1

    var bt = best_threshold(x, y, indices, bf, n_classes)

    var left_idx_list  = List[Int]()
    var right_idx_list = List[Int]()
    for i in range(len(indices)):
        if x[indices[i]][bf] <= bt:
            left_idx_list.append(indices[i])
        else:
            right_idx_list.append(indices[i])

    # Reserve node slot
    feats.append(bf)
    threshs.append(bt)
    lefts.append(-1)
    rights.append(-1)
    preds.append(pred)
    var node_idx = len(feats) - 1

    var li = build_tree(x, y, left_idx_list,  depth + 1,
                        max_depth, min_samples, n_classes,
                        n_features, max_features, rng_state,
                        feats, threshs, lefts, rights, preds)
    var ri = build_tree(x, y, right_idx_list, depth + 1,
                        max_depth, min_samples, n_classes,
                        n_features, max_features, rng_state,
                        feats, threshs, lefts, rights, preds)

    lefts[node_idx]  = li
    rights[node_idx] = ri
    return node_idx


fn predict_one(feats: List[Int], threshs: List[Float64],
               lefts: List[Int], rights: List[Int],
               preds: List[Int],
               x_query: List[Float64]) -> Int:
    """Predict class using one tree."""
    var idx = 0
    var go  = feats[idx] != -1
    while go:
        var f = feats[idx]
        var t = threshs[idx]
        if x_query[f] <= t:
            idx = lefts[idx]
        else:
            idx = rights[idx]
        go = feats[idx] != -1
    return preds[idx]


# ------------------------------------------------------------------ #
# Random Forest
# ------------------------------------------------------------------ #

struct RandomForest:
    """
    Random Forest Classifier.
    Each tree stored as 5 parallel Int/Float64 lists.
    """
    var n_trees   : Int
    var max_depth : Int
    var n_classes : Int
    var n_features: Int
    var max_features: Int

    var tree_feats   : List[List[Int]]
    var tree_threshs : List[List[Float64]]
    var tree_lefts   : List[List[Int]]
    var tree_rights  : List[List[Int]]
    var tree_preds   : List[List[Int]]

    fn __init__(out self, n_trees: Int = 10, max_depth: Int = 5,
                n_classes: Int = 3, n_features: Int = 2,
                max_features: Int = -1):
        self.n_trees    = n_trees
        self.max_depth  = max_depth
        self.n_classes  = n_classes
        self.n_features = n_features
        if max_features == -1:
            self.max_features = max(1, Int(sqrt(Float64(n_features))))
        else:
            self.max_features = max_features
        self.tree_feats   = List[List[Int]]()
        self.tree_threshs = List[List[Float64]]()
        self.tree_lefts   = List[List[Int]]()
        self.tree_rights  = List[List[Int]]()
        self.tree_preds   = List[List[Int]]()

    fn fit(mut self, x: List[List[Float64]], y: List[Int]):
        """Train all trees with bootstrap sampling."""
        var n         = len(x)
        var rng_state : UInt64 = 42

        self.tree_feats   = List[List[Int]]()
        self.tree_threshs = List[List[Float64]]()
        self.tree_lefts   = List[List[Int]]()
        self.tree_rights  = List[List[Int]]()
        self.tree_preds   = List[List[Int]]()

        for _ in range(self.n_trees):
            # Bootstrap sample
            var boot = List[Int]()
            for _ in range(n):
                boot.append(lcg_int(rng_state, n))

            # Build tree into local lists
            var feats   = List[Int]()
            var threshs = List[Float64]()
            var lefts   = List[Int]()
            var rights  = List[Int]()
            var preds   = List[Int]()

            _ = build_tree(x, y, boot, 0,
                           self.max_depth, 1,
                           self.n_classes, self.n_features,
                           self.max_features, rng_state,
                           feats, threshs, lefts, rights, preds)

            self.tree_feats.append(feats^)
            self.tree_threshs.append(threshs^)
            self.tree_lefts.append(lefts^)
            self.tree_rights.append(rights^)
            self.tree_preds.append(preds^)

    fn predict_single(self, x_query: List[Float64]) -> Int:
        """Predict class by majority vote across all trees."""
        var votes = List[Int]()
        for _ in range(self.n_classes):
            votes.append(0)
        for t in range(self.n_trees):
            var pred = predict_one(
                self.tree_feats[t], self.tree_threshs[t],
                self.tree_lefts[t], self.tree_rights[t],
                self.tree_preds[t], x_query
            )
            votes[pred] += 1
        var best = 0
        for c in range(1, self.n_classes):
            if votes[c] > votes[best]:
                best = c
        return best

    fn predict(self, x: List[List[Float64]]) -> List[Int]:
        """Predict classes for all samples."""
        var preds = List[Int]()
        for i in range(len(x)):
            preds.append(self.predict_single(x[i]))
        return preds^

    fn feature_importance(self) -> List[Float64]:
        """Estimate feature importance by split frequency."""
        var counts = List[Float64]()
        for _ in range(self.n_features):
            counts.append(0.0)
        var total: Float64 = 0.0
        for t in range(self.n_trees):
            for i in range(len(self.tree_feats[t])):
                var f = self.tree_feats[t][i]
                if f != -1:
                    counts[f] += 1.0
                    total += 1.0
        if total > 0.0:
            for f in range(self.n_features):
                counts[f] /= total
        return counts^


# ------------------------------------------------------------------ #
# Helpers
# ------------------------------------------------------------------ #

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
# Demo
# ------------------------------------------------------------------ #

fn main():
    print("=" * 65)
    print("  Random Forest Classifier")
    print("  Demo: Iris Flower Classification")
    print("  Features: petal length (cm), petal width (cm)")
    print("  Classes : 0=Setosa, 1=Versicolor, 2=Virginica")
    print("=" * 65)

    var x_data = List[List[Float64]]()
    var y_data = List[Int]()

    # Setosa
    x_data.append(make_point(1.4,0.2)); y_data.append(0)
    x_data.append(make_point(1.3,0.2)); y_data.append(0)
    x_data.append(make_point(1.5,0.2)); y_data.append(0)
    x_data.append(make_point(1.4,0.3)); y_data.append(0)
    x_data.append(make_point(1.7,0.4)); y_data.append(0)
    x_data.append(make_point(1.5,0.1)); y_data.append(0)
    x_data.append(make_point(1.6,0.2)); y_data.append(0)
    x_data.append(make_point(1.1,0.1)); y_data.append(0)
    x_data.append(make_point(1.2,0.2)); y_data.append(0)
    x_data.append(make_point(1.5,0.3)); y_data.append(0)
    # Versicolor
    x_data.append(make_point(4.7,1.4)); y_data.append(1)
    x_data.append(make_point(4.5,1.5)); y_data.append(1)
    x_data.append(make_point(4.9,1.5)); y_data.append(1)
    x_data.append(make_point(4.0,1.3)); y_data.append(1)
    x_data.append(make_point(4.6,1.5)); y_data.append(1)
    x_data.append(make_point(4.5,1.3)); y_data.append(1)
    x_data.append(make_point(4.7,1.6)); y_data.append(1)
    x_data.append(make_point(3.3,1.0)); y_data.append(1)
    x_data.append(make_point(4.6,1.3)); y_data.append(1)
    x_data.append(make_point(3.9,1.4)); y_data.append(1)
    # Virginica
    x_data.append(make_point(6.0,2.5)); y_data.append(2)
    x_data.append(make_point(5.1,1.9)); y_data.append(2)
    x_data.append(make_point(5.9,2.1)); y_data.append(2)
    x_data.append(make_point(5.6,1.8)); y_data.append(2)
    x_data.append(make_point(5.8,2.2)); y_data.append(2)
    x_data.append(make_point(6.6,2.1)); y_data.append(2)
    x_data.append(make_point(6.3,1.8)); y_data.append(2)
    x_data.append(make_point(6.1,2.5)); y_data.append(2)
    x_data.append(make_point(6.4,2.0)); y_data.append(2)
    x_data.append(make_point(5.6,2.1)); y_data.append(2)

    var n = len(y_data)
    print("\nDataset : " + String(n) + " samples (10 per class)")

    var class_names = List[String]()
    class_names.append("Setosa    ")
    class_names.append("Versicolor")
    class_names.append("Virginica ")

    # Accuracy vs n_trees
    print("\n--- Accuracy vs Number of Trees ---")
    print("Trees   Accuracy")
    print("-" * 22)
    var tree_counts = List[Int]()
    tree_counts.append(1)
    tree_counts.append(3)
    tree_counts.append(5)
    tree_counts.append(10)
    tree_counts.append(20)
    tree_counts.append(50)
    for i in range(len(tree_counts)):
        var nt = tree_counts[i]
        var m  = RandomForest(n_trees=nt, max_depth=5,
                              n_classes=3, n_features=2)
        m.fit(x_data, y_data)
        var p  = m.predict(x_data)
        var a  = accuracy(y_data, p)
        print(pad_left(String(nt), 5) + "   " + float_str(a, 1) + "%")

    # Main model
    print("\n--- Predictions (20 trees, max_depth=5) ---")
    var model = RandomForest(n_trees=20, max_depth=5,
                             n_classes=3, n_features=2)
    model.fit(x_data, y_data)
    var preds = model.predict(x_data)
    var acc   = accuracy(y_data, preds)

    print("PetalLen  PetalWid  Actual        Predicted     Correct?")
    print("-" * 62)
    for i in range(n):
        var pl      = float_str(x_data[i][0], 1)
        var pw      = float_str(x_data[i][1], 1)
        var actual  = class_names[y_data[i]]
        var pred    = class_names[preds[i]]
        var correct = "Yes" if preds[i] == y_data[i] else "No "
        print(pad_left(pl, 7) + "   " +
              pad_left(pw, 7) + "   " +
              actual + "   " + pred + "   " + correct)

    print("\nAccuracy (20 trees): " + float_str(acc, 1) + "%")

    # Feature importance
    var importance = model.feature_importance()
    print("\n--- Feature Importance ---")
    print("petal_length : " + float_str(importance[0] * 100.0, 1) + "%")
    print("petal_width  : " + float_str(importance[1] * 100.0, 1) + "%")

    # New predictions
    print("\n--- New Flower Predictions ---")
    print("PetalLen  PetalWid  ->  Predicted")
    print("-" * 40)
    var test = List[List[Float64]]()
    test.append(make_point(1.3, 0.2))
    test.append(make_point(4.5, 1.4))
    test.append(make_point(5.8, 2.0))
    test.append(make_point(3.8, 1.2))
    test.append(make_point(5.0, 1.7))
    for i in range(len(test)):
        var pl   = float_str(test[i][0], 1)
        var pw   = float_str(test[i][1], 1)
        var pred = model.predict_single(test[i])
        print(pad_left(pl, 7) + "   " +
              pad_left(pw, 7) + "   ->  " + class_names[pred])

    print("\nRandom Forest completed.")
    print("=" * 65)
