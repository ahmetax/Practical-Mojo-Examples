"""
Author: Ahmet Aksoy
Date: 2026-03-27
Mojo version: 0.26.2 | Python 3.12 | Ubuntu

16_ensemble.mojo -- Ensemble Methods: Voting + Stacking (pure Mojo)

Ensemble strategies implemented:
  1. Hard Voting   -- majority vote over base classifiers
  2. Soft Voting   -- average class probabilities, then argmax
  3. Stacking      -- base classifiers feed a meta-learner (Logistic Regression)

Base classifiers (self-contained, no external modules):
  - K-Nearest Neighbors (k=5, Euclidean distance)
  - Decision Tree       (max_depth=4, Gini impurity)
  - Gaussian Naive Bayes

Meta-learner (Stacking):
  - Logistic Regression (multi-class, softmax, gradient descent)

Dataset: Iris (30 samples, 3 classes, 4 features)
"""

from std.math import sqrt, exp, log


# ──────────────────────────────────────────────
# Constants  (gotcha #41 -- alias -> comptime)
# ──────────────────────────────────────────────
comptime N_SAMPLES  = 30
comptime N_FEATURES = 4
comptime N_CLASSES  = 3


# ──────────────────────────────────────────────
# Iris dataset
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


# ══════════════════════════════════════════════
# BASE CLASSIFIER 1: K-Nearest Neighbors
# ══════════════════════════════════════════════

fn knn_predict_one(
    X_train: List[Float64], y_train: List[Int],
    n_train: Int, n_features: Int,
    x_test: List[Float64],   # length n_features
    k: Int, n_classes: Int,
    mut probs: List[Float64]  # output: length n_classes
):
    # Compute distances to all training points
    var dists = List[Float64]()
    for i in range(n_train):
        var d = 0.0
        for f in range(n_features):
            var diff = x_test[f] - X_train[i * n_features + f]
            d += diff * diff
        dists.append(sqrt(d))

    # Find k nearest neighbours (partial selection sort)
    var votes = List[Int]()
    var used  = List[Int]()
    for _ in range(n_train):
        used.append(0)

    for _ in range(k):
        var best_d = 1e18
        var best_i = 0
        for i in range(n_train):
            if used[i] == 0 and dists[i] < best_d:
                best_d = dists[i]
                best_i = i
        used[best_i] = 1
        votes.append(y_train[best_i])

    # Class probability = vote fraction
    for c in range(n_classes):
        probs[c] = 0.0
    for vi in range(len(votes)):
        probs[votes[vi]] += 1.0
    for c in range(n_classes):
        probs[c] /= Float64(k)


fn knn_predict_all(
    X_train: List[Float64], y_train: List[Int],
    X_test: List[Float64],
    n_train: Int, n_test: Int, n_features: Int,
    k: Int, n_classes: Int,
    mut preds: List[Int],
    mut proba: List[Float64]   # n_test x n_classes
):
    for i in range(n_test):
        var x_i = List[Float64]()
        for f in range(n_features):
            x_i.append(X_test[i * n_features + f])
        var p = List[Float64]()
        for _ in range(n_classes):
            p.append(0.0)
        knn_predict_one(X_train, y_train, n_train, n_features,
                        x_i, k, n_classes, p)
        var best = 0
        for c in range(1, n_classes):
            if p[c] > p[best]:
                best = c
        preds.append(best)
        for c in range(n_classes):
            proba.append(p[c])


# ══════════════════════════════════════════════
# BASE CLASSIFIER 2: Decision Tree (Gini, max_depth)
# Tree stored as parallel lists  (gotcha #37)
# ══════════════════════════════════════════════

fn gini(counts: List[Int], total: Int) -> Float64:
    if total == 0:
        return 0.0
    var g = 1.0
    for c in range(len(counts)):
        var p = Float64(counts[c]) / Float64(total)
        g -= p * p
    return g


