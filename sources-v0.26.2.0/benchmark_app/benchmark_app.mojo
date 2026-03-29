"""
Author: Ahmet Aksoy
Date: 2026-03-27
Mojo version: 0.26.2 | Python 3.12 | Ubuntu

Description:
    Mojo vs Python Mathematical Benchmark Application.
    Built with Mojo + Flask + Chart.js.

    Architecture:
      Flask /run endpoint calls mojo_bench.mojo via subprocess.
      mojo_bench.mojo runs benchmarks and prints JSON to stdout.
      Flask reads the JSON, compares with Python results, renders page.

    File structure:
      benchmark_app.mojo    <- Flask startup (this file)
      mojo_bench.mojo       <- Mojo benchmark runner (subprocess)
      benchmark_helpers.py  <- Python benchmarks + Flask routes
      benchmark_templates/
        base.html
        index.html

    Run:
      mojo benchmark_app.mojo
    Then open http://localhost:8117

Requirements:
    pip install flask
"""

from std.python import Python, PythonObject


fn main() raises:
    flask: PythonObject    = Python.import_module("flask")
    builtins: PythonObject = Python.import_module("builtins")

    var app: PythonObject = flask.Flask(
        builtins.str("__main__"),
        template_folder=builtins.str("benchmark_templates")
    )
    app.secret_key = builtins.str("mojo-benchmark-secret-key")

    benchmark_helpers: PythonObject = Python.import_module("benchmark_helpers")
    benchmark_helpers.setup_routes(app)

    print("=" * 50)
    print("  Mojo Benchmark App starting on port 8117")
    print("  http://localhost:8117")
    print("  Press Ctrl+C to stop.")
    print("=" * 50)

    _ = app.run(host="0.0.0.0", port=8117, debug=False)
