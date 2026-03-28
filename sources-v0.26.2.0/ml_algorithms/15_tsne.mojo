"""
Author: Ahmet Aksoy
Date: 2026-03-26
Mojo version: 0.26.2 | Python 3.12 | Ubuntu

15_tsne.mojo -- t-SNE Dimensionality Reduction (pure Mojo)

Algorithm:
  t-SNE (t-distributed Stochastic Neighbor Embedding) maps high-
  dimensional data to 2D while preserving local neighborhood structure.

  Steps:
    1. Compute pairwise squared Euclidean distances in input space
    2. For each point, find sigma_i via binary search targeting
       the given perplexity: Perp = 2^H  where H = -sum p_j|i * log2 p_j|i
    3. Compute conditional probabilities p_j|i (Gaussian kernel)
    4. Symmetrize: P_ij = (p_j|i + p_i|j) / (2 * n)
    5. Initialise low-dim embedding Y randomly (small Gaussian noise)
    6. Gradient descent loop:
         a. Compute low-dim affinities q_ij (Student t, df=1)
         b. Gradient: dC/dY_i = 4 * sum_j (P_ij - q_ij)(Y_i - Y_j)(1+||y_i-y_j||^2)^-1
         c. Update with momentum and learning rate
         d. Apply early exaggeration in first 'exag_iter' iterations
         e. Zero-center embedding each step
    7. ASCII scatter plot of the 2D embedding

Hyperparameters demonstrated:
  perplexity, n_iter, learning_rate, early_exaggeration

Dataset: Iris (30 samples, 3 classes, 4 features)
"""

from std.math import sqrt, exp, log


# ──────────────────────────────────────────────
# Constants  (gotcha #41 -- alias -> comptime)
# ──────────────────────────────────────────────
comptime N_SAMPLES  = 30
comptime N_FEATURES = 4
comptime N_CLASSES  = 3
comptime N_DIMS     = 2      # target embedding dimensions


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
# Compute pairwise squared Euclidean distances
# D[i,j] = ||X_i - X_j||^2
# Returns flat list of size n x n
# gotcha #42 -- return List with ^
# ──────────────────────────────────────────────
fn pairwise_sq_dist(X: List[Float64], n: Int, d: Int) -> List[Float64]:
    var D = List[Float64]()
    for _ in range(n * n):
        D.append(0.0)
    for i in range(n):
        for j in range(i + 1, n):
            var s = 0.0
            for k in range(d):
                var diff = X[i * d + k] - X[j * d + k]
                s += diff * diff
            D[i * n + j] = s
            D[j * n + i] = s
    return D^


# ──────────────────────────────────────────────
# Binary search for sigma_i such that the perplexity of p_j|i equals
# the target perplexity.
# Returns the conditional probabilities for row i (length n, p_i|i = 0).
# gotcha #42 -- return List with ^
# ──────────────────────────────────────────────
fn compute_row_prob(D_row: List[Float64], i: Int, n: Int,
                    target_perp: Float64) -> List[Float64]:
    var target_H = log(target_perp)   # natural log of perplexity

    var sigma_lo = 1e-5
    var sigma_hi = 1e5

    var p = List[Float64]()
    for _ in range(n):
        p.append(0.0)

    for _ in range(50):   # binary search iterations
        var sigma = (sigma_lo + sigma_hi) / 2.0
        var two_sig2 = 2.0 * sigma * sigma

        # Conditional probabilities p_j|i
        var sum_p = 0.0
        for j in range(n):
            if j == i:
                p[j] = 0.0
            else:
                p[j] = exp(-D_row[j] / two_sig2)
                sum_p += p[j]

        if sum_p < 1e-12:
            sum_p = 1e-12

        # Normalize and compute Shannon entropy
        var H = 0.0
        for j in range(n):
            p[j] /= sum_p
            if p[j] > 1e-12:
                H -= p[j] * log(p[j])

        # Adjust sigma
        if H < target_H:
            sigma_lo = sigma
        else:
            sigma_hi = sigma

    return p^