fn dt_grow(
    X: List[Float64], y: List[Int],
    indices: List[Int],
    n_features: Int, n_classes: Int,
    depth: Int, max_depth: Int,
    mut nf: List[Int],
    mut nt: List[Float64],
    mut nl: List[Int],
    mut nr: List[Int],
    mut nlab: List[Int]    # leaf label (-1 for internal nodes)
) -> Int:
    var node_id = len(nf)
    nf.append(-1); nt.append(0.0)
    nl.append(-1); nr.append(-1); nlab.append(-1)

    # Majority class at this node
    var counts = List[Int]()
    for _ in range(n_classes):
        counts.append(0)
    for i in range(len(indices)):
        counts[y[indices[i]]] += 1
    var majority = 0
    for c in range(1, n_classes):
        if counts[c] > counts[majority]:
            majority = c
    nlab[node_id] = majority

    # Stop conditions
    if depth >= max_depth or len(indices) <= 1:
        return node_id
    # Pure node
    var n_nonzero = 0
    for c in range(n_classes):
        if counts[c] > 0:
            n_nonzero += 1
    if n_nonzero == 1:
        return node_id

    # Find best split  (gotcha #44 -- save only scalars)
    var best_gain    = -1.0
    var best_feature = -1
    var best_thresh  = 0.0
    var parent_gini  = gini(counts, len(indices))

    for f in range(n_features):
        # Collect and sort values
        var vals = List[Float64]()
        for i in range(len(indices)):
            vals.append(X[indices[i] * n_features + f])
        # Insertion sort  (gotcha #39)
        for i in range(1, len(vals)):
            var key = vals[i]
            var j = i - 1
            var go = j >= 0 and vals[j] > key
            while go:
                vals[j + 1] = vals[j]
                j -= 1
                go = j >= 0 and vals[j] > key
            vals[j + 1] = key

        for ti in range(len(vals) - 1):
            if vals[ti] == vals[ti + 1]:
                continue
            var thresh = (vals[ti] + vals[ti + 1]) / 2.0
            var lc = List[Int]()
            var rc = List[Int]()
            for _ in range(n_classes):
                lc.append(0)
                rc.append(0)
            var nl_cnt = 0; var nr_cnt = 0
            for i in range(len(indices)):
                var idx = indices[i]
                if X[idx * n_features + f] <= thresh:
                    lc[y[idx]] += 1
                    nl_cnt += 1
                else:
                    rc[y[idx]] += 1
                    nr_cnt += 1
            if nl_cnt == 0 or nr_cnt == 0:
                continue
            var gain = parent_gini - (
                Float64(nl_cnt) / Float64(len(indices)) * gini(lc, nl_cnt) +
                Float64(nr_cnt) / Float64(len(indices)) * gini(rc, nr_cnt)
            )
            if gain > best_gain:
                best_gain    = gain
                best_feature = f
                best_thresh  = thresh

    if best_feature == -1:
        return node_id

    # Rebuild index lists once  (gotcha #44)
    var left_idx  = List[Int]()
    var right_idx = List[Int]()
    for i in range(len(indices)):
        var idx = indices[i]
        if X[idx * n_features + best_feature] <= best_thresh:
            left_idx.append(idx)
        else:
            right_idx.append(idx)

    nf[node_id] = best_feature
    nt[node_id] = best_thresh

    var left_id = dt_grow(X, y, left_idx, n_features, n_classes,
                          depth + 1, max_depth, nf, nt, nl, nr, nlab)
    var right_id = dt_grow(X, y, right_idx, n_features, n_classes,
                           depth + 1, max_depth, nf, nt, nl, nr, nlab)
    nl[node_id] = left_id
    nr[node_id] = right_id
    return node_id


fn dt_predict_one(
    X: List[Float64], sample: Int, n_features: Int,
    nf: List[Int], nt: List[Float64],
    nl: List[Int], nr: List[Int], nlab: List[Int],
    root: Int, n_classes: Int,
    mut probs: List[Float64]
):
    var idx = root
    # gotcha #39 -- while + if/else: boolean control variable
    var go = nf[idx] != -1
    while go:
        var f = nf[idx]
        if X[sample * n_features + f] <= nt[idx]:
            idx = nl[idx]
        else:
            idx = nr[idx]
        go = nf[idx] != -1
    # Hard label -> one-hot probability
    for c in range(n_classes):
        probs[c] = 0.0
    probs[nlab[idx]] = 1.0


