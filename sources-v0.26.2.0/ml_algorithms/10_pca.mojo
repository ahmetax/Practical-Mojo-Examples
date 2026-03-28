"""
Author: Ahmet Aksoy
Date: 2026-03-23
Mojo version: 0.26.2 | Python 3.12 | Ubuntu

Principal Component Analysis (PCA) — Pure Mojo Implementation
==============================================================

PCA finds the directions (principal components) of maximum variance
in data and projects the data onto a lower-dimensional subspace.

Algorithm:
  1. Center the data: X = X - mean(X)
  2. Compute covariance matrix: C = (1/n) * X.T * X
  3. Find eigenvectors/eigenvalues of C
     (Jacobi iteration for symmetric matrices)
  4. Sort eigenvectors by descending eigenvalue
  5. Project: Z = X * W  (W = top-k eigenvectors)

Explained variance ratio:
  ratio_i = eigenvalue_i / sum(eigenvalues)

Demo: Iris dataset (4 features -> 2 components).
  Visualize class separation in 2D ASCII plot.
"""

from std.math import sqrt, abs


# ------------------------------------------------------------------ #
# Matrix helpers (flat row-major)
# ------------------------------------------------------------------ #

fn mat_zeros(rows: Int, cols: Int) -> List[Float64]:
    """Create a zero matrix."""
    var m = List[Float64]()
    for _ in range(rows * cols):
        m.append(0.0)
    return m^


fn mat_identity(n: Int) -> List[Float64]:
    """Create an identity matrix."""
    var m = mat_zeros(n, n)
    for i in range(n):
        m[i * n + i] = 1.0
    return m^


fn mat_copy(src: List[Float64]) -> List[Float64]:
    """Copy a matrix."""
    var dst = List[Float64]()
    for i in range(len(src)):
        dst.append(src[i])
    return dst^


fn transpose(A: List[Float64], rows: Int, cols: Int) -> List[Float64]:
    """Transpose A(rows x cols) -> A.T(cols x rows)."""
    var T = mat_zeros(cols, rows)
    for i in range(rows):
        for j in range(cols):
            T[j * rows + i] = A[i * cols + j]
    return T^


fn mat_mul(A: List[Float64], B: List[Float64],
           m: Int, k: Int, n: Int) -> List[Float64]:
    """Multiply A(m x k) @ B(k x n) -> C(m x n)."""
    var C = mat_zeros(m, n)
    for i in range(m):
        for j in range(n):
            var s: Float64 = 0.0
            for p in range(k):
                s += A[i * k + p] * B[p * n + j]
            C[i * n + j] = s
    return C^


# ------------------------------------------------------------------ #
# Jacobi eigenvalue algorithm for symmetric matrices
# ------------------------------------------------------------------ #

fn jacobi_rotate(A_in: List[Float64], n: Int,
                  max_iter: Int = 100) -> List[Float64]:
    """Run Jacobi rotations, return diagonalized A (eigenvalues on diagonal)."""
    var A = mat_copy(A_in)
    for _ in range(max_iter):
        var max_val: Float64 = 0.0
        var p = 0
        var q = 1
        for i in range(n):
            for j in range(i + 1, n):
                var aij = abs(A[i * n + j])
                if aij > max_val:
                    max_val = aij
                    p = i
                    q = j
        if max_val < 1e-10:
            break
        var app = A[p * n + p]
        var aqq = A[q * n + q]
        var apq = A[p * n + q]
        var theta: Float64
        if abs(app - aqq) < 1e-14:
            theta = 3.14159265358979 / 4.0
        else:
            theta = 0.5 * _atan((2.0 * apq) / (app - aqq))
        var c = _cos(theta)
        var s = _sin(theta)
        var A_new = mat_copy(A)
        for i in range(n):
            if i != p and i != q:
                A_new[i * n + p] = c * A[i * n + p] + s * A[i * n + q]
                A_new[p * n + i] = A_new[i * n + p]
                A_new[i * n + q] = -s * A[i * n + p] + c * A[i * n + q]
                A_new[q * n + i] = A_new[i * n + q]
        A_new[p * n + p] = c*c*app + 2.0*s*c*apq + s*s*aqq
        A_new[q * n + q] = s*s*app - 2.0*s*c*apq + c*c*aqq
        A_new[p * n + q] = 0.0
        A_new[q * n + p] = 0.0
        A = A_new^
    return A^