# ──────────────────────────────────────────────
# Compute symmetric joint probabilities P_ij
# P = (p_j|i + p_i|j) / (2 * n)
# gotcha #42 -- return List with ^
# ──────────────────────────────────────────────
fn compute_P(X: List[Float64], n: Int, d: Int,
             perplexity: Float64) -> List[Float64]:
    var D = pairwise_sq_dist(X, n, d)

    # Conditional probabilities (flat n x n)
    var P_cond = List[Float64]()
    for _ in range(n * n):
        P_cond.append(0.0)

    for i in range(n):
        # Extract distance row i
        var D_row = List[Float64]()
        for j in range(n):
            D_row.append(D[i * n + j])
        var p_row = compute_row_prob(D_row, i, n, perplexity)
        for j in range(n):
            P_cond[i * n + j] = p_row[j]

    # Symmetrize
    var P = List[Float64]()
    var inv2n = 1.0 / Float64(2 * n)
    for i in range(n):
        for j in range(n):
            var pij = (P_cond[i * n + j] + P_cond[j * n + i]) * inv2n
            if pij < 1e-12:
                pij = 1e-12
            P.append(pij)

    return P^


# ──────────────────────────────────────────────
# Deterministic pseudo-random init for embedding Y
# Uses a simple LCG to avoid Python dependency.
# Returns flat list of size n x 2 in range (-0.01, 0.01).
# gotcha #42 -- return List with ^
# ──────────────────────────────────────────────
fn init_embedding(n: Int, dims: Int) -> List[Float64]:
    var Y = List[Float64]()
    var state: Int = 42
    for _ in range(n * dims):
        # LCG parameters (Numerical Recipes)
        state = (state * 1664525 + 1013904223) & 0x7FFFFFFF
        var v = (Float64(state) / Float64(0x7FFFFFFF) - 0.5) * 0.02
        Y.append(v)
    return Y^


# ──────────────────────────────────────────────
# Zero-center the embedding (in-place)
# ──────────────────────────────────────────────
fn center_embedding(mut Y: List[Float64], n: Int, dims: Int):
    for d in range(dims):
        var mean = 0.0
        for i in range(n):
            mean += Y[i * dims + d]
        mean /= Float64(n)
        for i in range(n):
            Y[i * dims + d] -= mean


# ──────────────────────────────────────────────
# t-SNE gradient descent
# ──────────────────────────────────────────────
fn tsne(
    X: List[Float64],
    n: Int, d: Int, dims: Int,
    perplexity: Float64,
    n_iter: Int,
    lr: Float64,
    early_exag: Float64,
    exag_iter: Int,
    momentum_early: Float64,
    momentum_late: Float64,
    mut Y: List[Float64]
):
    # High-dimensional joint probabilities
    var P = compute_P(X, n, d, perplexity)

    # Momentum buffer and previous Y
    var dY    = List[Float64]()
    var Y_old = List[Float64]()
    for _ in range(n * dims):
        dY.append(0.0)
        Y_old.append(0.0)
    for i in range(n * dims):
        Y_old[i] = Y[i]

    for iteration in range(n_iter):
        # Effective P with early exaggeration
        var exag = 1.0
        if iteration < exag_iter:
            exag = early_exag

        var momentum = momentum_early
        if iteration >= exag_iter:
            momentum = momentum_late

        # Low-dim pairwise squared distances
        var D_low = List[Float64]()
        for _ in range(n * n):
            D_low.append(0.0)
        for i in range(n):
            for j in range(i + 1, n):
                var s = 0.0
                for k in range(dims):
                    var diff = Y[i * dims + k] - Y[j * dims + k]
                    s += diff * diff
                D_low[i * n + j] = s
                D_low[j * n + i] = s

        # q_ij = (1 + ||y_i - y_j||^2)^-1  (Student t, df=1)
        # normalised over all pairs
        var Q_num = List[Float64]()
        for _ in range(n * n):
            Q_num.append(0.0)
        var Q_sum = 0.0
        for i in range(n):
            for j in range(n):
                if i != j:
                    var q = 1.0 / (1.0 + D_low[i * n + j])
                    Q_num[i * n + j] = q
                    Q_sum += q
        if Q_sum < 1e-12:
            Q_sum = 1e-12

        # Gradient: dC/dY_i = 4 * sum_j (P_ij - Q_ij) * (Y_i - Y_j) * Q_num_ij
        for i in range(n):
            for k in range(dims):
                var grad = 0.0
                for j in range(n):
                    if i == j:
                        continue
                    var pij = P[i * n + j] * exag
                    var qij = Q_num[i * n + j] / Q_sum
                    var factor = 4.0 * (pij - qij) * Q_num[i * n + j]
                    grad += factor * (Y[i * dims + k] - Y[j * dims + k])
                dY[i * dims + k] = momentum * dY[i * dims + k] - lr * grad

        # Update Y
        for i in range(n * dims):
            Y[i] += dY[i]

        # Zero-center
        center_embedding(Y, n, dims)

    _ = Y_old   # suppress unused warning


