"""
Author: Ahmet Aksoy
Date: 2026-03-24
Mojo version: 0.26.2 | Python 3.12 | Ubuntu
AI: Claude Sonnet 4.6

DBSCAN — Density-Based Spatial Clustering of Applications with Noise
=====================================================================

DBSCAN groups points that are closely packed together and marks
points in low-density regions as outliers (noise).

Key concepts:
  Core point   : has >= min_samples neighbors within eps radius
  Border point : within eps of a core point, but not core itself
  Noise point  : neither core nor border — label = -1

Algorithm:
  For each unvisited point p:
    If p has < min_samples neighbors within eps -> mark NOISE
    Else -> start new cluster, expand recursively:
      Add all eps-neighbors to cluster
      For each neighbor that is also core -> expand further

Advantages over K-Means:
  - No need to specify number of clusters
  - Finds arbitrarily shaped clusters
  - Robust to outliers
  - Works well with varying density

Demo 1: 2D synthetic data with 3 clusters + noise points.
Demo 2: Iris petal features — compare with K-Means.
"""

from std.math import sqrt


# ------------------------------------------------------------------ #
# Distance
# ------------------------------------------------------------------ #

fn euclidean(a: List[Float64], b: List[Float64]) -> Float64:
    """Euclidean distance between two points."""
    var s: Float64 = 0.0
    for i in range(len(a)):
        var d = a[i] - b[i]
        s += d * d
    return sqrt(s)


fn region_query(x: List[List[Float64]], idx: Int,
                eps: Float64) -> List[Int]:
    """Return indices of all points within eps of x[idx]."""
    var neighbors = List[Int]()
    for i in range(len(x)):
        if i != idx and euclidean(x[idx], x[i]) <= eps:
            neighbors.append(i)
    return neighbors^


# ------------------------------------------------------------------ #
# DBSCAN
# ------------------------------------------------------------------ #

struct DBSCAN:
    """
    DBSCAN Clustering.
    Labels: -1 = noise, 0..k = cluster id.
    """
    var eps        : Float64
    var min_samples: Int
    var labels     : List[Int]
    var n_clusters : Int

    fn __init__(out self, eps: Float64 = 0.5,
                min_samples: Int = 3):
        self.eps         = eps
        self.min_samples = min_samples
        self.labels      = List[Int]()
        self.n_clusters  = 0

    fn fit(mut self, x: List[List[Float64]]):
        """Run DBSCAN on dataset x."""
        var n = len(x)

        # Initialize all labels as unvisited (-2)
        self.labels = List[Int]()
        for _ in range(n):
            self.labels.append(-2)

        var cluster_id = -1

        for i in range(n):
            if self.labels[i] != -2:
                continue   # already visited

            var neighbors = region_query(x, i, self.eps)

            if len(neighbors) < self.min_samples:
                # Not enough neighbors — mark as noise
                self.labels[i] = -1
                continue

            # Start new cluster
            cluster_id += 1
            self.labels[i] = cluster_id

            # Expand cluster using a queue (manual stack)
            var queue = List[Int]()
            for j in range(len(neighbors)):
                queue.append(neighbors[j])

            var qi = 0
            var go = qi < len(queue)
            while go:
                var q = queue[qi]
                qi += 1

                if self.labels[q] == -1:
                    # Noise -> border point of this cluster
                    self.labels[q] = cluster_id

                if self.labels[q] != -2:
                    go = qi < len(queue)
                    continue   # already processed

                self.labels[q] = cluster_id

                var q_neighbors = region_query(x, q, self.eps)
                if len(q_neighbors) >= self.min_samples:
                    # q is a core point — add its neighbors
                    for j in range(len(q_neighbors)):
                        var nb = q_neighbors[j]
                        if self.labels[nb] == -2 or self.labels[nb] == -1:
                            queue.append(nb)

                go = qi < len(queue)

        self.n_clusters = cluster_id + 1

    fn predict_single(self, x: List[List[Float64]],
                      query: List[Float64]) -> Int:
        """
        Assign new point to nearest cluster (or -1 if noise).
        Finds closest core-like point within eps.
        """
        var best_label = -1
        var best_dist  = 1.0e38
        for i in range(len(x)):
            if self.labels[i] >= 0:
                var d = euclidean(query, x[i])
                if d <= self.eps and d < best_dist:
                    best_dist  = d
                    best_label = self.labels[i]
        return best_label


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
    var sign = ""
    var v    = val
    if v < 0.0:
        sign = "-"
        v    = -v
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


fn make_point(x: Float64, y: Float64) -> List[Float64]:
    """Create a 2D point."""
    var p = List[Float64]()
    p.append(x)
    p.append(y)
    return p^


