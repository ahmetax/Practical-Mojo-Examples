"""
Author: Ahmet Aksoy
Date: 2026-03-26
Mojo version: 0.26.2 | Python 3.12 | Ubuntu
AI: Claude Sonnet 4.6

14_xgboost.mojo -- XGBoost Classifier (pure Mojo)

Algorithm:
  XGBoost builds an ensemble of regression trees using second-order
  Taylor approximation of the loss function.

  For multi-class (K classes) it trains K separate boosting chains,
  one per class, using softmax probabilities.

  Each boosting round:
    1. Compute softmax probabilities from current raw scores
    2. Compute gradient g_i = p_ik - y_ik  (one-vs-rest)
    3. Compute hessian  h_i = p_ik * (1 - p_ik)
    4. Grow a regression tree:
         split gain = 0.5 * [G_L^2/(H_L+lam) + G_R^2/(H_R+lam)
                             - G^2/(H+lam)] - gamma
         leaf weight = -G / (H + lam)
    5. Add leaf weights * learning_rate to raw scores
  Prediction: argmax over K raw scores.

  Tree storage: parallel lists (gotcha #37 -- List[CustomStruct] avoided)

Hyperparameters demonstrated:
  n_estimators, max_depth, learning_rate, lambda (L2), gamma (min gain)

Dataset: Iris (30 samples, 3 classes, 4 features)
"""

from std.math import exp


# ──────────────────────────────────────────────
# Constants  (gotcha #41 -- alias -> comptime)
# ──────────────────────────────────────────────
comptime N_SAMPLES  = 30
comptime N_FEATURES = 4
comptime N_CLASSES  = 3


# ──────────────────────────────────────────────
# Iris dataset  (30 samples x 4 features)
# sepal_len, sepal_wid, petal_len, petal_wid
# Classes: 0=Setosa  1=Versicolor  2=Virginica
# ──────────────────────────────────────────────
fn get_iris_data(mut X: List[Float64], mut y: List[Int]):
    var raw = List[Float64]()
    # Setosa (10 samples)
    raw.append(5.1); raw.append(3.5); raw.append(1.4); raw.append(0.2)
    raw.append(4.9); raw.append(3.0); raw.append(1.4); raw.append(0.2)
    raw.append(4.7); raw.append(3.2); raw.append(1.3); raw.append(0.2)
    raw.append(4.6); raw.append(3.1); raw.append(1.5); raw.append(0.2)
    raw.append(5.0); raw.append(3.6); raw.append(1.4); raw.append(0.2)
    raw.append(5.4); raw.append(3.9); raw.append(1.7); raw.append(0.4)
    raw.append(4.6); raw.append(3.4); raw.append(1.4); raw.append(0.3)
    raw.append(5.0); raw.append(3.4); raw.append(1.5); raw.append(0.2)
    raw.append(4.4); raw.append(2.9); raw.append(1.4); raw.append(0.2)
    raw.append(4.9); raw.append(3.1); raw.append(1.5); raw.append(0.1)
    # Versicolor (10 samples)
    raw.append(7.0); raw.append(3.2); raw.append(4.7); raw.append(1.4)
    raw.append(6.4); raw.append(3.2); raw.append(4.5); raw.append(1.5)
    raw.append(6.9); raw.append(3.1); raw.append(4.9); raw.append(1.5)
    raw.append(5.5); raw.append(2.3); raw.append(4.0); raw.append(1.3)
    raw.append(6.5); raw.append(2.8); raw.append(4.6); raw.append(1.5)
    raw.append(5.7); raw.append(2.8); raw.append(4.5); raw.append(1.3)
    raw.append(6.3); raw.append(3.3); raw.append(4.7); raw.append(1.6)
    raw.append(4.9); raw.append(2.4); raw.append(3.3); raw.append(1.0)
    raw.append(6.6); raw.append(2.9); raw.append(4.6); raw.append(1.3)
    raw.append(5.2); raw.append(2.7); raw.append(3.9); raw.append(1.4)
    # Virginica (10 samples)
    raw.append(6.3); raw.append(3.3); raw.append(6.0); raw.append(2.5)
    raw.append(5.8); raw.append(2.7); raw.append(5.1); raw.append(1.9)
    raw.append(7.1); raw.append(3.0); raw.append(5.9); raw.append(2.1)
    raw.append(6.3); raw.append(2.9); raw.append(5.6); raw.append(1.8)
    raw.append(6.5); raw.append(3.0); raw.append(5.8); raw.append(2.2)
    raw.append(7.6); raw.append(3.0); raw.append(6.6); raw.append(2.1)
    raw.append(4.9); raw.append(2.5); raw.append(4.5); raw.append(1.7)
    raw.append(7.3); raw.append(2.9); raw.append(6.3); raw.append(1.8)
    raw.append(6.7); raw.append(2.5); raw.append(5.8); raw.append(1.8)
    raw.append(7.2); raw.append(3.6); raw.append(6.1); raw.append(2.5)

    # gotcha #10 -- index-based iteration for List[Float64]
    for i in range(len(raw)):
        X.append(raw[i])
    for _ in range(10):
        y.append(0)
    for _ in range(10):
        y.append(1)
    for _ in range(10):
        y.append(2)


