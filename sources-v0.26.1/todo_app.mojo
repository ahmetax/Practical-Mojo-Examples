"""
Author: Ahmet Aksoy
Date: 2026-03-12
Revision Date: 2026-03-12
Mojo version no: 0.26.1
AI: Claude Sonnet 4.6

Description:
    A To-Do List web application built with Mojo + Flask + SQLite.

    Mojo handles application startup and database initialization.
    Flask route handlers and Jinja2 templates are managed on the
    Python side via todo_helpers.py and the todo_templates/ directory.

    Features:
      - Add tasks with priority (high / medium / low)
      - Mark tasks as done / undone
      - Edit task title and priority
      - Delete individual tasks
      - Clear all completed tasks
      - Filter by: all / pending / done / high priority
      - Live stats (total, pending, done, high priority)

    File structure:
      todo_app.mojo          <- this file
      todo_helpers.py        <- Flask routes
      todo.db                <- SQLite database (auto-created)
      todo_templates/
        base.html            <- shared layout
        index.html           <- task list
        edit.html            <- edit form

    Run:
      mojo todo_app.mojo
    Then open http://localhost:8117 in your browser.

Requirements:
    pip install flask
"""

from python import Python, PythonObject


fn ensure_db(sqlite3: PythonObject, os: PythonObject) raises:
    """Create the tasks table if it does not exist."""
    var db_path = String(os.getcwd()) + "/todo.db"
    var conn: PythonObject = sqlite3.connect(db_path)
    _ = conn.execute(
        "CREATE TABLE IF NOT EXISTS tasks ("
        "  id         INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  title      TEXT    NOT NULL,"
        "  priority   TEXT    NOT NULL DEFAULT 'medium',"
        "  done       INTEGER NOT NULL DEFAULT 0,"
        "  created_at TEXT    NOT NULL"
        ")"
    )
    conn.commit()
    conn.close()
    print("✓ Database ready: " + db_path)


fn main() raises:
    flask: PythonObject   = Python.import_module("flask")
    sqlite3: PythonObject = Python.import_module("sqlite3")
    os: PythonObject      = Python.import_module("os")
    builtins: PythonObject = Python.import_module("builtins")

    ensure_db(sqlite3, os)

    var app: PythonObject = flask.Flask(
        builtins.str("__main__"),
        template_folder=builtins.str("todo_templates")
    )

    # Secret key required for flash messages
    app.secret_key = builtins.str("mojo-todo-secret-key")

    # Register routes
    todo_helpers: PythonObject = Python.import_module("todo_helpers")
    todo_helpers.setup_routes(app)

    print("=" * 45)
    print("  To-Do App starting on port 8117")
    print("  http://localhost:8117")
    print("  Press Ctrl+C to stop.")
    print("=" * 45)

    _ = app.run(host="0.0.0.0", port=8117, debug=False)
