"""
Author: Ahmet Aksoy
Date: 2026-04-01
Mojo version: 0.26.2 | Python 3.12 | Ubuntu
AI: Claude Sonnet 4.6

parallelism_basics.mojo -- Parallelism with parallelize in Mojo

Topics covered:
  1. parallelize basics: def task(i: Int) capturing
  2. parallelize with num_workers
  3. Parallel data processing -- fill array in parallel
  4. Parallel reduction -- sum computed in parallel chunks
  5. Race condition demo -- why shared mutable state is dangerous
  6. Safe parallel pattern -- each worker owns its output slot
  7. Benchmark: serial vs parallel for CPU-bound work

Key rules:
  - Task function must be: def name(i: Int) capturing
  - 'capturing' keyword is mandatory (gotcha #59)
  - parallelize[task](n)             -- auto num_workers
  - parallelize[task](n, num_workers) -- explicit num_workers
  - Each call to task gets a unique index i in [0, n)
  - Tasks may run in any order -- do not assume ordering
  - Shared mutable state requires careful design (no atomic in 0.26.2)
"""

from std.algorithm import parallelize
from std.time import perf_counter_ns


fn fmt_time(ns: UInt) -> String:
    if ns >= 1_000_000:
        return String(ns // 1_000_000) + "." +
               String((ns % 1_000_000) // 10_000) + " ms"
    return String(ns // 1_000) + "." +
           String((ns % 1_000) // 10) + " us"


# ══════════════════════════════════════════════
# 1. parallelize basics
#    def task(i: Int) capturing  -- mandatory syntax
#    i ranges over [0, n)
#    Tasks may execute in any order
# ══════════════════════════════════════════════
fn section1_basics():
    print("=" * 55)
    print("1. parallelize basics")
    print("=" * 55)

    var n = 6

    def task(i: Int) capturing:
        print("  task " + String(i) + " of " + String(n))

    print("  Launching " + String(n) + " tasks (order may vary):")
    parallelize[task](n)
    print("  All tasks done.")
    print()


# ══════════════════════════════════════════════
# 2. parallelize with explicit num_workers
#    Second argument controls thread pool size
# ══════════════════════════════════════════════
fn section2_num_workers():
    print("=" * 55)
    print("2. parallelize with num_workers")
    print("=" * 55)

    var n = 8

    print("  n=8, num_workers=2:")
    def task2(i: Int) capturing:
        print("    task " + String(i))
    parallelize[task2](n, 2)

    print("  n=8, num_workers=4:")
    def task4(i: Int) capturing:
        print("    task " + String(i))
    parallelize[task4](n, 4)

    print()


# ══════════════════════════════════════════════
# 3. Parallel array fill
#    Each task writes to its own slot -- safe, no race condition
#    Pattern: result[i] = f(i)
# ══════════════════════════════════════════════
fn section3_parallel_fill():
    print("=" * 55)
    print("3. Parallel array fill: result[i] = i * i")
    print("=" * 55)

    comptime N = 16
    var result = List[Int]()
    for _ in range(N):
        result.append(0)

    # Each task owns exactly one slot -- no conflict
    def fill(i: Int) capturing:
        result[i] = i * i

    parallelize[fill](N)

    print("  result =", end="")
    var line = " ["
    for i in range(N):
        line += String(result[i]) + " "
    print(line + "]")
    print()


# ══════════════════════════════════════════════
# 4. Parallel reduction via chunking
#    Split work into chunks, each task computes a partial sum,
#    then main thread combines partial sums.
#    Safe: each task writes to its own partial_sums[i] slot.
# ══════════════════════════════════════════════
fn section4_parallel_reduction():
    print("=" * 55)
    print("4. Parallel reduction: sum of 0..N-1 in chunks")
    print("=" * 55)

    comptime N           = 1024
    comptime NUM_WORKERS = 8
    comptime CHUNK       = N // NUM_WORKERS   # 128 each

    # Each worker accumulates into its own slot
    var partial = List[Int]()
    for _ in range(NUM_WORKERS):
        partial.append(0)

    def compute_chunk(worker_id: Int) capturing:
        var start = worker_id * CHUNK
        var end   = start + CHUNK
        var s     = 0
        for j in range(start, end):
            s += j
        partial[worker_id] = s

    parallelize[compute_chunk](NUM_WORKERS)

    # Combine on main thread
    var total = 0
    for i in range(NUM_WORKERS):
        total += partial[i]

    var expected = N * (N - 1) // 2   # sum of 0..N-1
    print("  N=" + String(N) + "  workers=" + String(NUM_WORKERS))
    print("  parallel sum = " + String(total))
    print("  expected     = " + String(expected))
    print("  correct      = " + String(total == expected))
    print()


# ══════════════════════════════════════════════
# 5. Race condition demo
#    WRONG: multiple tasks write to the same variable
#    Result is non-deterministic and usually incorrect
# ══════════════════════════════════════════════
fn section5_race_condition():
    print("=" * 55)
    print("5. Race condition demo (shared counter -- UNSAFE)")
    print("=" * 55)

    var N = 100_000
    var counter = 0   # shared -- dangerous!

    def increment(i: Int) capturing:
        counter += 1

    parallelize[increment](N)

    print("  Expected: " + String(N))
    print("  Got     : " + String(counter))
    if counter < N:
        print("  -> Race condition confirmed: lost " +
              String(N - counter) + " increments")
    else:
        print("  -> No loss observed this run (try larger N)")
    print("  Fix: use partial sums pattern (see section 4)")
    print()


# ══════════════════════════════════════════════
# 6. Safe parallel pattern: per-worker output
#    CPU-bound work: compute sum of squares in range
# ══════════════════════════════════════════════
fn sum_of_squares_serial(data: List[Int]) -> Int:
    """Sum of squares of list elements -- List prevents compile-time folding."""
    var s = 0
    for i in range(len(data)):
        s += data[i] * data[i]
    return s


fn sum_of_squares_parallel(data: List[Int], num_workers: Int) -> Int:
    var n = len(data)
    var partial = List[Int]()
    for _ in range(num_workers):
        partial.append(0)

    var chunk = n // num_workers

    def worker(wid: Int) capturing:
        var start = wid * chunk
        var end   = start + chunk
        if wid == num_workers - 1:
            end = n
        var s = 0
        for i in range(start, end):
            s += data[i] * data[i]
        partial[wid] = s

    parallelize[worker](num_workers)

    var total = 0
    for i in range(num_workers):
        total += partial[i]
    return total


fn section6_safe_pattern():
    print("=" * 55)
    print("6. Safe parallel pattern: per-worker output slots")
    print("=" * 55)

    comptime N = 100_000
    var data = List[Int]()
    for i in range(N):
        data.append(i)

    var serial    = sum_of_squares_serial(data)
    var parallel2 = sum_of_squares_parallel(data, 2)
    var parallel4 = sum_of_squares_parallel(data, 4)
    var parallel8 = sum_of_squares_parallel(data, 8)

    print("  sum_of_squares(0.." + String(N) + "):")
    print("  serial       = " + String(serial))
    print("  parallel w=2 = " + String(parallel2) +
          "  match=" + String(serial == parallel2))
    print("  parallel w=4 = " + String(parallel4) +
          "  match=" + String(serial == parallel4))
    print("  parallel w=8 = " + String(parallel8) +
          "  match=" + String(serial == parallel8))
    print()


# ══════════════════════════════════════════════
# 7. Benchmark: serial vs parallel
#    CPU-bound: sum of squares over large range
# ══════════════════════════════════════════════
fn section7_benchmark():
    print("=" * 55)
    print("7. Benchmark: serial vs parallel sum of squares")
    print("=" * 55)

    comptime N = 5_000_000
    var REPEAT = 3

    # Build List -- prevents compile-time folding (gotcha #57)
    var data = List[Int]()
    for i in range(N):
        data.append(i)

    var keep_s = Int(0)
    var t0 = perf_counter_ns()
    for _ in range(REPEAT):
        keep_s += sum_of_squares_serial(data)
    var t1 = perf_counter_ns()

    var keep2 = Int(0)
    var t2 = perf_counter_ns()
    for _ in range(REPEAT):
        keep2 += sum_of_squares_parallel(data, 2)
    var t3 = perf_counter_ns()

    var keep4 = Int(0)
    var t4 = perf_counter_ns()
    for _ in range(REPEAT):
        keep4 += sum_of_squares_parallel(data, 4)
    var t5 = perf_counter_ns()

    var keep8 = Int(0)
    var t6 = perf_counter_ns()
    for _ in range(REPEAT):
        keep8 += sum_of_squares_parallel(data, 8)
    var t7 = perf_counter_ns()

    print("  Results match: " +
          String(keep_s == keep2 and keep_s == keep4 and keep_s == keep8))

    var ss = t1 - t0
    var s2 = t3 - t2
    var s4 = t5 - t4
    var s8 = t7 - t6

    print("  N=" + String(N) + "  repeats=" + String(REPEAT))
    print()
    print("  Serial       : " + fmt_time(ss))
    print("  Parallel w=2 : " + fmt_time(s2) +
          "  speedup=" + String(Int(Float64(ss)/Float64(s2)*10)) + "e-1x")
    print("  Parallel w=4 : " + fmt_time(s4) +
          "  speedup=" + String(Int(Float64(ss)/Float64(s4)*10)) + "e-1x")
    print("  Parallel w=8 : " + fmt_time(s8) +
          "  speedup=" + String(Int(Float64(ss)/Float64(s8)*10)) + "e-1x")
    print()


# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────
fn main():
    print("=" * 55)
    print("  Parallelism: parallelize -- Mojo 0.26.2")
    print("=" * 55)
    print()

    section1_basics()
    section2_num_workers()
    section3_parallel_fill()
    section4_parallel_reduction()
    section5_race_condition()
    section6_safe_pattern()
    section7_benchmark()

    print("=" * 55)
    print("  Done.")
    print("=" * 55)
