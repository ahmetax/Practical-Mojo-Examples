"""
Author: Ahmet Aksoy
Date: 2026-03-30
Mojo version: 0.26.2 | Python 3.12 | Ubuntu
AI: Claude Sonnet 4.6

simd_unsafe_pointer.mojo -- UnsafePointer with SIMD load/store

Topics covered:
  1. UnsafePointer(to=x)    -- pointer to an existing variable
  2. List.unsafe_ptr()      -- zero-copy pointer to List's internal buffer
  3. ptr.load[width=W]()    -- load W elements as a SIMD vector
  4. ptr.store(simd_vec)    -- store a SIMD vector to pointer
  5. Pointer arithmetic: ptr + offset
  6. Benchmark: List indexing vs UnsafePointer + SIMD load

API notes (Mojo 0.26.2):
  - UnsafePointer.alloc()  does NOT exist -- use List as buffer (gotcha #54)
  - UnsafePointer(to=x)    takes a reference to an existing variable
  - List.unsafe_ptr()      gives direct access to the List's heap buffer
  - Pointer arithmetic and SIMD load/store work correctly
  - perf_counter_ns() returns UInt (gotcha #52)
"""

from std.memory import UnsafePointer
from std.time import perf_counter_ns


comptime REPEAT = 1_000_000
comptime BN     = 512


fn fmt_time(ns: UInt) -> String:
    """Format nanoseconds as ms if >= 1ms, else as us."""
    if ns >= 1_000_000:
        var ms_int = ns // 1_000_000
        var ms_dec = (ns % 1_000_000) // 10_000
        return String(ms_int) + "." + String(ms_dec) + " ms"
    else:
        var us_int = ns // 1_000
        var us_dec = (ns % 1_000) // 10
        return String(us_int) + "." + String(us_dec) + " us"


# ══════════════════════════════════════════════
# 1. UnsafePointer(to=x) -- pointer to a variable
#    Shares memory with the original variable.
#    Write through pointer -> original changes too.
# ══════════════════════════════════════════════
fn section1_ptr_to_var():
    print("=" * 55)
    print("1. UnsafePointer(to=x) -- pointer to a variable")
    print("=" * 55)

    var x = Float32(3.14)
    var p = UnsafePointer(to=x)

    print("  x =", x)
    print("  p[0] =", p[0], "  (same memory as x)")

    # Write through pointer -- modifies x
    p[0] = 99.0
    print("  after p[0] = 99.0:")
    print("  x =", x, "  (x changed via pointer)")

    # Works with any scalar type
    var n = Int(42)
    var pn = UnsafePointer(to=n)
    pn[0] = 100
    print("  Int via pointer: n =", n)

    print()


# ══════════════════════════════════════════════
# 2. List.unsafe_ptr() -- zero-copy buffer access
#    Returns a pointer to the List's internal heap buffer.
#    No allocation, no copy -- direct access.
#    Warning: pointer is invalidated if List is resized.
# ══════════════════════════════════════════════
fn section2_list_ptr():
    print("=" * 55)
    print("2. List.unsafe_ptr() -- zero-copy buffer pointer")
    print("=" * 55)

    var data = List[Float32]()
    for i in range(8):
        data.append(Float32(i + 1))

    var p = data.unsafe_ptr()

    # Read via pointer
    print("  data[0..3] via ptr:", p[0], p[1], p[2], p[3])

    # Write via pointer -- modifies the List
    p[0] = 99.0
    print("  after p[0]=99: data[0] =", data[0],
          "  (List and pointer share memory)")

    # Restore
    p[0] = 1.0

    print()


# ══════════════════════════════════════════════
# 3. SIMD load from pointer
#    ptr.load[width=W]() reads W consecutive elements
#    from the pointer address -- single instruction.
# ══════════════════════════════════════════════
fn section3_simd_load():
    print("=" * 55)
    print("3. ptr.load[width=W]() -- SIMD load from pointer")
    print("=" * 55)

    var data = List[Float32]()
    for i in range(16):
        data.append(Float32(i + 1))

    var p = data.unsafe_ptr()

    # Load first 4 elements as SIMD vector
    var v4 = p.load[width=4]()
    print("  load[width=4] offset=0:", v4)

    # Load next 4 with pointer offset
    var v4b = (p + 4).load[width=4]()
    print("  load[width=4] offset=4:", v4b)

    # Load 8 at once
    var v8 = p.load[width=8]()
    print("  load[width=8] offset=0:", v8)
    print("  reduce_add:", v8.reduce_add(), " (expected 36.0)")

    # Arithmetic on loaded vectors
    print("  v4 + v4b =", v4 + v4b)

    print()


# ══════════════════════════════════════════════
# 4. SIMD store to pointer
#    ptr.store(simd_vec) writes W elements
#    to the pointer address -- single instruction.
# ══════════════════════════════════════════════
fn section4_simd_store():
    print("=" * 55)
    print("4. ptr.store(simd_vec) -- SIMD store to pointer")
    print("=" * 55)

    # Use a List as the backing buffer
    var buf = List[Float32]()
    for _ in range(16):
        buf.append(0.0)

    var p = buf.unsafe_ptr()

    # Build two SIMD vectors and store them
    var va = SIMD[DType.float32, 8](1.0, 2.0, 3.0, 4.0,
                                     5.0, 6.0, 7.0, 8.0)
    var vb = SIMD[DType.float32, 8](9.0, 10.0, 11.0, 12.0,
                                     13.0, 14.0, 15.0, 16.0)

    p.store(va)            # write lanes 0-7
    (p + 8).store(vb)      # write lanes 8-15

    # Read back via SIMD load
    var ra = p.load[width=8]()
    var rb = (p + 8).load[width=8]()
    print("  stored va:", ra)
    print("  stored vb:", rb)
    print("  total sum:", (ra + rb).reduce_add(), " (expected 136.0)")

    print()


