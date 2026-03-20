"""
Sorting Benchmark Flask route handler.
Python sorting algorithms + subprocess call to sort_bench.mojo.
"""

import time
import json
import subprocess
import os
import random
from flask import render_template, request


# ------------------------------------------------------------------ #
# Python sorting algorithms
# ------------------------------------------------------------------ #

def py_bubble_sort(lst):
    lst = lst[:]
    n = len(lst)
    for i in range(n):
        swapped = False
        for j in range(0, n - i - 1):
            if lst[j] > lst[j + 1]:
                lst[j], lst[j + 1] = lst[j + 1], lst[j]
                swapped = True
        if not swapped:
            break
    return lst


def py_selection_sort(lst):
    lst = lst[:]
    n = len(lst)
    for i in range(n):
        min_idx = i
        for j in range(i + 1, n):
            if lst[j] < lst[min_idx]:
                min_idx = j
        lst[i], lst[min_idx] = lst[min_idx], lst[i]
    return lst


def py_insertion_sort(lst):
    lst = lst[:]
    for i in range(1, len(lst)):
        key = lst[i]
        j = i - 1
        while j >= 0 and lst[j] > key:
            lst[j + 1] = lst[j]
            j -= 1
        lst[j + 1] = key
    return lst


def py_merge_sort(lst):
    if len(lst) <= 1:
        return lst
    mid   = len(lst) // 2
    left  = py_merge_sort(lst[:mid])
    right = py_merge_sort(lst[mid:])
    result = []
    i = j = 0
    while i < len(left) and j < len(right):
        if left[i] <= right[j]:
            result.append(left[i]); i += 1
        else:
            result.append(right[j]); j += 1
    result.extend(left[i:])
    result.extend(right[j:])
    return result


def py_quick_sort(lst):
    if len(lst) <= 1:
        return lst
    pivot = lst[len(lst) // 2]
    left  = [x for x in lst if x < pivot]
    mid   = [x for x in lst if x == pivot]
    right = [x for x in lst if x > pivot]
    return py_quick_sort(left) + mid + py_quick_sort(right)


def py_heap_sort(lst):
    import heapq
    lst = lst[:]
    heapq.heapify(lst)
    return [heapq.heappop(lst) for _ in range(len(lst))]


def py_builtin_sort(lst):
    return sorted(lst)


def make_list(size, seed):
    """Same LCG as Mojo side for identical input."""
    lst = []
    x = seed
    for _ in range(size):
        x = (x * 1664525 + 1013904223) & 0x7FFFFFFF
        lst.append(x % (size * 10))
    return lst


def run_python_benchmarks(size, seed):
    """Run all Python sort algorithms on identical input, return ns timings."""
    original = make_list(size, seed)
    results  = {}

    algos = {
        'bubble'   : py_bubble_sort,
        'selection': py_selection_sort,
        'insertion': py_insertion_sort,
        'merge'    : py_merge_sort,
        'quick'    : py_quick_sort,
        'heap'     : py_heap_sort,
        'builtin'  : py_builtin_sort,
    }

    # Skip O(n²) algos for large lists to avoid timeout
    skip_quadratic = size > 10000

    for key, fn in algos.items():
        if skip_quadratic and key in ('bubble', 'selection', 'insertion'):
            results[key] = None   # too slow
            continue
        t = time.perf_counter_ns()
        fn(original)
        results[key] = time.perf_counter_ns() - t

    return results


def run_mojo_benchmarks(size, seed):
    """Run sort_bench.mojo via subprocess, parse JSON output."""
    script = os.path.join(os.path.dirname(__file__), 'sort_bench.mojo')
    try:
        result = subprocess.run(
            ['mojo', script, str(size), str(seed)],
            capture_output=True, text=True, timeout=300
        )
        for line in result.stdout.strip().splitlines():
            line = line.strip()
            if line.startswith('{'):
                return json.loads(line)
        raise ValueError(
            f'No JSON in output:\n{result.stdout}\n{result.stderr}'
        )
    except Exception as e:
        raise RuntimeError(f'Mojo benchmark failed: {e}')


# ------------------------------------------------------------------ #
# Routes
# ------------------------------------------------------------------ #

ALGO_NAMES = {
    'bubble'   : 'Bubble Sort',
    'selection': 'Selection Sort',
    'insertion': 'Insertion Sort',
    'merge'    : 'Merge Sort',
    'quick'    : 'Quick Sort',
    'heap'     : 'Heap Sort',
    'builtin'  : 'Built-in Sort',
}

ALGO_COMPLEXITY = {
    'bubble'   : 'O(n²)',
    'selection': 'O(n²)',
    'insertion': 'O(n²)',
    'merge'    : 'O(n log n)',
    'quick'    : 'O(n log n)',
    'heap'     : 'O(n log n)',
    'builtin'  : 'O(n log n)',
}


def setup_routes(app):

    @app.route('/')
    def index():
        return render_template('index.html', results=None, params={})

    @app.route('/run', methods=['POST'])
    def run_benchmark():
        size = int(request.form.get('size', 5000))
        seed = int(request.form.get('seed', 42))
        size = max(100, min(size, 100000))

        params = {'size': size, 'seed': seed}

        # Python benchmarks
        py_res = run_python_benchmarks(size, seed)

        # Mojo benchmarks via subprocess
        try:
            mojo_res = run_mojo_benchmarks(size, seed)
        except RuntimeError as e:
            return render_template('index.html',
                results=None, params=params, error=str(e))

        # Build comparison rows
        results = []
        for key in ALGO_NAMES:
            py_ns   = py_res.get(key)
            mojo_ns = int(mojo_res.get(key, 0))

            if py_ns is None:
                speedup = None
            else:
                speedup = round(py_ns / mojo_ns, 2) if mojo_ns > 0 else 0

            results.append({
                'key'       : key,
                'name'      : ALGO_NAMES[key],
                'complexity': ALGO_COMPLEXITY[key],
                'mojo_ns'   : mojo_ns,
                'python_ns' : py_ns,
                'speedup'   : speedup,
                'skipped'   : py_ns is None,
            })

        # Sort by mojo_ns for ranking
        ranked = sorted(results, key=lambda r: r['mojo_ns'])
        for i, r in enumerate(ranked):
            r['rank'] = i + 1

        # Chart data — exclude skipped
        chart_results = [r for r in results if not r['skipped']]
        labels        = [r['name']      for r in chart_results]
        mojo_times    = [r['mojo_ns']   for r in chart_results]
        python_times  = [r['python_ns'] for r in chart_results]
        speedups      = [r['speedup']   for r in chart_results]

        # Average speedup (exclude None)
        valid_speedups = [r['speedup'] for r in results
                          if r['speedup'] is not None]
        avg_speedup = round(sum(valid_speedups) / len(valid_speedups), 2) \
                      if valid_speedups else 0

        return render_template('index.html',
            results      = results,
            ranked       = ranked,
            params       = params,
            labels       = labels,
            mojo_times   = mojo_times,
            python_times = python_times,
            speedups     = speedups,
            avg_speedup  = avg_speedup,
        )
