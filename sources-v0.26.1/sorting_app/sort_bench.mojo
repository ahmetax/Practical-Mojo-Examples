"""
Mojo Sorting Algorithm Benchmark — subprocess olarak çağrılır.

Kullanım:
  mojo sort_bench.mojo <list_size> <seed>

Çıktı: JSON formatında her algoritmanın süresi (ns cinsinden)

Algoritmalar:
  - Bubble Sort
  - Selection Sort
  - Insertion Sort
  - Merge Sort
  - Quick Sort
  - Heap Sort
  - Built-in Sort (referans)
"""

from python import Python, PythonObject
from time import perf_counter_ns
import sys


# ------------------------------------------------------------------ #
# List helpers
# ------------------------------------------------------------------ #

fn make_list(size: Int, seed: Int) -> List[Int]:
    """Pseudo-random list using LCG (Linear Congruential Generator)."""
    var lst = List[Int]()
    var x = seed
    for _ in range(size):
        x = (x * 1664525 + 1013904223) & 0x7FFFFFFF
        lst.append(x % (size * 10))
    return lst^


fn copy_list(src: List[Int]) -> List[Int]:
    """Return a copy of the list."""
    var dst = List[Int]()
    for i in range(len(src)):
        dst.append(src[i])
    return dst^


fn is_sorted(lst: List[Int]) -> Bool:
    """Verify the list is sorted ascending."""
    for i in range(len(lst) - 1):
        if lst[i] > lst[i + 1]:
            return False
    return True


# ------------------------------------------------------------------ #
# Sorting algorithms
# ------------------------------------------------------------------ #

fn bubble_sort(mut lst: List[Int]):
    var n = len(lst)
    for i in range(n):
        var swapped = False
        for j in range(0, n - i - 1):
            if lst[j] > lst[j + 1]:
                var tmp = lst[j]
                lst[j] = lst[j + 1]
                lst[j + 1] = tmp
                swapped = True
        if not swapped:
            break


fn selection_sort(mut lst: List[Int]):
    var n = len(lst)
    for i in range(n):
        var min_idx = i
        for j in range(i + 1, n):
            if lst[j] < lst[min_idx]:
                min_idx = j
        var tmp = lst[i]
        lst[i] = lst[min_idx]
        lst[min_idx] = tmp


fn insertion_sort(mut lst: List[Int]):
    var n = len(lst)
    for i in range(1, n):
        var key = lst[i]
        var j = i - 1
        while j >= 0 and lst[j] > key:
            lst[j + 1] = lst[j]
            j -= 1
        lst[j + 1] = key


fn merge(mut lst: List[Int], left: Int, mid: Int, right: Int):
    var left_part = List[Int]()
    var right_part = List[Int]()

    for i in range(left, mid + 1):
        left_part.append(lst[i])
    for i in range(mid + 1, right + 1):
        right_part.append(lst[i])

    var i = 0
    var j = 0
    var k = left

    while i < len(left_part) and j < len(right_part):
        if left_part[i] <= right_part[j]:
            lst[k] = left_part[i]
            i += 1
        else:
            lst[k] = right_part[j]
            j += 1
        k += 1

    while i < len(left_part):
        lst[k] = left_part[i]
        i += 1
        k += 1

    while j < len(right_part):
        lst[k] = right_part[j]
        j += 1
        k += 1


fn merge_sort(mut lst: List[Int], left: Int, right: Int):
    if left < right:
        var mid = (left + right) // 2
        merge_sort(lst, left, mid)
        merge_sort(lst, mid + 1, right)
        merge(lst, left, mid, right)


fn partition(mut lst: List[Int], low: Int, high: Int) -> Int:
    var pivot = lst[high]
    var i = low - 1
    for j in range(low, high):
        if lst[j] <= pivot:
            i += 1
            var tmp = lst[i]
            lst[i] = lst[j]
            lst[j] = tmp
    var tmp = lst[i + 1]
    lst[i + 1] = lst[high]
    lst[high] = tmp
    return i + 1


fn quick_sort(mut lst: List[Int], low: Int, high: Int):
    if low < high:
        var pi = partition(lst, low, high)
        quick_sort(lst, low, pi - 1)
        quick_sort(lst, pi + 1, high)


fn heapify(mut lst: List[Int], n: Int, i: Int):
    var largest = i
    var left    = 2 * i + 1
    var right   = 2 * i + 2

    if left < n and lst[left] > lst[largest]:
        largest = left
    if right < n and lst[right] > lst[largest]:
        largest = right

    if largest != i:
        var tmp = lst[i]
        lst[i] = lst[largest]
        lst[largest] = tmp
        heapify(lst, n, largest)


fn heap_sort(mut lst: List[Int]):
    var n = len(lst)
    for i in range(n // 2 - 1, -1, -1):
        heapify(lst, n, i)
    for i in range(n - 1, 0, -1):
        var tmp = lst[0]
        lst[0] = lst[i]
        lst[i] = tmp
        heapify(lst, i, 0)


# ------------------------------------------------------------------ #
# Main
# ------------------------------------------------------------------ #

fn main() raises:
    var argv = sys.argv()
    if len(argv) < 3:
        print('{"error": "Usage: mojo sort_bench.mojo <size> <seed>"}')
        return

    var size = Int(String(argv[1]))
    var seed = Int(String(argv[2]))

    var original = make_list(size, seed)

    # Bubble Sort
    var lst_bubble = copy_list(original)
    var t0 = perf_counter_ns()
    bubble_sort(lst_bubble)
    var bubble_ns = perf_counter_ns() - t0

    # Selection Sort
    var lst_selection = copy_list(original)
    t0 = perf_counter_ns()
    selection_sort(lst_selection)
    var selection_ns = perf_counter_ns() - t0

    # Insertion Sort
    var lst_insertion = copy_list(original)
    t0 = perf_counter_ns()
    insertion_sort(lst_insertion)
    var insertion_ns = perf_counter_ns() - t0

    # Merge Sort
    var lst_merge = copy_list(original)
    t0 = perf_counter_ns()
    merge_sort(lst_merge, 0, len(lst_merge) - 1)
    var merge_ns = perf_counter_ns() - t0

    # Quick Sort
    var lst_quick = copy_list(original)
    t0 = perf_counter_ns()
    quick_sort(lst_quick, 0, len(lst_quick) - 1)
    var quick_ns = perf_counter_ns() - t0

    # Heap Sort
    var lst_heap = copy_list(original)
    t0 = perf_counter_ns()
    heap_sort(lst_heap)
    var heap_ns = perf_counter_ns() - t0

    # Built-in Sort
    var lst_builtin = copy_list(original)
    t0 = perf_counter_ns()
    sort(lst_builtin)
    var builtin_ns = perf_counter_ns() - t0

    print(
        '{"bubble":'    + String(bubble_ns)    +
        ',"selection":' + String(selection_ns)  +
        ',"insertion":' + String(insertion_ns)  +
        ',"merge":'     + String(merge_ns)      +
        ',"quick":'     + String(quick_ns)      +
        ',"heap":'      + String(heap_ns)       +
        ',"builtin":'   + String(builtin_ns)    +
        '}'
    )
