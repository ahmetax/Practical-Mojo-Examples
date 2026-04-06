"""
Author: Ahmet Aksoy
Date: 2026-04-05
Mojo version: 0.26.2 | Python 3.12 | Ubuntu
AI: Claude Sonnet 4.6
memory_01_what_and_why.mojo -- UnsafePointer: What It Is and Why It Exists
Topics covered:
  1. What is UnsafePointer[T]?
  2. Why "Unsafe"? -- what protections are missing
  3. When to use UnsafePointer vs List[T]
  4. Memory layout visualised with a live example
Key rules:
  - UnsafePointer[T] is a raw address -- no bounds check, no lifetime guard
  - Mojo's borrow checker does NOT protect UnsafePointer accesses
  - Prefer List[T] for general use; reach for UnsafePointer only for
    SIMD loads, C interop, or performance-critical inner loops
  - The List that owns the buffer must outlive every pointer into it
  - Import with 'std.' prefix (implicit stdlib imports deprecated)
  - sizeof[T]() requires: from std.sys.info import sizeof  (gotcha #62)
  - Null pointer: no safe public constructor in 0.26.2 -- use Optional[T]
    UnsafePointer[T]() and UnsafePointer[T](unsafe_from_address=0) both
    fail to compile; is_null() exists but creating null is not in public API
"""

from std.memory import UnsafePointer
from std.sys.info import size_of


fn main():
    print()
    print("╔══════════════════════════════════════════════════════╗")
    print("║  memory_01 -- UnsafePointer: What and Why           ║")
    print("╚══════════════════════════════════════════════════════╝")
    print()

    # ── What is UnsafePointer[T]? ─────────────────────────────────────────
    #
    # UnsafePointer[T] holds a single integer: a memory address.
    # At that address, a value of type T is expected to live.
    #
    # It is the Mojo equivalent of a C pointer:
    #   C    : float *ptr = &arr[0];
    #   Mojo : var ptr = arr.unsafe_ptr()   # UnsafePointer[Float32]
    #
    # sizeof[T]() tells you how many bytes one T occupies.
    # The pointer always advances in steps of sizeof[T]() bytes.

    print("── sizeof demo ───────────────────────────────────────────")
    print("  sizeof[Int8]   =", size_of[Int8](),   "byte")
    print("  sizeof[Int32]  =", size_of[Int32](),  "bytes")
    print("  sizeof[Int64]  =", size_of[Int64](),  "bytes")
    print("  sizeof[Float32]=", size_of[Float32](), "bytes")
    print("  sizeof[Float64]=", size_of[Float64](), "bytes")
    print()

    # ── Why "Unsafe"? ─────────────────────────────────────────────────────
    #
    # Mojo's safe types (List, String, references) provide:
    #   ✓ Bounds checking   -- index out of range → panic, not corruption
    #   ✓ Lifetime tracking -- borrow checker prevents use-after-free
    #   ✓ Null safety       -- references are never null
    #
    # UnsafePointer provides NONE of these:
    #   ✗ ptr[999] on a 4-element buffer → silent memory corruption or crash
    #   ✗ Pointer to a freed List        → dangling pointer, undefined behaviour
    #   ✗ UnsafePointer()               → null pointer, crash on dereference
    #
    # "Unsafe" is a deliberate label -- a warning to the reader of the code.

    print("── null pointer demo ─────────────────────────────────────")
    # In Mojo 0.26.2, a null (zero-address) pointer is created with:
    #   UnsafePointer[T](to=some_var)  -- points TO an existing variable
    # There is no direct "null constructor" in the public API.
    # The safe way to represent "no pointer" is to use is_null() on a
    # pointer obtained from address 0 via bit manipulation -- but this
    # is implementation-specific and not recommended in production code.
    # Best practice: use Optional[SomeStruct] instead of null pointers.
    print("  No safe null-pointer constructor in Mojo 0.26.2 public API.")
    print("  Use Optional[T] to represent 'pointer may be absent'.")
    print("  is_null() exists but creating a null pointer intentionally")
    print("  is not part of the safe public API.")
    print()

    # ── When to use UnsafePointer ─────────────────────────────────────────
    #
    # USE IT when:
    #   ✓ Loading SIMD vectors from a List buffer   (fastest read path)
    #   ✓ Passing a raw pointer to a C extern fn    (FFI / C interop)
    #   ✓ Building a custom allocator or memory pool
    #   ✓ Inner loops where bounds-check overhead is measurable
    #
    # DO NOT USE IT when:
    #   ✗ You just need a growable array            → List[T]
    #   ✗ You need safe indexed access              → List[T]
    #   ✗ You need a slice or view                  → Span[T]  (coming in later versions)

    print("── when to use UnsafePointer ─────────────────────────────")
    print("  ✓ SIMD loads from List buffer")
    print("  ✓ C interop (extern fn expects raw pointer)")
    print("  ✓ Custom allocator / memory pool")
    print("  ✗ General container  → use List[T]")
    print("  ✗ Safe indexed reads → use List[T]")
    print()

    # ── Memory layout: live example ───────────────────────────────────────
    #
    # A List[Float32] with 5 elements looks like this in memory:
    #
    #   index :  [0]      [1]      [2]      [3]      [4]
    #   value :  1.0      2.0      3.0      4.0      5.0
    #   bytes :  4        4        4        4        4
    #            ▲
    #            │  unsafe_ptr() returns this address
    #            ptr
    #
    #   ptr[0] == 1.0      address: base + 0 * 4
    #   ptr[1] == 2.0      address: base + 1 * 4
    #   ptr[4] == 5.0      address: base + 4 * 4
    #   ptr[5] == ???      OUT OF BOUNDS -- undefined behaviour

    var buf = List[Float32](capacity=5)
    for i in range(5):
        buf.append(Float32(i + 1))   # [1.0, 2.0, 3.0, 4.0, 5.0]

    var ptr = buf.unsafe_ptr()

    print("── memory layout: live example ───────────────────────────")
    print("  List[Float32] with 5 elements:")
    print()
    print("  index │ value │ address offset (bytes)")
    print("  ──────┼───────┼──────────────────────")
    var base = Int(ptr)
    for i in range(5):
        var offset = Int(ptr + i) - base
        print("    ", i, "  │  ", ptr[i], " │ base +", offset)
    print()
    print("  sizeof[Float32] =", size_of[Float32](), "bytes  →",
          "each step = 4 bytes")
    print()
    print("  Rule: ptr[i]  ==  *(base_address + i * sizeof(T))")
    print()
    print("memory_01 complete.")
