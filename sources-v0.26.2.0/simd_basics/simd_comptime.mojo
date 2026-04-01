"""
Author: Ahmet Aksoy
Date: 2026-03-29
Mojo version: 0.26.2 | Python 3.12 | Ubuntu
AI: Claude Sonnet 4.6

simd_parameter.mojo -- @parameter and compile-time SIMD in Mojo

Topics covered:
  1. comptime if   -- compile-time conditional (replaces @parameter if)
  2. comptime for  -- compile-time loop unrolling (replaces @parameter for)
  3. Generic SIMD functions: fn foo[width: Int](...)
  4. Manual vectorized loop with comptime width
  5. Benchmark: scalar vs SIMD width=4 vs SIMD width=8 vs SIMD width=16

Notes:
  - Global var is not supported in Mojo 0.26.2 (gotcha #19)
  - Closures cannot have compile-time parameters [..] (gotcha #51)
  - simdwidthof / vectorize location unclear -- avoided in this script
  - perf_counter_ns() returns UInt, not Int (gotcha #52)
"""

from std.time import perf_counter_ns


# ──────────────────────────────────────────────
# Constants
# ──────────────────────────────────────────────
comptime REPEAT = 50_000
comptime BN     = 1024


fn ms(ns: UInt) -> String:
    return String(ns // 1_000_000) + "." +
           String((ns % 1_000_000) // 10_000) + " ms"


# ══════════════════════════════════════════════
# 1. comptime if -- compile-time conditional
# ══════════════════════════════════════════════
fn section1_comptime_if():
    print("=" * 55)
    print("1. comptime if -- compile-time conditional")
    print("=" * 55)

    comptime DEBUG = False

    comptime if DEBUG:
        print("  [DEBUG] compiled only when DEBUG=True")
    else:
        print("  [RELEASE] DEBUG=False branch active")

    comptime USE_F64 = True

    comptime if USE_F64:
        var v = SIMD[DType.float64, 4](1.0, 2.0, 3.0, 4.0)
        print("  float64 vector:", v)
    else:
        var v = SIMD[DType.float32, 4](1.0, 2.0, 3.0, 4.0)
        print("  float32 vector:", v)

    print()


# ══════════════════════════════════════════════
# 2. comptime for -- compile-time loop unrolling
# ══════════════════════════════════════════════
fn section2_comptime_for():
    print("=" * 55)
    print("2. comptime for -- compile-time loop unrolling")
    print("=" * 55)

    # Each iteration is a distinct compile-time specialization.
    # The loop variable is a compile-time constant in each body.
    comptime for log2w in range(1, 5):      # 2, 4, 8, 16
        comptime width = 1 << log2w
        var v = SIMD[DType.float32, width](0.0)

        # Inner comptime for: unrolled lane assignment
        comptime for lane in range(width):
            v[lane] = Float32(lane + 1)

        print("  SIMD[float32," + String(width) + "] lanes=" +
              String(width) + "  sum=" + String(v.reduce_add()))

    print()


# ══════════════════════════════════════════════
# 3. Generic SIMD function fn foo[width: Int](...)
#    Each call site with a different width produces
#    a distinct compiled specialization.
# ══════════════════════════════════════════════
fn dot[width: Int](
    a: List[Float32], b: List[Float32], n: Int
) -> Float32:
    """Dot product using width-wide SIMD accumulator."""
    var acc = SIMD[DType.float32, width](0.0)
    var i = 0
    var go = i + width <= n
    while go:
        var va = SIMD[DType.float32, width](0.0)
        var vb = SIMD[DType.float32, width](0.0)
        comptime for lane in range(width):
            va[lane] = a[i + lane]
            vb[lane] = b[i + lane]
        acc = acc + va * vb
        i += width
        go = i + width <= n
    # Scalar remainder
    var go2 = i < n
    while go2:
        acc[0] += a[i] * b[i]
        i += 1
        go2 = i < n
    return acc.reduce_add()


fn section3_generic_fn():
    print("=" * 55)
    print("3. Generic fn dot[width: Int](...)")
    print("   n=12 (not a power of 2 -- tests remainder handling)")
    print("=" * 55)

    comptime N = 12
    var a = List[Float32]()
    var b = List[Float32]()
    for i in range(N):
        a.append(Float32(i + 1))
        b.append(1.0)           # dot = sum(1..N) = 78

    print("  Expected: " + String(N * (N + 1) // 2))
    print("  dot[ 1] =", dot[1](a, b, N))
    print("  dot[ 2] =", dot[2](a, b, N))
    print("  dot[ 4] =", dot[4](a, b, N))
    print("  dot[ 8] =", dot[8](a, b, N))
    print()


# ══════════════════════════════════════════════
# 4. Manual vectorized loop
#    c[i] = a[i] * b[i] + 1.0  over n elements
#    processed width elements at a time
# ══════════════════════════════════════════════
fn muladd[width: Int](
    a: List[Float32], b: List[Float32],
    mut c: List[Float32], n: Int
):
    """Element-wise c[i] = a[i] * b[i] + 1.0 using SIMD width lanes."""
    var one = SIMD[DType.float32, width](1.0)
    var i = 0
    var go = i + width <= n
    while go:
        var va = SIMD[DType.float32, width](0.0)
        var vb = SIMD[DType.float32, width](0.0)
        comptime for lane in range(width):
            va[lane] = a[i + lane]
            vb[lane] = b[i + lane]
        var vc = va.fma(vb, one)    # va*vb + 1.0  (single fma instruction)
        comptime for lane in range(width):
            c[i + lane] = vc[lane]
        i += width
        go = i + width <= n
    # Scalar remainder
    var go2 = i < n
    while go2:
        c[i] = a[i] * b[i] + 1.0
        i += 1
        go2 = i < n


fn muladd_scalar(
    a: List[Float32], b: List[Float32],
    mut c: List[Float32], n: Int
):
    for i in range(n):
        c[i] = a[i] * b[i] + 1.0


fn section4_manual_vectorized():
    print("=" * 55)
    print("4. Manual vectorized loop: c[i] = a[i]*b[i] + 1.0")
    print("=" * 55)

    comptime N = 10
    var a = List[Float32]()
    var b = List[Float32]()
    var c = List[Float32]()
    for i in range(N):
        a.append(Float32(i + 1))
        b.append(Float32(2))
        c.append(0.0)

    muladd[4](a, b, c, N)

    print("  a =", end=""); print(" [", end="")
    for i in range(N):
        print(String(Int(a[i])), end=" ")
    print("]")
    print("  b =", end=""); print(" [", end="")
    for i in range(N):
        print(String(Int(b[i])), end=" ")
    print("]")
    print("  c = a*b+1 =", end=""); print(" [", end="")
    for i in range(N):
        print(String(Int(c[i])), end=" ")
    print("]")
    print()


# ══════════════════════════════════════════════
# 5. Benchmark: scalar vs SIMD width 4/8/16
# ══════════════════════════════════════════════
fn section5_benchmark():
    print("=" * 55)
    print("5. Benchmark: c[i] = a[i]*b[i] + 1.0")
    print("   n=" + String(BN) + "  repeats=" + String(REPEAT))
    print("=" * 55)

    var a = List[Float32]()
    var b = List[Float32]()
    var c = List[Float32]()
    for i in range(BN):
        var v = Float32(i + 1) / Float32(BN)
        a.append(v)
        b.append(Float32(1.0) - v)
        c.append(0.0)

    # Scalar
    var t0 = perf_counter_ns()
    for _ in range(REPEAT):
        muladd_scalar(a, b, c, BN)
    var t1 = perf_counter_ns()

    # SIMD width=4
    var t2 = perf_counter_ns()
    for _ in range(REPEAT):
        muladd[4](a, b, c, BN)
    var t3 = perf_counter_ns()

    # SIMD width=8
    var t4 = perf_counter_ns()
    for _ in range(REPEAT):
        muladd[8](a, b, c, BN)
    var t5 = perf_counter_ns()

    # SIMD width=16
    var t6 = perf_counter_ns()
    for _ in range(REPEAT):
        muladd[16](a, b, c, BN)
    var t7 = perf_counter_ns()

    var s  = t1 - t0
    var s4 = t3 - t2
    var s8 = t5 - t4
    var s16= t7 - t6

    print("  Scalar   (width= 1): " + ms(s))
    print("  SIMD     (width= 4): " + ms(s4) +
          "  speedup=" + String(Int(Float64(s) / Float64(s4)  * 10)) + "e-1x")
    print("  SIMD     (width= 8): " + ms(s8) +
          "  speedup=" + String(Int(Float64(s) / Float64(s8)  * 10)) + "e-1x")
    print("  SIMD     (width=16): " + ms(s16) +
          "  speedup=" + String(Int(Float64(s) / Float64(s16) * 10)) + "e-1x")
    print()


# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────
fn main():
    print("=" * 55)
    print("  SIMD + comptime -- Mojo 0.26.2")
    print("=" * 55)
    print()

    section1_comptime_if()
    section2_comptime_for()
    section3_generic_fn()
    section4_manual_vectorized()
    section5_benchmark()

    print("=" * 55)
    print("  Done.")
    print("=" * 55)