fn dt_predict_all(
    X_train: List[Float64], y_train: List[Int],
    X_test: List[Float64],
    n_train: Int, n_test: Int, n_features: Int,
    n_classes: Int, max_depth: Int,
    mut preds: List[Int],
    mut proba: List[Float64]
):
    # Build tree on training data
    var all_idx = List[Int]()
    for i in range(n_train):
        all_idx.append(i)

    var nf   = List[Int]()
    var nt_  = List[Float64]()
    var nl_  = List[Int]()
    var nr_  = List[Int]()
    var nlab = List[Int]()
    var root = dt_grow(X_train, y_train, all_idx,
                       n_features, n_classes, 0, max_depth,
                       nf, nt_, nl_, nr_, nlab)

    for i in range(n_test):
        var p = List[Float64]()
        for _ in range(n_classes):
            p.append(0.0)
        dt_predict_one(X_test, i, n_features,
                       nf, nt_, nl_, nr_, nlab, root, n_classes, p)
        var best = 0
        for c in range(1, n_classes):
            if p[c] > p[best]:
                best = c
        preds.append(best)
        for c in range(n_classes):
            proba.append(p[c])


# ══════════════════════════════════════════════
# BASE CLASSIFIER 3: Gaussian Naive Bayes
# ══════════════════════════════════════════════

fn gnb_predict_all(
    X_train: List[Float64], y_train: List[Int],
    X_test: List[Float64],
    n_train: Int, n_test: Int, n_features: Int, n_classes: Int,
    mut preds: List[Int],
    mut proba: List[Float64]
):
    # Compute per-class mean and variance
    var mean = List[Float64]()
    var var_ = List[Float64]()
    var cnt  = List[Float64]()
    for _ in range(n_classes * n_features):
        mean.append(0.0)
        var_.append(0.0)
    for _ in range(n_classes):
        cnt.append(0.0)

    for i in range(n_train):
        var c = y_train[i]
        cnt[c] += 1.0
        for f in range(n_features):
            mean[c * n_features + f] += X_train[i * n_features + f]
    for c in range(n_classes):
        for f in range(n_features):
            mean[c * n_features + f] /= cnt[c]

    for i in range(n_train):
        var c = y_train[i]
        for f in range(n_features):
            var diff = X_train[i * n_features + f] - mean[c * n_features + f]
            var_[c * n_features + f] += diff * diff
    for c in range(n_classes):
        for f in range(n_features):
            var_[c * n_features + f] = var_[c * n_features + f] / cnt[c] + 1e-9

    var log_prior = List[Float64]()
    for c in range(n_classes):
        log_prior.append(log(cnt[c] / Float64(n_train)))

    for i in range(n_test):
        var best     = 0
        var best_lp  = -1e18
        var raw_scores = List[Float64]()
        for c in range(n_classes):
            var lp = log_prior[c]
            for f in range(n_features):
                var v    = var_[c * n_features + f]
                var diff = X_test[i * n_features + f] - mean[c * n_features + f]
                lp -= 0.5 * (log(2.0 * 3.141592653589793 * v) +
                             diff * diff / v)
            raw_scores.append(lp)
            if lp > best_lp:
                best_lp = lp
                best    = c
        preds.append(best)

        # Softmax for probabilities
        var s = 0.0
        var exps = List[Float64]()
        for c in range(n_classes):
            var e = exp(raw_scores[c] - best_lp)
            exps.append(e)
            s += e
        for c in range(n_classes):
            proba.append(exps[c] / s)


# ══════════════════════════════════════════════
# ENSEMBLE: Hard Voting
# ══════════════════════════════════════════════

