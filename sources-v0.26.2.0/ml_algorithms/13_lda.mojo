"""Author: Ahmet Aksoy
Date: 2026-03-26
Mojo version: 0.26.2 | Python 3.12 | Ubuntu
AI: Claude Sonnet 4.6

13_lda.mojo — Linear Discriminant Analysis (pure Mojo)


Algorithm:
  1. Compute class means and overall mean
  2. Build within-class scatter matrix (Sw)
  3. Build between-class scatter matrix (Sb)
  4. Compute Sw^-1 via Gauss-Jordan elimination
  5. Form M = Sw^-1 * Sb
  6. Extract dominant eigenvectors via power iteration + deflation
  7. Project data to LDA space (4D -> 2D)
  8. Classify with nearest centroid
  9. Report accuracy, confusion matrix, separation ratio, ASCII scatter plot

Dataset: Iris (30 samples, 3 classes, 4 features)
"""

from std.math import sqrt


# ──────────────────────────────────────────────
# Constants (gotcha #41 — alias -> comptime)
# ──────────────────────────────────────────────
comptime N_SAMPLES    = 30
comptime N_FEATURES   = 4
comptime N_CLASSES    = 3
comptime N_COMPONENTS = 2    # project 4D -> 2D


# ──────────────────────────────────────────────
# Iris dataset (30 samples x 4 features)
# sepal_len, sepal_wid, petal_len, petal_wid
# Classes: 0=Setosa, 1=Versicolor, 2=Virginica
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

    for i in range(len(raw)):
        X.append(raw[i])
    for _ in range(10):
        y.append(0)
    for _ in range(10):
        y.append(1)
    for _ in range(10):
        y.append(2)


# ──────────────────────────────────────────────
# Matrix helpers
# Matrices are stored as flat List[Float64]: M[r, c] = data[r * n_cols + c]
# ──────────────────────────────────────────────
fn mat_get(mat: List[Float64], r: Int, c: Int, n_cols: Int) -> Float64:
    return mat[r * n_cols + c]

fn mat_set(mut mat: List[Float64], r: Int, c: Int, n_cols: Int, val: Float64):
    mat[r * n_cols + c] = val

fn mat_add(mut mat: List[Float64], r: Int, c: Int, n_cols: Int, val: Float64):
    mat[r * n_cols + c] += val


# ──────────────────────────────────────────────
# Allocate a zero-filled matrix (rows x cols)
# gotcha #42 — return List with ^ (transfer operator)
# ──────────────────────────────────────────────
fn zeros(rows: Int, cols: Int) -> List[Float64]:
    var m = List[Float64]()
    for _ in range(rows * cols):
        m.append(0.0)
    return m^


# ──────────────────────────────────────────────
# Matrix multiplication: A (ra x ca) x B (rb x cb) = C (ra x cb)
# ──────────────────────────────────────────────
fn mat_mul(
    A: List[Float64], ra: Int, ca: Int,
    B: List[Float64], rb: Int, cb: Int,
    mut C: List[Float64]
):
    for i in range(ra):
        for j in range(cb):
            var s = 0.0
            for k in range(ca):
                s += mat_get(A, i, k, ca) * mat_get(B, k, j, cb)
            mat_set(C, i, j, cb, s)


# ──────────────────────────────────────────────
# Gauss-Jordan matrix inverse for n x n matrix
# Augmented form [A | I] -> [I | A^-1]
# gotcha #42 — return List with ^
# ──────────────────────────────────────────────
fn mat_inv(A: List[Float64], n: Int) -> List[Float64]:
    # Build augmented matrix: n x 2n
    var aug = zeros(n, 2 * n)
    for i in range(n):
        for j in range(n):
            mat_set(aug, i, j, 2 * n, mat_get(A, i, j, n))
        mat_set(aug, i, n + i, 2 * n, 1.0)

    for col in range(n):
        # Find pivot row
        var max_val = 0.0
        var max_row = col
        for row in range(col, n):
            var v = mat_get(aug, row, col, 2 * n)
            if v < 0.0:
                v = -v
            if v > max_val:
                max_val = v
                max_row = row

        # Swap rows
        if max_row != col:
            for j in range(2 * n):
                var tmp = mat_get(aug, col, j, 2 * n)
                mat_set(aug, col, j, 2 * n, mat_get(aug, max_row, j, 2 * n))
                mat_set(aug, max_row, j, 2 * n, tmp)

        # Normalize pivot row
        var pivot = mat_get(aug, col, col, 2 * n)
        if pivot < 0.0001 and pivot > -0.0001:
            pivot = 0.0001   # guard against division by zero
        for j in range(2 * n):
            mat_set(aug, col, j, 2 * n, mat_get(aug, col, j, 2 * n) / pivot)

        # Eliminate column in all other rows
        for row in range(n):
            if row != col:
                var factor = mat_get(aug, row, col, 2 * n)
                for j in range(2 * n):
                    var new_val = mat_get(aug, row, j, 2 * n) - factor * mat_get(aug, col, j, 2 * n)
                    mat_set(aug, row, j, 2 * n, new_val)

    # Extract right half as the inverse
    var inv = zeros(n, n)
    for i in range(n):
        for j in range(n):
            mat_set(inv, i, j, n, mat_get(aug, i, n + j, 2 * n))
    return inv^


