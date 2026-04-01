"""
Author: Ahmet Aksoy
Date: 2026-03-28
Mojo version: 0.26.2 | Python 3.12 | Ubuntu
AI: Claude Sonnet 4.6

simd_basics.mojo -- SIMD fundamentals in Mojo

Topics covered:
  1.  SIMD type anatomy: SIMD[DType, size]
  2.  Construction: literal, splat, from List
  3.  Arithmetic operators: + - * /
  4.  Fused multiply-add: fma(a, b, c) = a*b + c
  5.  Comparison operators -> SIMD[DType.bool, size]
  6.  Reductions: reduce_add, reduce_mul, reduce_max, reduce_min
  7.  Lane access: simd[i]
  8.  Type casting: cast[DType]()
  9.  Different DType and size combinations
  10. Scalar vs SIMD dot product -- manual benchmark
"""

from std.math import sqrt
from time import perf_counter_ns


# ──────────────────────────────────────────────
# 1. SIMD type anatomy
#    SIMD[dtype, size]
#      dtype : DType.float32 | float64 | int32 | int64 | bool | ...
#      size  : must be a power of 2 (1, 2, 4, 8, 16, ...)
# ──────────────────────────────────────────────
fn section1_anatomy():
    print("=" * 55)
    print("1. SIMD Type Anatomy")
    print("=" * 55)

    # 4-wide float32 vector -- most common for CPU SIMD
    var a = SIMD[DType.float32, 4](1.0, 2.0, 3.0, 4.0)
    print("SIMD[float32, 4] a =", a)

    # 4-wide float64
    var b = SIMD[DType.float64, 4](1.0, 2.0, 3.0, 4.0)
    print("SIMD[float64, 4] b =", b)

    # 8-wide int32
    var c = SIMD[DType.int32, 8](1, 2, 3, 4, 5, 6, 7, 8)
    print("SIMD[int32,   8] c =", c)

    # 2-wide (still valid -- size must be power of 2)
    var d = SIMD[DType.float32, 2](3.14, 2.71)
    print("SIMD[float32, 2] d =", d)

    print()


# ──────────────────────────────────────────────
# 2. Construction methods
# ──────────────────────────────────────────────
fn section2_construction():
    print("=" * 55)
    print("2. Construction Methods")
    print("=" * 55)

    # Literal: provide one value per lane
    var v1 = SIMD[DType.float32, 4](10.0, 20.0, 30.0, 40.0)
    print("Literal          :", v1)

    # splat: broadcast a single scalar to all lanes
    var v2 = SIMD[DType.float32, 4](3.0)   # all lanes = 3.0
    print("Splat(3.0)       :", v2)

    # Zero vector
    var v3 = SIMD[DType.float32, 4](0.0)
    print("Zero             :", v3)

    # Lane access with []
    var v4 = SIMD[DType.float32, 4](5.0, 6.0, 7.0, 8.0)
    print("Lane access v4[0]:", v4[0], " v4[2]:", v4[2])

    print()


# ──────────────────────────────────────────────
# 3. Arithmetic operators
#    All operate element-wise across lanes
# ──────────────────────────────────────────────
fn section3_arithmetic():
    print("=" * 55)
    print("3. Arithmetic Operators (element-wise)")
    print("=" * 55)

    var a = SIMD[DType.float32, 4](1.0, 2.0, 3.0, 4.0)
    var b = SIMD[DType.float32, 4](4.0, 3.0, 2.0, 1.0)

    print("a          =", a)
    print("b          =", b)
    print("a + b      =", a + b)
    print("a - b      =", a - b)
    print("a * b      =", a * b)
    print("a / b      =", a / b)

    # Scalar mixed: broadcast scalar to all lanes automatically
    print("a * 2.0    =", a * 2.0)
    print("a + 10.0   =", a + 10.0)

    print()


# ──────────────────────────────────────────────
# 4. Fused Multiply-Add: fma(a, b, c) = a*b + c
#    Single CPU instruction -- no intermediate rounding
# ──────────────────────────────────────────────
fn section4_fma():
    print("=" * 55)
    print("4. Fused Multiply-Add: fma(a, b, c) = a*b + c")
    print("=" * 55)

    var a = SIMD[DType.float32, 4](1.0, 2.0, 3.0, 4.0)
    var b = SIMD[DType.float32, 4](2.0, 2.0, 2.0, 2.0)
    var c = SIMD[DType.float32, 4](0.5, 0.5, 0.5, 0.5)

    # fma(a, b, c) = a*b + c  in one fused instruction
    var result = a.fma(b, c)
    print("a             =", a)
    print("b             =", b)
    print("c             =", c)
    print("fma(a, b, c)  =", result, "  (= a*b + c)")

    # Comparison: separate multiply then add
    var manual = a * b + c
    print("a * b + c     =", manual, "  (two ops, may differ by rounding)")

    print()


