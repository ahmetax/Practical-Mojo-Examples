"""
Author: Ahmet Aksoy
Date: 2026-04-05
Mojo version: 0.26.2 | Python 3.12 | Ubuntu
AI: Claude Sonnet 4.6
memory_06_null_guard.mojo -- Null Pointer Guard and Optional[T]
Topics covered:
  1. What is a null pointer and why it is dangerous
  2. Int(ptr) == 0  -- checking whether a pointer holds address 0
  3. No safe null constructor in 0.26.2 -- gotcha #62
  4. Optional[T] -- the safe alternative to null pointers
  5. Defensive guard pattern -- always check before dereferencing
  6. Practical: optional result from a search function
Key rules:
  - Dereferencing a null pointer is undefined behaviour (crash / corruption)
  - is_null() removed in 0.26.2 -- use Int(ptr) == 0 instead (gotcha #64)
  - UnsafePointer[T]() and UnsafePointer[T](unsafe_from_address=0)
    do NOT compile in 0.26.2 (gotcha #62)
  - Pointers from List.unsafe_ptr() on a non-empty List are never null
  - Use Optional[T] to express "value may be absent" safely
  - Guard pattern: if Int(ptr) == 0: handle error; else: use ptr
"""

from std.memory import UnsafePointer


# ── Helper ────────────────────────────────────────────────────────────────────

fn print_buf(label: String, p: UnsafePointer[Float32, _], n: Int):
    print(" ", label, ": [", end="")
    for i in range(n):
        if i > 0:
            print(",", end="")
        print(" ", p[i], end="")
    print(" ]")


# ── Functions using the guard pattern ─────────────────────────────────────────

fn safe_sum(ptr: UnsafePointer[Float32, _], n: Int) -> Float32:
    """
    Sum n floats via pointer.
    Returns 0.0 and prints an error if ptr is null.
    Always call is_null() before dereferencing a pointer from an
    external source or an Optional that may be absent.
    """
    if Int(ptr) == 0:
        print("  [safe_sum] ERROR: null pointer -- returning 0.0")
        return Float32(0.0)
    var acc = Float32(0.0)
    for i in range(n):
        acc += ptr[i]
    return acc


fn safe_max(ptr: UnsafePointer[Float32, _], n: Int) -> Optional[Float32]:
    """
    Find the maximum value via pointer.
    Returns None if ptr is null or n == 0, otherwise Some(max).
    Using Optional[T] as the return type avoids a sentinel magic value.
    """
    if Int(ptr) == 0 or n == 0:
        return None
    var best = ptr[0]
    for i in range(1, n):
        if ptr[i] > best:
            best = ptr[i]
    return best


# ── Search returning Optional ─────────────────────────────────────────────────

fn find_first_negative(buf: List[Float32]) -> Optional[Int]:
    """
    Return the index of the first negative element, or None if not found.
    This is the idiomatic Mojo way to express a search that may fail.
    """
    for i in range(len(buf)):
        if buf[i] < 0.0:
            return i
    return None


