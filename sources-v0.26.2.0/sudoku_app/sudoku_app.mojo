"""
Author: Ahmet Aksoy
Date: 2026-03-20
Mojo version: 0.26.2 | Python 3.12 | Ubuntu

Description:
    Sudoku Creator / Solver web application.
    Built with Mojo + Flask + Python.

    Features:
      - Puzzle generation (Easy / Medium / Hard)
      - Optional random seed for reproducible puzzles
      - Python backtracking solver with step recording
      - Mojo backtracking solver via subprocess
      - Python vs Mojo timing comparison
      - Step-by-step animation with play/pause/step controls
      - Variable animation speed
      - User input via numpad or keyboard
      - Board validation (conflict detection)
      - Reset to given / Clear all

    File structure:
      sudoku_app.mojo       <- this file (Flask startup)
      sudoku_solver.mojo    <- Mojo solver (subprocess)
      sudoku_engine.py      <- Creator + Python solver
      sudoku_helpers.py     <- Flask routes
      sudoku_templates/
        base.html
        index.html

    Run:
      mojo sudoku_app.mojo
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
        template_folder=builtins.str("sudoku_templates")
    )
    app.secret_key = builtins.str("mojo-sudoku-secret-key")

    sudoku_helpers: PythonObject = Python.import_module("sudoku_helpers")
    sudoku_helpers.setup_routes(app)

    print("=" * 50)
    print("  Sudoku App starting on port 8117")
    print("  http://localhost:8117")
    print("  Press Ctrl+C to stop.")
    print("=" * 50)

    _ = app.run(host="0.0.0.0", port=8117, debug=False)