# ──────────────────────────────────────────────
# 5. Comparison operators -> SIMD[DType.bool, size]
#    Each lane independently produces True or False
# ──────────────────────────────────────────────
fn section5_comparison():
    print("=" * 55)
    print("5. Comparison Operators -> bool mask")
    print("=" * 55)

    var a = SIMD[DType.float32, 4](1.0, 5.0, 3.0, 7.0)
    var b = SIMD[DType.float32, 4](2.0, 4.0, 3.0, 6.0)

    print("a         =", a)
    print("b         =", b)

    # == and != work as infix but reduce the whole vector to a single bool
    # (gotcha #47 -- not lane-wise; use SIMD.eq / SIMD.ne for lane-wise masks)
    print("a == b    =", a == b,        "  <- single bool (all lanes equal?)")
    print("a != b    =", a != b,        "  <- single bool (any lane differs?)")
    print("SIMD.eq   =", SIMD.eq(a, b), "  <- lane-wise bool mask")
    print("SIMD.ne   =", SIMD.ne(a, b), "  <- lane-wise bool mask")
    print("SIMD.gt   =", SIMD.gt(a, b))
    print("SIMD.lt   =", SIMD.lt(a, b))
    print("SIMD.ge   =", SIMD.ge(a, b))
    print("SIMD.le   =", SIMD.le(a, b))

    # Compare against a scalar
    print("a > 3.0   =", SIMD.gt(a, 3.0))

    print()


# ──────────────────────────────────────────────
# 6. Reductions: collapse all lanes into one scalar
# ──────────────────────────────────────────────
fn section6_reductions():
    print("=" * 55)
    print("6. Reductions")
    print("=" * 55)

    var v = SIMD[DType.float32, 8](1.0, 2.0, 3.0, 4.0,
                                    5.0, 6.0, 7.0, 8.0)
    print("v              =", v)
    print("reduce_add     =", v.reduce_add())   # sum of all lanes
    print("reduce_mul     =", v.reduce_mul())   # product of all lanes
    print("reduce_max     =", v.reduce_max())   # maximum lane value
    print("reduce_min     =", v.reduce_min())   # minimum lane value

    # Useful pattern: SIMD dot product accumulation
    var a = SIMD[DType.float32, 4](1.0, 2.0, 3.0, 4.0)
    var b = SIMD[DType.float32, 4](4.0, 3.0, 2.0, 1.0)
    var dot = (a * b).reduce_add()
    print("\nDot product a·b =", dot, "  (expected 20.0)")

    print()


# ──────────────────────────────────────────────
# 7. Type casting between DType
# ──────────────────────────────────────────────
fn section7_casting():
    print("=" * 55)
    print("7. Type Casting")
    print("=" * 55)

    var f32 = SIMD[DType.float32, 4](1.7, 2.9, -3.1, 4.5)
    print("float32        =", f32)

    # Cast to int32: truncates toward zero
    var i32 = f32.cast[DType.int32]()
    print("cast[int32]    =", i32)

    # Cast back to float64
    var f64 = f32.cast[DType.float64]()
    print("cast[float64]  =", f64)

    # int32 -> float32
    var iv = SIMD[DType.int32, 4](10, 20, 30, 40)
    print("int32          =", iv)
    print("cast[float32]  =", iv.cast[DType.float32]())

    print()


# ──────────────────────────────────────────────
# 8. Different size combinations
#    size must be power of 2: 1, 2, 4, 8, 16
# ──────────────────────────────────────────────
fn section8_sizes():
    print("=" * 55)
    print("8. Different Sizes")
    print("=" * 55)

    var s1  = SIMD[DType.float32, 1](42.0)
    var s2  = SIMD[DType.float32, 2](1.0, 2.0)
    var s4  = SIMD[DType.float32, 4](1.0, 2.0, 3.0, 4.0)
    var s8  = SIMD[DType.float32, 8](1.0, 2.0, 3.0, 4.0,
                                      5.0, 6.0, 7.0, 8.0)
    var s16 = SIMD[DType.float32, 16](
        1.0,  2.0,  3.0,  4.0,  5.0,  6.0,  7.0,  8.0,
        9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0)

    print("size= 1:", s1)
    print("size= 2:", s2)
    print("size= 4:", s4)
    print("size= 8:", s8)
    print("size=16:", s16)
    print("reduce_add s16 =", s16.reduce_add(), " (expected 136.0)")

    print()


