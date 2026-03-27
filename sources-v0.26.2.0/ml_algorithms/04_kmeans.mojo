"""
Author: Ahmet Aksoy
Date: 2026-03-20
Mojo version: 0.26.2 | Python 3.12 | Ubuntu
AI: Claude Sonnet 4.6

K-Means Clustering — Pure Mojo Implementation
==============================================

K-Means is an unsupervised clustering algorithm that partitions
data into K groups by iteratively assigning points to the nearest
centroid and updating centroids.

Algorithm:
  1. Initialize K centroids randomly from data points
  2. Assign each point to the nearest centroid (E-step)
  3. Update each centroid to the mean of its assigned points (M-step)
  4. Repeat steps 2-3 until convergence or max iterations

Convergence: when centroids stop moving (or move less than tolerance)

Metrics:
  Inertia (WCSS): Σ distance² from each point to its centroid
                  Lower = tighter clusters

Demo dataset: 2D synthetic data with 3 natural clusters
"""

import std.math as math


# ------------------------------------------------------------------ #
# Helper functions
# ------------------------------------------------------------------ #

fn euclidean_sq(x1: List[Float64], x2: List[Float64]) -> Float64:
    """Squared Euclidean distance (faster, no sqrt needed for comparisons)."""
    var total: Float64 = 0.0
    for i in range(len(x1)):
        var diff = x1[i] - x2[i]
        total += diff * diff
    return total


fn euclidean(x1: List[Float64], x2: List[Float64]) -> Float64:
    """Euclidean distance."""
    return math.sqrt(euclidean_sq(x1, x2))


fn make_point(x: Float64, y: Float64) -> List[Float64]:
    """Create a 2D point."""
    var p = List[Float64]()
    p.append(x)
    p.append(y)
    return p^


fn copy_point(src: List[Float64]) -> List[Float64]:
    """Copy a point."""
    var dst = List[Float64]()
    for i in range(len(src)):
        dst.append(src[i])
    return dst^


fn points_equal(a: List[Float64], b: List[Float64], tol: Float64) -> Bool:
    """Check if two points are within tolerance."""
    for i in range(len(a)):
        if abs(a[i] - b[i]) > tol:
            return False
    return True


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


fn cluster_symbol(label: Int) -> String:
    """Return a symbol for each cluster."""
    if label == 0:
        return "A"
    if label == 1:
        return "B"
    return "C"


# ------------------------------------------------------------------ #
# K-Means Classifier
# ------------------------------------------------------------------ #