fn jacobi_vectors(A_in: List[Float64], n: Int,
                  max_iter: Int = 100) -> List[Float64]:
    """Run Jacobi rotations, return accumulated eigenvector matrix V."""
    var A = mat_copy(A_in)
    var V = mat_identity(n)
    for _ in range(max_iter):
        var max_val: Float64 = 0.0
        var p = 0
        var q = 1
        for i in range(n):
            for j in range(i + 1, n):
                var aij = abs(A[i * n + j])
                if aij > max_val:
                    max_val = aij
                    p = i
                    q = j
        if max_val < 1e-10:
            break
        var app = A[p * n + p]
        var aqq = A[q * n + q]
        var apq = A[p * n + q]
        var theta: Float64
        if abs(app - aqq) < 1e-14:
            theta = 3.14159265358979 / 4.0
        else:
            theta = 0.5 * _atan((2.0 * apq) / (app - aqq))
        var c = _cos(theta)
        var s = _sin(theta)
        var A_new = mat_copy(A)
        for i in range(n):
            if i != p and i != q:
                A_new[i * n + p] = c * A[i * n + p] + s * A[i * n + q]
                A_new[p * n + i] = A_new[i * n + p]
                A_new[i * n + q] = -s * A[i * n + p] + c * A[i * n + q]
                A_new[q * n + i] = A_new[i * n + q]
        A_new[p * n + p] = c*c*app + 2.0*s*c*apq + s*s*aqq
        A_new[q * n + q] = s*s*app - 2.0*s*c*apq + c*c*aqq
        A_new[p * n + q] = 0.0
        A_new[q * n + p] = 0.0
        A = A_new^
        var V_new = mat_copy(V)
        for i in range(n):
            V_new[i * n + p] = c * V[i * n + p] + s * V[i * n + q]
            V_new[i * n + q] = -s * V[i * n + p] + c * V[i * n + q]
        V = V_new^
    return V^


# Simple trig functions (Taylor series)
fn _sin(x: Float64) -> Float64:
    """Sine via Taylor series (good for small angles)."""
    var result: Float64 = x
    var term:   Float64 = x
    var sign:   Float64 = -1.0
    for k in range(1, 10):
        term   *= x * x / Float64((2 * k) * (2 * k + 1))
        result += sign * term
        sign   *= -1.0
    return result


fn _cos(x: Float64) -> Float64:
    """Cosine via Taylor series."""
    var result: Float64 = 1.0
    var term:   Float64 = 1.0
    var sign:   Float64 = -1.0
    for k in range(1, 10):
        term   *= x * x / Float64((2 * k - 1) * (2 * k))
        result += sign * term
        sign   *= -1.0
    return result


fn _atan(x: Float64) -> Float64:
    """Arctangent via identity atan(x) = x/(1+x^2) series approx."""
    # Use atan(x) ≈ pi/4 + (x-1)/2 for x near 1
    # For general x use series: atan(x) = x - x^3/3 + x^5/5 ...
    if abs(x) <= 1.0:
        var result: Float64 = x
        var xpow:   Float64 = x
        for k in range(1, 20):
            xpow   *= x * x
            var sign: Float64 = -1.0 if k % 2 == 1 else 1.0
            result += sign * xpow / Float64(2 * k + 1)
        return result
    else:
        # atan(x) = pi/2 - atan(1/x) for x > 1
        var pi2: Float64 = 3.14159265358979 / 2.0
        var inv  = 1.0 / x
        var result: Float64 = inv
        var xpow:   Float64 = inv
        for k in range(1, 20):
            xpow   *= inv * inv
            var sign: Float64 = -1.0 if k % 2 == 1 else 1.0
            result += sign * xpow / Float64(2 * k + 1)
        if x > 0.0:
            return pi2 - result
        return -pi2 - result


# ------------------------------------------------------------------ #
# Helper functions
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


