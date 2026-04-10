"""
Author: Ahmet Aksoy
Date: 2026-04-05
Mojo version: 0.26.2 | Python 3.12 | Ubuntu
AI: Claude Sonnet 4.6
memory_07_danger_zones.mojo -- Dangerous Memory Patterns (Commentary)
Topics covered:
  1. Dangling pointer -- pointer outlives its owning List
  2. Use-after-free -- reading freed memory
  3. Out-of-bounds access -- reading past the end of the buffer
  4. Pointer invalidation on List resize (recap from memory_02)
  5. Safe discipline summary -- rules to avoid all four bugs
Key rules:
  - None of the dangerous patterns are demonstrated with runnable code.
    They cause undefined behaviour: crash, silent corruption, or worse.
  - Understanding them conceptually is essential for safe UnsafePointer use.
  - Every bug in this file is prevented by one rule:
      "The owning List must be alive, unresized, and in scope
       for the entire lifetime of any pointer into its buffer."
"""

from std.memory import UnsafePointer


fn main():
    print()
    print("╔══════════════════════════════════════════════════════╗")
    print("║  memory_07 -- Dangerous Memory Patterns             ║")
    print("╚══════════════════════════════════════════════════════╝")
    print()
    print("  All patterns in this file are explained as comments only.")
    print("  Running the dangerous code would cause undefined behaviour.")
    print()

    # ── 1. Dangling pointer ───────────────────────────────────────────────
    #
    # A dangling pointer holds an address that was once valid but the
    # memory at that address has since been freed.
    #
    # How it happens with List + UnsafePointer:
    #
    #   {
    #       var tmp = List[Float32](capacity=4)
    #       tmp.append(1.0); tmp.append(2.0)
    #       var ptr = tmp.unsafe_ptr()   # ptr → tmp's buffer (heap)
    #   }  ← tmp goes out of scope HERE
    #      ← tmp's destructor runs: heap buffer is freed
    #      ← ptr still holds the old address -- DANGLING
    #
    #   print(ptr[0])   ← UB: reads freed memory
    #                      May print 1.0 (lucky), garbage, or crash.
    #
    # Why it is hard to detect:
    #   The allocator does not immediately overwrite freed memory.
    #   The old value may still be there, making the bug look like correct
    #   behaviour until some other allocation overwrites the same address.
    #
    # Prevention:
    #   Keep the owning List alive for the entire lifetime of the pointer.
    #   Never return a pointer to a local List from a function.

    print("── 1. Dangling Pointer ────────────────────────────────────")
    print("  Bug: ptr outlives the List that owns the buffer.")
    print()
    print("  WRONG (do not do this):")
    print("    fn get_ptr() -> UnsafePointer[Float32]:")
    print("        var tmp = List[Float32](capacity=4)")
    print("        tmp.append(1.0)")
    print("        return tmp.unsafe_ptr()  # tmp freed on return!")
    print("    var p = get_ptr()")
    print("    print(p[0])                  # UB: dangling pointer")
    print()
    print("  CORRECT:")
    print("    Keep the List alive in the same scope as the pointer.")
    print("    Never return a pointer to a local List.")
    print()

    # Demonstrate the SAFE version (List and pointer in same scope)
    var safe_list = List[Float32](capacity=4)
    safe_list.append(1.0); safe_list.append(2.0)
    safe_list.append(3.0); safe_list.append(4.0)
    var safe_ptr = safe_list.unsafe_ptr()
    print("  Safe version (List and ptr in same scope):")
    print("  safe_ptr[0] =", safe_ptr[0], "  safe_ptr[3] =", safe_ptr[3])
    print()

    # ── 2. Use-after-free ─────────────────────────────────────────────────
    #
    # Use-after-free is the same class of bug as dangling pointer:
    # accessing memory after the allocator has reclaimed it.
    #
    # The difference in terminology:
    #   Dangling pointer  -- the pointer was valid, the owner was destroyed.
    #   Use-after-free    -- emphasises the READ or WRITE after the free.
    #
    # Three possible outcomes (all undefined behaviour):
    #
    #   a. The memory has not been reused yet:
    #      Reads return the old value. Looks like it works. Hard to catch.
    #
    #   b. The memory has been reused by another allocation:
    #      Reads return unexpected data (silent wrong results).
    #      Writes corrupt a completely unrelated object.
    #
    #   c. The address is no longer mapped:
    #      Segmentation fault on first access. Easiest to debug.
    #
    # Outcome (a) is the most dangerous because the bug is invisible
    # until conditions change (different allocation order, different OS,
    # different build flags).

    print("── 2. Use-After-Free ──────────────────────────────────────")
    print("  Bug: reading/writing memory after the List frees it.")
    print()
    print("  Three outcomes (all UB):")
    print("  a. Old value still there  → looks correct, invisible bug")
    print("  b. Memory reused          → silent wrong results or corruption")
    print("  c. Address unmapped       → segfault (easiest to find)")
    print()
    print("  Most dangerous: outcome (a) -- passes tests, fails in prod.")
    print()

    # ── 3. Out-of-bounds access ───────────────────────────────────────────
    #
    # Accessing ptr[i] where i >= len(buf) reads memory that belongs
    # to some other object or to the allocator's internal bookkeeping.
    #
    # Unlike Python (IndexError) or Mojo List (panic), UnsafePointer
    # performs NO bounds check -- it blindly computes the address and reads.
    #
    # Memory layout around a 4-element List buffer:
    #
    #   ... [other data] [1.0][2.0][3.0][4.0] [allocator metadata] ...
    #                     ▲                     ▲
    #                    ptr[0]               ptr[4]  ← OOB read
    #
    # ptr[4] reads the allocator's metadata as if it were a Float32.
    # Writing to ptr[4] corrupts the allocator → future malloc may crash.
    #
    # Prevention:
    #   Always pass the buffer length alongside the pointer.
    #   Use comptime constants (comptime N = ...) where possible.
    #   Never assume the length from context -- make it explicit.

    print("── 3. Out-of-Bounds Access ────────────────────────────────")
    print("  Bug: ptr[i] where i >= len(buf).")
    print()
    print("  No bounds check -- reads/writes arbitrary memory.")
    print("  Writing OOB can corrupt allocator metadata → future crash.")
    print()
    print("  Prevention: always pass length alongside the pointer.")

    # Safe demonstration: bounds check done manually
    var oob_buf = List[Float32](capacity=4)
    for i in range(4):
        oob_buf.append(Float32(i + 1))
    var oob_ptr = oob_buf.unsafe_ptr()
    var n = len(oob_buf)

    print()
    print("  Safe manual bounds check:")
    var query_idx = 5
    if query_idx < n:
        print("  ptr[", query_idx, "] =", oob_ptr[query_idx])
    else:
        print("  Index", query_idx, "is out of bounds (n =", n, ") -- access skipped.")
    print()

    # ── 4. Pointer invalidation on resize (recap) ─────────────────────────
    #
    # Covered in depth in memory_02, section 4.
    # Brief recap:
    #
    #   var ptr = buf.unsafe_ptr()   # ptr → old buffer
    #   buf.append(x)                # may reallocate → old buffer freed
    #   print(ptr[0])                # UB: ptr may now be dangling
    #
    # The List doubles its capacity when full.
    # After reallocation, the old buffer address is freed.
    # Any pointer obtained before the append is now dangling.
    #
    # Prevention:
    #   Finish ALL append / resize operations before calling unsafe_ptr().

    print("── 4. Pointer Invalidation on Resize (recap) ─────────────")
    print("  Bug: append() may reallocate the buffer.")
    print("  Any pointer taken before the append becomes dangling.")
    print()
    print("  WRONG:  var ptr = buf.unsafe_ptr(); buf.append(x)")
    print("  CORRECT: buf.append(x); var ptr = buf.unsafe_ptr()")
    print()

    # ── 5. Safe discipline summary ────────────────────────────────────────
    #
    # All four bugs are prevented by following three simple rules:
    #
    #   Rule 1 -- Lifetime:
    #     The owning List must be alive for the entire lifetime of the pointer.
    #     Never return a pointer to a local variable.
    #
    #   Rule 2 -- No resize after ptr:
    #     Call unsafe_ptr() only AFTER all append / reserve / resize operations.
    #     If you must append, re-obtain the pointer afterwards.
    #
    #   Rule 3 -- Bounds:
    #     Always track the buffer length separately.
    #     Never access ptr[i] without verifying i < n.

    print("── 5. Safe Discipline Summary ─────────────────────────────")
    print()
    print("  Rule 1 (Lifetime)  : List must outlive every pointer into it.")
    print("                       Never return ptr to a local List.")
    print()
    print("  Rule 2 (No resize) : Call unsafe_ptr() AFTER all appends.")
    print("                       Re-obtain ptr if the List grows later.")
    print()
    print("  Rule 3 (Bounds)    : Track length separately.")
    print("                       Verify i < n before every ptr[i].")
    print()
    print("  Following all three rules makes UnsafePointer safe in practice.")
    print()
    print("memory_07 complete.")