# ──────────────────────────────────────────────
# Normalize a vector in-place
# ──────────────────────────────────────────────
fn normalize(mut v: List[Float64]):
    var norm = 0.0
    for i in range(len(v)):
        norm += v[i] * v[i]
    norm = sqrt(norm)
    if norm < 1e-10:
        norm = 1e-10
    for i in range(len(v)):
        v[i] /= norm


# ──────────────────────────────────────────────
# Matrix-vector product: M (rows x cols) * v (cols) -> out (rows)
# gotcha #42 — return List with ^
# ──────────────────────────────────────────────
fn mat_vec(M: List[Float64], rows: Int, cols: Int, v: List[Float64]) -> List[Float64]:
    var out = List[Float64]()
    for i in range(rows):
        var s = 0.0
        for j in range(cols):
            s += mat_get(M, i, j, cols) * v[j]
        out.append(s)
    return out^


# ──────────────────────────────────────────────
# Power iteration with deflation.
# Returns the dominant eigenvector of M orthogonal to all vectors in prev_vecs.
# gotcha #42 — return List with ^
# ──────────────────────────────────────────────
fn power_iteration(
    M: List[Float64], n: Int,
    prev_vecs: List[Float64], n_prev: Int,
    n_iter: Int = 200
) -> List[Float64]:
    # Non-uniform initial vector
    var v = List[Float64]()
    for i in range(n):
        v.append(Float64(i + 1) / Float64(n + 1))
    normalize(v)

    for _ in range(n_iter):
        var w = mat_vec(M, n, n, v)

        # Deflation: subtract projections onto previously found eigenvectors
        for p in range(n_prev):
            var dot = 0.0
            for i in range(n):
                dot += mat_get(prev_vecs, p, i, n) * w[i]
            for i in range(n):
                w[i] -= dot * mat_get(prev_vecs, p, i, n)

        normalize(w)
        v = w^

    return v^


# ──────────────────────────────────────────────
# Compute LDA projection vectors (discriminant axes).
# Writes n_components row vectors into W (n_components x n_features).
# ──────────────────────────────────────────────
fn compute_lda_components(
    X: List[Float64],
    y: List[Int],
    n_samples: Int,
    n_features: Int,
    n_classes: Int,
    n_components: Int,
    mut W: List[Float64]
):
    # 1. Overall mean
    var overall_mean = List[Float64]()
    for _ in range(n_features):
        overall_mean.append(0.0)
    for i in range(n_samples):
        for f in range(n_features):
            overall_mean[f] += X[i * n_features + f]
    for f in range(n_features):
        overall_mean[f] /= Float64(n_samples)

    # 2. Per-class means and counts
    var class_mean  = zeros(n_classes, n_features)
    var class_count = List[Float64]()
    for _ in range(n_classes):
        class_count.append(0.0)

    for i in range(n_samples):
        var c = y[i]
        class_count[c] += 1.0
        for f in range(n_features):
            mat_add(class_mean, c, f, n_features, X[i * n_features + f])

    for c in range(n_classes):
        for f in range(n_features):
            var old = mat_get(class_mean, c, f, n_features)
            mat_set(class_mean, c, f, n_features, old / class_count[c])

    # 3. Within-class scatter Sw
    var Sw = zeros(n_features, n_features)
    for i in range(n_samples):
        var c = y[i]
        for r in range(n_features):
            var dr = X[i * n_features + r] - mat_get(class_mean, c, r, n_features)
            for col in range(n_features):
                var dc = X[i * n_features + col] - mat_get(class_mean, c, col, n_features)
                mat_add(Sw, r, col, n_features, dr * dc)

    # 4. Between-class scatter Sb
    var Sb = zeros(n_features, n_features)
    for c in range(n_classes):
        var nc = class_count[c]
        for r in range(n_features):
            var dr = mat_get(class_mean, c, r, n_features) - overall_mean[r]
            for col in range(n_features):
                var dc = mat_get(class_mean, c, col, n_features) - overall_mean[col]
                mat_add(Sb, r, col, n_features, nc * dr * dc)

    # 5. Sw^-1
    var Sw_inv = mat_inv(Sw, n_features)

    # 6. M = Sw^-1 * Sb
    var M = zeros(n_features, n_features)
    mat_mul(Sw_inv, n_features, n_features, Sb, n_features, n_features, M)

    # 7. Extract first n_components eigenvectors via power iteration
    var prev_vecs = zeros(n_components, n_features)

    for k in range(n_components):
        var v = power_iteration(M, n_features, prev_vecs, k)
        for f in range(n_features):
            mat_set(prev_vecs, k, f, n_features, v[f])
            mat_set(W, k, f, n_features, v[f])