fn hard_voting(
    preds_knn: List[Int],
    preds_dt:  List[Int],
    preds_gnb: List[Int],
    n_samples: Int, n_classes: Int,
    mut preds_out: List[Int]
):
    for i in range(n_samples):
        var votes = List[Int]()
        for _ in range(n_classes):
            votes.append(0)
        votes[preds_knn[i]] += 1
        votes[preds_dt[i]]  += 1
        votes[preds_gnb[i]] += 1
        var best = 0
        for c in range(1, n_classes):
            if votes[c] > votes[best]:
                best = c
        preds_out.append(best)


# ══════════════════════════════════════════════
# ENSEMBLE: Soft Voting
# ══════════════════════════════════════════════

fn soft_voting(
    proba_knn: List[Float64],
    proba_dt:  List[Float64],
    proba_gnb: List[Float64],
    n_samples: Int, n_classes: Int,
    mut preds_out: List[Int]
):
    for i in range(n_samples):
        var best   = 0
        var best_p = -1.0
        for c in range(n_classes):
            var avg = (proba_knn[i * n_classes + c] +
                       proba_dt [i * n_classes + c] +
                       proba_gnb[i * n_classes + c]) / 3.0
            if avg > best_p:
                best_p = avg
                best   = c
        preds_out.append(best)


# ══════════════════════════════════════════════
# META-LEARNER: Logistic Regression (softmax)
# Trains on meta-features: concatenated base probabilities
# meta_X shape: n_samples x (n_classes * n_base)
# ══════════════════════════════════════════════

fn softmax_row(scores: List[Float64], offset: Int, n_classes: Int,
               mut out: List[Float64], out_offset: Int):
    var max_v = scores[offset]
    for c in range(1, n_classes):
        if scores[offset + c] > max_v:
            max_v = scores[offset + c]
    var s = 0.0
    for c in range(n_classes):
        var e = exp(scores[offset + c] - max_v)
        out[out_offset + c] = e
        s += e
    for c in range(n_classes):
        out[out_offset + c] /= s


fn logreg_train(
    meta_X: List[Float64],   # n_samples x n_meta_features
    y: List[Int],
    n_samples: Int, n_meta: Int, n_classes: Int,
    n_iter: Int, lr: Float64,
    mut W: List[Float64],    # n_meta x n_classes  (output)
    mut b: List[Float64]     # n_classes            (output)
):
    # Initialise weights to zero
    for _ in range(n_meta * n_classes):
        W.append(0.0)
    for _ in range(n_classes):
        b.append(0.0)

    var probs = List[Float64]()
    for _ in range(n_samples * n_classes):
        probs.append(0.0)

    for _ in range(n_iter):
        # Forward pass: scores = meta_X @ W + b
        var scores = List[Float64]()
        for _ in range(n_samples * n_classes):
            scores.append(0.0)

        for i in range(n_samples):
            for c in range(n_classes):
                var s = b[c]
                for f in range(n_meta):
                    s += meta_X[i * n_meta + f] * W[f * n_classes + c]
                scores[i * n_classes + c] = s

        # Softmax
        for i in range(n_samples):
            softmax_row(scores, i * n_classes, n_classes, probs, i * n_classes)

        # Gradients and update
        for f in range(n_meta):
            for c in range(n_classes):
                var grad = 0.0
                for i in range(n_samples):
                    var t = 0.0
                    if y[i] == c:
                        t = 1.0
                    grad += (probs[i * n_classes + c] - t) * meta_X[i * n_meta + f]
                W[f * n_classes + c] -= lr * grad / Float64(n_samples)

        for c in range(n_classes):
            var grad = 0.0
            for i in range(n_samples):
                var t = 0.0
                if y[i] == c:
                    t = 1.0
                grad += probs[i * n_classes + c] - t
            b[c] -= lr * grad / Float64(n_samples)


fn logreg_predict(
    meta_X: List[Float64],
    W: List[Float64], b: List[Float64],
    n_samples: Int, n_meta: Int, n_classes: Int,
    mut preds_out: List[Int]
):
    for i in range(n_samples):
        var best   = 0
        var best_s = -1e18
        for c in range(n_classes):
            var s = b[c]
            for f in range(n_meta):
                s += meta_X[i * n_meta + f] * W[f * n_classes + c]
            if s > best_s:
                best_s = s
                best   = c
        preds_out.append(best)