fn make_point4(a: Float64, b: Float64,
               c: Float64, d: Float64) -> List[Float64]:
    """Create a 4D feature vector."""
    var p = List[Float64]()
    p.append(a); p.append(b); p.append(c); p.append(d)
    return p^


# ------------------------------------------------------------------ #
# PCA
# ------------------------------------------------------------------ #

struct PCA:
    """
    Principal Component Analysis.
    Reduces dimensionality by projecting onto top-k components.
    """
    var n_components: Int
    var n_features  : Int

    # Learned parameters
    var mean_vec      : List[Float64]   # feature means
    var components    : List[Float64]   # eigenvectors (row-major, n_comp x n_feat)
    var eigenvalues   : List[Float64]   # top-k eigenvalues
    var explained_var : List[Float64]   # explained variance ratio per component
    var total_var     : Float64         # total variance

    fn __init__(out self, n_components: Int = 2, n_features: Int = 4):
        self.n_components  = n_components
        self.n_features    = n_features
        self.mean_vec      = List[Float64]()
        self.components    = List[Float64]()
        self.eigenvalues   = List[Float64]()
        self.explained_var = List[Float64]()
        self.total_var     = 0.0

    fn fit(mut self, x: List[List[Float64]]):
        """Compute PCA components from data."""
        var n  = len(x)
        var nf = self.n_features

        # 1. Compute mean
        self.mean_vec = List[Float64]()
        for f in range(nf):
            var s: Float64 = 0.0
            for i in range(n):
                s += x[i][f]
            self.mean_vec.append(s / Float64(n))

        # 2. Center data: X_c[i][f] = x[i][f] - mean[f]
        var Xc = mat_zeros(n, nf)
        for i in range(n):
            for f in range(nf):
                Xc[i * nf + f] = x[i][f] - self.mean_vec[f]

        # 3. Covariance matrix: C = Xc.T @ Xc / n
        var XcT = transpose(Xc, n, nf)
        var cov = mat_mul(XcT, Xc, nf, n, nf)
        for i in range(nf * nf):
            cov[i] /= Float64(n)

        # 4. Eigen decomposition
        var A_diag = jacobi_rotate(cov, nf)
        var evecs  = jacobi_vectors(cov, nf)
        var evals  = List[Float64]()
        for i in range(nf):
            evals.append(A_diag[i * nf + i])   # evecs[i * nf + k] = row i, col k eigenvec

        # 5. Sort by descending eigenvalue
        var order = List[Int]()
        for i in range(nf):
            order.append(i)
        # Insertion sort
        for i in range(1, nf):
            var key_val = evals[order[i]]
            var key_idx = order[i]
            var j       = i - 1
            var go      = j >= 0 and evals[order[j]] < key_val
            while go:
                order[j + 1] = order[j]
                j -= 1
                go = j >= 0 and evals[order[j]] < key_val
            order[j + 1] = key_idx

        # Total variance
        self.total_var = 0.0
        for i in range(nf):
            if evals[i] > 0.0:
                self.total_var += evals[i]

        # 6. Store top-k components and eigenvalues
        self.components  = List[Float64]()
        self.eigenvalues = List[Float64]()
        self.explained_var = List[Float64]()

        for ki in range(self.n_components):
            var col = order[ki]
            self.eigenvalues.append(evals[col])
            var ev_ratio = evals[col] / self.total_var if self.total_var > 0.0 else 0.0
            self.explained_var.append(ev_ratio)
            # Store eigenvector (column col of evecs)
            for f in range(nf):
                self.components.append(evecs[f * nf + col])

    fn transform(self, x: List[List[Float64]]) -> List[List[Float64]]:
        """Project data onto top-k components."""
        var n   = len(x)
        var nf  = self.n_features
        var nc  = self.n_components
        var out = List[List[Float64]]()

        for i in range(n):
            var row = List[Float64]()
            for ki in range(nc):
                var proj: Float64 = 0.0
                for f in range(nf):
                    var xc = x[i][f] - self.mean_vec[f]
                    proj  += xc * self.components[ki * nf + f]
                row.append(proj)
            out.append(row^)
        return out^


