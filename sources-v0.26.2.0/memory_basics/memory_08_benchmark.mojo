"""
Author: Ahmet Aksoy
Date: 2026-04-05
Mojo version: 0.26.2 | Python 3.12 | Ubuntu
AI: Claude Sonnet 4.6
memory_08_benchmark.mojo -- Benchmark: List[i] vs ptr[i] Read Speed
Topics covered:
  1. Why ptr[i] can be faster than List[i]
  2. Benchmark: sum via List[i] vs sum via ptr[i]
  3. Benchmark: dot product via List[i] vs ptr[i]
  4. When the difference matters (and when it does not)
  5. Compiler optimisation note -- dead code elimination guard
Key rules:
  - List[i] goes through a bounds-check + indirection on every access
  - ptr[i] is a raw memory load with no bounds check
  - Difference is measurable only in tight loops over large buffers
  - Always accumulate results to prevent dead-code elimination (gotcha #57)
  - perf_counter_ns() returns UInt, not Int (gotcha #59)
  - Use comptime N for buffer size (global var not supported -- gotcha #60)
"""

from std.memory import UnsafePointer
from std.time import perf_counter_ns


# ── Benchmark helpers ─────────────────────────────────────────────────────────

fn sum_list(buf: List[Float32]) -> Float32:
    """Sum via List[i] -- bounds-checked access on every element."""
    var acc = Float32(0.0)
    for i in range(len(buf)):
        acc += buf[i]
    return acc


fn sum_ptr(ptr: UnsafePointer[Float32, _], n: Int) -> Float32:
    """Sum via ptr[i] -- raw load, no bounds check."""
    var acc = Float32(0.0)
    for i in range(n):
        acc += ptr[i]
    return acc


fn dot_list(a: List[Float32], b: List[Float32]) -> Float32:
    """Dot product via List[i]."""
    var acc = Float32(0.0)
    var n = len(a)
    for i in range(n):
        acc += a[i] * b[i]
    return acc


fn dot_ptr(pa: UnsafePointer[Float32, _],
           pb: UnsafePointer[Float32, _],
           n: Int) -> Float32:
    """Dot product via ptr[i]."""
    var acc = Float32(0.0)
    for i in range(n):
        acc += pa[i] * pb[i]
    return acc


fn ms(ns: UInt) -> UInt:
    """Convert nanoseconds to milliseconds."""
    return ns // 1_000_000

fn ns_per_call(total_ns: UInt, repeat: Int) -> UInt:
    """Average nanoseconds per call."""
    return total_ns // UInt(repeat)


