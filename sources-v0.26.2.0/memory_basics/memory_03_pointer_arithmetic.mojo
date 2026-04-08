"""
Author: Ahmet Aksoy
Date: 2026-04-05
Mojo version: 0.26.2 | Python 3.12 | Ubuntu
AI: Claude Sonnet 4.6
memory_03_pointer_arithmetic.mojo -- Pointer Arithmetic
Topics covered:
  1. ptr + n  and  ptr - n  -- advancing and retreating a pointer
  2. (ptr + n)[]  -- dereferencing at an offset
  3. ptr[n]  -- index sugar (same as (ptr+n)[])
  4. Pointer distance -- measuring element count between two pointers
  5. Walking a pointer in a loop
  6. Practical example: dot product via raw pointer reads
Key rules:
  - Arithmetic is in units of T, not bytes:
      ptr + 1  moves  size_of[T]()  bytes forward
  - ptr[n]  ==  (ptr + n)[]  -- both forms compile and behave identically
  - Pointer distance: (Int(ptr2) - Int(ptr1)) // size_of[T]()  → elements
  - Out-of-bounds access is undefined behaviour -- no runtime check
  - fn params: UnsafePointer[T, _] for read-only (gotcha #55)
"""

from std.memory import UnsafePointer
from std.sys.info import size_of


fn dot_product(pa: UnsafePointer[Float32, _],
               pb: UnsafePointer[Float32, _],
               n: Int) -> Float32:
    """
    Dot product via raw pointer reads.
    _ origin: read-only access accepted from any source (gotcha #55).
    """
    var acc = Float32(0.0)
    for i in range(n):
        acc += pa[i] * pb[i]
    return acc


fn find_max(p: UnsafePointer[Float32, _], n: Int) -> Float32:
    """Walk the pointer to find the maximum value."""
    var cur = p          # start at element 0
    var best = cur[]     # dereference: read element 0
    for _ in range(1, n):
        cur = cur + 1    # advance one element forward
        if cur[] > best:
            best = cur[]
    return best