# ------------------------------------------------------------------ #
# ASCII scatter plot
# ------------------------------------------------------------------ #

fn ascii_plot(z: List[List[Float64]], labels: List[Int],
              width: Int = 60, height: Int = 24):
    """
    Draw a 2D ASCII scatter plot of PCA-projected data.
    Classes: 0=S (Setosa), 1=V (Versicolor), 2=G (Virginica)
    .
    """
    var n = len(z)

    # Find data range
    var x_min = z[0][0]; var x_max = z[0][0]
    var y_min = z[0][1]; var y_max = z[0][1]
    for i in range(n):
        if z[i][0] < x_min: x_min = z[i][0]
        if z[i][0] > x_max: x_max = z[i][0]
        if z[i][1] < y_min: y_min = z[i][1]
        if z[i][1] > y_max: y_max = z[i][1]

    # Add padding
    var x_pad = (x_max - x_min) * 0.1
    var y_pad = (y_max - y_min) * 0.1
    x_min -= x_pad; x_max += x_pad
    y_min -= y_pad; y_max += y_pad

    # Initialize grid with spaces
    var grid = List[List[String]]()
    for _ in range(height):
        var line = List[String]()
        for _ in range(width):
            line.append(" ")
        grid.append(line^)

    # Plot points
    var symbols = List[String]()
    symbols.append("S")   # Setosa
    symbols.append("V")   # Versicolor
    symbols.append("G")   # Virginica

    for i in range(n):
        var col = Int((z[i][0] - x_min) / (x_max - x_min) * Float64(width  - 1))
        var row = Int((z[i][1] - y_min) / (y_max - y_min) * Float64(height - 1))
        # Flip y-axis
        row = height - 1 - row
        if col >= 0 and col < width and row >= 0 and row < height:
            grid[row][col] = symbols[labels[i]]

    # Print plot
    print("+" + "-" * width + "+")
    for row in range(height):
        var line = "|"
        for col in range(width):
            line += grid[row][col]
        line += "|"
        print(line)
    print("+" + "-" * width + "+")
    print("  x-axis: PC1   y-axis: PC2")
    print("  S=Setosa  V=Versicolor  G=Virginica")


# ------------------------------------------------------------------ #
# Demo
# ------------------------------------------------------------------ #

