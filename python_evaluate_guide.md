# Python.evaluate() in Mojo

Mojo version: 0.26.1

## What is Python.evaluate()?

`Python.evaluate()` sends a Python expression as a string to the embedded
Python interpreter and returns the result as a `PythonObject`.

```mojo
var result = Python.evaluate("1 + 2")
# result is a PythonObject with value 3
```

It is similar to Python's built-in `eval()` function — it evaluates a
single expression and returns its value.

---

## How it works

Mojo's Python interop layer runs an embedded Python interpreter in the
background. `Python.evaluate()` provides direct access to this interpreter:

```
Mojo code
   │
   ▼
Python.evaluate("expression")
   │
   ▼
Embedded Python interpreter (already running)
   │
   ▼
PythonObject (result returned to Mojo)
```

---

## Common use cases

### 1. Building tuples for Python functions

Mojo tuples cannot be passed directly to Python functions (see gotcha #1).
`Python.evaluate()` solves this by building the tuple on the Python side:

```mojo
# Single-element tuple
conn.execute(
    "SELECT * FROM books WHERE id = ?",
    Python.evaluate("lambda x: (x,)")(book_id)
)

# Two-element tuple
conn.execute(
    "UPDATE books SET rating = ? WHERE id = ?",
    Python.evaluate("lambda a, b: (a, b)")(rating, book_id)
)

# Passing auth credentials to requests
var auth = Python.evaluate("lambda u, p: (u, p)")(username, password)
response = requests.get(url, auth=auth)
```

### 2. Accessing Python built-in types

```mojo
# Get the Python list type and create an empty list
var py_list_type = Python.evaluate("list")
var my_list: PythonObject = py_list_type()

# Simpler: use builtins module directly
builtins: PythonObject = Python.import_module("builtins")
var my_list: PythonObject = builtins.list()
```

### 3. Single-line lambda functions

Useful for passing key functions to Python's `sorted()`, `max()`, etc.:

```mojo
var by_rating = Python.evaluate("lambda x: x['rating']")
var sorted_books = sorted(books, key=by_rating)

# Or for nlargest
var get_score = Python.evaluate("lambda scores: lambda k: scores[k]")
var top = nlargest(3, keys, key=get_score(scores))
```

### 4. Python literals and constants

```mojo
var pi    = Python.evaluate("3.14159")
var empty = Python.evaluate("None")    # same as Python.none()
var true  = Python.evaluate("True")
```

### 5. Quick Python expressions

```mojo
var upper   = Python.evaluate("'hello world'.upper()")
# result: "HELLO WORLD"

var version = Python.evaluate("__import__('sys').version")
# result: Python version string
```

### 6. Font and style tuples for tkinter

tkinter functions often expect tuples for font specifications:

```mojo
_ = canvas.create_text(
    x, y,
    text="Score: 100",
    font=Python.evaluate("('Arial', 12, 'bold')")
)
```

---

## Important limitations

### Only single-line expressions are accepted

`Python.evaluate()` accepts expressions, not statements.
Multi-line definitions cause a syntax error at runtime:

```mojo
# WRONG — multi-line string causes runtime error:
# "invalid syntax (<string>, line 2)"
Python.evaluate("""
def my_func(x):
    return x * 2
""")

# CORRECT — move multi-line code to a .py helper file
helpers: PythonObject = Python.import_module("my_helpers")
helpers.my_func(x)
```

### `import` statements do not work inside it

```mojo
# WRONG
Python.evaluate("import os; os.getcwd()")

# CORRECT — import the module separately
os: PythonObject = Python.import_module("os")
var cwd = String(os.getcwd())
```

### Only expressions, not statements

Assignment, `if`, `for`, `def`, `class` are all statements and
cannot be used inside `Python.evaluate()`:

```mojo
# WRONG — assignment is a statement
Python.evaluate("x = 42")

# CORRECT — use as an expression
var x = Python.evaluate("42")
```

---

## Python.evaluate() vs Python.import_module()

| | `Python.evaluate()` | `Python.import_module()` |
|---|---|---|
| Input | Python expression (string) | Module name (string) |
| Returns | Result of the expression | Module object |
| Typical use | Lambda, tuple, type, constant | requests, sqlite3, flask, numpy... |
| Multi-line | ❌ Not supported | ✅ Full module file |
| Performance | Evaluated each call | Cached after first import |

---

## The most common pattern in practice

Throughout our Mojo examples, the most frequent use of `Python.evaluate()`
is building parameter tuples for SQLite and requests — because Mojo tuples
cannot be passed to Python functions directly:

```mojo
# SQLite — single parameter
conn.execute(
    "DELETE FROM books WHERE id = ?",
    Python.evaluate("lambda x: (x,)")(book_id)
)

# SQLite — multiple parameters
conn.execute(
    "INSERT INTO books (title, year, rating) VALUES (?, ?, ?)",
    Python.evaluate("lambda a, b, c: (a, b, c)")(title, year, rating)
)

# requests — timeout tuple
var timeout = Python.evaluate("lambda c, r: (c, r)")(3, 10)
response = requests.get(url, timeout=timeout)

# requests — basic auth
var auth = Python.evaluate("lambda u, p: (u, p)")(username, password)
response = requests.get(url, auth=auth)
```

---

## Summary

`Python.evaluate()` is a lightweight bridge that lets you run any
single-line Python expression from Mojo and get the result back as a
`PythonObject`. Its main strengths are:

- Building Python tuples (the most common use case)
- Creating lambda functions for use as callbacks
- Accessing Python built-in types and constants
- Quick one-liner expressions that have no Mojo equivalent

For anything more complex — multi-line functions, class definitions,
decorator-based code like Flask routes — move the code to a `.py` helper
file and import it with `Python.import_module()`.