fn make_point2(x: Float64, y: Float64) -> List[Float64]:
    """Alias for make_point."""
    var p = List[Float64]()
    p.append(x)
    p.append(y)
    return p^


fn cluster_symbol(label: Int) -> String:
    """Symbol for cluster label."""
    if label == -1:
        return "*"   # noise
    if label == 0:
        return "A"
    if label == 1:
        return "B"
    if label == 2:
        return "C"
    if label == 3:
        return "D"
    return "?"


fn ascii_plot(x: List[List[Float64]], labels: List[Int],
              width: Int = 60, height: Int = 20):
    """Simple ASCII scatter plot colored by cluster."""
    var n = len(x)
    var x_min = x[0][0]; var x_max = x[0][0]
    var y_min = x[0][1]; var y_max = x[0][1]
    for i in range(n):
        if x[i][0] < x_min: x_min = x[i][0]
        if x[i][0] > x_max: x_max = x[i][0]
        if x[i][1] < y_min: y_min = x[i][1]
        if x[i][1] > y_max: y_max = x[i][1]

    var xpad = (x_max - x_min) * 0.1
    var ypad = (y_max - y_min) * 0.1
    x_min -= xpad; x_max += xpad
    y_min -= ypad; y_max += ypad

    var grid = List[List[String]]()
    for _ in range(height):
        var row = List[String]()
        for _ in range(width):
            row.append(" ")
        grid.append(row^)

    for i in range(n):
        var col = Int((x[i][0] - x_min) / (x_max - x_min) * Float64(width  - 1))
        var row = Int((x[i][1] - y_min) / (y_max - y_min) * Float64(height - 1))
        row = height - 1 - row
        if col >= 0 and col < width and row >= 0 and row < height:
            grid[row][col] = cluster_symbol(labels[i])

    print("+" + "-" * width + "+")
    for r in range(height):
        var line = "|"
        for c in range(width):
            line += grid[r][c]
        line += "|"
        print(line)
    print("+" + "-" * width + "+")
    print("  A/B/C = clusters   * = noise")


fn print_cluster_stats(labels: List[Int], n_clusters: Int):
    """Print cluster sizes and noise count."""
    var noise = 0
    for i in range(len(labels)):
        if labels[i] == -1:
            noise += 1
    print("Clusters found : " + String(n_clusters))
    print("Noise points   : " + String(noise))
    for c in range(n_clusters):
        var count = 0
        for i in range(len(labels)):
            if labels[i] == c:
                count += 1
        print("  Cluster " + cluster_symbol(c) +
              " : " + String(count) + " points")


# ------------------------------------------------------------------ #
# Demo
# ------------------------------------------------------------------ #