struct KMeans:
    """
    K-Means Clustering.
    Uses squared Euclidean distance for assignments,
    Euclidean distance for inertia reporting.
    """
    var k          : Int
    var max_iters  : Int
    var tol        : Float64
    var centroids  : List[List[Float64]]
    var labels     : List[Int]
    var inertia    : Float64
    var n_iters    : Int

    fn __init__(out self, k: Int = 3,
                max_iters: Int = 100,
                tol: Float64 = 1e-4):
        self.k         = k
        self.max_iters = max_iters
        self.tol       = tol
        self.centroids = List[List[Float64]]()
        self.labels    = List[Int]()
        self.inertia   = 0.0
        self.n_iters   = 0

    fn fit(mut self, x: List[List[Float64]]):
        """Run K-Means on dataset x."""
        var n = len(x)
        var dims = len(x[0])

        # ── K-Means++ initialization ───────────────────────────── #
        # 1. Pick first centroid: point farthest from dataset center
        # 2. Each next centroid: point with max min-distance to existing centroids
        self.centroids = List[List[Float64]]()

        # Step 1: pick the point farthest from the mean
        var mean_pt = List[Float64]()
        for _ in range(dims):
            mean_pt.append(0.0)
        for i in range(n):
            for d in range(dims):
                mean_pt[d] += x[i][d]
        for d in range(dims):
            mean_pt[d] /= Float64(n)

        var best_dist: Float64 = -1.0
        var best_idx: Int = 0
        for i in range(n):
            var dist = euclidean_sq(x[i], mean_pt)
            if dist > best_dist:
                best_dist = dist
                best_idx  = i
        self.centroids.append(copy_point(x[best_idx]))

        # Step 2: each next centroid = point with max min-dist to existing
        for _ in range(1, self.k):
            var max_min_dist: Float64 = -1.0
            var next_idx: Int = 0
            for i in range(n):
                # min distance from x[i] to any existing centroid
                var min_dist = euclidean_sq(x[i], self.centroids[0])
                for c in range(1, len(self.centroids)):
                    var d = euclidean_sq(x[i], self.centroids[c])
                    if d < min_dist:
                        min_dist = d
                if min_dist > max_min_dist:
                    max_min_dist = min_dist
                    next_idx     = i
            self.centroids.append(copy_point(x[next_idx]))

        # ── Initialize labels ──────────────────────────────────── #
        self.labels = List[Int]()
        for _ in range(n):
            self.labels.append(0)

        # ── EM loop ────────────────────────────────────────────── #
        for iteration in range(self.max_iters):
            self.n_iters = iteration + 1

            # E-step: assign each point to nearest centroid
            for i in range(n):
                var best_dist = euclidean_sq(x[i], self.centroids[0])
                var best_k    = 0
                for c in range(1, self.k):
                    var dist = euclidean_sq(x[i], self.centroids[c])
                    if dist < best_dist:
                        best_dist = dist
                        best_k    = c
                self.labels[i] = best_k

            # M-step: update centroids to mean of assigned points
            var new_centroids = List[List[Float64]]()
            for c in range(self.k):
                var sum_point = List[Float64]()
                for _ in range(dims):
                    sum_point.append(0.0)
                var count = 0
                for i in range(n):
                    if self.labels[i] == c:
                        for d in range(dims):
                            sum_point[d] += x[i][d]
                        count += 1
                # Avoid division by zero (empty cluster)
                if count > 0:
                    for d in range(dims):
                        sum_point[d] /= Float64(count)
                else:
                    # Keep old centroid if cluster is empty
                    sum_point = copy_point(self.centroids[c])
                new_centroids.append(sum_point^)

            # Check convergence
            var converged = True
            for c in range(self.k):
                if not points_equal(
                    self.centroids[c], new_centroids[c], self.tol
                ):
                    converged = False
                    break

            # Update centroids
            self.centroids = List[List[Float64]]()
            for c in range(self.k):
                self.centroids.append(copy_point(new_centroids[c]))

            if converged:
                break

        # ── Compute inertia (WCSS) ─────────────────────────────── #
        self.inertia = 0.0
        for i in range(n):
            self.inertia += euclidean_sq(x[i], self.centroids[self.labels[i]])

    fn predict_single(self, x_query: List[Float64]) -> Int:
        """Assign a new point to the nearest centroid."""
        var best_dist = euclidean_sq(x_query, self.centroids[0])
        var best_k    = 0
        for c in range(1, self.k):
            var dist = euclidean_sq(x_query, self.centroids[c])
            if dist < best_dist:
                best_dist = dist
                best_k    = c
        return best_k


# ------------------------------------------------------------------ #
# Demo
# ------------------------------------------------------------------ #

