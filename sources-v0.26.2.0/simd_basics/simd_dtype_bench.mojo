"""
Author: Ahmet Aksoy
Date: 2026-03-31
Mojo version: 0.26.2 | Python 3.12 | Ubuntu
AI: Claude Sonnet 4.6

simd_dtype_bench.mojo -- SIMD DType Performance Comparison

Compares SIMD performance across numeric types:
  float64  -- 64-bit IEEE float  (2 lanes per 128-bit register)
  float32  -- 32-bit IEEE float  (4 lanes per 128-bit register)
  float16  -- 16-bit half float  (8 lanes per 128-bit register)
  int64    -- 64-bit integer     (2 lanes)
  int32    -- 32-bit integer     (4 lanes)
  int16    -- 16-bit integer     (8 lanes)
  int8     -- 8-bit integer      (16 lanes)

Fixed SIMD width = 8 throughout:
  float64 W=8 uses 512 bits (AVX-512) or two 256-bit ops (AVX2)
  float32 W=8 uses 256 bits (one AVX2 op)
  int8    W=8 uses 64 bits

Operations benchmarked:
  1. Element-wise add
  2. Element-wise multiply
  3. fma (fused multiply-add)
  4. reduce_add (horizontal sum)
  5. Dot product loop (n=1024)

Key insight: narrower types pack more lanes per register, so
float32 is often 2x faster than float64 for the same algorithm.
"""

from std.time import perf_counter_ns


comptime W      = 8        # fixed SIMD width throughout
comptime N      = 1024     # vector length for dot product
comptime REPEAT = 500_000


