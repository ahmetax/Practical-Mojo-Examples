"""
Author: Ahmet Aksoy
Date: 2026-03-15
Revision Date: 2026-03-15
Mojo version no: 0.26.1
AI: Claude Sonnet 4.6

Description:
    Library REST API built with Mojo + Flask + SQLite.

    Mojo handles startup, database initialization, and seed data.
    All route handlers are in library_api_helpers.py.

    Endpoints:
      POST   /api/auth/register
      POST   /api/auth/login

      GET    /api/books              ?page, per_page, q, author_id,
                                      min_year, max_year, sort_by, order
      GET    /api/books/<id>
      POST   /api/books              (JWT required)
      PUT    /api/books/<id>         (JWT required)
      DELETE /api/books/<id>         (JWT required)

      GET    /api/authors
      GET    /api/authors/<id>       (includes author's books)

    Authentication:
      JWT Bearer token — obtain via /api/auth/login
      Include as: Authorization: Bearer <token>
      Token expires in 24 hours.

    Pagination envelope:
      {
        "data": [...],
        "pagination": {
          "page": 1, "per_page": 5,
          "total": 20, "total_pages": 4,
          "has_prev": false, "has_next": true
        }
      }

    Run:
      mojo library_api.mojo
    Test with curl or see library_api_guide.md

Requirements:
    pip install flask bcrypt pyjwt
"""

from python import Python, PythonObject


fn seed_data(conn: PythonObject) raises:
    """Insert sample authors and books if tables are empty."""
    var count: PythonObject = conn.execute(
        "SELECT COUNT(*) FROM authors"
    ).fetchone()[0]

    if Int(String(count)) > 0:
        return

    # Authors
    _ = conn.execute(
        "INSERT INTO authors (name, nationality) VALUES ('George Orwell', 'British')"
    )
    _ = conn.execute(
        "INSERT INTO authors (name, nationality) VALUES ('Aldous Huxley', 'British')"
    )
    _ = conn.execute(
        "INSERT INTO authors (name, nationality) VALUES ('Ray Bradbury', 'American')"
    )
    _ = conn.execute(
        "INSERT INTO authors (name, nationality) VALUES ('Isaac Asimov', 'American')"
    )

    # Books
    _ = conn.execute(
        "INSERT INTO books (title, author_id, year, rating, isbn) "
        "VALUES ('1984', 1, 1949, 9.2, '978-0451524935')"
    )
    _ = conn.execute(
        "INSERT INTO books (title, author_id, year, rating, isbn) "
        "VALUES ('Animal Farm', 1, 1945, 8.7, '978-0451526342')"
    )
    _ = conn.execute(
        "INSERT INTO books (title, author_id, year, rating, isbn) "
        "VALUES ('Brave New World', 2, 1932, 8.9, '978-0060850524')"
    )
    _ = conn.execute(
        "INSERT INTO books (title, author_id, year, rating, isbn) "
        "VALUES ('Fahrenheit 451', 3, 1953, 8.8, '978-1451673319')"
    )
    _ = conn.execute(
        "INSERT INTO books (title, author_id, year, rating, isbn) "
        "VALUES ('The Martian Chronicles', 3, 1950, 8.5, '978-1451678192')"
    )
    _ = conn.execute(
        "INSERT INTO books (title, author_id, year, rating, isbn) "
        "VALUES ('Foundation', 4, 1951, 9.1, '978-0553293357')"
    )
    _ = conn.execute(
        "INSERT INTO books (title, author_id, year, rating, isbn) "
        "VALUES ('I, Robot', 4, 1950, 8.6, '978-0553294385')"
    )

    conn.commit()
    print("✓ Seed data inserted (4 authors, 7 books)")


fn ensure_db(sqlite3: PythonObject, os: PythonObject) raises:
    """Create tables and seed initial data."""
    var db_path = String(os.getcwd()) + "/library.db"
    var conn: PythonObject = sqlite3.connect(db_path)

    _ = conn.execute(
        "CREATE TABLE IF NOT EXISTS users ("
        "  id         INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  username   TEXT    NOT NULL UNIQUE,"
        "  password   TEXT    NOT NULL,"
        "  created_at TEXT    NOT NULL"
        ")"
    )

    _ = conn.execute(
        "CREATE TABLE IF NOT EXISTS authors ("
        "  id          INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  name        TEXT    NOT NULL,"
        "  nationality TEXT"
        ")"
    )

    _ = conn.execute(
        "CREATE TABLE IF NOT EXISTS books ("
        "  id        INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  title     TEXT    NOT NULL,"
        "  author_id INTEGER NOT NULL,"
        "  year      INTEGER,"
        "  rating    REAL,"
        "  isbn      TEXT,"
        "  FOREIGN KEY (author_id) REFERENCES authors(id)"
        ")"
    )

    conn.commit()
    seed_data(conn)
    conn.close()
    print("✓ Database ready: " + db_path)


fn main() raises:
    flask: PythonObject    = Python.import_module("flask")
    sqlite3: PythonObject  = Python.import_module("sqlite3")
    os: PythonObject       = Python.import_module("os")
    builtins: PythonObject = Python.import_module("builtins")

    ensure_db(sqlite3, os)

    var app: PythonObject = flask.Flask(builtins.str("__main__"))
    app.config[builtins.str("JSON_SORT_KEYS")] = False

    var jwt_secret = String("mojo-library-jwt-secret-change-in-production")

    library_api_helpers: PythonObject = Python.import_module("library_api_helpers")
    library_api_helpers.setup_routes(app, jwt_secret)

    print("=" * 50)
    print("  Library REST API starting on port 8117")
    print("  http://localhost:8117")
    print("  See library_api_guide.md for test commands.")
    print("  Press Ctrl+C to stop.")
    print("=" * 50)

    _ = app.run(host="0.0.0.0", port=8117, debug=False)
