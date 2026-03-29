"""
Mojo benchmark runner — subprocess olarak çağrılır.
Parametreler komut satırından alınır, sonuçlar stdout'a JSON olarak yazılır.

Kullanım:
  mojo mojo_bench.mojo <fib_n> <prime_limit> <fact_n> <sum_n>
"""

from python import Python, PythonObject
from time import perf_counter_ns
import sys


fn mojo_fibonacci(n: Int) -> Int:
    if n <= 1:
        return n
    var a: Int = 0
    var b: Int = 1
    for _ in range(2, n + 1):
        var tmp = b
        b = a + b
        a = tmp
    return b


fn mojo_fibonacci_recursive(n: Int) -> Int:
    if n <= 1:
        return n
    return mojo_fibonacci_recursive(n - 1) + mojo_fibonacci_recursive(n - 2)


fn mojo_sieve(limit: Int) -> Int:
    var sieve = List[Bool]()
    for _ in range(limit + 1):
        sieve.append(True)
    sieve[0] = False
    if limit > 0:
        sieve[1] = False
    var i = 2
    while i * i <= limit:
        if sieve[i]:
            var j = i * i
            while j <= limit:
                sieve[j] = False
                j += i
        i += 1
    var count = 0
    for k in range(limit + 1):
        if sieve[k]:
            count += 1
    return count


fn mojo_factorial(n: Int, builtins: PythonObject) raises -> PythonObject:
    var result: PythonObject = builtins.int(1)
    for i in range(2, n + 1):
        result = result * i
    return result


fn mojo_sum(n: Int) -> Int:
    var total: Int = 0
    for i in range(1, n + 1):
        total += i
    return total


fn main() raises:
    var argv = sys.argv()
    if len(argv) < 5:
        print('{"error": "Missing arguments"}')
        return

    var fib_n       = Int(String(argv[1]))
    var prime_limit = Int(String(argv[2]))
    var fact_n      = Int(String(argv[3]))
    var sum_n       = Int(String(argv[4]))

    builtins: PythonObject = Python.import_module("builtins")

    var t0 = perf_counter_ns()
    _ = mojo_fibonacci(fib_n)
    var fib_iter_ns = perf_counter_ns() - t0

    t0 = perf_counter_ns()
    _ = mojo_fibonacci_recursive(fib_n)
    var fib_rec_ns = perf_counter_ns() - t0

    t0 = perf_counter_ns()
    _ = mojo_sieve(prime_limit)
    var sieve_ns = perf_counter_ns() - t0

    t0 = perf_counter_ns()
    _ = mojo_factorial(fact_n, builtins)
    var factorial_ns = perf_counter_ns() - t0

    t0 = perf_counter_ns()
    _ = mojo_sum(sum_n)
    var sum_ns = perf_counter_ns() - t0

    print(
        '{"fib_iter":' + String(fib_iter_ns) +
        ',"fib_rec":'  + String(fib_rec_ns)  +
        ',"sieve":'    + String(sieve_ns)     +
        ',"factorial":' + String(factorial_ns) +
        ',"sum":'      + String(sum_ns)       +
        "}"
    )
