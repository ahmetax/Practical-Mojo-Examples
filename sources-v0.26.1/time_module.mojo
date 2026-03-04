"""
Author: Ahmet Aksoy
Date: 2026-02-25
Revision Date: 2026-02-28
Mojo version no: 0.26.1
"""

from time import perf_counter_ns

fn main() raises:
    
    var t0 = perf_counter_ns()
    var sum = 0
    for i in range(1000_000):
        sum += i
    print('Sum : ', sum)
    var t1 = perf_counter_ns()
    
    print("Start:", t0)
    print("End : :", t1)
    print("Difference", (t1-t0), "nanoseconds")