# ──────────────────────────────────────────────
# Softmax over K raw scores for one sample.
# Writes probabilities into probs[p_offset .. p_offset+n_classes].
# ──────────────────────────────────────────────
fn softmax_one(raw: List[Float64], offset: Int, n_classes: Int,
               mut probs: List[Float64], p_offset: Int):
    var max_val = raw[offset]
    for k in range(1, n_classes):
        if raw[offset + k] > max_val:
            max_val = raw[offset + k]
    var s = 0.0
    for k in range(n_classes):
        var e = exp(raw[offset + k] - max_val)
        probs[p_offset + k] = e
        s += e
    for k in range(n_classes):
        probs[p_offset + k] /= s


# ──────────────────────────────────────────────
# Tree storage: parallel lists  (gotcha #37)
# node_feature[i] == -1  ->  leaf node
# ──────────────────────────────────────────────
fn grow_tree(
    X: List[Float64],
    n_samples: Int, n_features: Int,
    indices: List[Int],
    G: List[Float64],
    H: List[Float64],
    depth: Int, max_depth: Int,
    lam: Float64, gamma: Float64,
    mut nf: List[Int],       # node_feature   (-1 = leaf)
    mut nt: List[Float64],   # node_threshold
    mut nl: List[Int],       # node_left
    mut nr: List[Int],       # node_right
    mut nw: List[Float64],   # node_weight    (leaf value)
) -> Int:
    # Allocate this node
    var node_id = len(nf)
    nf.append(-1)
    nt.append(0.0)
    nl.append(-1)
    nr.append(-1)
    nw.append(0.0)

    # Aggregate G and H
    var G_sum = 0.0
    var H_sum = 0.0
    for i in range(len(indices)):
        var idx = indices[i]
        G_sum += G[idx]
        H_sum += H[idx]

    # Optimal leaf weight: w* = -G / (H + lambda)
    nw[node_id] = -G_sum / (H_sum + lam)

    # Stop: max depth or single sample
    if depth >= max_depth or len(indices) <= 1:
        return node_id

    # ── Find best split (record scalars only -- gotcha #44) ──
    var best_gain    = gamma    # only split when gain > gamma
    var best_feature = -1
    var best_thresh  = 0.0

    for f in range(n_features):
        # Collect feature values for samples at this node
        var vals = List[Float64]()
        for i in range(len(indices)):
            vals.append(X[indices[i] * n_features + f])

        # Insertion sort  (gotcha #39 -- while + if: use boolean flag)
        for i in range(1, len(vals)):
            var key = vals[i]
            var j = i - 1
            var go = j >= 0 and vals[j] > key
            while go:
                vals[j + 1] = vals[j]
                j -= 1
                go = j >= 0 and vals[j] > key
            vals[j + 1] = key

        # Try each midpoint threshold
        for ti in range(len(vals) - 1):
            if vals[ti] == vals[ti + 1]:
                continue
            var thresh = (vals[ti] + vals[ti + 1]) / 2.0

            var GL = 0.0; var HL = 0.0
            var GR = 0.0; var HR = 0.0
            var n_left = 0; var n_right = 0

            for i in range(len(indices)):
                var idx = indices[i]
                if X[idx * n_features + f] <= thresh:
                    GL += G[idx]; HL += H[idx]
                    n_left += 1
                else:
                    GR += G[idx]; HR += H[idx]
                    n_right += 1

            if n_left == 0 or n_right == 0:
                continue

            var gain = 0.5 * (
                GL * GL / (HL + lam) +
                GR * GR / (HR + lam) -
                G_sum * G_sum / (H_sum + lam)
            ) - gamma

            if gain > best_gain:
                best_gain    = gain
                best_feature = f
                best_thresh  = thresh

    # No beneficial split found -- remain a leaf
    if best_feature == -1:
        return node_id

    # ── Rebuild left/right index lists once with the winning params ──
    # gotcha #44 -- List[Int] is not ImplicitlyCopyable;
    # save only scalars inside the loop, reconstruct lists here.
    var best_left  = List[Int]()
    var best_right = List[Int]()
    for i in range(len(indices)):
        var idx = indices[i]
        if X[idx * n_features + best_feature] <= best_thresh:
            best_left.append(idx)
        else:
            best_right.append(idx)

    # Record split in this node
    nf[node_id] = best_feature
    nt[node_id] = best_thresh

    # Grow children
    var left_id = grow_tree(
        X, n_samples, n_features,
        best_left, G, H,
        depth + 1, max_depth, lam, gamma,
        nf, nt, nl, nr, nw
    )
    var right_id = grow_tree(
        X, n_samples, n_features,
        best_right, G, H,
        depth + 1, max_depth, lam, gamma,
        nf, nt, nl, nr, nw
    )

    nl[node_id] = left_id
    nr[node_id] = right_id

    return node_id


