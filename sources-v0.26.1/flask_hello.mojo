"""
Author: Ahmet Aksoy
Date: 2026-03-11
Revision Date: 2026-03-11
Mojo version no: 0.26.1
AI: Claude Sonnet 4.6

Description:
    Minimal Flask web server started from Mojo via Python interop.
    Tests whether Flask's application loop can be launched from Mojo.

    Endpoints:
      GET /          -> "Hello from Mojo + Flask!"
      GET /ping      -> JSON {"status": "ok"}

    Run:
      mojo flask_hello.mojo
    Then open http://localhost:8117 in your browser.
"""

from python import Python, PythonObject


fn main() raises:
    flask: PythonObject    = Python.import_module("flask")
    builtins: PythonObject = Python.import_module("builtins")

    # Create Flask app
    var app: PythonObject = flask.Flask(builtins.str("__main__"))

    # Route handlers are defined in flask_helpers.py
    # (Python.evaluate() does not support multi-line strings — gotcha #15)
    flask_helpers: PythonObject = Python.import_module("flask_helpers")
    flask_helpers.setup_routes(app)

    print("=" * 45)
    print("  Flask server starting on port 8117")
    print("  http://localhost:8117")
    print("  http://localhost:8117/ping")
    print("  Press Ctrl+C to stop.")
    print("=" * 45)

    # Start the Flask development server
    _ = app.run(
        host="0.0.0.0",
        port=8117,
        debug=False
    )