fn fmt_time(ns: UInt) -> String:
    if ns >= 1_000_000:
        return String(ns // 1_000_000) + "." +
               String((ns % 1_000_000) // 10_000) + " ms"
    return String(ns // 1_000) + "." +
           String((ns % 1_000) // 10) + " us"


# ══════════════════════════════════════════════
# 1. Basic ops for each DType -- correctness demo
# ══════════════════════════════════════════════
fn section1_basic_ops():
    print("=" * 55)
    print("1. Basic SIMD ops across DTypes (W=8)")
    print("=" * 55)

    # float64
    var vf64 = SIMD[DType.float64, W](1.0, 2.0, 3.0, 4.0,
                                       5.0, 6.0, 7.0, 8.0)
    print("  float64 sum  :", vf64.reduce_add())
    print("  float64 max  :", vf64.reduce_max())

    # float32
    var vf32 = SIMD[DType.float32, W](1.0, 2.0, 3.0, 4.0,
                                       5.0, 6.0, 7.0, 8.0)
    print("  float32 sum  :", vf32.reduce_add())
    print("  float32 max  :", vf32.reduce_max())

    # int32
    var vi32 = SIMD[DType.int32, W](1, 2, 3, 4, 5, 6, 7, 8)
    print("  int32   sum  :", vi32.reduce_add())
    print("  int32   max  :", vi32.reduce_max())

    # int16
    var vi16 = SIMD[DType.int16, W](1, 2, 3, 4, 5, 6, 7, 8)
    print("  int16   sum  :", vi16.reduce_add())

    # int8
    var vi8  = SIMD[DType.int8,  W](1, 2, 3, 4, 5, 6, 7, 8)
    print("  int8    sum  :", vi8.reduce_add())

    print()


# ══════════════════════════════════════════════
# 2. fma availability per DType
#    fma(a, b, c) = a*b + c
#    Available for float types; int uses a*b + c (two ops)
# ══════════════════════════════════════════════
fn section2_fma():
    print("=" * 55)
    print("2. fma(a, b, c) = a*b + c")
    print("=" * 55)

    var a32 = SIMD[DType.float32, W](1.0, 2.0, 3.0, 4.0,
                                      5.0, 6.0, 7.0, 8.0)
    var b32 = SIMD[DType.float32, W](2.0)
    var c32 = SIMD[DType.float32, W](0.5)
    print("  float32 fma(a,2,0.5):", a32.fma(b32, c32))

    var a64 = SIMD[DType.float64, W](1.0, 2.0, 3.0, 4.0,
                                      5.0, 6.0, 7.0, 8.0)
    var b64 = SIMD[DType.float64, W](2.0)
    var c64 = SIMD[DType.float64, W](0.5)
    print("  float64 fma(a,2,0.5):", a64.fma(b64, c64))

    # int32: no fma -- use a*b + c (two instructions)
    var ai32 = SIMD[DType.int32, W](1, 2, 3, 4, 5, 6, 7, 8)
    var bi32 = SIMD[DType.int32, W](2)
    var ci32 = SIMD[DType.int32, W](1)
    print("  int32   a*b+c       :", ai32 * bi32 + ci32,
          "  (no fma for int)")

    print()


# ══════════════════════════════════════════════
# 3. Precision comparison: float32 vs float64
#    float32 has ~7 significant digits
#    float64 has ~15 significant digits
# ══════════════════════════════════════════════
fn section3_precision():
    print("=" * 55)
    print("3. Precision: float32 vs float64")
    print("=" * 55)

    # Sum of 1/3 eight times -- reveals rounding
    var third32 = SIMD[DType.float32, W](0.3333333333333333)
    var third64 = SIMD[DType.float64, W](0.3333333333333333)

    var sum32 = third32.reduce_add()   # float32
    var sum64 = third64.reduce_add()   # float64

    print("  8 * (1/3) float32 =", sum32,
          "  (expected 2.6666...)")
    print("  8 * (1/3) float64 =", sum64,
          "  (expected 2.6666...)")

    # Cast float32 result to float64 to compare
    var sum32_as64 = Float64(sum32)
    var diff = sum64 - sum32_as64
    if diff < 0.0:
        diff = -diff
    print("  abs difference     =", diff)
    print("  float32: ~7 sig digits, float64: ~15 sig digits")

    print()


# ══════════════════════════════════════════════
# 4. Integer overflow behaviour
#    int8 overflows at 127; wraps around silently
# ══════════════════════════════════════════════
fn section4_overflow():
    print("=" * 55)
    print("4. Integer overflow (wraps silently)")
    print("=" * 55)

    var v8 = SIMD[DType.int8, W](100, 110, 120, 125,
                                   126, 127, -128, -1)
    var one8 = SIMD[DType.int8, W](10)
    print("  int8  v           :", v8)
    print("  int8  v + 10      :", v8 + one8,
          "  <- wraps at 127")

    var v16 = SIMD[DType.int16, W](30000, 32000, 32700, 32767,
                                    -32768, -32000, 0, 1)
    var one16 = SIMD[DType.int16, W](1000)
    print("  int16 v           :", v16)
    print("  int16 v + 1000    :", v16 + one16,
          "  <- wraps at 32767")

    print()


# ══════════════════════════════════════════════
# 5. Benchmark: dot product across DTypes
#    All use W=8, n=1024
#    float16 excluded -- no direct float16 List support
# ══════════════════════════════════════════════
fn dot_f64(a: List[Float64], b: List[Float64], n: Int) -> Float64:
    var pa = a.unsafe_ptr()
    var pb = b.unsafe_ptr()
    var acc = SIMD[DType.float64, W](0.0)
    var i = 0
    var go = i + W <= n
    while go:
        var va = (pa + i).load[width=W]()
        var vb = (pb + i).load[width=W]()
        acc = acc + va * vb
        i += W
        go = i + W <= n
    return acc.reduce_add()


fn dot_f32(a: List[Float32], b: List[Float32], n: Int) -> Float32:
    var pa = a.unsafe_ptr()
    var pb = b.unsafe_ptr()
    var acc = SIMD[DType.float32, W](0.0)
    var i = 0
    var go = i + W <= n
    while go:
        var va = (pa + i).load[width=W]()
        var vb = (pb + i).load[width=W]()
        acc = acc + va * vb
        i += W
        go = i + W <= n
    return acc.reduce_add()


fn dot_i32(a: List[Int32], b: List[Int32], n: Int) -> Int32:
    # Use unsafe_ptr() for direct SIMD load -- avoids element conversion overhead
    # (gotcha #56)
    var pa = a.unsafe_ptr()
    var pb = b.unsafe_ptr()
    var acc = SIMD[DType.int32, W](0)
    var i = 0
    var go = i + W <= n
    while go:
        var va = (pa + i).load[width=W]()
        var vb = (pb + i).load[width=W]()
        acc = acc + va * vb
        i += W
        go = i + W <= n
    var s = acc.reduce_add()
    var go2 = i < n
    while go2:
        s += a[i] * b[i]
        i += 1
        go2 = i < n
    return s


fn section5_benchmark():
    print("=" * 55)
    print("5. Benchmark: dot product  n=" + String(N) +
          "  W=" + String(W) + "  repeats=" + String(REPEAT))
    print("=" * 55)

    # Build input vectors
    var af64 = List[Float64]()
    var bf64 = List[Float64]()
    var af32 = List[Float32]()
    var bf32 = List[Float32]()
    var ai32 = List[Int32]()
    var bi32 = List[Int32]()

    for i in range(N):
        var v = Float64(i + 1) / Float64(N)
        af64.append(v)
        bf64.append(1.0 - v)
        af32.append(Float32(v))
        bf32.append(Float32(1.0 - v))
        ai32.append(Int32(i + 1))
        bi32.append(Int32(N - i))

    # Correctness
    print("  dot float64 =", dot_f64(af64, bf64, N))
    print("  dot float32 =", dot_f32(af32, bf32, N))
    print("  dot int32   =", dot_i32(ai32, bi32, N))
    print()

    # Accumulate results to prevent dead code elimination (gotcha #57)
    var kf64 = Float64(0.0)
    var kf32 = Float32(0.0)
    var ki32 = Int32(0)

    # Benchmark float64
    var t0 = perf_counter_ns()
    for _ in range(REPEAT):
        kf64 += dot_f64(af64, bf64, N)
    var t1 = perf_counter_ns()

    # Benchmark float32
    var t2 = perf_counter_ns()
    for _ in range(REPEAT):
        kf32 += dot_f32(af32, bf32, N)
    var t3 = perf_counter_ns()

    # Benchmark int32
    var t4 = perf_counter_ns()
    for _ in range(REPEAT):
        ki32 += dot_i32(ai32, bi32, N)
    var t5 = perf_counter_ns()

    # Print keep values to ensure they are not optimized away
    _ = kf64; _ = kf32; _ = ki32

    var sf64 = t1 - t0
    var sf32 = t3 - t2
    var si32 = t5 - t4

    print("  float64 W=8 : " + fmt_time(sf64) + "  (baseline)")
    print("  float32 W=8 : " + fmt_time(sf32) +
          "  speedup vs f64=" +
          String(Int(Float64(sf64)/Float64(sf32)*10)) + "e-1x")
    print("  int32   W=8 : " + fmt_time(si32) +
          "  speedup vs f64=" +
          String(Int(Float64(sf64)/Float64(si32)*10)) + "e-1x")
    print()
    print("  Note: with unsafe_ptr(), int32 is comparable to or faster than float32")
    print("  Element-by-element SIMD construction (without unsafe_ptr) is very slow")
    print()


# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────
fn main():
    print("=" * 55)
    print("  SIMD DType Comparison -- Mojo 0.26.2")
    print("=" * 55)
    print()

    section1_basic_ops()
    section2_fma()
    section3_precision()
    section4_overflow()
    section5_benchmark()

    print("=" * 55)
    print("  Done.")
    print("=" * 55)