# ──────────────────────────────────────────────
# Traverse a single tree for one sample; return leaf weight.
# gotcha #39 -- while + if/else: boolean control variable
# ──────────────────────────────────────────────
fn tree_predict_one(
    X: List[Float64], sample: Int, n_features: Int,
    nf: List[Int], nt: List[Float64],
    nl: List[Int], nr: List[Int], nw: List[Float64],
    root: Int
) -> Float64:
    var idx = root
    var go  = nf[idx] != -1
    while go:
        var f = nf[idx]
        if X[sample * n_features + f] <= nt[idx]:
            idx = nl[idx]
        else:
            idx = nr[idx]
        go = nf[idx] != -1
    return nw[idx]


# ──────────────────────────────────────────────
# XGBoost training
# Trains n_estimators trees per class (K trees per round).
# ──────────────────────────────────────────────
fn xgb_train(
    X: List[Float64], y: List[Int],
    n_samples: Int, n_features: Int, n_classes: Int,
    n_estimators: Int, max_depth: Int,
    lr: Float64, lam: Float64, gamma: Float64,
    mut all_nf   : List[List[Int]],
    mut all_nt   : List[List[Float64]],
    mut all_nl   : List[List[Int]],
    mut all_nr   : List[List[Int]],
    mut all_nw   : List[List[Float64]],
    mut all_roots: List[List[Int]],
    mut raw_scores: List[Float64]
):
    var probs = List[Float64]()
    for _ in range(n_samples * n_classes):
        probs.append(0.0)

    var G = List[Float64]()
    var H = List[Float64]()
    for _ in range(n_samples):
        G.append(0.0)
        H.append(0.0)

    var all_indices = List[Int]()
    for i in range(n_samples):
        all_indices.append(i)

    for _ in range(n_estimators):
        # Softmax probabilities
        for i in range(n_samples):
            softmax_one(raw_scores, i * n_classes, n_classes,
                        probs, i * n_classes)

        # One tree per class
        for k in range(n_classes):
            for i in range(n_samples):
                var p = probs[i * n_classes + k]
                var t = 0.0
                if y[i] == k:
                    t = 1.0
                G[i] = p - t
                H[i] = p * (1.0 - p)

            var root = grow_tree(
                X, n_samples, n_features,
                all_indices, G, H,
                0, max_depth, lam, gamma,
                all_nf[k], all_nt[k], all_nl[k], all_nr[k], all_nw[k]
            )
            all_roots[k].append(root)

            for i in range(n_samples):
                raw_scores[i * n_classes + k] += lr * tree_predict_one(
                    X, i, n_features,
                    all_nf[k], all_nt[k], all_nl[k], all_nr[k], all_nw[k],
                    root
                )


