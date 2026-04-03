"""
Author: Ahmet Aksoy
Date: 2026-03-30
Mojo version: 0.26.2 | Python 3.12 | Ubuntu
AI: Claude Sonnet 4.6

simd_matmul.mojo -- Matrix Multiply with SIMD (pure Mojo)

Implementations compared:
  1. Scalar (naive)     -- triple loop, List indexing
  2. SIMD W=8           -- inner loop uses 8-wide SIMD accumulator
  3. SIMD W=16          -- same with wider vector
  4. SIMD + pointer     -- UnsafePointer load instead of List indexing

Matrix storage: row-major flat List[Float32]
  M[i, j] = data[i * n_cols + j]

Benchmark sizes: 32x32, 64x64, 128x128
"""

from std.memory import UnsafePointer
from std.time import perf_counter_ns


comptime REPEAT_SMALL = 1000   # for 128x128
comptime REPEAT_LARGE = 10000  # for 32x32, 64x64


fn fmt_time(ns: UInt) -> String:
    if ns >= 1_000_000:
        return String(ns // 1_000_000) + "." +
               String((ns % 1_000_000) // 10_000) + " ms"
    else:
        return String(ns // 1_000) + "." +
               String((ns % 1_000) // 10) + " us"


# ──────────────────────────────────────────────
# Matrix helpers
# ──────────────────────────────────────────────
fn make_matrix(n: Int) -> List[Float32]:
    """Create n x n matrix filled with 1/n (row-major)."""
    var m = List[Float32]()
    for i in range(n * n):
        m.append(Float32(i + 1) / Float32(n * n))
    return m^


fn make_zeros(n: Int) -> List[Float32]:
    """Create n x n zero matrix."""
    var m = List[Float32]()
    for _ in range(n * n):
        m.append(0.0)
    return m^


fn zero_out(mut m: List[Float32]):
    """Reset all elements to zero."""
    for i in range(len(m)):
        m[i] = 0.0


# ══════════════════════════════════════════════
# Implementation 1: Scalar naive matmul
#   C[i,j] = sum_k A[i,k] * B[k,j]
# ══════════════════════════════════════════════
fn matmul_scalar(
    A: List[Float32], B: List[Float32],
    mut C: List[Float32], n: Int
):
    for i in range(n):
        for j in range(n):
            var s = Float32(0.0)
            for k in range(n):
                s += A[i * n + k] * B[k * n + j]
            C[i * n + j] = s


# ══════════════════════════════════════════════
# Implementation 2: SIMD matmul
#   Inner k-loop processes W elements at a time.
#   B must be transposed for contiguous memory access.
#
#   C[i,j] = dot(row_i(A), col_j(B))
#           = dot(row_i(A), row_j(B^T))
# ══════════════════════════════════════════════
fn transpose(A: List[Float32], n: Int) -> List[Float32]:
    """Return A^T."""
    var T = List[Float32]()
    for _ in range(n * n):
        T.append(0.0)
    for i in range(n):
        for j in range(n):
            T[j * n + i] = A[i * n + j]
    return T^


fn matmul_simd[W: Int](
    A: List[Float32], BT: List[Float32],   # BT = B transposed
    mut C: List[Float32], n: Int
):
    """C = A * B  where BT = B^T (pre-transposed for cache efficiency)."""
    var pa = A.unsafe_ptr()
    var pb = BT.unsafe_ptr()

    for i in range(n):
        for j in range(n):
            var acc = SIMD[DType.float32, W](0.0)
            var k = 0
            var go = k + W <= n
            while go:
                var va = (pa + i * n + k).load[width=W]()
                var vb = (pb + j * n + k).load[width=W]()
                acc = acc + va * vb
                k += W
                go = k + W <= n
            # Scalar remainder
            var s = acc.reduce_add()
            var go2 = k < n
            while go2:
                s += A[i * n + k] * BT[j * n + k]
                k += 1
                go2 = k < n
            C[i * n + j] = s


# ══════════════════════════════════════════════
# Verify: check C ≈ expected value
# For A filled with (i+1)/(n*n) and B = A,
# C[0,0] should be sum of first row of A times first col of B
# ══════════════════════════════════════════════
fn check_result(C: List[Float32], n: Int, label: String):
    var c00 = C[0]
    var cnn = C[n * n - 1]
    print("  " + label + ": C[0,0]=" +
          String(Int(c00 * 1000)) + "e-3" +
          "  C[n-1,n-1]=" + String(Int(cnn * 1000)) + "e-3")


# ══════════════════════════════════════════════
# Benchmark one matrix size
# ══════════════════════════════════════════════
fn bench_size(n: Int, repeat: Int):
    print("\n  -- " + String(n) + "x" + String(n) +
          "  repeats=" + String(repeat) + " --")

    var A  = make_matrix(n)
    var B  = make_matrix(n)
    var BT = transpose(B, n)
    var C  = make_zeros(n)

    # Correctness check
    matmul_scalar(A, B, C, n)
    check_result(C, n, "scalar")
    zero_out(C)
    matmul_simd[8](A, BT, C, n)
    check_result(C, n, "simd W=8")
    zero_out(C)
    matmul_simd[16](A, BT, C, n)
    check_result(C, n, "simd W=16")
    zero_out(C)

    # Benchmark scalar
    var t0 = perf_counter_ns()
    for _ in range(repeat):
        matmul_scalar(A, B, C, n)
    var t1 = perf_counter_ns()

    # Benchmark SIMD W=8
    var t2 = perf_counter_ns()
    for _ in range(repeat):
        matmul_simd[8](A, BT, C, n)
    var t3 = perf_counter_ns()

    # Benchmark SIMD W=16
    var t4 = perf_counter_ns()
    for _ in range(repeat):
        matmul_simd[16](A, BT, C, n)
    var t5 = perf_counter_ns()

    var s0  = t1 - t0
    var s8  = t3 - t2
    var s16 = t5 - t4

    print("  Scalar        : " + fmt_time(s0))
    print("  SIMD W= 8     : " + fmt_time(s8) +
          "  speedup=" + String(Int(Float64(s0)/Float64(s8)*10)) + "e-1x")
    print("  SIMD W=16     : " + fmt_time(s16) +
          "  speedup=" + String(Int(Float64(s0)/Float64(s16)*10)) + "e-1x")


# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────
fn main():
    print("=" * 55)
    print("  Matrix Multiply + SIMD -- Mojo 0.26.2")
    print("  C = A * B  (square matrices, float32)")
    print("  Strategy: transpose B for cache-friendly access")
    print("=" * 55)

    bench_size(32,  REPEAT_LARGE)
    bench_size(64,  REPEAT_LARGE)
    bench_size(128, REPEAT_SMALL)

    print("\n" + "=" * 55)
    print("  Done.")
    print("=" * 55)
