"""
Author: Ahmet Aksoy
Date: 2026-03-31
Mojo version: 0.26.2 | Python 3.12 | Ubuntu
AI: Claude Sonnet 4.6

simd_mask.mojo -- SIMD Masks and Conditional Select

Topics covered:
  1. Bool mask creation: SIMD.eq/ne/gt/lt/ge/le
  2. select(mask, a, b) -- lane-wise conditional (numpy where equivalent)
  3. Mask arithmetic: AND, OR, NOT via cast + multiply
  4. Masked reduction: sum only lanes where mask is True
  5. Practical kernels:
       ReLU        : max(x, 0)
       Clamp       : clip(x, lo, hi)
       Absolute val: |x|
       Count > 0   : number of positive lanes
  6. Benchmark: scalar branch vs SIMD select (branchless)
"""

from std.time import perf_counter_ns


comptime W      = 8
comptime N      = 1024
comptime REPEAT = 1_000_000


fn fmt_time(ns: UInt) -> String:
    if ns >= 1_000_000:
        return String(ns // 1_000_000) + "." +
               String((ns % 1_000_000) // 10_000) + " ms"
    return String(ns // 1_000) + "." +
           String((ns % 1_000) // 10) + " us"


# ══════════════════════════════════════════════
# 1. Bool mask creation
#    Comparison methods return SIMD[DType.bool, W]
#    Each lane is independently True or False
# ══════════════════════════════════════════════
fn section1_bool_masks():
    print("=" * 55)
    print("1. Bool mask creation")
    print("=" * 55)

    var a = SIMD[DType.float32, W](-3.0, -1.0, 0.0, 1.0,
                                     2.0,  4.0, 6.0, 8.0)
    var zero = SIMD[DType.float32, W](0.0)
    var four = SIMD[DType.float32, W](4.0)

    print("  a         =", a)
    print("  a > 0     =", SIMD.gt(a, zero))
    print("  a < 0     =", SIMD.lt(a, zero))
    print("  a >= 4    =", SIMD.ge(a, four))
    print("  a == 0    =", SIMD.eq(a, zero))
    print("  a != 0    =", SIMD.ne(a, zero))

    # Mask from two vectors
    var b = SIMD[DType.float32, W](0.0, -2.0, 1.0, 1.0,
                                     1.0,  5.0, 5.0, 7.0)
    print("\n  b         =", b)
    print("  a > b     =", SIMD.gt(a, b))
    print("  a == b    =", SIMD.eq(a, b))

    print()


# ══════════════════════════════════════════════
# 2. select(mask, true_val, false_val)
#    For each lane: result = mask ? true_val : false_val
#    This is the SIMD equivalent of numpy.where()
# ══════════════════════════════════════════════
fn section2_select():
    print("=" * 55)
    print("2. select(mask, true_val, false_val)")
    print("   Equivalent to: numpy.where(mask, a, b)")
    print("=" * 55)

    var a = SIMD[DType.float32, W](-3.0, -1.0, 0.0, 1.0,
                                     2.0,  4.0, 6.0, 8.0)
    var zero = SIMD[DType.float32, W](0.0)

    # ReLU: max(x, 0) = select(x > 0, x, 0)
    var mask_pos = SIMD.gt(a, zero)
    var relu = mask_pos.select(a, zero)
    print("  a          =", a)
    print("  ReLU(a)    =", relu)

    # Replace negatives with -99
    var neg99 = SIMD[DType.float32, W](-99.0)
    var mask_neg = SIMD.lt(a, zero)
    var replaced = mask_neg.select(neg99, a)
    print("  replace <0 =", replaced)

    # Select between two different vectors
    var b = SIMD[DType.float32, W](10.0, 20.0, 30.0, 40.0,
                                     50.0, 60.0, 70.0, 80.0)
    var mask_ab = SIMD.gt(a, zero)   # pick a where a>0, else b
    var mixed = mask_ab.select(a, b)
    print("  b          =", b)
    print("  a>0? a : b =", mixed)

    print()


# ══════════════════════════════════════════════
# 3. Mask cast to numeric type
#    bool True  -> 1  (or 1.0)
#    bool False -> 0  (or 0.0)
#    Enables masked arithmetic without branching
# ══════════════════════════════════════════════
fn section3_mask_cast():
    print("=" * 55)
    print("3. Mask cast to numeric: True->1, False->0")
    print("=" * 55)

    var a = SIMD[DType.float32, W](-3.0, -1.0, 0.0, 1.0,
                                     2.0,  4.0, 6.0, 8.0)
    var zero = SIMD[DType.float32, W](0.0)
    var mask = SIMD.gt(a, zero)

    print("  mask (bool)   =", mask)

    # Cast to float32: True->1.0, False->0.0
    var mask_f32 = mask.cast[DType.float32]()
    print("  cast[float32] =", mask_f32)

    # Cast to int32: True->1, False->0
    var mask_i32 = mask.cast[DType.int32]()
    print("  cast[int32]   =", mask_i32)

    # Count positive elements: sum of cast mask
    var count = mask_i32.reduce_add()
    print("  count(a > 0)  =", count, " (expected 5: 1,2,4,6,8)")

    # Masked sum: sum only positive elements
    var masked_vals = mask_f32 * a    # zero out negatives
    var masked_sum  = masked_vals.reduce_add()
    print("  sum(a>0)      =", masked_sum, " (1+2+4+6+8 = 21.0)")

    print()


# ══════════════════════════════════════════════
# 4. Practical SIMD kernels using masks
# ══════════════════════════════════════════════
fn section4_kernels():
    print("=" * 55)
    print("4. Practical kernels: ReLU, Clamp, Abs, Count")
    print("=" * 55)

    var x = SIMD[DType.float32, W](-4.0, -2.0, -0.5, 0.0,
                                     0.5,  2.0,  5.0, 9.0)
    print("  x          =", x)

    # ReLU: max(x, 0)
    var relu = SIMD.gt(x, SIMD[DType.float32, W](0.0)).select(
        x, SIMD[DType.float32, W](0.0))
    print("  ReLU(x)    =", relu)

    # Clamp: clip(x, lo=-1, hi=3)
    var lo  = SIMD[DType.float32, W](-1.0)
    var hi  = SIMD[DType.float32, W](3.0)
    var clamp = SIMD.lt(x, lo).select(lo,
                SIMD.gt(x, hi).select(hi, x))
    print("  clamp(-1,3)=", clamp)

    # Absolute value: |x| = select(x < 0, -x, x)
    var abs_x = SIMD.lt(x, SIMD[DType.float32, W](0.0)).select(-x, x)
    print("  |x|        =", abs_x)

    # Count positive: number of lanes where x > 0
    var pos_mask = SIMD.gt(x, SIMD[DType.float32, W](0.0))
    var pos_count = pos_mask.cast[DType.int32]().reduce_add()
    print("  count(x>0) =", pos_count, " (expected 4: 0.5,2,5,9)")

    # Max via mask: max(a, b) lane-wise
    var a = SIMD[DType.float32, W](1.0, 5.0, 3.0, 7.0,
                                     2.0, 8.0, 4.0, 6.0)
    var b = SIMD[DType.float32, W](4.0, 2.0, 6.0, 1.0,
                                     9.0, 3.0, 7.0, 5.0)
    var lane_max = SIMD.gt(a, b).select(a, b)
    print("\n  a          =", a)
    print("  b          =", b)
    print("  max(a,b)   =", lane_max)

    print()


# ══════════════════════════════════════════════
# 5. Benchmark: scalar branch vs SIMD select
#    ReLU over a large array
#    Scalar: if x > 0: keep else 0
#    SIMD:   mask.select(x, zero) -- branchless
# ══════════════════════════════════════════════
fn relu_scalar(a: List[Float32], mut c: List[Float32], n: Int):
    for i in range(n):
        if a[i] > 0.0:
            c[i] = a[i]
        else:
            c[i] = 0.0


fn relu_simd[width: Int](
    a: List[Float32],
    mut c: List[Float32],
    n: Int
):
    var pa   = a.unsafe_ptr()
    var zero = SIMD[DType.float32, width](0.0)
    var i = 0
    var go = i + width <= n
    while go:
        var v   = (pa + i).load[width=width]()
        var res = SIMD.gt(v, zero).select(v, zero)
        comptime for lane in range(width):
            c[i + lane] = res[lane]
        i += width
        go = i + width <= n
    var go2 = i < n
    while go2:
        c[i] = a[i] if a[i] > 0.0 else 0.0
        i += 1
        go2 = i < n


fn section5_benchmark():
    print("=" * 55)
    print("5. Benchmark: ReLU  n=" + String(N) +
          "  repeats=" + String(REPEAT))
    print("=" * 55)

    var a = List[Float32]()
    var c = List[Float32]()
    for i in range(N):
        # Alternating positive/negative to stress branch predictor
        if i % 2 == 0:
            a.append(Float32(i + 1))
        else:
            a.append(-Float32(i + 1))
        c.append(0.0)

    var pa = a.unsafe_ptr()                  # read-only loads

    # Correctness check
    relu_scalar(a, c, N)
    print("  scalar c[0]=" + String(c[0]) +
          " c[1]=" + String(c[1]) +
          " c[2]=" + String(c[2]))
    relu_simd[W](a, c, N)
    print("  simd   c[0]=" + String(c[0]) +
          " c[1]=" + String(c[1]) +
          " c[2]=" + String(c[2]))
    print()

    # Benchmark scalar
    var keep_s = Float32(0.0)
    var t0 = perf_counter_ns()
    for _ in range(REPEAT):
        relu_scalar(a, c, N)
        keep_s += c[0]
    var t1 = perf_counter_ns()

    # Benchmark SIMD W=8
    var keep8 = Float32(0.0)
    var t2 = perf_counter_ns()
    for _ in range(REPEAT):
        relu_simd[8](a, c, N)
        keep8 += c[0]
    var t3 = perf_counter_ns()

    # Benchmark SIMD W=16
    var keep16 = Float32(0.0)
    var t4 = perf_counter_ns()
    for _ in range(REPEAT):
        relu_simd[16](a, c, N)
        keep16 += c[0]
    var t5 = perf_counter_ns()

    _ = keep_s; _ = keep8; _ = keep16; _ = pa

    var ss  = t1 - t0
    var s8  = t3 - t2
    var s16 = t5 - t4

    print("  Scalar (branch)  : " + fmt_time(ss))
    print("  SIMD W= 8 select : " + fmt_time(s8) +
          "  speedup=" + String(Int(Float64(ss)/Float64(s8)*10)) + "e-1x")
    print("  SIMD W=16 select : " + fmt_time(s16) +
          "  speedup=" + String(Int(Float64(ss)/Float64(s16)*10)) + "e-1x")
    print()
    print("  SIMD select is branchless -- no branch misprediction penalty")
    print("  Especially fast with unpredictable data (alternating +/-)")
    print()


# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────
fn main():
    print("=" * 55)
    print("  SIMD Masks + Conditional Select -- Mojo 0.26.2")
    print("=" * 55)
    print()

    section1_bool_masks()
    section2_select()
    section3_mask_cast()
    section4_kernels()
    section5_benchmark()

    print("=" * 55)
    print("  Done.")
    print("=" * 55)
