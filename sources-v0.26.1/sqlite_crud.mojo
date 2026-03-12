"""
Author: Ahmet Aksoy
Date: 2026-03-11
Revision Date: 2026-03-11
Mojo version no: 0.26.1
AI: Claude Sonnet 4.6

Description:
    SQLite database access from Mojo using Python's sqlite3 module.

    Demonstrates the full CRUD cycle:
      - CREATE : create a table
      - INSERT  : add rows one by one and in bulk
      - SELECT  : query all rows, filter by condition, order by column
      - UPDATE  : modify a row
      - DELETE  : remove a row
      - DROP    : remove the table

    The database is created as an in-memory database (:memory:) so no
    file is left on disk after the program exits.

    No external packages are needed — sqlite3 is part of Python's
    standard library.
"""

from python import Python, PythonObject


fn connect(sqlite3: PythonObject) raises -> PythonObject:
    """Open an in-memory SQLite database and return the connection."""
    var conn: PythonObject = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    return conn


fn create_table(conn: PythonObject) raises:
    """Create the 'employees' table."""
    var sql = String(
        "CREATE TABLE IF NOT EXISTS employees ("
        "  id        INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  name      TEXT    NOT NULL,"
        "  dept      TEXT    NOT NULL,"
        "  salary    REAL    NOT NULL"
        ")"
    )
    _ = conn.execute(sql)
    conn.commit()
    print("✓ Table created.")


fn insert_rows(conn: PythonObject, builtins: PythonObject) raises:
    """Insert sample rows using executemany() for bulk insert."""
    var sql = String(
        "INSERT INTO employees (name, dept, salary) VALUES (?, ?, ?)"
    )

    # Build rows as a Python list of tuples
    var rows: PythonObject = builtins.list()

    var make_tuple = Python.evaluate("lambda a, b, c: (a, b, c)")
    rows.append(make_tuple("Alice",   "Engineering", 85000.0))
    rows.append(make_tuple("Bob",     "Marketing",   62000.0))
    rows.append(make_tuple("Carol",   "Engineering", 91000.0))
    rows.append(make_tuple("David",   "HR",          54000.0))
    rows.append(make_tuple("Eve",     "Engineering", 78000.0))
    rows.append(make_tuple("Frank",   "Marketing",   67000.0))
    rows.append(make_tuple("Grace",   "HR",          58000.0))
    rows.append(make_tuple("Hank",    "Engineering", 95000.0))

    _ = conn.executemany(sql, rows)
    conn.commit()
    print("✓ " + String(8) + " rows inserted.")


fn print_row(row: PythonObject) raises:
    """Print a single employee row."""
    var id_val  = String(row[String("id")])
    var name    = String(row[String("name")])
    var dept    = String(row[String("dept")])
    var salary  = String(row[String("salary")])
    print("  " + id_val + "  " + name + "  |  " + dept + "  |  $" + salary)


fn select_all(conn: PythonObject) raises:
    """Select and print all employees ordered by id."""
    print("\n--- All Employees ---")
    var cursor: PythonObject = conn.execute(
        "SELECT * FROM employees ORDER BY id"
    )
    var rows: PythonObject = cursor.fetchall()
    var n = Int(Float64(String(rows.__len__())))
    for i in range(n):
        print_row(rows[i])


fn select_by_dept(conn: PythonObject, dept: String) raises:
    """Select employees in a specific department."""
    print("\n--- Department: " + dept + " ---")
    var cursor: PythonObject = conn.execute(
        "SELECT * FROM employees WHERE dept = ? ORDER BY salary DESC",
        Python.evaluate("lambda d: (d,)")(dept)
    )
    var rows: PythonObject = cursor.fetchall()
    var n = Int(Float64(String(rows.__len__())))
    for i in range(n):
        print_row(rows[i])


fn select_avg_salary(conn: PythonObject) raises:
    """Print average salary per department."""
    print("\n--- Average Salary by Department ---")
    var cursor: PythonObject = conn.execute(
        "SELECT dept, AVG(salary) as avg_sal "
        "FROM employees "
        "GROUP BY dept "
        "ORDER BY avg_sal DESC"
    )
    var rows: PythonObject = cursor.fetchall()
    var n = Int(Float64(String(rows.__len__())))
    for i in range(n):
        var dept    = String(rows[i][String("dept")])
        var avg_sal = String(rows[i][String("avg_sal")])
        print("  " + dept + " : $" + avg_sal)


fn update_salary(conn: PythonObject, name: String, new_salary: Float64) raises:
    """Update the salary of an employee by name."""
    _ = conn.execute(
        "UPDATE employees SET salary = ? WHERE name = ?",
        Python.evaluate("lambda s, n: (s, n)")(new_salary, name)
    )
    conn.commit()
    var affected = Int(Float64(String(conn.execute(
        "SELECT changes()"
    ).fetchone()[0])))
    print("\n✓ Updated " + name + "'s salary to $"
          + String(new_salary)
          + " (" + String(affected) + " row affected)")


fn delete_employee(conn: PythonObject, name: String) raises:
    """Delete an employee by name."""
    _ = conn.execute(
        "DELETE FROM employees WHERE name = ?",
        Python.evaluate("lambda n: (n,)")(name)
    )
    conn.commit()
    var affected = Int(Float64(String(conn.execute(
        "SELECT changes()"
    ).fetchone()[0])))
    print("\n✓ Deleted " + name
          + " (" + String(affected) + " row affected)")


fn drop_table(conn: PythonObject) raises:
    """Drop the employees table."""
    _ = conn.execute("DROP TABLE IF EXISTS employees")
    conn.commit()
    print("\n✓ Table dropped.")


fn main() raises:
    sqlite3: PythonObject  = Python.import_module("sqlite3")
    builtins: PythonObject = Python.import_module("builtins")

    print("=" * 45)
    print("   SQLite CRUD Demo — Mojo + sqlite3")
    print("=" * 45)

    var conn = connect(sqlite3)

    # CREATE
    create_table(conn)

    # INSERT
    insert_rows(conn, builtins)

    # SELECT — all rows
    select_all(conn)

    # SELECT — filtered by department
    select_by_dept(conn, "Engineering")

    # SELECT — aggregate
    select_avg_salary(conn)

    # UPDATE
    update_salary(conn, "Bob", 68000.0)

    # SELECT — verify update
    select_by_dept(conn, "Marketing")

    # DELETE
    delete_employee(conn, "David")

    # SELECT — verify delete
    select_all(conn)

    # DROP
    drop_table(conn)

    conn.close()
    print("\n✓ Connection closed.")
    print("=" * 45)
