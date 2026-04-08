"""
Author: Ahmet Aksoy
Date: 2026-04-05
Mojo version: 0.26.2 | Python 3.12 | Ubuntu
AI: Claude Sonnet 4.6
memory_04_memset_memcpy.mojo -- memset and memcpy
Topics covered:
  1. memset  -- filling a memory region with a byte value
  2. memset pitfall -- byte fill vs element fill (Float32 example)
  3. memcpy  -- copying a memory region element by element
  4. memcpy independence -- modifying source does not affect destination
  5. Practical pattern: zero-initialise then fill selectively
Key rules:
  - memset(ptr, byte_value, count): fills 'count' ELEMENTS with byte_value
    byte_value repeats into every byte of every element
    → memset(ptr, 0, n)   zeroes all elements  (safe for any numeric T)
    → memset(ptr, 1, n)   does NOT give 1.0 in Float32 -- fills 0x01010101
  - memcpy(dest=dst, src=src, count=n): keyword arguments required in 0.26.2
    dst and src must not overlap (use manual copy for overlapping regions)
  - Both functions work on UnsafePointer[T] obtained via List.unsafe_ptr()
  - Import: from std.memory import memset, memcpy
"""

from std.memory import UnsafePointer, memset, memcpy


fn print_buf(label: String, p: UnsafePointer[Float32, _], n: Int):
    """Helper: print a float buffer with a label."""
    print(" ", label, ": [", end="")
    for i in range(n):
        if i > 0:
            print(",", end="")
        print(" ", p[i], end="")
    print(" ]")


fn main():
    print()
    print("╔══════════════════════════════════════════════════════╗")
    print("║  memory_04 -- memset and memcpy                     ║")
    print("╚══════════════════════════════════════════════════════╝")
    print()

    comptime N = 6

    # ── 1. memset -- filling with a byte value ────────────────────────────
    #
    # memset(ptr, byte_value, count)
    #   ptr        : UnsafePointer[T] -- start of the region
    #   byte_value : Int              -- value written to EVERY BYTE (0..255)
    #   count      : Int              -- number of ELEMENTS (not bytes) to fill
    #
    # Memory diagram for memset(ptr, 0, 3) on Float32:
    #
    #   Each Float32 = 4 bytes
    #   Before: [ ?? ?? ?? ?? | ?? ?? ?? ?? | ?? ?? ?? ?? ]
    #   After:  [ 00 00 00 00 | 00 00 00 00 | 00 00 00 00 ]
    #            └── 0.0 ───┘  └── 0.0 ───┘  └── 0.0 ───┘

    print("── 1. memset with byte value 0 (zero initialisation) ────")

    var buf = List[Float32](capacity=N)
    for _ in range(N):
        buf.append(Float32(99.0))    # sentinel: pre-fill with 99.0
    var ptr = buf.unsafe_ptr()

    print_buf("before memset", ptr, N)
    memset(ptr, 0, N)                # positional form -- works for memset
    print_buf("after  memset(0)", ptr, N)
    print()

    # ── 2. memset pitfall -- byte 1 is NOT element 1.0 ───────────────────
    #
    # memset writes the SAME BYTE VALUE into every byte of every element.
    # For Float32 (4 bytes), memset(ptr, 1, n) writes 0x01 into all 4 bytes:
    #   binary: 0 01111111 00000010000000100000010  (IEEE 754)
    #           ≈ 2.3694e-38   (a very small positive float, not 1.0)
    #
    # The only byte value that reliably gives a useful numeric result is 0:
    #   memset(ptr, 0, n) → 0.0   for any float or integer type
    #
    # For any other initialisation value, fill element by element:
    #   for i in range(n): buf[i] = desired_value

    print("── 2. memset pitfall -- byte 1 ≠ element 1.0 ────────────")

    var buf2 = List[Float32](capacity=N)
    for _ in range(N):
        buf2.append(Float32(0.0))
    var ptr2 = buf2.unsafe_ptr()

    memset(ptr2, 1, N)    # fills every byte with 0x01
    print_buf("memset(ptr, 1, N) -- NOT 1.0!", ptr2, N)
    print("  Expected 1.0 but got:", ptr2[0], "  (0x01010101 interpreted as Float32)")
    print()

    # Correct way to initialise with 1.0:
    for i in range(N):
        buf2[i] = Float32(1.0)
    print_buf("correct init to 1.0 (element loop)", ptr2, N)
    print()

    # ── 3. memcpy -- copying elements ─────────────────────────────────────
    #
    # memcpy(dst, src, count)
    #   dst   : destination UnsafePointer[T]
    #   src   : source UnsafePointer[T]
    #   count : number of ELEMENTS to copy
    #
    # memcpy copies  count * size_of[T]()  bytes from src to dst.
    # It is equivalent to:
    #   for i in range(count): dst[i] = src[i]
    # but implemented as a single optimised bulk memory operation.
    #
    # WARNING: dst and src must NOT overlap.
    #          For overlapping regions, copy element by element manually.

    print("── 3. memcpy -- bulk element copy ────────────────────────")

    # Source buffer: [10, 20, 30, 40, 50, 60]
    var src = List[Float32](capacity=N)
    for i in range(N):
        src.append(Float32((i + 1) * 10))
    var src_ptr = src.unsafe_ptr()

    # Destination buffer: pre-filled with zeros
    var dst = List[Float32](capacity=N)
    for _ in range(N):
        dst.append(Float32(0.0))
    var dst_ptr = dst.unsafe_ptr()

    print_buf("src before copy", src_ptr, N)
    print_buf("dst before copy", dst_ptr, N)

    memcpy(dest=dst_ptr, src=src_ptr, count=N)   # keyword args required in 0.26.2

    print_buf("dst after  memcpy", dst_ptr, N)
    print()

    # ── 4. memcpy independence -- src and dst are separate ────────────────
    #
    # memcpy creates an independent copy.
    # Modifying the source after the copy does not affect the destination,
    # and vice versa.  This is a DEEP COPY of the raw bytes.
    #
    # Note: for types that contain pointers (e.g. String, List inside a struct),
    # memcpy copies the pointer value, not the pointed-to data -- shallow copy.
    # For plain numeric types (Int, Float32, Float64 etc.) memcpy is a true
    # deep copy because there are no inner pointers.

    print("── 4. memcpy independence ─────────────────────────────────")

    src[0] = Float32(-1.0)           # modify source after copy
    print_buf("src after  src[0]=-1", src_ptr, N)
    print_buf("dst unchanged        ", dst_ptr, N)
    print("  dst[0] still =", dst_ptr[0], "  (copy is independent)")
    print()

    # ── 5. Practical pattern: zero-init then fill selectively ─────────────
    #
    # A common pattern in numerical code:
    #   1. Zero the whole buffer with memset.
    #   2. Write only the non-zero elements explicitly.
    # This is faster than initialising every element individually when
    # most elements are 0 (sparse initialisation).

    print("── 5. Practical pattern: zero-init then fill selectively ─")

    var sparse = List[Float32](capacity=N)
    for _ in range(N):
        sparse.append(Float32(99.0))    # garbage sentinel
    var sp = sparse.unsafe_ptr()

    # Step 1: zero the whole buffer
    memset(sp, 0, N)
    print_buf("after memset(0)     ", sp, N)

    # Step 2: set only the non-zero positions
    sparse[1] = Float32(3.14)
    sparse[4] = Float32(2.71)
    print_buf("after selective fill", sp, N)
    print()

    print("memory_04 complete.")
