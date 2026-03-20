"""
Author: Ahmet Aksoy
Date: 2026-03-19
Revision Date: 2026-03-19
Mojo version no: 0.26.1
AI: Claude Sonnet 4.6

Description:
    Sorting Algorithm Benchmark — Mojo vs Python.
    Built with Mojo + Flask + Chart.js.

    Algorithms compared:
      Bubble Sort     O(n²)
      Selection Sort  O(n²)
      Insertion Sort  O(n²)
      Merge Sort      O(n log n)
      Quick Sort      O(n log n)
      Heap Sort       O(n log n)
      Built-in Sort   O(n log n)  ← Mojo's sort()

    Architecture:
      sorting_app.mojo    <- Flask startup (this file)
      sort_bench.mojo     <- Mojo sort benchmark (subprocess)
      sorting_helpers.py  <- Python sorts + Flask routes

    Both Mojo and Python use identical input lists generated
    with the same LCG (Linear Congruential Generator) and seed.

    O(n²) algorithms are skipped on the Python side for list
    sizes > 10,000 to avoid timeouts.

    Run:
      mojo sorting_app.mojo
    Then open http://localhost:8117

Requirements:
    pip install flask
"""

from python import Python, PythonObject


fn main() raises:
    flask: PythonObject    = Python.import_module("flask")
    builtins: PythonObject = Python.import_module("builtins")

    var app: PythonObject = flask.Flask(
        builtins.str("__main__"),
        template_folder=builtins.str("sorting_templates")
    )
    app.secret_key = builtins.str("mojo-sorting-secret-key")

    # Custom Jinja2 filter for integer formatting
    var add_filter = Python.evaluate("""
lambda app: app.jinja_env.filters.update(
    {'format_int': lambda v: '{:,}'.format(int(v))}
)
""")
    _ = add_filter(app)

    sorting_helpers: PythonObject = Python.import_module("sorting_helpers")
    sorting_helpers.setup_routes(app)

    print("=" * 50)
    print("  Sorting Benchmark starting on port 8117")
    print("  http://localhost:8117")
    print("  Press Ctrl+C to stop.")
    print("=" * 50)

    _ = app.run(host="0.0.0.0", port=8117, debug=False)