fn main():
    print("=" * 65)
    print("  K-Means Clustering")
    print("  Demo: 2D Synthetic Data with 3 Natural Clusters")
    print("=" * 65)

    # ── Dataset: 3 clusters ───────────────────────────────────── #
    # Cluster A — bottom-left  (~2, 2)
    # Cluster B — top-center   (~5, 8)
    # Cluster C — right        (~9, 4)
    var x_data = List[List[Float64]]()

    # Cluster A
    x_data.append(make_point(1.0, 1.5))
    x_data.append(make_point(1.5, 2.0))
    x_data.append(make_point(2.0, 2.5))
    x_data.append(make_point(2.5, 1.8))
    x_data.append(make_point(1.8, 1.2))
    x_data.append(make_point(3.0, 2.0))
    x_data.append(make_point(2.2, 3.0))
    x_data.append(make_point(1.2, 2.8))

    # Cluster B
    x_data.append(make_point(4.5, 7.5))
    x_data.append(make_point(5.0, 8.0))
    x_data.append(make_point(5.5, 8.5))
    x_data.append(make_point(4.8, 9.0))
    x_data.append(make_point(5.2, 7.8))
    x_data.append(make_point(6.0, 8.2))
    x_data.append(make_point(4.2, 8.8))
    x_data.append(make_point(5.8, 7.2))

    # Cluster C
    x_data.append(make_point(8.5, 3.5))
    x_data.append(make_point(9.0, 4.0))
    x_data.append(make_point(9.5, 4.5))
    x_data.append(make_point(8.8, 5.0))
    x_data.append(make_point(9.2, 3.2))
    x_data.append(make_point(10.0, 4.2))
    x_data.append(make_point(8.2, 4.8))
    x_data.append(make_point(9.8, 3.8))

    var n = len(x_data)
    print("\nDataset  : " + String(n) + " points (8 per cluster)")
    print("Features : x, y coordinates")
    print("Expected : 3 natural clusters (A, B, C)")

    # ── Fit model ─────────────────────────────────────────────── #
    var model = KMeans(k=3, max_iters=100, tol=1e-4)
    model.fit(x_data)

    print("\n--- Training Results ---")
    print("Iterations : " + String(model.n_iters))
    print("Inertia    : " + float_str(model.inertia, 2))

    # ── Centroids ─────────────────────────────────────────────── #
    print("\n--- Final Centroids ---")
    print("Cluster   X        Y")
    print("-" * 30)
    for c in range(model.k):
        var cx = float_str(model.centroids[c][0], 3)
        var cy = float_str(model.centroids[c][1], 3)
        print("  " + cluster_symbol(c) + "     " +
              pad_left(cx, 7) + "  " + pad_left(cy, 7))

    # ── Assignments ───────────────────────────────────────────── #
    print("\n--- Point Assignments ---")
    print("   X       Y      Cluster")
    print("-" * 30)
    for i in range(n):
        var xs = pad_left(float_str(x_data[i][0], 1), 5)
        var ys = pad_left(float_str(x_data[i][1], 1), 7)
        var c  = cluster_symbol(model.labels[i])
        print(xs + ys + "      " + c)

    # ── Cluster sizes ─────────────────────────────────────────── #
    print("\n--- Cluster Sizes ---")
    for c in range(model.k):
        var count = 0
        for i in range(n):
            if model.labels[i] == c:
                count += 1
        print("Cluster " + cluster_symbol(c) + " : " +
              String(count) + " points")

    # ── Inertia vs K (elbow method) ───────────────────────────── #
    print("\n--- Inertia vs K (Elbow Method) ---")
    print("K     Inertia")
    print("-" * 25)
    for k in range(1, 7):
        var m = KMeans(k=k, max_iters=100, tol=1e-4)
        m.fit(x_data)
        print("K=" + String(k) + "   " + float_str(m.inertia, 2))

    # ── New point predictions ─────────────────────────────────── #
    print("\n--- New Point Predictions ---")
    print("   X       Y    ->  Cluster")
    print("-" * 32)
    var test_points = List[List[Float64]]()
    test_points.append(make_point(2.0, 2.0))   # should be A
    test_points.append(make_point(5.0, 8.0))   # should be B
    test_points.append(make_point(9.0, 4.0))   # should be C
    test_points.append(make_point(5.0, 5.0))   # boundary

    for i in range(len(test_points)):
        var xs   = pad_left(float_str(test_points[i][0], 1), 5)
        var ys   = pad_left(float_str(test_points[i][1], 1), 7)
        var pred = model.predict_single(test_points[i])
        print(xs + ys + "   ->  " + cluster_symbol(pred))

    print("\nK-Means Clustering completed.")
    print("=" * 65)
