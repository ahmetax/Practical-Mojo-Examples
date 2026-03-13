"""
Author: Ahmet Aksoy
Date: 2026-03-12
Revision Date: 2026-03-12
Mojo version no: 0.26.1
AI: Claude Sonnet 4.6

Description:
    Expense Tracker web application built with Mojo + Flask + SQLite.

    Mojo handles application startup and database initialization.
    Flask routes are defined in expense_helpers.py.
    HTML templates are in the expense_templates/ directory.

    Features:
      - Add expenses with description, amount, category and date
      - Dashboard with total / monthly / weekly spending stats
      - Doughnut chart: spending by category
      - Delete individual expenses
      - Monthly report with:
          - Daily spending bar chart (Chart.js)
          - Category breakdown table
          - Month navigation (prev / next)
          - Daily average and top category

    File structure:
      expense_app.mojo           <- this file
      expense_helpers.py         <- Flask routes
      expense.db                 <- SQLite database (auto-created)
      expense_templates/
        base.html
        index.html               <- dashboard
        add.html                 <- add expense form
        report.html              <- monthly report

    Run:
      mojo expense_app.mojo
    Then open http://localhost:8117

Requirements:
    pip install flask
"""

from python import Python, PythonObject


fn ensure_db(sqlite3: PythonObject, os: PythonObject) raises:
    """Create the expenses table if it does not exist."""
    var db_path = String(os.getcwd()) + "/expense.db"
    var conn: PythonObject = sqlite3.connect(db_path)
    _ = conn.execute(
        "CREATE TABLE IF NOT EXISTS expenses ("
        "  id          INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  description TEXT    NOT NULL,"
        "  amount      REAL    NOT NULL,"
        "  category    TEXT    NOT NULL DEFAULT 'Other',"
        "  date        TEXT    NOT NULL"
        ")"
    )
    conn.commit()
    conn.close()
    print("✓ Database ready: " + db_path)


fn main() raises:
    flask: PythonObject    = Python.import_module("flask")
    sqlite3: PythonObject  = Python.import_module("sqlite3")
    os: PythonObject       = Python.import_module("os")
    builtins: PythonObject = Python.import_module("builtins")

    ensure_db(sqlite3, os)

    var app: PythonObject = flask.Flask(
        builtins.str("__main__"),
        template_folder=builtins.str("expense_templates")
    )

    app.secret_key = builtins.str("mojo-expense-secret-key")

    expense_helpers: PythonObject = Python.import_module("expense_helpers")
    expense_helpers.setup_routes(app)

    print("=" * 48)
    print("  Expense Tracker starting on port 8117")
    print("  http://localhost:8117")
    print("  Press Ctrl+C to stop.")
    print("=" * 48)

    _ = app.run(host="0.0.0.0", port=8117, debug=False)