# ──────────────────────────────────────────────
# Project data: X (n x p) * W^T (p x k) = Z (n x k)
# ──────────────────────────────────────────────
fn project(
    X: List[Float64], n_samples: Int, n_features: Int,
    W: List[Float64], n_components: Int,
    mut Z: List[Float64]
):
    for i in range(n_samples):
        for k in range(n_components):
            var dot = 0.0
            for f in range(n_features):
                dot += X[i * n_features + f] * mat_get(W, k, f, n_features)
            Z.append(dot)


# ──────────────────────────────────────────────
# Compute per-class centroids in the projected space
# ──────────────────────────────────────────────
fn compute_centroids(
    Z: List[Float64], y: List[Int],
    n_samples: Int, n_components: Int, n_classes: Int,
    mut centroids: List[Float64]
):
    var counts = List[Float64]()
    for _ in range(n_classes):
        counts.append(0.0)

    for i in range(n_samples):
        var c = y[i]
        counts[c] += 1.0
        for k in range(n_components):
            centroids[c * n_components + k] += Z[i * n_components + k]

    for c in range(n_classes):
        for k in range(n_components):
            centroids[c * n_components + k] /= counts[c]


# ──────────────────────────────────────────────
# Nearest centroid prediction for one sample
# ──────────────────────────────────────────────
fn predict_one(
    z: List[Float64], n_components: Int,
    centroids: List[Float64], n_classes: Int
) -> Int:
    var best_class = 0
    var best_dist  = 1e18

    for c in range(n_classes):
        var dist = 0.0
        for k in range(n_components):
            var diff = z[k] - centroids[c * n_components + k]
            dist += diff * diff
        if dist < best_dist:
            best_dist  = dist
            best_class = c

    return best_class


# ──────────────────────────────────────────────
# Classification accuracy (percentage)
# ──────────────────────────────────────────────
fn accuracy(y_true: List[Int], y_pred: List[Int]) -> Float64:
    var correct = 0
    for i in range(len(y_true)):
        if y_true[i] == y_pred[i]:
            correct += 1
    return Float64(correct) / Float64(len(y_true)) * 100.0


# ──────────────────────────────────────────────
# Print confusion matrix (rows = actual, cols = predicted)
# ──────────────────────────────────────────────
fn print_confusion_matrix(
    y_true: List[Int], y_pred: List[Int],
    n_classes: Int
):
    var cm = zeros(n_classes, n_classes)
    for i in range(len(y_true)):
        mat_add(cm, y_true[i], y_pred[i], n_classes, 1.0)

    print("Confusion Matrix (rows=actual, cols=predicted):")
    print("              Setosa  Versicol Virginica")
    var labels = List[String]()
    labels.append("Setosa   ")
    labels.append("Versicol ")
    labels.append("Virginica")

    for r in range(n_classes):
        var row_str = labels[r] + "   |"
        for c in range(n_classes):
            var val = Int(mat_get(cm, r, c, n_classes))
            var cell = String(val)
            var pad = 9 - len(cell)
            for _ in range(pad):
                row_str += " "
            row_str += cell
        print(row_str)