fn main():
    print()
    print("╔══════════════════════════════════════════════════════╗")
    print("║  memory_06 -- Null Pointer Guard and Optional[T]    ║")
    print("╚══════════════════════════════════════════════════════╝")
    print()

    # ── 1. What is a null pointer? ────────────────────────────────────────
    #
    # A null pointer holds address 0.
    # Address 0 is never a valid user-space memory location on Linux/macOS.
    # Reading or writing through a null pointer triggers a segmentation fault.
    #
    # In Mojo, null pointers arise from:
    #   a. Unintentional use of a pointer variable before assignment.
    #   b. A C library function returning NULL on failure.
    #   c. Explicit construction for sentinel use (not recommended in 0.26.2
    #      because the safe constructor does not exist -- gotcha #62).
    #
    # Pointers obtained from List.unsafe_ptr() on a non-empty List
    # are NEVER null -- the List always allocates real heap memory.

    print("── 1. What is a null pointer? ────────────────────────────")
    print("  Address 0 = never valid user-space memory on Linux.")
    print("  Dereferencing it = segmentation fault (undefined behaviour).")
    print("  Pointers from List.unsafe_ptr() on non-empty List: never null.")
    print()

    # ── 2. Int(ptr) == 0 -- checking the pointer address ─────────────────
    #
    # is_null() was removed in Mojo 0.26.2 (gotcha #64).
    # Use Int(ptr) == 0 to check for a null pointer.
    # Int(ptr) casts the pointer to its integer address -- no dereference.
    #
    # Practical use: guard every pointer that may have come from
    # an external source (C library, FFI, or an Optional that was unwrapped).

    print("── 2. Int(ptr) == 0  null check ──────────────────────────")

    var buf = List[Float32](capacity=4)
    buf.append(1.0); buf.append(2.0); buf.append(3.0); buf.append(4.0)
    var valid_ptr = buf.unsafe_ptr()

    print("  valid_ptr from non-empty List:")
    print("    Int(ptr) == 0 =", Int(valid_ptr) == 0, "  (expected False)")
    print("    address       =", Int(valid_ptr), "  (non-zero)")
    print()

    # ── 3. No safe null constructor in 0.26.2 (gotcha #62) ───────────────
    #
    # The following do NOT compile:
    #   var p = UnsafePointer[Float32]()                 # no-arg: error
    #   var p = UnsafePointer[Float32](unsafe_from_address=0)  # error
    #
    # If you genuinely need to represent "no pointer", use Optional[T]
    # or a Bool flag alongside the pointer variable.
    # Do not attempt to fabricate a null pointer through bit casting --
    # that is implementation-specific and fragile.

    print("── 3. No safe null constructor (gotcha #62) ──────────────")
    print("  UnsafePointer[T]()                     -- does not compile")
    print("  UnsafePointer[T](unsafe_from_address=0) -- does not compile")
    print("  is_null() method also removed in 0.26.2 (gotcha #64)")
    print("  → Use Int(ptr) == 0 for null check, Optional[T] for absence.")
    print()

    # ── 4. Optional[T] -- the safe alternative ────────────────────────────
    #
    # Optional[T] is Mojo's built-in "maybe" type.
    #   Optional[T](value)  -- holds a value  (Some)
    #   None                -- holds nothing  (None / absent)
    #
    # Accessing the value:
    #   opt.value()         -- returns T; panics if None (unsafe)
    #   opt.or_else(default) -- returns T or default if None (safe)
    #   if opt: ...         -- branch on presence
    #
    # Optional[T] is always the right choice when:
    #   - A function may or may not find a result
    #   - A configuration value may be unset
    #   - You would otherwise use a sentinel value (-1, NaN, etc.)

    print("── 4. Optional[T] -- safe absence representation ─────────")

    var some_val: Optional[Float32] = Float32(3.14)
    var no_val:   Optional[Float32] = None

    print("  some_val has value:", some_val.__bool__())
    print("  some_val.value()  :", some_val.value())
    print("  no_val   has value:", no_val.__bool__())
    print("  no_val.or_else(0) :", no_val.or_else(Float32(0.0)))
    print()

    # ── 5. Defensive guard pattern ────────────────────────────────────────
    #
    # Pattern for any function that receives a pointer from outside:
    #
    #   fn process(ptr: UnsafePointer[T, _], n: Int) -> Result:
    #       if Int(ptr) == 0:        # null check (is_null() removed in 0.26.2)
    #           return default_value
    #       # safe to use ptr here

    print("── 5. Defensive guard pattern ────────────────────────────")

    # valid call
    var sum1 = safe_sum(valid_ptr, 4)
    print("  safe_sum(valid_ptr, 4) =", sum1, "  (expected 10.0)")

    # safe_max with valid pointer
    var mx = safe_max(valid_ptr, 4)
    if mx:
        print("  safe_max(valid_ptr, 4) =", mx.value(), "  (expected 4.0)")
    else:
        print("  safe_max returned None")

    # safe_max with n=0 (edge case)
    var mx0 = safe_max(valid_ptr, 0)
    print("  safe_max(valid_ptr, 0) is None:", not mx0.__bool__())
    print()

    # ── 6. Practical: search returning Optional ───────────────────────────

    print("── 6. Practical: search returning Optional ───────────────")

    var data = List[Float32](capacity=6)
    data.append(3.0); data.append(1.0); data.append(-2.0)
    data.append(4.0); data.append(-1.0); data.append(5.0)

    var idx = find_first_negative(data)
    if idx:
        print("  First negative at index", idx.value(),
              "value =", data[idx.value()])
    else:
        print("  No negative element found.")

    var positive_only = List[Float32](capacity=3)
    positive_only.append(1.0); positive_only.append(2.0); positive_only.append(3.0)

    var idx2 = find_first_negative(positive_only)
    if idx2:
        print("  Found negative at", idx2.value())
    else:
        print("  No negative element in positive_only -- None returned correctly.")
    print()

    print("memory_06 complete.")
