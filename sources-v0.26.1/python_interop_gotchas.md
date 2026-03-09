# Python Interop Gotchas in Mojo

Common pitfalls when using Python modules and objects in Mojo.
Tested on Mojo version 0.26.1, Ubuntu, Python 3.12.

Each entry includes the problem, the error message you will see,
and the correct solution with a working code example.

---

## 1. Passing tuples to Python functions

**Problem:**
Mojo tuples cannot be passed directly to Python functions as arguments.

**Error:**
```
invalid call to '__call__': value passed to 'kwargs' cannot be converted
from 'Tuple[String, String]' to 'PythonObject'
```

**Wrong:**
```mojo
response = requests.get(url, auth=(username, password))
```

**Correct:**
```mojo
# Build the tuple on the Python side using Python.evaluate()
var auth = Python.evaluate("lambda u, p: (u, p)")(username, password)
response = requests.get(url, auth=auth)
```

The same pattern applies to any Python function that expects a tuple argument,
for example timeouts:
```mojo
# (connect_timeout, read_timeout) as a Python tuple
var timeout = Python.evaluate("lambda c, r: (c, r)")(3, 10)
response = requests.get(url, timeout=timeout)
```

---

## 2. Catching exceptions with a named variable

**Problem:**
Mojo does not yet support `except Exception as e` syntax.
You cannot inspect the exception type or message at runtime.

**Error:**
```
invalid syntax
```

**Wrong:**
```mojo
except Exception as e:
    print(String(e))
```

**Correct:**
```mojo
except:
    print("An error occurred.")
```

If distinguishing between error types is important, consider wrapping
the call in a Python helper function and returning an error code or
message string instead.

---

## 3. Using bytes() built-in

**Problem:**
`bytes()` is not available as a built-in in Mojo.

**Error:**
```
use of unknown declaration 'bytes'
```

**Wrong:**
```mojo
f.write(bytes(chunk))
```

**Correct:**
```mojo
# Import Python's builtins module and use bytes() from there
builtins = Python.import_module("builtins")
f.write(builtins.bytes(chunk))
```

Or simply pass the Python object directly if it is already bytes:
```mojo
f.write(chunk)   # chunk from iter_content() is already a Python bytes object
```

---

## 4. Writing binary files

**Problem:**
Mojo's built-in `open()` does not support binary write mode (`"wb"`).

**Error:**
```
invalid call to 'open': argument #2 cannot be converted from 'StringLiteral' to ...
```

**Wrong:**
```mojo
var f = open(save_path, "wb")
f.write(chunk)
```

**Correct:**
```mojo
# Use Python's built-in open() for binary file operations
builtins = Python.import_module("builtins")
var f    = builtins.open(save_path, "wb")
f.write(chunk)
f.close()
```

---

## 5. Python's None value

**Problem:**
`None` is not defined in Mojo. `Python.None` (as an attribute) does not exist.
Python's `None` must be accessed via `Python.none()` (a method call).

**Error:**
```
use of unknown declaration 'None'           # for bare None
Python has no attribute 'None'              # for Python.None
```

**Wrong:**
```mojo
result = some_dict.get("key", None)
if result != Python.None:
    ...
```

**Correct:**
```mojo
result = some_dict.get("key", Python.none())
if result != Python.none():
    ...
```

---

## 6. Using Python.dict() vs Mojo Dict

**Problem:**
Mojo's `Dict` and Python's `dict` are different types and are not
directly interchangeable. Python functions expect `PythonObject` (Python dict),
not Mojo's `Dict[K, V]`.

**Wrong:**
```mojo
from collections import Dict
var params = Dict[String, String]()
params["key"] = "value"
requests.get(url, params=params)   # params is a Mojo Dict, not a PythonObject
```

**Correct:**
```mojo
# Use Python.dict() to create a Python-native dict
params = Python.dict()
params["key"] = "value"
requests.get(url, params=params)
```

When you need to pass computed data from a Mojo `Dict` to a Python function,
convert it first:
```mojo
py_dict = Python.dict()
for item in mojo_dict.items():
    py_dict[item.key] = item.value
```

---

## 7. Calling Python lambdas with Python.evaluate()