fn main():
    print("=" * 62)
    print("  Principal Component Analysis (PCA)")
    print("  Demo: Iris dataset 4D -> 2D projection")
    print("=" * 62)

    # Dataset (4 features)
    var x_data = List[List[Float64]]()
    var y_data = List[Int]()

    # Setosa (0)
    x_data.append(make_point4(5.1,3.5,1.4,0.2)); y_data.append(0)
    x_data.append(make_point4(4.9,3.0,1.4,0.2)); y_data.append(0)
    x_data.append(make_point4(4.7,3.2,1.3,0.2)); y_data.append(0)
    x_data.append(make_point4(4.6,3.1,1.5,0.2)); y_data.append(0)
    x_data.append(make_point4(5.0,3.6,1.4,0.2)); y_data.append(0)
    x_data.append(make_point4(5.4,3.9,1.7,0.4)); y_data.append(0)
    x_data.append(make_point4(4.6,3.4,1.4,0.3)); y_data.append(0)
    x_data.append(make_point4(5.0,3.4,1.5,0.2)); y_data.append(0)
    x_data.append(make_point4(4.4,2.9,1.4,0.2)); y_data.append(0)
    x_data.append(make_point4(4.9,3.1,1.5,0.1)); y_data.append(0)
    # Versicolor (1)
    x_data.append(make_point4(7.0,3.2,4.7,1.4)); y_data.append(1)
    x_data.append(make_point4(6.4,3.2,4.5,1.5)); y_data.append(1)
    x_data.append(make_point4(6.9,3.1,4.9,1.5)); y_data.append(1)
    x_data.append(make_point4(5.5,2.3,4.0,1.3)); y_data.append(1)
    x_data.append(make_point4(6.5,2.8,4.6,1.5)); y_data.append(1)
    x_data.append(make_point4(5.7,2.8,4.5,1.3)); y_data.append(1)
    x_data.append(make_point4(6.3,3.3,4.7,1.6)); y_data.append(1)
    x_data.append(make_point4(4.9,2.4,3.3,1.0)); y_data.append(1)
    x_data.append(make_point4(6.6,2.9,4.6,1.3)); y_data.append(1)
    x_data.append(make_point4(5.2,2.7,3.9,1.4)); y_data.append(1)
    # Virginica (2)
    x_data.append(make_point4(6.3,3.3,6.0,2.5)); y_data.append(2)
    x_data.append(make_point4(5.8,2.7,5.1,1.9)); y_data.append(2)
    x_data.append(make_point4(7.1,3.0,5.9,2.1)); y_data.append(2)
    x_data.append(make_point4(6.3,2.9,5.6,1.8)); y_data.append(2)
    x_data.append(make_point4(6.5,3.0,5.8,2.2)); y_data.append(2)
    x_data.append(make_point4(7.6,3.0,6.6,2.1)); y_data.append(2)
    x_data.append(make_point4(4.9,2.5,4.5,1.7)); y_data.append(2)
    x_data.append(make_point4(7.3,2.9,6.3,1.8)); y_data.append(2)
    x_data.append(make_point4(6.7,2.5,5.8,1.8)); y_data.append(2)
    x_data.append(make_point4(7.2,3.6,6.1,2.5)); y_data.append(2)

    var n = len(y_data)
    print("\nDataset : " + String(n) +
          " samples, 4 features -> 2 components")

    # Fit PCA
    var pca = PCA(n_components=2, n_features=4)
    pca.fit(x_data)

    # Explained variance
    print("\n--- Explained Variance ---")
    var cumulative: Float64 = 0.0
    for ki in range(pca.n_components):
        cumulative += pca.explained_var[ki]
        print("PC" + String(ki + 1) +
              ": eigenvalue=" + float_str(pca.eigenvalues[ki], 4) +
              "  explained=" + float_str(pca.explained_var[ki] * 100.0, 1) +
              "%  cumulative=" + float_str(cumulative * 100.0, 1) + "%")

    # Component loadings
    print("\n--- Component Loadings ---")
    var feat_names = List[String]()
    feat_names.append("sepal_len")
    feat_names.append("sepal_wid")
    feat_names.append("petal_len")
    feat_names.append("petal_wid")

    for ki in range(pca.n_components):
        print("PC" + String(ki + 1) + ":")
        for f in range(pca.n_features):
            var loading = pca.components[ki * pca.n_features + f]
            print("  " + feat_names[f] + " : " + float_str(loading, 4))

    # Transform data
    var z = pca.transform(x_data)

    # Projected coordinates
    print("\n--- Projected Coordinates (first 5 per class) ---")
    print("Class       PC1       PC2")
    print("-" * 30)
    var class_names = List[String]()
    class_names.append("Setosa    ")
    class_names.append("Versicolor")
    class_names.append("Virginica ")

    for c in range(3):
        var count = 0
        for i in range(n):
            if y_data[i] == c and count < 5:
                print(class_names[c] + "  " +
                      pad_left(float_str(z[i][0], 3), 8) + "  " +
                      pad_left(float_str(z[i][1], 3), 8))
                count += 1

    # ASCII scatter plot
    print("\n--- 2D Projection (ASCII plot) ---")
    ascii_plot(z, y_data, width=62, height=20)

    # Reconstruct and compute reconstruction error
    print("\n--- Reconstruction Error ---")
    var total_err: Float64 = 0.0
    for i in range(n):
        # Reconstruct: x_approx = mean + z[i] * components
        for f in range(pca.n_features):
            var x_approx = pca.mean_vec[f]
            for ki in range(pca.n_components):
                x_approx += z[i][ki] * pca.components[ki * pca.n_features + f]
            var diff = x_data[i][f] - x_approx
            total_err += diff * diff
    var mse = total_err / Float64(n * pca.n_features)
    print("MSE (4D->2D reconstruction): " + float_str(mse, 6))
    print("Explained variance total   : " +
          float_str(cumulative * 100.0, 1) + "%")

    print("\nPCA completed.")
    print("=" * 62)
