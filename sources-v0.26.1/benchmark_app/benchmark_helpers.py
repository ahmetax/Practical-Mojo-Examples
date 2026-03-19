"""
Benchmark App Flask route handler and Python benchmark helper.
Mojo benchmarks run via subprocess (mojo mojo_bench.mojo).
"""

import time
import json
import subprocess
import os
from flask import render_template, request


# ------------------------------------------------------------------ #
# Python benchmark functions
# ------------------------------------------------------------------ #

def py_fibonacci(n):
    if n <= 1:
        return n
    a, b = 0, 1
    for _ in range(2, n + 1):
        a, b = b, a + b
    return b


def py_fibonacci_recursive(n):
    if n <= 1:
        return n
    return py_fibonacci_recursive(n - 1) + py_fibonacci_recursive(n - 2)


def py_sieve(limit):
    sieve = bytearray([1]) * (limit + 1)
    sieve[0] = sieve[1] = 0
    for i in range(2, int(limit**0.5) + 1):
        if sieve[i]:
            sieve[i*i::i] = bytearray(len(sieve[i*i::i]))
    return sum(sieve)


def py_factorial_loop(n):
    result = 1
    for i in range(2, n + 1):
        result *= i
    return result


def py_sum_loop(n):
    total = 0
    for i in range(1, n + 1):
        total += i
    return total


def run_python_benchmarks(fib_n, prime_limit, fact_n, sum_n):
    results = {}

    t = time.perf_counter_ns()
    py_fibonacci(fib_n)
    results['fib_iter'] = time.perf_counter_ns() - t

    t = time.perf_counter_ns()
    py_fibonacci_recursive(fib_n)
    results['fib_rec'] = time.perf_counter_ns() - t

    t = time.perf_counter_ns()
    py_sieve(prime_limit)
    results['sieve'] = time.perf_counter_ns() - t

    t = time.perf_counter_ns()
    py_factorial_loop(fact_n)
    results['factorial'] = time.perf_counter_ns() - t

    t = time.perf_counter_ns()
    py_sum_loop(sum_n)
    results['sum'] = time.perf_counter_ns() - t

    return results


def run_mojo_benchmarks(fib_n, prime_limit, fact_n, sum_n):
    """Run mojo_bench.mojo as subprocess, parse JSON output."""
    script = os.path.join(os.path.dirname(__file__), 'mojo_bench.mojo')
    try:
        result = subprocess.run(
            ['mojo', script,
             str(fib_n), str(prime_limit), str(fact_n), str(sum_n)],
            capture_output=True, text=True, timeout=120
        )
        # Find the JSON line in stdout
        for line in result.stdout.strip().splitlines():
            line = line.strip()
            if line.startswith('{'):
                return json.loads(line)
        raise ValueError(f'No JSON in output:\n{result.stdout}\n{result.stderr}')
    except Exception as e:
        raise RuntimeError(f'Mojo benchmark failed: {e}')


# ------------------------------------------------------------------ #
# Routes
# ------------------------------------------------------------------ #

def setup_routes(app):

    @app.route('/')
    def index():
        return render_template('index.html', results=None, params={})

    @app.route('/run', methods=['POST'])
    def run_benchmark():
        fib_n       = int(request.form.get('fib_n',       35))
        prime_limit = int(request.form.get('prime_limit', 1000000))
        fact_n      = int(request.form.get('fact_n',      10000))
        sum_n       = int(request.form.get('sum_n',       10000000))

        params = {
            'fib_n'      : fib_n,
            'prime_limit': prime_limit,
            'fact_n'     : fact_n,
            'sum_n'      : sum_n,
        }

        # Run Python benchmarks
        py_res = run_python_benchmarks(fib_n, prime_limit, fact_n, sum_n)

        # Run Mojo benchmarks via subprocess
        try:
            mojo_res = run_mojo_benchmarks(fib_n, prime_limit, fact_n, sum_n)
        except RuntimeError as e:
            return render_template('index.html',
                results=None, params=params, error=str(e))

        # Build comparison
        test_map = {
            'fib_iter' : f'Fibonacci Iterative (n={fib_n})',
            'fib_rec'  : f'Fibonacci Recursive (n={fib_n})',
            'sieve'    : f'Sieve of Eratosthenes (n={prime_limit:,})',
            'factorial': f'Factorial (n={fact_n:,})',
            'sum'      : f'Sum 1..{sum_n:,}',
        }

        results = []
        for key, name in test_map.items():
            py_ns   = py_res[key]
            mojo_ns = int(mojo_res[key])
            speedup = round(py_ns / mojo_ns, 2) if mojo_ns > 0 else 0
            bar_pct = min(100, int((speedup / 20) * 100))
            results.append({
                'key'      : key,
                'name'     : name,
                'python_ns': py_ns,
                'mojo_ns'  : mojo_ns,
                'speedup'  : speedup,
                'bar_pct'  : bar_pct,
            })

        labels       = [r['name']      for r in results]
        mojo_times   = [r['mojo_ns']   for r in results]
        python_times = [r['python_ns'] for r in results]
        speedups     = [r['speedup']   for r in results]
        avg_speedup  = round(sum(speedups) / len(speedups), 2)

        return render_template('index.html',
            results      = results,
            params       = params,
            labels       = labels,
            mojo_times   = mojo_times,
            python_times = python_times,
            speedups     = speedups,
            avg_speedup  = avg_speedup,
        )
