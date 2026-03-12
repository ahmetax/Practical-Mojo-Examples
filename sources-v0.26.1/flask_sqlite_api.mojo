"""
Author: Ahmet Aksoy
Date: 2026-03-11
Revision Date: 2026-03-11
Mojo version no: 0.26.1
AI: Claude Sonnet 4.6

Description:
    A simple REST API built with Mojo + Flask + SQLite.

    Mojo handles application startup, database initialization,
    and Flask server configuration. Route handlers are defined
    in flask_sqlite_helpers.py (multi-line Python functions
    cannot be passed via Python.evaluate() — gotcha #15).

    The API uses the library.db database created by sqlite_file.mojo.
    If the database does not exist, it is created and seeded automatically.

    Endpoints:
      GET    /api/books              -> list all books
      GET    /api/books/<id>         -> get one book
      GET    /api/books?genre=Sci-Fi -> filter by genre
      GET    /api/authors            -> list all authors
      POST   /api/books              -> add a new book
      PUT    /api/books/<id>         -> update a book
      DELETE /api/books/<id>         -> delete a book
      GET    /api/stats              -> summary statistics

    Run:
      mojo flask_sqlite_api.mojo
    Test:
      curl http://localhost:8117/api/books
      curl http://localhost:8117/api/stats
      curl http://localhost:8117/api/books?genre=Sci-Fi

Requirements:
    pip install flask
"""

from python import Python, PythonObject


fn ensure_db(sqlite3: PythonObject,
             builtins: PythonObject,
             os: PythonObject) raises:
    """
    Create and seed the database if it does not exist yet.
    Safe to call on every startup — uses INSERT OR IGNORE.
    """
    var db_path = String(os.getcwd()) + "/library.db"
    var conn: PythonObject = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row

    _ = conn.execute("PRAGMA journal_mode=WAL")

    # Authors table
    _ = conn.execute(
        "CREATE TABLE IF NOT EXISTS authors ("
        "  id    INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  name  TEXT    NOT NULL UNIQUE"
        ")"
    )

    # Books table
    _ = conn.execute(
        "CREATE TABLE IF NOT EXISTS books ("
        "  id        INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  title     TEXT    NOT NULL,"
        "  author_id INTEGER NOT NULL,"
        "  year      INTEGER NOT NULL,"
        "  genre     TEXT    NOT NULL,"
        "  rating    REAL    DEFAULT 0.0,"
        "  FOREIGN KEY (author_id) REFERENCES authors(id)"
        ")"
    )
    conn.commit()

    # Seed authors
    var make_t1 = Python.evaluate("lambda a: (a,)")
    var authors: PythonObject = builtins.list()
    authors.append(make_t1("George Orwell"))
    authors.append(make_t1("Frank Herbert"))
    authors.append(make_t1("Isaac Asimov"))
    authors.append(make_t1("Ursula K. Le Guin"))
    authors.append(make_t1("Philip K. Dick"))
    _ = conn.executemany(
        "INSERT OR IGNORE INTO authors (name) VALUES (?)", authors
    )
    conn.commit()

    # Helper to get author id
    var get_id = Python.evaluate(
        "lambda conn, name: conn.execute("
        "'SELECT id FROM authors WHERE name=?', (name,)"
        ").fetchone()[0]"
    )

    # Seed books
    var make_t5 = Python.evaluate("lambda a,b,c,d,e: (a,b,c,d,e)")
    var books: PythonObject = builtins.list()

    var orwell_id  = get_id(conn, "George Orwell")
    var herbert_id = get_id(conn, "Frank Herbert")
    var asimov_id  = get_id(conn, "Isaac Asimov")
    var leguin_id  = get_id(conn, "Ursula K. Le Guin")
    var dick_id    = get_id(conn, "Philip K. Dick")

    books.append(make_t5("1984",                       orwell_id,  1949, "Dystopia",   4.7))
    books.append(make_t5("Animal Farm",                orwell_id,  1945, "Satire",     4.5))
    books.append(make_t5("Dune",                       herbert_id, 1965, "Sci-Fi",     4.8))
    books.append(make_t5("Dune Messiah",               herbert_id, 1969, "Sci-Fi",     4.4))
    books.append(make_t5("Foundation",                 asimov_id,  1951, "Sci-Fi",     4.6))
    books.append(make_t5("I, Robot",                   asimov_id,  1950, "Sci-Fi",     4.5))
    books.append(make_t5("The Left Hand of Darkness",  leguin_id,  1969, "Sci-Fi",     4.6))
    books.append(make_t5("The Dispossessed",           leguin_id,  1974, "Sci-Fi",     4.5))
    books.append(make_t5("Do Androids Dream",          dick_id,    1968, "Sci-Fi",     4.4))
    books.append(make_t5("The Man in the High Castle", dick_id,    1962, "Alt-History", 4.2))

    _ = conn.executemany(
        "INSERT OR IGNORE INTO books (title, author_id, year, genre, rating)"
        " VALUES (?, ?, ?, ?, ?)",
        books
    )
    conn.commit()
    conn.close()
    print("✓ Database ready: " + db_path)


fn main() raises:
    flask: PythonObject    = Python.import_module("flask")
    sqlite3: PythonObject  = Python.import_module("sqlite3")
    builtins: PythonObject = Python.import_module("builtins")
    os: PythonObject       = Python.import_module("os")

    # Ensure database exists and is seeded
    ensure_db(sqlite3, builtins, os)

    # Create Flask app
    var app: PythonObject = flask.Flask(builtins.str("__main__"))

    # Register routes from helper module
    flask_sqlite_helpers: PythonObject = Python.import_module(
        "flask_sqlite_helpers"
    )
    flask_sqlite_helpers.setup_routes(app)

    print("=" * 50)
    print("  Flask + SQLite API starting on port 8117")
    print("  Endpoints:")
    print("    GET  /api/books")
    print("    GET  /api/books/<id>")
    print("    GET  /api/books?genre=Sci-Fi")
    print("    GET  /api/authors")
    print("    POST /api/books")
    print("    PUT  /api/books/<id>")
    print("    DELETE /api/books/<id>")
    print("    GET  /api/stats")
    print("  Press Ctrl+C to stop.")
    print("=" * 50)

    _ = app.run(host="0.0.0.0", port=8117, debug=False)