# ══════════════════════════════════════════════
# ENSEMBLE: Stacking
# ══════════════════════════════════════════════

fn stacking(
    proba_knn: List[Float64],
    proba_dt:  List[Float64],
    proba_gnb: List[Float64],
    y: List[Int],
    n_samples: Int, n_classes: Int,
    mut preds_out: List[Int]
):
    # Meta-features: concatenate base probabilities
    # meta shape: n_samples x (3 * n_classes)
    var n_meta = 3 * n_classes
    var meta_X = List[Float64]()
    for i in range(n_samples):
        for c in range(n_classes):
            meta_X.append(proba_knn[i * n_classes + c])
        for c in range(n_classes):
            meta_X.append(proba_dt[i * n_classes + c])
        for c in range(n_classes):
            meta_X.append(proba_gnb[i * n_classes + c])

    var W = List[Float64]()
    var b = List[Float64]()
    logreg_train(meta_X, y, n_samples, n_meta, n_classes,
                 300, 0.1, W, b)
    logreg_predict(meta_X, W, b, n_samples, n_meta, n_classes, preds_out)


# ══════════════════════════════════════════════
# Accuracy and confusion matrix
# ══════════════════════════════════════════════

fn accuracy(y_true: List[Int], y_pred: List[Int]) -> Float64:
    var correct = 0
    for i in range(len(y_true)):
        if y_true[i] == y_pred[i]:
            correct += 1
    return Float64(correct) / Float64(len(y_true)) * 100.0


fn print_confusion_matrix(y_true: List[Int], y_pred: List[Int],
                           n_classes: Int, label: String):
    var cm = List[Int]()
    for _ in range(n_classes * n_classes):
        cm.append(0)
    for i in range(len(y_true)):
        cm[y_true[i] * n_classes + y_pred[i]] += 1

    print("  " + label + " -- Confusion Matrix:")
    print("                Setosa  Versicol Virginica")
    var labels = List[String]()
    labels.append("  Setosa   ")
    labels.append("  Versicol ")
    labels.append("  Virginica")
    for r in range(n_classes):
        var row_str = labels[r] + "   |"
        for c in range(n_classes):
            var cell = String(cm[r * n_classes + c])
            for _ in range(9 - len(cell)):
                row_str += " "
            row_str += cell
        print(row_str)


# ══════════════════════════════════════════════
# Agreement analysis: how often do classifiers agree?
# ══════════════════════════════════════════════

fn print_agreement(
    preds_knn: List[Int], preds_dt: List[Int], preds_gnb: List[Int],
    n_samples: Int
):
    var all_agree  = 0
    var knn_dt     = 0
    var knn_gnb    = 0
    var dt_gnb     = 0
    var all_differ = 0

    for i in range(n_samples):
        var a = preds_knn[i]; var b = preds_dt[i]; var c = preds_gnb[i]
        if a == b and b == c:
            all_agree += 1
        elif a != b and b != c and a != c:
            all_differ += 1
        else:
            if a == b: knn_dt  += 1
            if a == c: knn_gnb += 1
            if b == c: dt_gnb  += 1

    print("Classifier Agreement:")
    print("  All 3 agree     : " + String(all_agree)  +
          "/" + String(n_samples))
    print("  KNN + DT agree  : " + String(knn_dt)     +
          "/" + String(n_samples))
    print("  KNN + GNB agree : " + String(knn_gnb)    +
          "/" + String(n_samples))
    print("  DT  + GNB agree : " + String(dt_gnb)     +
          "/" + String(n_samples))
    print("  All 3 differ    : " + String(all_differ)  +
          "/" + String(n_samples))


# ══════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════

