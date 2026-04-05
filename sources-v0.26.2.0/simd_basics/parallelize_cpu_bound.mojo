"""
Author: Ahmet Aksoy
Date: 2026-04-01
Mojo version: 0.26.2 | Python 3.12 | Ubuntu
AI: Claude Sonnet 4.6

parallelize_cpu_bound.mojo -- parallelize on CPU-bound work

Demonstrates that parallelize gives real speedup when the work
is CPU-bound (heavy computation, minimal memory access).

Task: for each element i in [0, N), compute a heavy float chain:
  result[i] = sum of k iterations of:
      x = sqrt(x * 1.0000001 + 0.5) * (x - 0.3)
  This has no memory bottleneck -- all work stays in registers.

Compared with memory-bound work (simple List read/write),
CPU-bound work scales linearly with num_workers.
"""

from std.math import sqrt
from std.algorithm import parallelize
from std.time import perf_counter_ns


fn fmt_time(ns: UInt) -> String:
    if ns >= 1_000_000:
        return String(ns // 1_000_000) + "." +
               String((ns % 1_000_000) // 10_000) + " ms"
    return String(ns // 1_000) + "." +
           String((ns % 1_000) // 10) + " us"


# ──────────────────────────────────────────────
# Heavy CPU-bound computation for one element.
# Many floating-point ops, result stays in registers.
# ──────────────────────────────────────────────
fn heavy_compute(start_val: Float64, iters: Int) -> Float64:
    var x = start_val
    for _ in range(iters):
        x = sqrt(x * 1.0000001 + 0.5) * (x - 0.3)
        x = x * x - x + 1.1
        if x < 0.01:
            x = 0.01   # keep positive for sqrt
    return x


# ──────────────────────────────────────────────
# Serial: compute heavy_compute for each element
# ──────────────────────────────────────────────
fn compute_serial(
    n: Int, iters: Int,
    mut results: List[Float64]
):
    for i in range(n):
        results[i] = heavy_compute(Float64(i + 1) / Float64(n), iters)


# ──────────────────────────────────────────────
# Parallel: each task owns one output slot
# ──────────────────────────────────────────────
fn compute_parallel(
    n: Int, iters: Int, num_workers: Int,
    mut results: List[Float64]
):
    var chunk = n // num_workers

    def worker(wid: Int) capturing:
        var start = wid * chunk
        var end   = start + chunk
        if wid == num_workers - 1:
            end = n
        for i in range(start, end):
            results[i] = heavy_compute(
                Float64(i + 1) / Float64(n), iters)

    parallelize[worker](num_workers)


# ──────────────────────────────────────────────
# Verify: serial and parallel give same results
# ──────────────────────────────────────────────
fn verify(a: List[Float64], b: List[Float64], n: Int) -> Bool:
    for i in range(n):
        var diff = a[i] - b[i]
        if diff < 0.0:
            diff = -diff
        if diff > 1e-10:
            return False
    return True


fn main():
    print("=" * 55)
    print("  CPU-bound parallelize -- Mojo 0.26.2")
    print("=" * 55)

    comptime N     = 1000    # number of elements
    comptime ITERS = 50_000  # heavy iterations per element
    comptime RUNS  = 3       # benchmark repeats

    print("\n  N=" + String(N) +
          "  iters_per_element=" + String(ITERS) +
          "  runs=" + String(RUNS))
    print("  Total float ops ~ " +
          String(N * ITERS * 6 // 1_000_000) + "M per run")
    print()

    # Allocate result buffers
    var res_serial = List[Float64]()
    var res_par    = List[Float64]()
    for _ in range(N):
        res_serial.append(0.0)
        res_par.append(0.0)

    # ── Correctness check ──
    compute_serial(N, ITERS, res_serial)
    compute_parallel(N, ITERS, 4, res_par)
    print("  Correctness (serial vs parallel w=4): " +
          String(verify(res_serial, res_par, N)))
    print()

    # ── Benchmark ──
    print("  " + "-" * 45)
    print("  Method          Time        Speedup")
    print("  " + "-" * 45)

    # Serial
    var t0 = perf_counter_ns()
    for _ in range(RUNS):
        compute_serial(N, ITERS, res_serial)
    var t1 = perf_counter_ns()
    var t_serial = t1 - t0
    print("  Serial        : " + fmt_time(t_serial) + "  (baseline)")

    # Parallel w=1 (overhead baseline)
    var t2 = perf_counter_ns()
    for _ in range(RUNS):
        compute_parallel(N, ITERS, 1, res_par)
    var t3 = perf_counter_ns()
    var t1w = t3 - t2
    print("  Parallel w= 1 : " + fmt_time(t1w) +
          "  speedup=" +
          String(Int(Float64(t_serial) / Float64(t1w) * 10)) + "e-1x")

    # Parallel w=2
    var t4 = perf_counter_ns()
    for _ in range(RUNS):
        compute_parallel(N, ITERS, 2, res_par)
    var t5 = perf_counter_ns()
    var t2w = t5 - t4
    print("  Parallel w= 2 : " + fmt_time(t2w) +
          "  speedup=" +
          String(Int(Float64(t_serial) / Float64(t2w) * 10)) + "e-1x")

    # Parallel w=4
    var t6 = perf_counter_ns()
    for _ in range(RUNS):
        compute_parallel(N, ITERS, 4, res_par)
    var t7 = perf_counter_ns()
    var t4w = t7 - t6
    print("  Parallel w= 4 : " + fmt_time(t4w) +
          "  speedup=" +
          String(Int(Float64(t_serial) / Float64(t4w) * 10)) + "e-1x")

    # Parallel w=8
    var t8 = perf_counter_ns()
    for _ in range(RUNS):
        compute_parallel(N, ITERS, 8, res_par)
    var t9 = perf_counter_ns()
    var t8w = t9 - t8
    print("  Parallel w= 8 : " + fmt_time(t8w) +
          "  speedup=" +
          String(Int(Float64(t_serial) / Float64(t8w) * 10)) + "e-1x")

    # Parallel w=16
    var ta = perf_counter_ns()
    for _ in range(RUNS):
        compute_parallel(N, ITERS, 16, res_par)
    var tb = perf_counter_ns()
    var t16w = tb - ta
    print("  Parallel w=16 : " + fmt_time(t16w) +
          "  speedup=" +
          String(Int(Float64(t_serial) / Float64(t16w) * 10)) + "e-1x")

    print("  " + "-" * 45)
    print()
    print("  Expected: speedup ~ num_workers (up to CPU core count)")
    print("  Compare with memory-bound benchmark in parallelism_basics.mojo")
    print("  where parallel was SLOWER than serial.")
    print()
    print("=" * 55)
    print("  Done.")
    print("=" * 55)