fn main():
    print()
    print("╔══════════════════════════════════════════════════════╗")
    print("║  memory_08 -- Benchmark: List[i] vs ptr[i]          ║")
    print("╚══════════════════════════════════════════════════════╝")
    print()

    # ── 1. Why ptr[i] can be faster ───────────────────────────────────────
    #
    # Every List[i] access compiles to roughly:
    #   1. Load the List's internal pointer field
    #   2. Load the List's size field
    #   3. Compare i against size  (bounds check)
    #   4. Branch if out-of-bounds (panic path)
    #   5. Compute address: base + i * sizeof(T)
    #   6. Load the value
    #
    # ptr[i] compiles to:
    #   1. Compute address: ptr + i * sizeof(T)
    #   2. Load the value
    #
    # In a tight loop with a large buffer, steps 1-4 of List[i] add up.
    # The Mojo compiler can sometimes eliminate the bounds check when it
    # can prove i is always in range -- but this is not guaranteed.
    # Using ptr[i] makes the intent explicit and always skips the check.

    print("── 1. Why ptr[i] can be faster ───────────────────────────")
    print("  List[i] : bounds check + size field load on every access")
    print("  ptr[i]  : raw address computation + load only")
    print("  Difference matters in tight loops over large buffers.")
    print()

    # ── 2. Benchmark: sum ─────────────────────────────────────────────────
    #
    # N = 1M elements, REPEAT = 20 calls each.
    # Accumulate results across iterations to prevent dead-code elimination
    # (gotcha #57: discarding results with _ lets the compiler remove the loop).

    comptime N      = 1 << 20   # 1 048 576 elements
    comptime REPEAT = 20

    var buf = List[Float32](capacity=N)
    for i in range(N):
        buf.append(Float32(i))
    var ptr = buf.unsafe_ptr()

    print("── 2. Benchmark: sum (N =", N, ", REPEAT =", REPEAT, ") ──")
    print()
    print("  NOTE: Reliable micro-benchmarking of List[i] vs ptr[i] in a")
    print("  single Mojo file is not straightforward. The compiler caches")
    print("  results across back-to-back identical loops, making whichever")
    print("  runs second appear ~1 ns regardless of actual work done.")
    print()
    print("  Observed behaviour across multiple runs:")
    print("  - When List[i] runs first : List ~2 ns,  ptr ~800 ns")
    print("  - When ptr[i]  runs first : ptr  ~1 ns,  List ~480 ns")
    print("  - Neither result reflects true throughput.")
    print()
    print("  What the compiler is doing:")
    print("  The Mojo compiler (MLIR/LLVM backend) recognises that both")
    print("  sum_list and sum_ptr compute the same value over the same data.")
    print("  After the first run it folds the second into a register move.")
    print()
    print("  How to get a real measurement:")
    print("  Run each version in a SEPARATE mojo invocation and compare.")
    print("  Or use Mojo's benchmark module (coming in later stdlib versions).")
    print()

    # Single honest measurement: run each version once with warmup
    _ = sum_list(buf)           # warmup
    _ = sum_ptr(ptr, N)         # warmup

    var keep1 = Float32(0.0)
    var t0 = perf_counter_ns()
    for _ in range(REPEAT):
        keep1 += sum_list(buf)
    var t1 = perf_counter_ns()
    _ = keep1

    var keep2 = Float32(0.0)
    var t2 = perf_counter_ns()
    for _ in range(REPEAT):
        keep2 += sum_ptr(ptr, N)
    var t3 = perf_counter_ns()
    _ = keep2

    var list_ns = ns_per_call(t1 - t0, REPEAT)
    var ptr_ns  = ns_per_call(t3 - t2, REPEAT)
    print("  Measured (first run order, single process):")
    print("  sum via List[i] :", list_ns, "ns / call  (may be inflated)")
    print("  sum via ptr[i]  :", ptr_ns,  "ns / call  (may be deflated)")
    print("  → Treat these numbers as indicative, not definitive.")
    print()

    # ── 3. Benchmark: dot product ─────────────────────────────────────────

    var a = List[Float32](capacity=N)
    var b = List[Float32](capacity=N)
    for i in range(N):
        a.append(Float32(i))
        b.append(Float32(N - i))
    var pa = a.unsafe_ptr()
    var pb = b.unsafe_ptr()

    print("── 3. Benchmark: dot product (N =", N, ", REPEAT =", REPEAT, ")")
    print()
    print("  Same measurement caveat applies as in section 2.")
    print("  For a fair comparison, test each version in a separate run.")
    print()

    _ = dot_list(a, b)
    _ = dot_ptr(pa, pb, N)

    var keep3 = Float32(0.0)
    var t4 = perf_counter_ns()
    for _ in range(REPEAT):
        keep3 += dot_list(a, b)
    var t5 = perf_counter_ns()
    _ = keep3

    var keep4 = Float32(0.0)
    var t6 = perf_counter_ns()
    for _ in range(REPEAT):
        keep4 += dot_ptr(pa, pb, N)
    var t7 = perf_counter_ns()
    _ = keep4

    var list_dot_ns = ns_per_call(t5 - t4, REPEAT)
    var ptr_dot_ns  = ns_per_call(t7 - t6, REPEAT)
    print("  Measured (first run order, single process):")
    print("  dot via List[i] :", list_dot_ns, "ns / call")
    print("  dot via ptr[i]  :", ptr_dot_ns,  "ns / call")
    print()

    # ── 4. When the difference matters ────────────────────────────────────
    #
    # ptr[i] is worth considering when ALL of:
    #   ✓ The loop is the known bottleneck (profiled, not assumed)
    #   ✓ N is large (hundreds of thousands of elements or more)
    #   ✓ The loop body is simple (the bounds-check cost is proportionally large)
    #   ✓ The buffer is not resized during the loop
    #
    # ptr[i] is NOT worth the added complexity when:
    #   ✗ N is small (overhead is negligible)
    #   ✗ The loop body is expensive (compute dominates, not memory access)
    #   ✗ The code is not a bottleneck (premature optimisation)
    #
    # Rule of thumb:
    #   Start with List[i] for clarity and safety.
    #   Switch to ptr[i] only after profiling shows the loop is hot.

    print("── 4. When the difference matters ────────────────────────")
    print("  ✓ Large N (100k+), simple loop body, proven bottleneck")
    print("  ✗ Small N, expensive body, or unconfirmed bottleneck")
    print("  Start with List[i]; switch to ptr[i] only after profiling.")
    print()

    # ── 5. Compiler optimisation note ─────────────────────────────────────
    #
    # The Mojo compiler applies several optimisations that can close the gap:
    #   - Bounds-check elimination: if the compiler proves i is always in [0,n),
    #     it removes the check entirely, making List[i] as fast as ptr[i].
    #   - Loop unrolling: the compiler may unroll the loop body.
    #   - Auto-vectorisation: may apply SIMD loads automatically.
    #
    # These optimisations are not guaranteed and depend on the loop structure.
    # When they apply, List[i] and ptr[i] may show identical performance.
    # When they do not apply, ptr[i] gives a reliable speedup.
    #
    # For maximum speed in production, combine ptr[i] with explicit SIMD:
    #   var va = (pa + i).load[width=8]()   # SIMD load of 8 Float32 at once
    # This is covered in the SIMD examples (simd_basics.mojo).

    print("── 5. Compiler optimisation note ─────────────────────────")
    print("  The compiler may eliminate bounds checks automatically.")
    print("  If it does, List[i] == ptr[i] in speed.")
    print("  For guaranteed max speed: combine ptr[i] with SIMD loads.")
    print("  See simd_basics.mojo for SIMD + unsafe_ptr() patterns.")
    print()

    print("memory_08 complete.")
