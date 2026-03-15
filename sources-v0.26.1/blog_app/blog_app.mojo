"""
Author: Ahmet Aksoy
Date: 2026-03-14
Revision Date: 2026-03-14
Mojo version no: 0.26.1
AI: Claude Sonnet 4.6

Description:
    Blog / Content Management System built with Mojo + Flask + SQLite.

    Mojo handles application startup and database initialization.
    Flask routes and authentication logic are in blog_helpers.py.
    HTML templates are in the blog_templates/ directory.

    Authentication features:
      - User registration with input validation
      - Password hashing with bcrypt
      - Login / logout with Flask session
      - login_required decorator for protected routes
      - Change password (verifies current password first)
      - Delete account (cascades to posts)

    Blog features:
      - Public: home page (all posts), single post view
      - Protected: dashboard, new post, edit post, delete post
      - Authors can only edit/delete their own posts

    File structure:
      blog_app.mojo              <- this file
      blog_helpers.py            <- Flask routes + auth logic
      blog.db                    <- SQLite database (auto-created)
      blog_templates/
        base.html
        index.html               <- public home
        post.html                <- public single post
        login.html
        register.html
        dashboard.html           <- protected
        post_form.html           <- protected (new + edit)
        profile.html             <- protected

    Run:
      mojo blog_app.mojo
    Then open http://localhost:8117

Requirements:
    pip install flask bcrypt
"""

from python import Python, PythonObject


fn ensure_db(sqlite3: PythonObject, os: PythonObject) raises:
    """Create users and posts tables if they do not exist."""
    var db_path = String(os.getcwd()) + "/blog.db"
    var conn: PythonObject = sqlite3.connect(db_path)

    _ = conn.execute(
        "CREATE TABLE IF NOT EXISTS users ("
        "  id         INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  username   TEXT    NOT NULL UNIQUE,"
        "  email      TEXT    NOT NULL UNIQUE,"
        "  password   TEXT    NOT NULL,"
        "  created_at TEXT    NOT NULL"
        ")"
    )

    _ = conn.execute(
        "CREATE TABLE IF NOT EXISTS posts ("
        "  id         INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  user_id    INTEGER NOT NULL,"
        "  title      TEXT    NOT NULL,"
        "  body       TEXT    NOT NULL,"
        "  created_at TEXT    NOT NULL,"
        "  updated_at TEXT    NOT NULL,"
        "  FOREIGN KEY (user_id) REFERENCES users(id)"
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
        template_folder=builtins.str("blog_templates")
    )

    app.secret_key = builtins.str("mojo-blog-secret-key-change-in-production")

    blog_helpers: PythonObject = Python.import_module("blog_helpers")
    blog_helpers.setup_routes(app)

    print("=" * 50)
    print("  MojoBlog starting on port 8117")
    print("  http://localhost:8117")
    print("  Press Ctrl+C to stop.")
    print("=" * 50)

    _ = app.run(host="0.0.0.0", port=8117, debug=False)