# ──────────────────────────────────────────────
# 9. Scalar vs SIMD dot product benchmark
#    Demonstrates the throughput difference
# ──────────────────────────────────────────────
comptime VEC_SIZE = 1024   # must be divisible by SIMD width
comptime SIMD_W   = 8      # 8-wide float32
comptime N_REPEAT = 10000  # repetitions for stable timing


fn dot_scalar(a: List[Float64], b: List[Float64], n: Int) -> Float64:
    var s = 0.0
    for i in range(n):
        s += a[i] * b[i]
    return s


fn dot_simd(a: List[Float32], b: List[Float32], n: Int) -> Float32:
    var acc = SIMD[DType.float32, SIMD_W](0.0)
    var i = 0
    # Process SIMD_W elements per iteration
    var go = i + SIMD_W <= n
    while go:
        # Load SIMD_W elements from each list
        var va = SIMD[DType.float32, SIMD_W](
            a[i+0], a[i+1], a[i+2], a[i+3],
            a[i+4], a[i+5], a[i+6], a[i+7]
        )
        var vb = SIMD[DType.float32, SIMD_W](
            b[i+0], b[i+1], b[i+2], b[i+3],
            b[i+4], b[i+5], b[i+6], b[i+7]
        )
        acc = acc + va * vb
        i += SIMD_W
        go = i + SIMD_W <= n
    # Reduce all lanes to a single sum
    return acc.reduce_add()


fn section9_benchmark():
    print("=" * 55)
    print("9. Scalar vs SIMD Dot Product Benchmark")
    print("   VEC_SIZE=" + String(VEC_SIZE) +
          "  SIMD_W=" + String(SIMD_W) +
          "  repeats=" + String(N_REPEAT))
    print("=" * 55)

    # Build input vectors
    var a_scalar = List[Float64]()
    var b_scalar = List[Float64]()
    var a_simd   = List[Float32]()
    var b_simd   = List[Float32]()

    for i in range(VEC_SIZE):
        var v = Float64(i + 1) / Float64(VEC_SIZE)
        a_scalar.append(v)
        b_scalar.append(1.0 - v)
        a_simd.append(Float32(v))
        b_simd.append(Float32(1.0 - v))

    # Warm-up
    _ = dot_scalar(a_scalar, b_scalar, VEC_SIZE)
    _ = dot_simd(a_simd, b_simd, VEC_SIZE)

    # Benchmark scalar
    var t0 = perf_counter_ns()
    var result_scalar = 0.0
    for _ in range(N_REPEAT):
        result_scalar = dot_scalar(a_scalar, b_scalar, VEC_SIZE)
    var t1 = perf_counter_ns()
    var scalar_ms = Float64(t1 - t0) / 1_000_000.0

    # Benchmark SIMD
    var t2 = perf_counter_ns()
    var result_simd = Float32(0.0)
    for _ in range(N_REPEAT):
        result_simd = dot_simd(a_simd, b_simd, VEC_SIZE)
    var t3 = perf_counter_ns()
    var simd_ms = Float64(t3 - t2) / 1_000_000.0

    print("Scalar result  : " + String(Int(result_scalar * 1000)) + "e-3")
    print("SIMD   result  : " + String(Int(result_simd   * 1000)) + "e-3")
    print()
    print("Scalar time    : " + String(Int(scalar_ms)) + " ms")
    print("SIMD   time    : " + String(Int(simd_ms))   + " ms")

    if simd_ms > 0.0:
        var speedup = scalar_ms / simd_ms
        print("Speedup        : " + String(Int(speedup * 10)) + "e-1 x")

    print()


# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────
fn main():
    print("=" * 55)
    print("  SIMD Basics -- Mojo 0.26.2")
    print("=" * 55)
    print()

    section1_anatomy()
    section2_construction()
    section3_arithmetic()
    section4_fma()
    section5_comparison()
    section6_reductions()
    section7_casting()
    section8_sizes()
    section9_benchmark()

    print("=" * 55)
    print("  Done.")
    print("=" * 55)
