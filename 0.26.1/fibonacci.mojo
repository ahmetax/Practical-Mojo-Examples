"""
Author: Ahmet Aksoy
Date: 2026-02-25
Revision Date: 2026-02-27
Mojo version no: 0.26.1
"""

from time import perf_counter_ns
fn fib(n: Int) raises -> Int:
    if n < 2:
        return n
    return fib(n - 1) + fib(n - 2)

fn main() raises:
    var t0: UInt = perf_counter_ns()
    t2 = t0
    for i in range(41):
        t1 = perf_counter_ns()
        if i < 26:
            print("{} : {} ({} ns)".format(i, fib(i), t1 - t2))
        else:
            print(i, " : ", fib(i), "(", (t1 - t2) // 1_000_000, "ms )")
        t2 = t1