# ──────────────────────────────────────────────
# Predict class for one sample (argmax over K scores)
# ──────────────────────────────────────────────
fn xgb_predict_one(
    X: List[Float64], sample: Int, n_features: Int, n_classes: Int,
    all_nf   : List[List[Int]],
    all_nt   : List[List[Float64]],
    all_nl   : List[List[Int]],
    all_nr   : List[List[Int]],
    all_nw   : List[List[Float64]],
    all_roots: List[List[Int]]
) -> Int:
    var scores = List[Float64]()
    for _ in range(n_classes):
        scores.append(0.0)

    var n_rounds = len(all_roots[0])
    for rnd in range(n_rounds):
        for k in range(n_classes):
            scores[k] += tree_predict_one(
                X, sample, n_features,
                all_nf[k], all_nt[k], all_nl[k], all_nr[k], all_nw[k],
                all_roots[k][rnd]
            )

    var best = 0
    for k in range(1, n_classes):
        if scores[k] > scores[best]:
            best = k
    return best


# ──────────────────────────────────────────────
# Accuracy
# ──────────────────────────────────────────────
fn accuracy(y_true: List[Int], y_pred: List[Int]) -> Float64:
    var correct = 0
    for i in range(len(y_true)):
        if y_true[i] == y_pred[i]:
            correct += 1
    return Float64(correct) / Float64(len(y_true)) * 100.0


# ──────────────────────────────────────────────
# Confusion matrix
# ──────────────────────────────────────────────
fn print_confusion_matrix(y_true: List[Int], y_pred: List[Int], n_classes: Int):
    var cm = List[Int]()
    for _ in range(n_classes * n_classes):
        cm.append(0)
    for i in range(len(y_true)):
        cm[y_true[i] * n_classes + y_pred[i]] += 1

    print("Confusion Matrix (rows=actual, cols=predicted):")
    print("              Setosa  Versicol Virginica")
    var labels = List[String]()
    labels.append("Setosa   ")
    labels.append("Versicol ")
    labels.append("Virginica")

    for r in range(n_classes):
        var row_str = labels[r] + "   |"
        for c in range(n_classes):
            var cell = String(cm[r * n_classes + c])
            for _ in range(9 - len(cell)):
                row_str += " "
            row_str += cell
        print(row_str)