**Problem:**
Some Python constructs (lambdas, comprehensions, multi-line expressions)
cannot be expressed inline in Mojo. `Python.evaluate()` lets you create
a Python callable and call it from Mojo.

**Pattern:**
```mojo
# Create a Python lambda and call it immediately with Mojo arguments
var result = Python.evaluate("lambda a, b: (a, b)")(arg1, arg2)

# Or store the callable for repeated use
var get_score = Python.evaluate("lambda scores: lambda k: scores[k]")
summary = nlargest(n, keys, key=get_score(scores))
```

This is particularly useful for:
- Building tuples (see #1)
- Passing key functions to Python's `sorted()`, `max()`, `nlargest()` etc.
- Any Python expression that has no direct Mojo equivalent

---

---

## 8. Converting PythonObject to numeric Mojo types

**Problem:**
`Int(py_obj)` and `Float64(py_obj)` do not work directly with PythonObject.

**Error:**
```
no matching function in initialization
```

**Wrong:**
```mojo
var x: Int     = Int(py_obj)
var y: Float64 = Float64(py_obj)
```

**Correct:**
```mojo
# Convert via String as an intermediate step
var x: Int     = Int(String(py_obj))
var y: Float64 = Float64(String(py_obj))
```

---

## 9. Comparing PythonObject to None

**Problem:**
`Bool(obj == Python.none())` is unreliable — it returns `True` even when
the object is not None.

**Wrong:**
```mojo
if Bool(obj == Python.none()):
    print("is none")
```

**Correct:**
```mojo
# Check the Python type name instead
var builtins: PythonObject = Python.import_module("builtins")
var type_name = String(builtins.type(obj).__name__)
if type_name == "NoneType":
    print("is none")
```

---

## 10. Iterating over a Mojo List and passing elements to Python

**Problem:**
`for item in list:` yields a `Reference` in Mojo, not the value itself.
Using `item[]` to dereference does not work for `String` — it is interpreted
as `__getitem__` (index access) instead.

**Error:**
```
no matching method in call to '__getitem__'
```

**Wrong:**
```mojo
for key in keys:
    data.get(key[], Python.none())   # key[] fails for String
```

**Correct:**
```mojo
# Use index-based iteration to get a clean String value
for i in range(len(keys)):
    var k: String = keys[i]
    data.get(k, Python.none())
```

---

## 11. Initializing List[T] with values

**Problem:**
`List[T]` constructor does not accept initial values as positional arguments.

**Error:**
```
no matching function in initialization
```

**Wrong:**
```mojo
var keys = List[String]("name", "version", "missing_key")
```

**Correct:**
```mojo
var keys = List[String]()
keys.append("name")
keys.append("version")
keys.append("missing_key")
```

---

## 12. String.format() alignment specifiers are not supported

**Problem:**
Mojo's `String.format()` does not support alignment specifiers like `{:<16}` or `{:>10}`.

**Error:**
```
constraint failed: Index :<16 not in kwargs
```

**Wrong:**
```mojo
print("{:<16} {:>10}".format("Product", "Total"))
```

**Correct:**
```mojo
# Print columns side-by-side with plain print()
print("Product          Total")

# Or use Python's built-in format() via builtins
builtins = Python.import_module("builtins")
print(builtins.format("Product", "<16"), builtins.format("Total", ">10"))
```

---

## 13. Int(String(...)) does not accept decimal number strings

**Problem:**
Libraries like Pandas may return integer values as decimal strings (e.g. `"5.0"`).
`Int(String(...))` cannot parse these — it expects a plain integer string.

**Error:**
```
String is not convertible to integer with base 10: '5.0'
```

**Wrong:**
```mojo
var count: Int = Int(String(py_obj))   # fails if py_obj is "5.0"
```

**Correct:**
```mojo
# Convert to Float64 first, then to Int
var count: Int = Int(Float64(String(py_obj)))
```

---

---

## 14. NumPy multi-dimensional slicing is not supported in Mojo

**Problem:**
NumPy's multi-dimensional slice syntax (`arr[:, :, 0]`, `arr[0:10, 0:10, 2]`)
causes a `__getitem__` error in Mojo. Mojo cannot pass Python slice objects
with multiple dimensions directly.

**Error:**
```
no matching method in call to '__getitem__'
```

**Wrong:**
```mojo
var channel = array[:, :, 0]          # fails
array[20:120, 20:120, 0] = 220        # fails
```

**Correct:**
```mojo
# Move slice operations into a Python helper module (helpers.py)
# and call them via Python.import_module()

# In helpers.py:
# def get_channel(arr, ch):
#     return arr[:, :, ch].astype(np.float32)

var helpers: PythonObject = Python.import_module("helpers")
var channel = helpers.get_channel(array, 0)
```

This pattern applies to any NumPy operation that requires multi-dimensional
indexing, boolean masking, or fancy indexing.

---

## 15. Python.evaluate() does not accept multi-line strings

**Problem:**
`Python.evaluate()` only accepts single-line Python expressions.
Multi-line function definitions inside `Python.evaluate()` cause a syntax error.

**Error:**
```
invalid syntax (<string>, line 2)
```

**Wrong:**
```mojo
Python.evaluate("""
def my_func(arr):
    import numpy as np
    arr[:, :, 2] = 0
""")(img_array)
```

**Correct:**
```mojo
# Place the function in a separate .py file and import it
# my_helpers.py:
#   def my_func(arr):
#       arr[:, :, 2] = 0

var helpers: PythonObject = Python.import_module("my_helpers")
helpers.my_func(img_array)
```

---

## 16. 'import sys' refers to Mojo's sys, not Python's

**Problem:**
Mojo has its own `sys` module. Writing `import sys` imports Mojo's module,
not Python's. Accessing `sys.path` then fails because Mojo's `sys`
does not have a `path` attribute.

**Error:**
```
use of unknown declaration 'path'
```

**Wrong:**
```mojo
import sys
sys.path.insert(0, ".")   # refers to Mojo's sys, not Python's
```

**Correct:**
```mojo
# Import Python's sys explicitly via Python.import_module()
var sys: PythonObject = Python.import_module("sys")
sys.path.insert(0, ".")
```

This applies to any Python standard library module that shares a name
with a Mojo built-in module (e.g. `sys`, `math`).

---

## 17. Docstrings must end with a period

**Problem:**
Mojo enforces a style rule that docstring summary lines must end with a period.
This triggers a lint warning if omitted.

**Warning:**
```
doc string summary should end with a period '.', but this ends with '<last_word>'
```

**Wrong:**
```mojo
fn load_image(path: String) raises -> PythonObject:
    """Load an image and return it as a NumPy array"""
```

**Correct:**
```mojo
fn load_image(path: String) raises -> PythonObject:
    """Load an image and return it as a NumPy array."""
```

Applies to both single-line and multi-line docstrings — the closing line
before the `"""` must end with `.`.

---

## Summary Table

| Pitfall | Wrong | Correct |
|---|---|---|
| Tuple argument | `func(arg=(a, b))` | `var t = Python.evaluate("lambda a,b: (a,b)")(a,b)` |
| Exception handling | `except Exception as e:` | `except:` |
| bytes() built-in | `bytes(obj)` | `Python.import_module("builtins").bytes(obj)` |
| Binary file write | `open(path, "wb")` | `Python.import_module("builtins").open(path, "wb")` |
| Python None value | `None` or `Python.None` | `Python.none()` |
| Dict for Python API | `Dict[String, String]()` | `Python.dict()` |
| Lambda / key functions | *(not possible inline)* | `Python.evaluate("lambda ...")` |
| Numeric conversion | `Int(py_obj)` | `Int(String(py_obj))` |
| None comparison | `Bool(obj == Python.none())` | `String(builtins.type(obj).__name__) == "NoneType"` |
| List iteration | `for item in list: item[]` | `for i in range(len(list)): list[i]` |
| List initialization | `List[String]("a", "b")` | `list.append("a"); list.append("b")` |
| String alignment | `"{:<16}".format(val)` | `Python.import_module("builtins").format(val, "<16")` |
| Decimal int string | `Int(String("5.0"))` | `Int(Float64(String(py_obj)))` |
| NumPy slicing | `arr[:, :, 0]` | helper `.py` modülüne taşı |
| Multi-line evaluate | `Python.evaluate("""...""")` | helper `.py` modülüne taşı |
| Mojo sys vs Python sys | `import sys` | `Python.import_module("sys")` |
| Docstring period | `"""Load image"""` | `"""Load image."""` |