# ══════════════════════════════════════════════
# 5. Pointer arithmetic
#    ptr + n  moves the pointer n elements forward
#    (not n bytes -- element-aware)
# ══════════════════════════════════════════════
fn section5_ptr_arithmetic():
    print("=" * 55)
    print("5. Pointer arithmetic: ptr + offset")
    print("=" * 55)

    var data = List[Float32]()
    for i in range(16):
        data.append(Float32(i * 10))

    var p = data.unsafe_ptr()

    print("  p[0]     =", p[0],      "  (element 0)")
    print("  (p+4)[0] =", (p+4)[0],  "  (element 4)")
    print("  (p+8)[0] =", (p+8)[0],  "  (element 8)")
    print("  (p+12)[0]=", (p+12)[0], "  (element 12)")

    # Walk through with SIMD chunks of 4
    print("  Walking 16 elements in 4-wide SIMD chunks:")
    var offset = 0
    var go = offset < 16
    while go:
        var v = (p + offset).load[width=4]()
        print("    offset=" + String(offset) + ":", v)
        offset += 4
        go = offset < 16

    print()


# ══════════════════════════════════════════════
# 6. Benchmark: List indexing vs pointer + SIMD
#    dot product: sum(a[i] * b[i])
# ══════════════════════════════════════════════
fn dot_list(a: List[Float32], b: List[Float32], n: Int) -> Float32:
    var s = Float32(0.0)
    for i in range(n):
        s += a[i] * b[i]
    return s


fn dot_ptr[W: Int](
    pa: UnsafePointer[Float32, _],
    pb: UnsafePointer[Float32, _],
    n: Int
) -> Float32:
    var acc = SIMD[DType.float32, W](0.0)
    var i = 0
    var go = i + W <= n
    while go:
        acc = acc + (pa + i).load[width=W]() * (pb + i).load[width=W]()
        i += W
        go = i + W <= n
    var s = acc.reduce_add()
    var go2 = i < n
    while go2:
        s += pa[i] * pb[i]
        i += 1
        go2 = i < n
    return s


fn section6_benchmark():
    print("=" * 55)
    print("6. Benchmark: List scalar vs Pointer + SIMD")
    print("   dot product  n=" + String(BN) +
          "  repeats=" + String(REPEAT))
    print("=" * 55)

    var la = List[Float32]()
    var lb = List[Float32]()
    for i in range(BN):
        la.append(Float32(i + 1) / Float32(BN))
        lb.append(Float32(BN - i) / Float32(BN))

    var pa = la.unsafe_ptr()
    var pb = lb.unsafe_ptr()

    # Correctness check
    var r0 = dot_list(la, lb, BN)
    var r4 = dot_ptr[4](pa, pb, BN)
    var r8 = dot_ptr[8](pa, pb, BN)
    var r16= dot_ptr[16](pa, pb, BN)
    print("  dot_list      =", r0)
    print("  dot_ptr W= 4  =", r4)
    print("  dot_ptr W= 8  =", r8)
    print("  dot_ptr W=16  =", r16)
    print()

    # Benchmarks
    var t0 = perf_counter_ns()
    for _ in range(REPEAT):
        _ = dot_list(la, lb, BN)
    var t1 = perf_counter_ns()

    var t2 = perf_counter_ns()
    for _ in range(REPEAT):
        _ = dot_ptr[4](pa, pb, BN)
    var t3 = perf_counter_ns()

    var t4 = perf_counter_ns()
    for _ in range(REPEAT):
        _ = dot_ptr[8](pa, pb, BN)
    var t5 = perf_counter_ns()

    var t6 = perf_counter_ns()
    for _ in range(REPEAT):
        _ = dot_ptr[16](pa, pb, BN)
    var t7 = perf_counter_ns()

    var s0  = t1 - t0
    var s4  = t3 - t2
    var s8  = t5 - t4
    var s16 = t7 - t6

    print("  List scalar      : " + fmt_time(s0))
    print("  Ptr+SIMD W= 4    : " + fmt_time(s4)  +
          "  speedup=" + String(Int(Float64(s0)/Float64(s4) *10)) + "e-1x")
    print("  Ptr+SIMD W= 8    : " + fmt_time(s8)  +
          "  speedup=" + String(Int(Float64(s0)/Float64(s8) *10)) + "e-1x")
    print("  Ptr+SIMD W=16    : " + fmt_time(s16) +
          "  speedup=" + String(Int(Float64(s0)/Float64(s16)*10)) + "e-1x")
    print()


# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────
fn main():
    print("=" * 55)
    print("  UnsafePointer + SIMD -- Mojo 0.26.2")
    print("=" * 55)
    print()

    section1_ptr_to_var()
    section2_list_ptr()
    section3_simd_load()
    section4_simd_store()
    section5_ptr_arithmetic()
    section6_benchmark()

    print("=" * 55)
    print("  Done.")
    print("=" * 55)
