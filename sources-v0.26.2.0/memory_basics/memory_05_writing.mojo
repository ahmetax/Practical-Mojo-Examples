"""
Author: Ahmet Aksoy
Date: 2026-04-05
Mojo version: 0.26.2 | Python 3.12 | Ubuntu
AI: Claude Sonnet 4.6
memory_05_writing.mojo -- Writing Through a Pointer
Topics covered:
  1. Pattern A -- write via List index (safest, always works)
  2. Pattern B -- .store() on a local pointer (same scope as the List)
  3. Why writing through UnsafePointer[T, _] does not compile (gotcha #58)
  4. Practical example: in-place ReLU and scale via mut List
  5. Practical example: fill pattern via local .store()
Key rules:
  - Writing through a _ -origin UnsafePointer does NOT compile (gotcha #58)
  - Pattern A (mut List index): always safe, preferred for clarity
  - Pattern B (.store() local ptr): ptr obtained in same scope as List,
    origin is known → store() compiles
  - initialize_pointee_move: only for truly uninitialised memory;
    using it on a live element is undefined behaviour (covered in memory_07)
  - Import: from std.memory import UnsafePointer
"""

from std.memory import UnsafePointer


# ── Pattern A helpers (mut List) ──────────────────────────────────────────────

fn relu(mut buf: List[Float32]):
    """In-place ReLU: buf[i] = max(0, buf[i]).  Write via List index."""
    for i in range(len(buf)):
        if buf[i] < 0.0:
            buf[i] = Float32(0.0)


fn scale(mut buf: List[Float32], factor: Float32):
    """In-place scale: buf[i] *= factor.  Write via List index."""
    for i in range(len(buf)):
        buf[i] *= factor


fn fill(mut buf: List[Float32], value: Float32):
    """Fill every element with value.  Write via List index."""
    for i in range(len(buf)):
        buf[i] = value


# ── Helpers ───────────────────────────────────────────────────────────────────

fn print_buf(label: String, p: UnsafePointer[Float32, _], n: Int):
    print(" ", label, ": [", end="")
    for i in range(n):
        if i > 0:
            print(",", end="")
        print(" ", p[i], end="")
    print(" ]")


