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

## Summary Table

| Pitfall | Wrong | Correct |
|---|---|---|
| Tuple argument | `func(arg=(a, b))` | `var t = Python.evaluate("lambda a,b: (a,b)")(a,b)` |
| Exception handling | `except Exception as e:` | `except:` |
| bytes() built-in | `bytes(obj)` | `Python.import_module("builtins").bytes(obj)` |
| Binary file write | `open(path, "wb")` | `Python.import_module("builtins").open(path, "wb")` |
| Python None | `None` or `Python.None` | `Python.none()` |
| Dict for Python API | `Dict[String, String]()` | `Python.dict()` |
| Lambda / key functions | *(not possible inline)* | `Python.evaluate("lambda ...")` |