# ──────────────────────────────────────────────
# ASCII scatter plot
# ──────────────────────────────────────────────
fn ascii_plot(Y: List[Float64], y: List[Int], n: Int, dims: Int,
              title: String):
    comptime WIDTH  = 60
    comptime HEIGHT = 22

    var min_x = Y[0]; var max_x = Y[0]
    var min_y = Y[1]; var max_y = Y[1]
    for i in range(n):
        var px = Y[i * dims + 0]
        var py = Y[i * dims + 1]
        if px < min_x: min_x = px
        if px > max_x: max_x = px
        if py < min_y: min_y = py
        if py > max_y: max_y = py

    var rx = max_x - min_x + 1e-10
    var ry = max_y - min_y + 1e-10

    var grid = List[String]()
    for _ in range(HEIGHT * WIDTH):
        grid.append(".")

    var symbols = List[String]()
    symbols.append("S")   # Setosa
    symbols.append("V")   # Versicolor
    symbols.append("G")   # Virginica

    for i in range(n):
        var px  = Y[i * dims + 0]
        var py  = Y[i * dims + 1]
        var col = Int((px - min_x) / rx * Float64(WIDTH  - 1))
        var row = Int((1.0 - (py - min_y) / ry) * Float64(HEIGHT - 1))
        if col < 0: col = 0
        if col >= WIDTH:  col = WIDTH  - 1
        if row < 0: row = 0
        if row >= HEIGHT: row = HEIGHT - 1
        grid[row * WIDTH + col] = symbols[y[i]]

    print("\n" + title)
    print("S=Setosa  V=Versicolor  G=Virginica")
    print("+" + "-" * WIDTH + "+")
    for r in range(HEIGHT):
        var line = "|"
        for c in range(WIDTH):
            line += grid[r * WIDTH + c]
        line += "|"
        print(line)
    print("+" + "-" * WIDTH + "+")


# ──────────────────────────────────────────────
# Cluster separation metric:
# ratio of mean between-class distance to mean within-class distance
# ──────────────────────────────────────────────
fn separation_score(Y: List[Float64], y: List[Int],
                    n: Int, dims: Int, n_classes: Int) -> Float64:
    # Per-class centroids
    var cx = List[Float64]()
    var cy = List[Float64]()
    var cnt = List[Float64]()
    for _ in range(n_classes):
        cx.append(0.0); cy.append(0.0); cnt.append(0.0)

    for i in range(n):
        var c = y[i]
        cx[c]  += Y[i * dims + 0]
        cy[c]  += Y[i * dims + 1]
        cnt[c] += 1.0
    for c in range(n_classes):
        cx[c] /= cnt[c]
        cy[c] /= cnt[c]

    # Mean within-class distance to centroid
    var within = 0.0
    for i in range(n):
        var c = y[i]
        var dx = Y[i * dims + 0] - cx[c]
        var dy = Y[i * dims + 1] - cy[c]
        within += sqrt(dx * dx + dy * dy)
    within /= Float64(n)

    # Mean between-class centroid distance
    var between = 0.0
    var pairs = 0
    for a in range(n_classes):
        for b in range(a + 1, n_classes):
            var dx = cx[a] - cx[b]
            var dy = cy[a] - cy[b]
            between += sqrt(dx * dx + dy * dy)
            pairs += 1
    if pairs > 0:
        between /= Float64(pairs)

    if within < 1e-10:
        return 0.0
    return between / within


# ──────────────────────────────────────────────
# Run one t-SNE experiment; return separation score
# ──────────────────────────────────────────────
fn run_tsne(
    X: List[Float64], y: List[Int],
    n: Int, d: Int, dims: Int,
    perplexity: Float64,
    n_iter: Int,
    lr: Float64,
    early_exag: Float64,
    exag_iter: Int,
    show_plot: Bool,
    plot_title: String
) -> Float64:
    var Y = init_embedding(n, dims)

    tsne(X, n, d, dims,
         perplexity, n_iter, lr, early_exag, exag_iter,
         0.5,   # momentum_early
         0.8,   # momentum_late
         Y)

    var score = separation_score(Y, y, n, dims, N_CLASSES)

    if show_plot:
        ascii_plot(Y, y, n, dims, plot_title)
        print("  Separation score (between/within): " +
              String(Int(score * 100)) + "e-2")

    return score


