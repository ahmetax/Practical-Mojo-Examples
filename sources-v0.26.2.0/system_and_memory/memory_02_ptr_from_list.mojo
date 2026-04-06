"""
Author: Ahmet Aksoy
Date: 2026-04-05
Mojo version: 0.26.2 | Python 3.12 | Ubuntu
AI: Claude Sonnet 4.6
memory_02_ptr_from_list.mojo -- Obtaining a Pointer from a List
Topics covered:
  1. unsafe_ptr() -- getting a raw pointer to a List's backing buffer
  2. Pointer validity rule -- the List must outlive the pointer
  3. Reading through the pointer (safe with _ origin)
  4. What happens when the List is resized -- pointer invalidation
Key rules:
  - buf.unsafe_ptr() returns UnsafePointer[T] to the first element
  - The pointer is valid only while the List is alive AND not resized
  - List.append() may reallocate the buffer → old pointer becomes dangling
  - Always obtain the pointer AFTER all appends are done
  - Reading via ptr[i] is safe; writing requires mut List (gotcha #58)
  - Import: from std.memory import UnsafePointer
"""

from std.memory import UnsafePointer
from std.sys.info import size_of


fn main():
    print()
    print("╔══════════════════════════════════════════════════════╗")
    print("║  memory_02 -- Obtaining a Pointer from a List       ║")
    print("╚══════════════════════════════════════════════════════╝")
    print()

    # ── 1. unsafe_ptr() basics ────────────────────────────────────────────
    #
    # Every List[T] owns a heap-allocated buffer.
    # unsafe_ptr() returns the address of element [0] in that buffer.
    #
    #   List[Float32]  (size=4, capacity=4)
    #   ┌────────────────────────────┐
    #   │  1.0  │  2.0  │  3.0  │  4.0  │   ← heap buffer
    #   └────────────────────────────┘
    #     ▲
    #     ptr = buf.unsafe_ptr()
    #
    # ptr[0] == buf[0],  ptr[1] == buf[1],  ...
    # The pointer is just a number (an address) -- it carries no length info.
    # You must track the length separately (use len(buf) or a comptime N).

    print("── 1. unsafe_ptr() basics ────────────────────────────────")

    var buf = List[Float32](capacity=4)
    buf.append(1.0)
    buf.append(2.0)
    buf.append(3.0)
    buf.append(4.0)

    # Obtain the pointer AFTER all appends -- see section 4 for why
    var ptr = buf.unsafe_ptr()

    print("  buf (via List index) :", end=" ")
    for i in range(len(buf)):
        print(buf[i], end=" ")
    print()

    print("  buf (via ptr[i])     :", end=" ")
    for i in range(len(buf)):
        print(ptr[i], end=" ")
    print()

    print("  ptr[0] == buf[0]:", ptr[0] == buf[0])
    print("  size_of[Float32] =", size_of[Float32](), "bytes")
    print()

    # ── 2. Pointer validity rule ──────────────────────────────────────────
    #
    # The pointer is valid as long as TWO conditions hold:
    #   A. The owning List is still alive (not destroyed / out of scope).
    #   B. The List has not been resized since the pointer was obtained.
    #
    # Condition A -- lifetime:
    #   The List's destructor frees the heap buffer when the List goes
    #   out of scope. Any pointer into that buffer becomes dangling.
    #
    #   SAFE pattern:
    #     var buf = List[Float32](capacity=N)
    #     # ... fill buf ...
    #     var ptr = buf.unsafe_ptr()
    #     use_ptr(ptr, N)          # buf is still alive here
    #     # buf destroyed here (end of scope) -- ptr is now dangling
    #     # DO NOT use ptr after this point
    #
    #   UNSAFE pattern (do not do this):
    #     fn get_ptr() -> UnsafePointer[Float32]:
    #         var tmp = List[Float32](capacity=4)
    #         tmp.append(1.0)
    #         return tmp.unsafe_ptr()   # tmp destroyed on return!
    #         # caller receives a dangling pointer -- undefined behaviour

    print("── 2. Pointer validity rule ──────────────────────────────")
    print("  Rule A: the owning List must be alive while the pointer is used.")
    print("  Rule B: the List must not be resized after the pointer is taken.")
    print()

    # ── 3. Reading through the pointer (safe with _ origin) ───────────────
    #
    # When an UnsafePointer is passed to a function as UnsafePointer[T, _],
    # reads (ptr[i]) are always allowed.
    # Writes (ptr[i] = v  or  ptr.store()) are NOT allowed through _ origin.
    # (gotcha #58 -- use mut List for writes)

    print("── 3. Reading through a function parameter (UnsafePointer[T, _])")

    fn print_floats(p: UnsafePointer[Float32, _], n: Int):
        """Read-only access through _ origin -- always safe."""
        print("  values:", end=" ")
        for i in range(n):
            print(p[i], end=" ")
        print()

    fn sum_floats(p: UnsafePointer[Float32, _], n: Int) -> Float32:
        """Sum via raw pointer -- no bounds check, fast inner loop."""
        var acc = Float32(0.0)
        for i in range(n):
            acc += p[i]
        return acc

    print_floats(ptr, len(buf))
    print("  sum =", sum_floats(ptr, len(buf)), "  (expected 10.0)")
    print()

    # ── 4. Pointer invalidation on resize ─────────────────────────────────
    #
    # List.append() calls reserve() internally when size == capacity.
    # reserve() allocates a NEW, larger buffer and copies the data.
    # The OLD buffer is freed. Any pointer to the old buffer is now dangling.
    #
    # Safe pattern: fill the List completely BEFORE calling unsafe_ptr().
    #
    #   WRONG:
    #     var ptr = buf.unsafe_ptr()   # ptr points to old buffer
    #     buf.append(5.0)              # may reallocate! ptr is now dangling
    #     print(ptr[0])                # undefined behaviour
    #
    #   CORRECT:
    #     buf.append(5.0)              # finish all mutations first
    #     var ptr = buf.unsafe_ptr()   # then obtain the pointer
    #     print(ptr[0])                # safe

    print("── 4. Pointer invalidation on resize ─────────────────────")

    var buf2 = List[Float32](capacity=2)
    buf2.append(10.0)
    buf2.append(20.0)

    # Obtain pointer while capacity == size (no room to grow)
    var ptr2 = buf2.unsafe_ptr()
    print("  Before append: ptr2[0] =", ptr2[0], "ptr2[1] =", ptr2[1])

    # append forces a reallocation -- ptr2 now points to freed memory!
    buf2.append(30.0)

    # DO NOT read ptr2 here in production -- this is for illustration only.
    # The value may still look correct (freed memory not yet overwritten)
    # or may be garbage. This is undefined behaviour.
    print("  After append (buf2 reallocated):")
    print("  buf2[0] =", buf2[0], "buf2[1] =", buf2[1], "buf2[2] =", buf2[2])
    print("  (ptr2 is now dangling -- do not use it)")

    # Correct: re-obtain the pointer after all appends
    var ptr2_new = buf2.unsafe_ptr()
    print("  Re-obtained ptr2_new[0] =", ptr2_new[0],
          "ptr2_new[2] =", ptr2_new[2], "  (safe)")
    print()

    print("memory_02 complete.")