# ──────────────────────────────────────────────
# ASCII scatter plot of the first two LDA components
# ──────────────────────────────────────────────
fn ascii_plot(
    Z: List[Float64], y: List[Int],
    n_samples: Int, n_components: Int
):
    comptime WIDTH  = 60
    comptime HEIGHT = 20

    # Find data range
    var min_x = Z[0]; var max_x = Z[0]
    var min_y = Z[1]; var max_y = Z[1]
    for i in range(n_samples):
        var x  = Z[i * n_components + 0]
        var yy = Z[i * n_components + 1]
        if x  < min_x: min_x = x
        if x  > max_x: max_x = x
        if yy < min_y: min_y = yy
        if yy > max_y: max_y = yy

    var range_x = max_x - min_x + 1e-10
    var range_y = max_y - min_y + 1e-10

    # Build grid (flat list, HEIGHT x WIDTH)
    var grid = List[String]()
    for _ in range(HEIGHT * WIDTH):
        grid.append(".")

    var symbols = List[String]()
    symbols.append("S")   # Setosa
    symbols.append("V")   # Versicolor
    symbols.append("G")   # Virginica

    for i in range(n_samples):
        var px = Z[i * n_components + 0]
        var py = Z[i * n_components + 1]
        var col = Int((px - min_x) / range_x * Float64(WIDTH  - 1))
        var row = Int((1.0 - (py - min_y) / range_y) * Float64(HEIGHT - 1))
        if col < 0: col = 0
        if col >= WIDTH: col = WIDTH - 1
        if row < 0: row = 0
        if row >= HEIGHT: row = HEIGHT - 1
        grid[row * WIDTH + col] = symbols[y[i]]

    print("\nLDA Scatter Plot (LD1 x LD2)")
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
# Between-class separation ratio: Sb / (Sb + Sw) in projected space
# ──────────────────────────────────────────────
fn separation_ratio(
    Z: List[Float64], y: List[Int],
    n_samples: Int, n_components: Int, n_classes: Int
) -> Float64:
    # Overall mean in projected space
    var overall = List[Float64]()
    for _ in range(n_components):
        overall.append(0.0)
    for i in range(n_samples):
        for k in range(n_components):
            overall[k] += Z[i * n_components + k]
    for k in range(n_components):
        overall[k] /= Float64(n_samples)

    # Per-class means
    var cmean = zeros(n_classes, n_components)
    var count = List[Float64]()
    for _ in range(n_classes):
        count.append(0.0)
    for i in range(n_samples):
        var c = y[i]
        count[c] += 1.0
        for k in range(n_components):
            mat_add(cmean, c, k, n_components, Z[i * n_components + k])
    for c in range(n_classes):
        for k in range(n_components):
            var old = mat_get(cmean, c, k, n_components)
            mat_set(cmean, c, k, n_components, old / count[c])

    # Between-class variance
    var sb = 0.0
    for c in range(n_classes):
        for k in range(n_components):
            var d = mat_get(cmean, c, k, n_components) - overall[k]
            sb += count[c] * d * d

    # Within-class variance
    var sw = 0.0
    for i in range(n_samples):
        var c = y[i]
        for k in range(n_components):
            var d = Z[i * n_components + k] - mat_get(cmean, c, k, n_components)
            sw += d * d

    if sb + sw < 1e-10:
        return 0.0
    return sb / (sb + sw) * 100.0


# ──────────────────────────────────────────────
# Parameter sensitivity: compare n_components = 1 vs 2
# ──────────────────────────────────────────────
fn test_components(
    X: List[Float64], y: List[Int],
    n_samples: Int, n_features: Int, n_classes: Int
):
    print("\n" + "=" * 50)
    print("Parameter Effect: n_components = 1 vs 2")
    print("=" * 50)

    var comp_list = List[Int]()
    comp_list.append(1)
    comp_list.append(2)

    for ci in range(len(comp_list)):
        var nc = comp_list[ci]

        var W = zeros(nc, n_features)
        compute_lda_components(X, y, n_samples, n_features, n_classes, nc, W)

        var Z = List[Float64]()
        project(X, n_samples, n_features, W, nc, Z)

        var centroids = zeros(n_classes, nc)
        compute_centroids(Z, y, n_samples, nc, n_classes, centroids)

        var y_pred = List[Int]()
        for i in range(n_samples):
            var z_i = List[Float64]()
            for k in range(nc):
                z_i.append(Z[i * nc + k])
            y_pred.append(predict_one(z_i, nc, centroids, n_classes))

        var acc = accuracy(y, y_pred)
        var sep = separation_ratio(Z, y, n_samples, nc, n_classes)
        print("  n_components=" + String(nc) +
              "  Accuracy=" + String(Int(acc)) + "%" +
              "  Separation=" + String(Int(sep)) + "%")


# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────
fn main():
    print("=" * 60)
    print("  Linear Discriminant Analysis (LDA) -- Mojo 0.26.2")
    print("  Dataset: Iris (30 samples, 4 features, 3 classes)")
    print("=" * 60)

    # Load data
    var X = List[Float64]()
    var y = List[Int]()
    get_iris_data(X, y)
    print("\n[Data] " + String(N_SAMPLES) + " samples loaded.")

    # Compute LDA projection vectors
    print("\n[Step 1] Computing Sw and Sb...")
    print("[Step 2] Finding eigenvectors via power iteration...")
    var W = zeros(N_COMPONENTS, N_FEATURES)
    compute_lda_components(X, y, N_SAMPLES, N_FEATURES, N_CLASSES, N_COMPONENTS, W)

    print("\nLD1 component weights:")
    var feat_names = List[String]()
    feat_names.append("sepal_len")
    feat_names.append("sepal_wid")
    feat_names.append("petal_len")
    feat_names.append("petal_wid")
    for f in range(N_FEATURES):
        var w = mat_get(W, 0, f, N_FEATURES)
        var w_str: String
        if w >= 0.0:
            w_str = " " + String(Int(w * 1000)) + "e-3"
        else:
            w_str = String(Int(w * 1000)) + "e-3"
        print("  " + feat_names[f] + ": " + w_str)

    print("\nLD2 component weights:")
    for f in range(N_FEATURES):
        var w = mat_get(W, 1, f, N_FEATURES)
        var w_str: String
        if w >= 0.0:
            w_str = " " + String(Int(w * 1000)) + "e-3"
        else:
            w_str = String(Int(w * 1000)) + "e-3"
        print("  " + feat_names[f] + ": " + w_str)

    # Project to LDA space
    print("\n[Step 3] Projecting data to LDA space (4D -> 2D)...")
    var Z = List[Float64]()
    project(X, N_SAMPLES, N_FEATURES, W, N_COMPONENTS, Z)

    # Nearest centroid classification
    print("[Step 4] Nearest centroid classification...")
    var centroids = zeros(N_CLASSES, N_COMPONENTS)
    compute_centroids(Z, y, N_SAMPLES, N_COMPONENTS, N_CLASSES, centroids)

    var y_pred = List[Int]()
    for i in range(N_SAMPLES):
        var z_i = List[Float64]()
        for k in range(N_COMPONENTS):
            z_i.append(Z[i * N_COMPONENTS + k])
        y_pred.append(predict_one(z_i, N_COMPONENTS, centroids, N_CLASSES))

    # Results
    print("\n" + "-" * 50)
    print("  Results")
    print("-" * 50)
    var acc = accuracy(y, y_pred)
    print("Accuracy: " + String(Int(acc)) + "%")
    print("Classified: " + String(N_SAMPLES) + " samples")

    var class_names = List[String]()
    class_names.append("Setosa   ")
    class_names.append("Versicol ")
    class_names.append("Virginica")

    for c in range(N_CLASSES):
        var correct = 0
        var total   = 0
        for i in range(N_SAMPLES):
            if y[i] == c:
                total += 1
                if y_pred[i] == c:
                    correct += 1
        print("  " + class_names[c] + ": " +
              String(correct) + "/" + String(total) + " correct")

    print()
    print_confusion_matrix(y, y_pred, N_CLASSES)

    # Separation ratio
    var sep = separation_ratio(Z, y, N_SAMPLES, N_COMPONENTS, N_CLASSES)
    print("\nClass Separation Ratio: " + String(Int(sep)) + "%")
    print("(Between-class / Total variance -- closer to 100% = better separation)")

    # Sample projections
    print("\n-- First 5 samples in LDA space --")
    print("  i  Actual  Pred  LD1         LD2")
    print("  " + "-" * 40)
    for i in range(5):
        var ld1 = Z[i * N_COMPONENTS + 0]
        var ld2 = Z[i * N_COMPONENTS + 1]
        print("  " + String(i) + "  " +
              String(y[i]) + "       " +
              String(y_pred[i]) + "     " +
              String(Int(ld1 * 100)) + "e-2      " +
              String(Int(ld2 * 100)) + "e-2")

    # ASCII scatter plot
    ascii_plot(Z, y, N_SAMPLES, N_COMPONENTS)

    # Parameter sensitivity
    test_components(X, y, N_SAMPLES, N_FEATURES, N_CLASSES)

    print("\n" + "=" * 60)
    print("  LDA complete.")
    print("  Next: 14_xgboost.mojo or 14_tsne.mojo")
    print("=" * 60)