fn main():
    print()
    print("╔══════════════════════════════════════════════════════╗")
    print("║  memory_05 -- Writing Through a Pointer             ║")
    print("╚══════════════════════════════════════════════════════╝")
    print()

    comptime N = 6

    # ── 1. Pattern A -- write via List index ──────────────────────────────
    #
    # The simplest and safest way to write to heap memory:
    # pass the List as `mut` and use buf[i] = value.
    #
    # Why this always works:
    #   The List owns the buffer. Writing through buf[i] goes through
    #   the List's subscript operator which has full mutability knowledge.
    #   No pointer origin issues arise.
    #
    # This is the RECOMMENDED pattern for all write operations.

    print("── 1. Pattern A -- write via mut List index ──────────────")

    var buf = List[Float32](capacity=N)
    for i in range(N):
        buf.append(Float32(i - 2))   # [-2, -1, 0, 1, 2, 3]
    var ptr = buf.unsafe_ptr()

    print_buf("initial        ", ptr, N)

    relu(buf)
    print_buf("after relu     ", ptr, N)   # [0, 0, 0, 1, 2, 3]

    scale(buf, Float32(2.0))
    print_buf("after scale x2 ", ptr, N)   # [0, 0, 0, 2, 4, 6]

    fill(buf, Float32(-1.0))
    print_buf("after fill(-1) ", ptr, N)   # [-1, -1, -1, -1, -1, -1]
    print()

    # ── 2. Pattern B -- .store() on a local pointer ───────────────────────
    #
    # When the pointer is obtained in the SAME scope as the List,
    # Mojo knows its origin and allows .store() on it.
    #
    # (ptr + i).store(value)  writes value to address  ptr + i.
    #
    # This is useful when you want to avoid the List subscript overhead
    # in a tight inner loop -- the generated code is a raw memory store.
    #
    # Limitation: the pointer must NOT be passed to a function as
    # UnsafePointer[T, _] before calling .store(); that would lose
    # mutability (gotcha #58).  Keep the .store() call in the same
    # scope where unsafe_ptr() was called.

    print("── 2. Pattern B -- .store() on a local pointer ───────────")

    var buf2 = List[Float32](capacity=N)
    for _ in range(N):
        buf2.append(Float32(0.0))

    var ptr2 = buf2.unsafe_ptr()    # local pointer -- origin known here

    # Write a ramp using .store()
    for i in range(N):
        (ptr2 + i).store(Float32(i * i))   # 0, 1, 4, 9, 16, 25

    print_buf("ramp via .store()", ptr2, N)

    # Verify: read back through the List (both views see the same memory)
    print("  Verify via buf2[3] =", buf2[3], "  (expected 9.0)")
    print()

    # ── 3. Why UnsafePointer[T, _] does not allow writes (gotcha #58) ────
    #
    # When a pointer is passed to a function as UnsafePointer[T, _],
    # Mojo erases the origin information.  Without origin, the compiler
    # cannot prove that writing is safe, so it disallows it.
    #
    # The following code does NOT compile -- shown here as a comment only:
    #
    #   fn bad_write(p: UnsafePointer[Float32, _], n: Int):
    #       for i in range(n):
    #           p[i] = Float32(0.0)     # ERROR: expression must be mutable
    #           (p + i).store(0.0)      # ERROR: no matching method 'store'
    #
    # Solutions:
    #   A. Pass mut List[Float32] instead  (Pattern A above)
    #   B. Keep .store() in the same scope as unsafe_ptr()  (Pattern B above)

    print("── 3. _ -origin pointer does not allow writes (gotcha #58)")
    print("  fn bad(p: UnsafePointer[Float32, _]):")
    print("      p[0] = 1.0        # compile error -- not mutable")
    print("      (p+0).store(1.0)  # compile error -- no matching store")
    print("  → Use mut List (Pattern A) or local .store() (Pattern B)")
    print()

    # ── 4. Practical: in-place operations combining read ptr + write List ──
    #
    # A common high-performance pattern:
    #   - Read via ptr[i]   (raw load, no bounds check)
    #   - Write via buf[i]  (List subscript, always mutable)
    #
    # This gives the read speed of a raw pointer while keeping
    # writes safe and clear.

    print("── 4. Practical: read via ptr, write via List ────────────")

    var data = List[Float32](capacity=N)
    for i in range(N):
        data.append(Float32(i + 1))    # [1, 2, 3, 4, 5, 6]
    var dp = data.unsafe_ptr()

    print_buf("before clip    ", dp, N)

    # Clip to [2.0, 4.0]: read raw, write via List
    var lo = Float32(2.0)
    var hi = Float32(4.0)
    for i in range(N):
        var v = dp[i]               # raw read
        if v < lo:
            data[i] = lo            # write via List
        elif v > hi:
            data[i] = hi

    print_buf("after clip[2,4]", dp, N)   # [2, 2, 3, 4, 4, 4]
    print()

    # ── 5. Practical: fill pattern via local .store() ─────────────────────
    #
    # Writing an alternating pattern (0, 1, 0, 1, ...) using .store().
    # Pattern B is natural here because both ptr and List live in main().

    print("── 5. Fill pattern via local .store() ────────────────────")

    var pat = List[Float32](capacity=N)
    for _ in range(N):
        pat.append(Float32(0.0))
    var pp = pat.unsafe_ptr()

    for i in range(N):
        (pp + i).store(Float32(i % 2))   # alternating 0.0 and 1.0

    print_buf("alternating 0/1", pp, N)
    print()

    print("memory_05 complete.")