fn main():
    print("=" * 62)
    print("  DBSCAN — Density-Based Clustering")
    print("=" * 62)

    # ── Demo 1: Synthetic 2D data ─────────────────────────────── #
    print("\n--- Demo 1: Synthetic 2D Data (3 clusters + noise) ---")

    var x1 = List[List[Float64]]()

    # Cluster A — bottom-left
    x1.append(make_point(1.0, 1.0)); x1.append(make_point(1.2, 1.1))
    x1.append(make_point(0.9, 1.3)); x1.append(make_point(1.1, 0.9))
    x1.append(make_point(1.3, 1.2)); x1.append(make_point(0.8, 1.0))
    x1.append(make_point(1.0, 1.4)); x1.append(make_point(1.2, 0.8))

    # Cluster B — top-center
    x1.append(make_point(5.0, 8.0)); x1.append(make_point(5.2, 8.1))
    x1.append(make_point(4.9, 7.9)); x1.append(make_point(5.1, 8.3))
    x1.append(make_point(5.3, 7.8)); x1.append(make_point(4.8, 8.2))
    x1.append(make_point(5.0, 7.7)); x1.append(make_point(5.2, 8.4))

    # Cluster C — right
    x1.append(make_point(9.0, 4.0)); x1.append(make_point(9.2, 4.1))
    x1.append(make_point(8.9, 3.9)); x1.append(make_point(9.1, 4.3))
    x1.append(make_point(9.3, 3.8)); x1.append(make_point(8.8, 4.2))
    x1.append(make_point(9.0, 3.7)); x1.append(make_point(9.2, 4.4))

    # Noise points
    x1.append(make_point(3.0, 5.0)); x1.append(make_point(7.0, 1.0))
    x1.append(make_point(2.0, 9.0)); x1.append(make_point(6.0, 6.0))

    var db1 = DBSCAN(eps=0.6, min_samples=3)
    db1.fit(x1)

    print("eps=0.6, min_samples=3")
    print_cluster_stats(db1.labels, db1.n_clusters)
    print("")
    ascii_plot(x1, db1.labels)

    # ── Demo 2: Effect of eps ─────────────────────────────────── #
    print("\n--- Demo 2: Effect of eps ---")
    print("eps     Clusters  Noise")
    print("-" * 28)
    var eps_vals = List[Float64]()
    eps_vals.append(0.3); eps_vals.append(0.5)
    eps_vals.append(0.6); eps_vals.append(1.0)
    eps_vals.append(2.0); eps_vals.append(5.0)
    for i in range(len(eps_vals)):
        var ep = eps_vals[i]
        var db = DBSCAN(eps=ep, min_samples=3)
        db.fit(x1)
        var noise = 0
        for j in range(len(db.labels)):
            if db.labels[j] == -1:
                noise += 1
        print(pad_left(float_str(ep, 1), 5) + "     " +
              pad_left(String(db.n_clusters), 5) + "     " +
              String(noise))

    # ── Demo 3: Iris petal features ───────────────────────────── #
    print("\n--- Demo 3: Iris Petal Features ---")
    print("Comparing DBSCAN vs true labels")

    var x_iris = List[List[Float64]]()
    var y_iris = List[Int]()   # true labels

    # Setosa
    x_iris.append(make_point2(1.4,0.2)); y_iris.append(0)
    x_iris.append(make_point2(1.3,0.2)); y_iris.append(0)
    x_iris.append(make_point2(1.5,0.2)); y_iris.append(0)
    x_iris.append(make_point2(1.4,0.3)); y_iris.append(0)
    x_iris.append(make_point2(1.7,0.4)); y_iris.append(0)
    x_iris.append(make_point2(1.5,0.1)); y_iris.append(0)
    x_iris.append(make_point2(1.6,0.2)); y_iris.append(0)
    x_iris.append(make_point2(1.1,0.1)); y_iris.append(0)
    x_iris.append(make_point2(1.2,0.2)); y_iris.append(0)
    x_iris.append(make_point2(1.5,0.3)); y_iris.append(0)
    # Versicolor
    x_iris.append(make_point2(4.7,1.4)); y_iris.append(1)
    x_iris.append(make_point2(4.5,1.5)); y_iris.append(1)
    x_iris.append(make_point2(4.9,1.5)); y_iris.append(1)
    x_iris.append(make_point2(4.0,1.3)); y_iris.append(1)
    x_iris.append(make_point2(4.6,1.5)); y_iris.append(1)
    x_iris.append(make_point2(4.5,1.3)); y_iris.append(1)
    x_iris.append(make_point2(4.7,1.6)); y_iris.append(1)
    x_iris.append(make_point2(3.3,1.0)); y_iris.append(1)
    x_iris.append(make_point2(4.6,1.3)); y_iris.append(1)
    x_iris.append(make_point2(3.9,1.4)); y_iris.append(1)
    # Virginica
    x_iris.append(make_point2(6.0,2.5)); y_iris.append(2)
    x_iris.append(make_point2(5.1,1.9)); y_iris.append(2)
    x_iris.append(make_point2(5.9,2.1)); y_iris.append(2)
    x_iris.append(make_point2(5.6,1.8)); y_iris.append(2)
    x_iris.append(make_point2(5.8,2.2)); y_iris.append(2)
    x_iris.append(make_point2(6.6,2.1)); y_iris.append(2)
    x_iris.append(make_point2(6.3,1.8)); y_iris.append(2)
    x_iris.append(make_point2(6.1,2.5)); y_iris.append(2)
    x_iris.append(make_point2(6.4,2.0)); y_iris.append(2)
    x_iris.append(make_point2(5.6,2.1)); y_iris.append(2)

    var db_iris = DBSCAN(eps=0.8, min_samples=3)
    db_iris.fit(x_iris)

    print("eps=0.8, min_samples=3")
    print_cluster_stats(db_iris.labels, db_iris.n_clusters)

    # Comparison table
    print("\nPoint  TrueClass  DBSCANCluster")
    print("-" * 35)
    var class_names = List[String]()
    class_names.append("Setosa    ")
    class_names.append("Versicolor")
    class_names.append("Virginica ")
    for i in range(len(x_iris)):
        var true_lbl = class_names[y_iris[i]]
        var pred_lbl = String(db_iris.labels[i]) if db_iris.labels[i] >= 0 else "noise"
        print(pad_left(String(i), 5) + "  " +
              true_lbl + "  " + pred_lbl)

    print("")
    ascii_plot(x_iris, db_iris.labels)

    print("\nDBSCAN completed.")
    print("=" * 62)