# ──────────────────────────────────────────────
# Parameter sensitivity
# ──────────────────────────────────────────────
fn param_study(X: List[Float64], y: List[Int], n: Int, d: Int, dims: Int):
    print("\n" + "=" * 55)
    print("Parameter Sensitivity (separation score)")
    print("=" * 55)

    # perplexity
    print("\nperplexity  (n_iter=300, lr=100, exag=4.0):")
    var perp_vals = List[Float64]()
    perp_vals.append(2.0); perp_vals.append(5.0)
    perp_vals.append(10.0); perp_vals.append(15.0)
    for pi in range(len(perp_vals)):
        var perp = perp_vals[pi]
        var score = run_tsne(X, y, n, d, dims,
                             perp, 300, 100.0, 4.0, 100,
                             False, "")
        print("  perplexity=" + String(Int(perp)) +
              "  ->  separation=" + String(Int(score * 100)) + "e-2")

    # n_iter
    print("\nn_iter  (perplexity=10, lr=100, exag=4.0):")
    var iter_vals = List[Int]()
    iter_vals.append(50); iter_vals.append(100)
    iter_vals.append(200); iter_vals.append(500)
    for ii in range(len(iter_vals)):
        var ni = iter_vals[ii]
        var score = run_tsne(X, y, n, d, dims,
                             10.0, ni, 100.0, 4.0, 100,
                             False, "")
        print("  n_iter=" + String(ni) +
              "  ->  separation=" + String(Int(score * 100)) + "e-2")

    # learning_rate
    print("\nlearning_rate  (perplexity=10, n_iter=300, exag=4.0):")
    var lr_vals = List[Float64]()
    lr_vals.append(10.0); lr_vals.append(50.0)
    lr_vals.append(100.0); lr_vals.append(200.0)
    for li in range(len(lr_vals)):
        var lr = lr_vals[li]
        var score = run_tsne(X, y, n, d, dims,
                             10.0, 300, lr, 4.0, 100,
                             False, "")
        print("  lr=" + String(Int(lr)) +
              "  ->  separation=" + String(Int(score * 100)) + "e-2")

    # early_exaggeration
    print("\nearly_exaggeration  (perplexity=10, n_iter=300, lr=100):")
    var exag_vals = List[Float64]()
    exag_vals.append(1.0); exag_vals.append(2.0)
    exag_vals.append(4.0); exag_vals.append(8.0)
    for ei in range(len(exag_vals)):
        var exag = exag_vals[ei]
        var score = run_tsne(X, y, n, d, dims,
                             10.0, 300, 100.0, exag, 100,
                             False, "")
        print("  exag=" + String(Int(exag)) +
              "  ->  separation=" + String(Int(score * 100)) + "e-2")


# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────
fn main():
    print("=" * 60)
    print("  t-SNE -- Mojo 0.26.2")
    print("  Dataset: Iris (30 samples, 4 features, 3 classes)")
    print("=" * 60)

    var X = List[Float64]()
    var y = List[Int]()
    get_iris_data(X, y)
    print("\n[Data] " + String(N_SAMPLES) + " samples loaded.")

    # Default hyperparameters
    var perplexity  : Float64 = 10.0
    var n_iter      : Int     = 500
    var lr          : Float64 = 100.0
    var early_exag  : Float64 = 4.0
    var exag_iter   : Int     = 100

    print("\n[Config]")
    print("  perplexity        : " + String(Int(perplexity)))
    print("  n_iter            : " + String(n_iter))
    print("  learning_rate     : " + String(Int(lr)))
    print("  early_exaggeration: " + String(Int(early_exag)))
    print("  exag_iter         : " + String(exag_iter))
    print("  momentum early    : 0.5   (first " +
          String(exag_iter) + " iters)")
    print("  momentum late     : 0.8")

    print("\n[Running t-SNE...]")
    _ = run_tsne(
        X, y, N_SAMPLES, N_FEATURES, N_DIMS,
        perplexity, n_iter, lr, early_exag, exag_iter,
        True,
        "t-SNE 2D Embedding (perplexity=10, iter=500)"
    )

    param_study(X, y, N_SAMPLES, N_FEATURES, N_DIMS)

    print("\n" + "=" * 60)
    print("  t-SNE complete.")
    print("  Next: 16_ensemble.mojo or 16_adaboost.mojo")
    print("=" * 60)