# ──────────────────────────────────────────────
# Feature importance: split frequency per feature
# ──────────────────────────────────────────────
fn print_feature_importance(
    all_nf: List[List[Int]],
    n_classes: Int, n_features: Int
):
    var usage = List[Int]()
    for _ in range(n_features):
        usage.append(0)

    for k in range(n_classes):
        for ni in range(len(all_nf[k])):
            var f = all_nf[k][ni]
            if f >= 0:
                usage[f] += 1

    var total = 0
    for f in range(n_features):
        total += usage[f]
    if total == 0:
        total = 1

    print("Feature Importance (split frequency):")
    var feat_names = List[String]()
    feat_names.append("sepal_len")
    feat_names.append("sepal_wid")
    feat_names.append("petal_len")
    feat_names.append("petal_wid")

    for f in range(n_features):
        var pct = Float64(usage[f]) / Float64(total) * 100.0
        var bar = ""
        for _ in range(Int(pct / 2.5)):
            bar += "#"
        print("  " + feat_names[f] + " | " + bar + " " + String(Int(pct)) + "%")


# ──────────────────────────────────────────────
# Run one experiment; return accuracy
# ──────────────────────────────────────────────
fn run_experiment(
    X: List[Float64], y: List[Int],
    n_samples: Int, n_features: Int, n_classes: Int,
    n_estimators: Int, max_depth: Int,
    lr: Float64, lam: Float64, gamma: Float64,
    print_details: Bool
) -> Float64:
    var all_nf    = List[List[Int]]()
    var all_nt    = List[List[Float64]]()
    var all_nl    = List[List[Int]]()
    var all_nr    = List[List[Int]]()
    var all_nw    = List[List[Float64]]()
    var all_roots = List[List[Int]]()

    for _ in range(n_classes):
        all_nf.append(List[Int]())
        all_nt.append(List[Float64]())
        all_nl.append(List[Int]())
        all_nr.append(List[Int]())
        all_nw.append(List[Float64]())
        all_roots.append(List[Int]())

    var raw_scores = List[Float64]()
    for _ in range(n_samples * n_classes):
        raw_scores.append(0.0)

    xgb_train(
        X, y, n_samples, n_features, n_classes,
        n_estimators, max_depth, lr, lam, gamma,
        all_nf, all_nt, all_nl, all_nr, all_nw, all_roots, raw_scores
    )

    var y_pred = List[Int]()
    for i in range(n_samples):
        y_pred.append(xgb_predict_one(
            X, i, n_features, n_classes,
            all_nf, all_nt, all_nl, all_nr, all_nw, all_roots
        ))

    var acc = accuracy(y, y_pred)

    if print_details:
        print("Accuracy: " + String(Int(acc)) + "%")

        var class_names = List[String]()
        class_names.append("Setosa   ")
        class_names.append("Versicol ")
        class_names.append("Virginica")
        for c in range(n_classes):
            var correct = 0; var total = 0
            for i in range(n_samples):
                if y[i] == c:
                    total += 1
                    if y_pred[i] == c:
                        correct += 1
            print("  " + class_names[c] + ": " +
                  String(correct) + "/" + String(total) + " correct")

        print()
        print_confusion_matrix(y, y_pred, n_classes)
        print()
        print_feature_importance(all_nf, n_classes, n_features)

    return acc


