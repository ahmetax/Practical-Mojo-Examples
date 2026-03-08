"""
Author: Ahmet Aksoy
Date: 2026-03-07
Revision Date: 2026-03-07
Mojo version no: 0.26.1
AI: Claude Sonnet 4.6

Description:
    Introduction to PythonObject — Mojo's explicit type for Python values.

    In Style A, Python objects are stored in implicitly typed variables:
        requests = Python.import_module("requests")

    In Style B, we declare the type explicitly as PythonObject:
        var requests: PythonObject = Python.import_module("requests")

    Style B is more verbose but has clear advantages:
      - The Mojo compiler knows the variable holds a Python object
      - Function signatures become self-documenting
      - Mojo functions (fn) can accept and return Python objects safely
      - Easier to reason about which variables are Mojo types vs Python types

    This file covers the fundamental PythonObject patterns:
      1. Declaring PythonObject variables
      2. Passing PythonObject to Mojo fn functions
      3. Converting between PythonObject and Mojo types
      4. Checking Python types from Mojo

Requirements:
    No external packages needed — uses Python standard library only.
"""

from python import Python, PythonObject


# ------------------------------------------------------------
# Pattern 1: Declaring PythonObject variables
# ------------------------------------------------------------
# With Style A, the type is implicit — Mojo infers it.
# With Style B, we declare PythonObject explicitly.
# Both work, but Style B makes the intent clear.

def style_a_vs_b() -> None:
    # Style A — implicit, shorter
    math = Python.import_module("math")
    result_a = math.sqrt(144.0)
    print("Style A result:", String(result_a))

    # Style B — explicit PythonObject declaration
    var math2: PythonObject = Python.import_module("math")
    var result_b: PythonObject = math2.sqrt(144.0)
    print("Style B result:", String(result_b))

    # Both produce the same output.
    # Style B is preferred inside fn functions (see Pattern 2).


# ------------------------------------------------------------
# Pattern 2: Passing PythonObject to Mojo fn functions
# ------------------------------------------------------------
# Regular 'def' functions accept Python objects implicitly.
# Mojo 'fn' functions require explicit types — so we use PythonObject
# in the signature to accept Python values.

fn print_list_items(py_list: PythonObject) raises -> None:
    """
    An fn function that accepts a Python list as PythonObject.
    We iterate over it and convert each item to a Mojo String.
    """
    var count = len(py_list)
    print("List has", count, "items:")
    for i in range(count):
        var item = String(py_list[i])
        print(" ", i, "->", item)


fn sum_numeric_list(py_list: PythonObject) raises -> Float64:
    """
    An fn function that accepts a Python list of numbers,
    sums them up and returns a Mojo Float64.
    This pattern is useful when you fetch data via Python
    and want to process it on the Mojo side.
    """
    var total: Float64 = 0.0
    var count = len(py_list)
    for i in range(count):
        # Direct Float64(py_list[i]) does not work — convert via String first
        total += Float64(String(py_list[i]))
    return total


def pattern_fn_with_python_object() -> None:
    var builtins: PythonObject = Python.import_module("builtins")

    # Create a Python list using builtins
    var py_list: PythonObject = builtins.list()
    py_list.append("Mojo")
    py_list.append("Python")
    py_list.append("Interop")

    print("--- Passing PythonObject to fn ---")
    print_list_items(py_list)

    # Create a numeric list for summing
    var numbers: PythonObject = builtins.list()
    numbers.append(10)
    numbers.append(25)
    numbers.append(37)
    numbers.append(48)

    var total = sum_numeric_list(numbers)
    print("Sum of numbers:", total)


# ------------------------------------------------------------
# Pattern 3: Converting between PythonObject and Mojo types
# ------------------------------------------------------------
# When you receive a PythonObject, you often need to convert it
# to a Mojo type before using it in Mojo logic.
# Common conversions:
#   String(obj)   -> Mojo String
#   Int(obj)      -> Mojo Int
#   Float64(obj)  -> Mojo Float64
#   Bool(obj)     -> Mojo Bool

def pattern_type_conversion() -> None:
    var builtins: PythonObject = Python.import_module("builtins")

    # Python int -> Mojo Int
    var py_int: PythonObject = builtins.int(42)
    var mojo_int: Int = Int(String(py_int))
    print("Python int -> Mojo Int:", mojo_int)
    print("  Doubled in Mojo     :", mojo_int * 2)

    # Python float -> Mojo Float64
    var py_float: PythonObject = builtins.float(3.14159)
    var mojo_float: Float64 = Float64(String(py_float))
    print("Python float -> Mojo Float64:", mojo_float)
    print("  Squared in Mojo          :", mojo_float * mojo_float)

    # Python string -> Mojo String
    var py_str: PythonObject = builtins.str("Hello from Python")
    var mojo_str: String = String(py_str)
    print("Python str -> Mojo String:", mojo_str)
    print("  Uppercase in Mojo      :", mojo_str.upper())

    # Mojo value -> back to PythonObject (implicit, just assign)
    var mojo_value: Int = 100
    var py_back: PythonObject = mojo_value   # Mojo auto-converts
    print("Mojo Int -> PythonObject:", String(py_back))


# ------------------------------------------------------------
# Pattern 4: Checking Python object types from Mojo
# ------------------------------------------------------------
# Sometimes a Python function can return different types
# (e.g. a value or None). We can check the type using
# Python's builtins.isinstance() or by comparing to Python.none().

fn is_none(obj: PythonObject) raises -> Bool:
    # Bool(obj == Python.none()) is unreliable — always returns True.
    # Instead, check the Python type name of the object.
    # If it is 'NoneType', the value is None.
    var builtins: PythonObject = Python.import_module("builtins")
    var type_name = String(builtins.type(obj).__name__)
    return type_name == "NoneType"


def pattern_type_checking() -> None:
    var builtins: PythonObject = Python.import_module("builtins")

    # Simulate a dict lookup that may or may not find a key
    var data: PythonObject = Python.dict()
    data["name"] = "Mojo"
    data["version"] = 1

    var keys = List[String]()
    keys.append("name")
    keys.append("version")
    keys.append("missing_key")
    print("Dict lookup with type checking:")
    for i in range(len(keys)):
        var k: String = keys[i]
        var value: PythonObject = data.get(k, Python.none())
        if is_none(value):
            print(" ", k, "-> not found")
        else:
            # Check Python type before converting
            var type_name = String(builtins.type(value).__name__)
            print(" ", k, "->", String(value), "  (Python type:", type_name + ")")


fn main() raises:
    print("=== Style A vs Style B ===")
    print()
    style_a_vs_b()

    print()
    print("=== PythonObject in fn functions ===")
    print()
    pattern_fn_with_python_object()

    print()
    print("=== Type Conversion: PythonObject <-> Mojo ===")
    print()
    pattern_type_conversion()

    print()
    print("=== Type Checking ===")
    print()
    pattern_type_checking()