fn main():
    print()
    print("╔══════════════════════════════════════════════════════╗")
    print("║  memory_03 -- Pointer Arithmetic                    ║")
    print("╚══════════════════════════════════════════════════════╝")
    print()

    var buf = List[Float32](capacity=6)
    for i in range(6):
        buf.append(Float32(i * 10))   # [0, 10, 20, 30, 40, 50]
    var ptr = buf.unsafe_ptr()

    # ── 1. ptr + n  and  ptr - n ──────────────────────────────────────────
    #
    # ptr + n  does NOT add n bytes.
    # It adds  n * size_of[T]()  bytes -- one full T per step.
    #
    #   buf  :  [0]    [1]    [2]    [3]    [4]    [5]
    #           0.0   10.0   20.0   30.0   40.0   50.0
    #           ▲      ▲             ▲
    #          ptr   ptr+1         ptr+3
    #
    # (ptr + n)  returns a new UnsafePointer at the offset address.
    # It does NOT modify ptr itself.

    print("── 1. ptr + n  and  ptr - n ──────────────────────────────")
    print("  size_of[Float32] =", size_of[Float32](), "bytes per element")
    print()

    var p0 = ptr
    var p2 = ptr + 2
    var p5 = ptr + 5

    print("  ptr    points to element 0:", p0[])
    print("  ptr+2  points to element 2:", p2[])
    print("  ptr+5  points to element 5:", p5[])

    # Retreat: ptr + 5 - 3  ==  ptr + 2
    var p2_again = p5 - 3
    print("  (ptr+5) - 3  points to element 2:", p2_again[], "  (same as ptr+2)")
    print()

    # ── 2. (ptr + n)[]  -- dereference at offset ──────────────────────────
    #
    # []  (the dereference operator) reads the value at the pointer's address.
    # Combined with arithmetic:  (ptr + n)[]  reads element n.
    # This is the explicit form; ptr[n] is syntactic sugar for the same thing.

    print("── 2. (ptr + n)[]  -- dereference at offset ──────────────")
    for i in range(6):
        print("  (ptr +", i, ")[] =", (ptr + i)[], end="")
        if i < 5:
            print("   ", end="")
    print()
    print()

    # ── 3. ptr[n]  -- index sugar ─────────────────────────────────────────
    #
    # ptr[n]  is exactly equivalent to  (ptr + n)[].
    # The compiler lowers both to the same load instruction.
    # Use whichever reads more naturally for the context:
    #   ptr[i]        -- looks like array indexing (common in loops)
    #   (ptr + i)[]   -- makes the arithmetic explicit (useful for teaching)

    print("── 3. ptr[n]  vs  (ptr+n)[]  -- same result ──────────────")
    for i in range(6):
        var via_index  = ptr[i]
        var via_deref  = (ptr + i)[]
        print("  ptr[", i, "] ==", via_index,
              "  (ptr+", i, ")[] ==", via_deref,
              "  equal:", via_index == via_deref)
    print()

    # ── 4. Pointer distance ───────────────────────────────────────────────
    #
    # To count how many elements lie between two pointers:
    #   byte_distance = Int(ptr_end) - Int(ptr_start)
    #   element_count = byte_distance // size_of[T]()
    #
    # Both pointers must point into the same buffer.
    # The result is signed: ptr_end < ptr_start gives a negative count.

    print("── 4. Pointer distance ────────────────────────────────────")
    var start_ptr = ptr
    var end_ptr   = ptr + 6     # one past the last element (C-style sentinel)

    var byte_dist    = Int(end_ptr) - Int(start_ptr)
    var element_dist = byte_dist // size_of[Float32]()

    print("  start_ptr = ptr + 0")
    print("  end_ptr   = ptr + 6  (one-past-end sentinel)")
    print("  byte distance    =", byte_dist)
    print("  element distance =", element_dist, "  (= byte_dist // 4)")
    print()

    # Reverse distance
    var mid_ptr  = ptr + 3
    var rev_dist = (Int(mid_ptr) - Int(end_ptr)) // size_of[Float32]()
    print("  mid_ptr - end_ptr =", rev_dist, "elements  (negative: mid is before end)")
    print()

    # ── 5. Walking a pointer in a loop ────────────────────────────────────
    #
    # Instead of ptr[i] with a fixed base, you can advance a copy of the
    # pointer step by step.  Both approaches compile to the same machine code.
    #
    # Advancing-pointer style is common in C; index style is clearer in Mojo.
    # Use index style (ptr[i]) unless you have a specific reason not to.

    print("── 5. Walking a pointer in a loop ────────────────────────")
    print("  Advancing-pointer walk:")
    var walker = ptr              # copy -- does not modify ptr
    for i in range(6):
        print("  step", i, ": value =", walker[], end="")
        if i < 5:
            walker = walker + 1  # advance one element
            print("  →  next address offset:", Int(walker) - Int(ptr), "bytes")
        else:
            print()
    print()

    # ── 6. Practical example: dot product and find_max ────────────────────

    print("── 6. Practical example: dot product and find_max ────────")

    var a = List[Float32](capacity=5)
    var b = List[Float32](capacity=5)
    for i in range(5):
        a.append(Float32(i + 1))       # [1, 2, 3, 4, 5]
        b.append(Float32(5 - i))       # [5, 4, 3, 2, 1]

    var pa = a.unsafe_ptr()
    var pb = b.unsafe_ptr()

    var dp = dot_product(pa, pb, 5)
    # 1*5 + 2*4 + 3*3 + 4*2 + 5*1 = 5+8+9+8+5 = 35
    print("  a = [1, 2, 3, 4, 5]")
    print("  b = [5, 4, 3, 2, 1]")
    print("  dot product =", dp, "  (expected 35.0)")

    var vals = List[Float32](capacity=6)
    vals.append(3.0)
    vals.append(7.0)
    vals.append(1.0)
    vals.append(9.0)
    vals.append(2.0)
    vals.append(5.0)
    var pv = vals.unsafe_ptr()
    print("  vals = [3, 7, 1, 9, 2, 5]")
    print("  max  =", find_max(pv, 6), "  (expected 9.0)")
    print()

    print("memory_03 complete.")