fn main():
    print("=" * 60)
    print("  Ensemble Methods -- Mojo 0.26.2")
    print("  Base: KNN(k=5) + DecisionTree(d=4) + GaussianNB")
    print("  Ensemble: Hard Voting / Soft Voting / Stacking")
    print("  Dataset: Iris (30 samples, 4 features, 3 classes)")
    print("=" * 60)

    var X = List[Float64]()
    var y = List[Int]()
    get_iris_data(X, y)
    print("\n[Data] " + String(N_SAMPLES) + " samples loaded.")

    # ── Base classifier predictions ──
    print("\n[Step 1] Running base classifiers...")

    var preds_knn = List[Int]()
    var proba_knn = List[Float64]()
    knn_predict_all(X, y, X, N_SAMPLES, N_SAMPLES, N_FEATURES,
                    5, N_CLASSES, preds_knn, proba_knn)

    var preds_dt  = List[Int]()
    var proba_dt  = List[Float64]()
    dt_predict_all(X, y, X, N_SAMPLES, N_SAMPLES, N_FEATURES,
                   N_CLASSES, 4, preds_dt, proba_dt)

    var preds_gnb = List[Int]()
    var proba_gnb = List[Float64]()
    gnb_predict_all(X, y, X, N_SAMPLES, N_SAMPLES, N_FEATURES,
                    N_CLASSES, preds_gnb, proba_gnb)

    # ── Base classifier results ──
    print("\n" + "-" * 50)
    print("  Base Classifier Results")
    print("-" * 50)
    var acc_knn = accuracy(y, preds_knn)
    var acc_dt  = accuracy(y, preds_dt)
    var acc_gnb = accuracy(y, preds_gnb)
    print("  KNN (k=5)           : " + String(Int(acc_knn)) + "%")
    print("  Decision Tree (d=4) : " + String(Int(acc_dt))  + "%")
    print("  Gaussian Naive Bayes: " + String(Int(acc_gnb)) + "%")

    # ── Agreement analysis ──
    print()
    print_agreement(preds_knn, preds_dt, preds_gnb, N_SAMPLES)

    # ── Ensemble predictions ──
    print("\n[Step 2] Running ensemble methods...")

    var preds_hard = List[Int]()
    hard_voting(preds_knn, preds_dt, preds_gnb,
                N_SAMPLES, N_CLASSES, preds_hard)

    var preds_soft = List[Int]()
    soft_voting(proba_knn, proba_dt, proba_gnb,
                N_SAMPLES, N_CLASSES, preds_soft)

    var preds_stack = List[Int]()
    stacking(proba_knn, proba_dt, proba_gnb,
             y, N_SAMPLES, N_CLASSES, preds_stack)

    # ── Ensemble results ──
    print("\n" + "-" * 50)
    print("  Ensemble Results")
    print("-" * 50)
    var acc_hard  = accuracy(y, preds_hard)
    var acc_soft  = accuracy(y, preds_soft)
    var acc_stack = accuracy(y, preds_stack)
    print("  Hard Voting : " + String(Int(acc_hard))  + "%")
    print("  Soft Voting : " + String(Int(acc_soft))  + "%")
    print("  Stacking    : " + String(Int(acc_stack)) + "%")

    # ── Confusion matrices ──
    print("\n" + "-" * 50)
    print("  Confusion Matrices")
    print("-" * 50)
    print_confusion_matrix(y, preds_hard,  N_CLASSES, "Hard Voting")
    print()
    print_confusion_matrix(y, preds_soft,  N_CLASSES, "Soft Voting")
    print()
    print_confusion_matrix(y, preds_stack, N_CLASSES, "Stacking   ")

    # ── Summary comparison ──
    print("\n" + "=" * 50)
    print("  Summary")
    print("=" * 50)
    print("  Classifier          Accuracy")
    print("  " + "-" * 35)
    print("  KNN (k=5)         : " + String(Int(acc_knn))   + "%")
    print("  Decision Tree d=4 : " + String(Int(acc_dt))    + "%")
    print("  Gaussian NB       : " + String(Int(acc_gnb))   + "%")
    print("  Hard Voting       : " + String(Int(acc_hard))  + "%")
    print("  Soft Voting       : " + String(Int(acc_soft))  + "%")
    print("  Stacking          : " + String(Int(acc_stack)) + "%")

    print("\n" + "=" * 60)
    print("  Ensemble complete.")
    print("  Next: 17_adaboost.mojo or 17_isolation_forest.mojo")
    print("=" * 60)
