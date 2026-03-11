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

---

## 18. Functions may not have multiple `out` arguments

**Problem:**
Mojo 0.26.1 allows at most one `out` argument per function.
Using multiple `out` arguments to return several values causes a compile error.

**Error:**
```
function may not have multiple 'out' arguments
```

**Wrong:**
```mojo
fn init_snake(
    out body_x: List[Int], out body_y: List[Int],
    out dir: Int, out dx: Int, out dy: Int,
    out score: Int, out alive: Bool
):
    ...
```

**Correct:**
```mojo
# Store all mutable state in a single Python dict and pass it by reference.
# Python dicts are reference types — mutations inside the function
# are visible to the caller without any return value.

fn init_snake(s: PythonObject) raises:
    s["body_x"] = ...
    s["dir"]    = DIR_RIGHT
    s["score"]  = 0
    ...

# Create the dict once and pass it everywhere:
var s: PythonObject = Python.dict()
init_snake(s)
move_snake(s)
render(canvas, s)
```

---

## 19. `alias` is deprecated — use `comptime` for global constants

**Problem:**
`alias` is deprecated in Mojo 0.26.1 and triggers a warning.
`comptime var` causes an `invalid comptime declaration` error.
Global `var` is not supported at module level.

**Warning / Error:**
```
'alias' is deprecated, use 'comptime' instead
invalid comptime declaration: expected an identifier or '_'   # for comptime var
```

**Wrong:**
```mojo
alias  GRID_W = 30          # deprecated warning
comptime var GRID_W = 30    # compile error
var GRID_W = 30             # not allowed at module level
```

**Correct:**
```mojo
# Global integer constants: use comptime without var
comptime GRID_W = 30
comptime GRID_H = 25

# Runtime variables that are not truly constant:
# define them inside the function where they are used
fn run_game() raises:
    var cell   = 20
    var grid_w = 30
    ...
```

---

## 20. Python list creation with `Python.evaluate("list")([...])`  fails

**Problem:**
Calling `Python.evaluate("list")` returns the Python `list` type, but passing
a Mojo list literal to it as an argument causes a type inference error.

**Error:**
```
invalid call to '__call__': could not infer type of parameter pack 'args'
given value with unresolved type
```

**Wrong:**
```mojo
s["body_x"] = Python.evaluate("list")([cx, cx - 1, cx - 2])
```

**Correct:**
```mojo
# Build the Python list by appending elements one by one
builtins: PythonObject = Python.import_module("builtins")
var bx: PythonObject = builtins.list()
bx.append(cx)
bx.append(cx - 1)
bx.append(cx - 2)
s["body_x"] = bx
```

---

---

## 21. `str()` is not defined in Mojo — use `String()`

**Problem:**
Python's `str()` built-in does not exist in Mojo.
Using it to convert a value to string causes a compile error.

**Error:**
```
use of unknown declaration 'str'
```

**Wrong:**
```mojo
var s = str(some_value)
if guessed[i] == str(ch):
```

**Correct:**
```mojo
var s = String(some_value)
if guessed[i] == String(ch):
```

---

## 22. Iterating over a String — use `codepoint_slices()`

**Problem:**
Iterating directly over a `String` with `for ch in my_string:` is deprecated
in Mojo 0.26.1.

**Warning:**
```
Use `str.codepoints()` or `str.codepoint_slices()` instead.
```

**Wrong:**
```mojo
for ch in word:
    if ch == "a":
        ...
```

**Correct:**
```mojo
for ch in word.codepoint_slices():
    if String(ch) == "a":
        ...
```

Use `codepoint_slices()` when you need to compare or convert the character
to a `String`. Use `codepoints()` when you need the integer codepoint value.

---

## 23. Functions cannot return tuple types

**Problem:**
Mojo does not support tuple return types such as `-> (Int, Int)`.
Attempting to use them causes an initialization error.

**Error:**
```
no matching function in initialization
```

**Wrong:**
```mojo
fn card_xy(idx: Int) -> (Int, Int):
    return (x, y)

var xy = card_xy(i)
var x  = xy[0]
```

**Correct:**
```mojo
# Split into separate functions, one per return value
fn card_x(idx: Int) -> Int:
    return PAD + (idx % COLS) * (CARD_W + PAD)

fn card_y(idx: Int) -> Int:
    return PAD + (idx // ROWS) * (CARD_H + PAD)

# Or pack multiple values into a Python dict
fn card_xy(idx: Int) raises -> PythonObject:
    var d = Python.dict()
    d["x"] = PAD + (idx % COLS) * (CARD_W + PAD)
    d["y"] = PAD + (idx // ROWS) * (CARD_H + PAD)
    return d
```

---

## 24. Unused variable warning — assign to `_`

**Problem:**
Mojo warns when a variable is declared but never read.

**Warning:**
```
assignment to 'x' was never used; assign to '_' instead?
```

**Wrong:**
```mojo
var locked = Bool(s["locked"])   # declared but never used below
```

**Correct:**
```mojo
# Option 1: remove the unused variable entirely
# Option 2: assign to _ to explicitly discard the value
_ = Bool(s["locked"])

# Option 3: use _ directly when calling a function for side effects
_ = canvas.create_rectangle(x1, y1, x2, y2, fill=color)
```

---

## 25. Mojo `List` `len()` should not be passed to Python functions

**Problem:**
Passing `len(mojo_list)` directly to a Python function such as
`random.randint()` can produce unexpected results because Mojo's `len()`
returns a Mojo `Int`, not a Python int, and the conversion may silently
produce a wrong value.

**Wrong:**
```mojo
var words = List[String]()
# ... append words ...
var idx = Int(Float64(String(random.randint(0, len(words) - 1))))
# may always return the same index
```

**Correct:**
```mojo
# Use a Python list and Python's builtins.len() to stay on the Python side
builtins: PythonObject = Python.import_module("builtins")
var py_words: PythonObject = builtins.list()
# ... append words ...
var n   = Int(Float64(String(builtins.len(py_words))))
var idx = Int(Float64(String(random.randint(0, n - 1))))
```

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
| Multiple out args | `fn f(out a: Int, out b: Int)` | tek `Python.dict()` içinde tut |
| Global constants | `alias X = 0` veya `comptime var X = 0` | `comptime X = 0` |
| Python list creation | `Python.evaluate("list")([a, b])` | `builtins.list()` + `.append()` |
| `str()` not defined | `str(obj)` | `String(obj)` |
| String iteration | `for ch in s:` | `for ch in s.codepoint_slices():` |
| Tuple return type | `fn f() -> (Int, Int)` | iki ayrı `fn` veya `Python.dict()` |
| Unused variable | `var x = val` (kullanılmıyor) | `_ = val` veya tanımı kaldır |
| Mojo `len()` to Python | `random.randint(0, len(mojo_list))` | `builtins.len(py_list)` kullan |