# ──────────────────────────────────────────────
# Parameter sensitivity study
# ──────────────────────────────────────────────
fn param_study(X: List[Float64], y: List[Int],
               n_samples: Int, n_features: Int, n_classes: Int):
    print("\n" + "=" * 55)
    print("Parameter Sensitivity")
    print("=" * 55)

    # n_estimators
    print("\nn_estimators  (max_depth=3, lr=0.3, lam=1.0, gamma=0.0):")
    var est_vals = List[Int]()
    est_vals.append(1); est_vals.append(3); est_vals.append(5)
    est_vals.append(10); est_vals.append(20)
    for ei in range(len(est_vals)):
        var n = est_vals[ei]
        var acc = run_experiment(X, y, n_samples, n_features, n_classes,
                                 n, 3, 0.3, 1.0, 0.0, False)
        print("  n_estimators=" + String(n) +
              "  ->  Accuracy=" + String(Int(acc)) + "%")

    # max_depth
    print("\nmax_depth  (n_estimators=10, lr=0.3, lam=1.0, gamma=0.0):")
    var depth_vals = List[Int]()
    depth_vals.append(1); depth_vals.append(2)
    depth_vals.append(3); depth_vals.append(4)
    for di in range(len(depth_vals)):
        var d = depth_vals[di]
        var acc = run_experiment(X, y, n_samples, n_features, n_classes,
                                 10, d, 0.3, 1.0, 0.0, False)
        print("  max_depth=" + String(d) +
              "  ->  Accuracy=" + String(Int(acc)) + "%")

    # learning_rate
    print("\nlearning_rate  (n_estimators=10, max_depth=3, lam=1.0, gamma=0.0):")
    var lr_vals = List[Float64]()
    lr_vals.append(0.1); lr_vals.append(0.3); lr_vals.append(0.5)
    lr_vals.append(0.8); lr_vals.append(1.0)
    for li in range(len(lr_vals)):
        var lr = lr_vals[li]
        var acc = run_experiment(X, y, n_samples, n_features, n_classes,
                                 10, 3, lr, 1.0, 0.0, False)
        print("  lr=" + String(Int(lr * 10)) + "e-1" +
              "  ->  Accuracy=" + String(Int(acc)) + "%")

    # lambda (L2)
    print("\nlambda  (n_estimators=10, max_depth=3, lr=0.3, gamma=0.0):")
    var lam_vals = List[Float64]()
    lam_vals.append(0.0); lam_vals.append(0.1); lam_vals.append(0.5)
    lam_vals.append(1.0); lam_vals.append(5.0)
    for li in range(len(lam_vals)):
        var lam = lam_vals[li]
        var acc = run_experiment(X, y, n_samples, n_features, n_classes,
                                 10, 3, 0.3, lam, 0.0, False)
        print("  lambda=" + String(Int(lam * 10)) + "e-1" +
              "  ->  Accuracy=" + String(Int(acc)) + "%")

    # gamma (min split gain)
    print("\ngamma  (n_estimators=10, max_depth=3, lr=0.3, lam=1.0):")
    var gam_vals = List[Float64]()
    gam_vals.append(0.0); gam_vals.append(0.01); gam_vals.append(0.05)
    gam_vals.append(0.1); gam_vals.append(0.5)
    for gi in range(len(gam_vals)):
        var gam = gam_vals[gi]
        var acc = run_experiment(X, y, n_samples, n_features, n_classes,
                                 10, 3, 0.3, 1.0, gam, False)
        print("  gamma=" + String(Int(gam * 100)) + "e-2" +
              "  ->  Accuracy=" + String(Int(acc)) + "%")


# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────
fn main():
    print("=" * 60)
    print("  XGBoost Classifier -- Mojo 0.26.2")
    print("  Dataset: Iris (30 samples, 4 features, 3 classes)")
    print("=" * 60)

    var X = List[Float64]()
    var y = List[Int]()
    get_iris_data(X, y)
    print("\n[Data] " + String(N_SAMPLES) + " samples loaded.")

    comptime N_EST  = 10
    comptime MAX_D  = 3
    var lr    : Float64 = 0.3
    var lam   : Float64 = 1.0
    var gamma : Float64 = 0.0

    print("\n[Config]")
    print("  n_estimators : " + String(N_EST))
    print("  max_depth    : " + String(MAX_D))
    print("  learning_rate: " + String(Int(lr * 10)) + "e-1")
    print("  lambda (L2)  : " + String(Int(lam)))
    print("  gamma        : " + String(Int(gamma)))

    print("\n[Training...]")
    _ = run_experiment(
        X, y, N_SAMPLES, N_FEATURES, N_CLASSES,
        N_EST, MAX_D, lr, lam, gamma,
        True
    )

    param_study(X, y, N_SAMPLES, N_FEATURES, N_CLASSES)

    print("\n" + "=" * 60)
    print("  XGBoost complete.")
    print("  Next: 15_tsne.mojo or 15_ensemble.mojo")
    print("=" * 60)
