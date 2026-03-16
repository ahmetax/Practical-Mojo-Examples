"""
Library REST API Flask route handler helper.
Imported by library_api.mojo via Python.import_module().

Endpoints:
  POST   /api/auth/register
  POST   /api/auth/login

  GET    /api/books              ?page=1&per_page=5&q=title&author_id=&min_year=&max_year=
  GET    /api/books/<id>
  POST   /api/books              (JWT required)
  PUT    /api/books/<id>         (JWT required)
  DELETE /api/books/<id>         (JWT required)

  GET    /api/authors
  GET    /api/authors/<id>
"""

import sqlite3
import jwt
import bcrypt
from datetime import datetime, timedelta, timezone
from functools import wraps
from flask import request, jsonify

DB_PATH    = "library.db"
JWT_SECRET = ""        # set by setup_routes()
JWT_EXPIRY = 24        # hours


# ------------------------------------------------------------------ #
# DB helpers
# ------------------------------------------------------------------ #
def get_conn():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def row_to_dict(row):
    if row is None:
        return None
    return dict(zip(row.keys(), tuple(row)))


# ------------------------------------------------------------------ #
# Auth helpers
# ------------------------------------------------------------------ #
def hash_password(plain):
    return bcrypt.hashpw(plain.encode(), bcrypt.gensalt()).decode()


def check_password(plain, hashed):
    return bcrypt.checkpw(plain.encode(), hashed.encode())


def make_token(user_id, username):
    payload = {
        'user_id' : user_id,
        'username': username,
        'exp'     : datetime.now(timezone.utc) + timedelta(hours=JWT_EXPIRY)
    }
    return jwt.encode(payload, JWT_SECRET, algorithm='HS256')


def decode_token(token):
    return jwt.decode(token, JWT_SECRET, algorithms=['HS256'])


def jwt_required(f):
    """Decorator: extracts and validates Bearer token."""
    @wraps(f)
    def decorated(*args, **kwargs):
        auth = request.headers.get('Authorization', '')
        if not auth.startswith('Bearer '):
            return jsonify({'error': 'Missing or invalid Authorization header'}), 401
        token = auth[7:]
        try:
            payload = decode_token(token)
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Token expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401
        request.user_id  = payload['user_id']
        request.username = payload['username']
        return f(*args, **kwargs)
    return decorated


# ------------------------------------------------------------------ #
# Pagination helper
# ------------------------------------------------------------------ #
def paginate(query_rows, page, per_page, total, endpoint, **kwargs):
    """Build a standard pagination envelope."""
    total_pages = (total + per_page - 1) // per_page
    return {
        'data'      : query_rows,
        'pagination': {
            'page'       : page,
            'per_page'   : per_page,
            'total'      : total,
            'total_pages': total_pages,
            'has_prev'   : page > 1,
            'has_next'   : page < total_pages,
        }
    }


# ------------------------------------------------------------------ #
# Validation helpers
# ------------------------------------------------------------------ #
def require_json_fields(data, *fields):
    missing = [f for f in fields if not data.get(f)]
    if missing:
        return {'error': f'Missing required fields: {", ".join(missing)}'}
    return None


# ------------------------------------------------------------------ #
# Route setup
# ------------------------------------------------------------------ #
def setup_routes(app, jwt_secret):
    global JWT_SECRET
    JWT_SECRET = jwt_secret

    # ============================================================== #
    # AUTH
    # ============================================================== #

    @app.route('/api/auth/register', methods=['POST'])
    def auth_register():
        data = request.get_json(silent=True) or {}
        err  = require_json_fields(data, 'username', 'password')
        if err:
            return jsonify(err), 400

        username = str(data['username']).strip()
        password = str(data['password'])

        if len(username) < 3:
            return jsonify({'error': 'Username must be at least 3 characters'}), 400
        if len(password) < 6:
            return jsonify({'error': 'Password must be at least 6 characters'}), 400

        conn = get_conn()
        if conn.execute(
            "SELECT id FROM users WHERE username=?", (username,)
        ).fetchone():
            conn.close()
            return jsonify({'error': 'Username already taken'}), 409

        hashed = hash_password(password)
        now    = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        cur    = conn.execute(
            "INSERT INTO users (username, password, created_at) VALUES (?,?,?)",
            (username, hashed, now)
        )
        conn.commit()
        user_id = cur.lastrowid
        conn.close()

        token = make_token(user_id, username)
        return jsonify({
            'message' : 'User registered successfully',
            'username': username,
            'token'   : token
        }), 201


    @app.route('/api/auth/login', methods=['POST'])
    def auth_login():
        data = request.get_json(silent=True) or {}
        err  = require_json_fields(data, 'username', 'password')
        if err:
            return jsonify(err), 400

        username = str(data['username']).strip()
        password = str(data['password'])

        conn = get_conn()
        row  = conn.execute(
            "SELECT * FROM users WHERE username=?", (username,)
        ).fetchone()
        conn.close()

        if row is None or not check_password(password, row['password']):
            return jsonify({'error': 'Invalid username or password'}), 401

        token = make_token(row['id'], row['username'])
        return jsonify({
            'message' : 'Login successful',
            'username': row['username'],
            'token'   : token,
            'expires_in': f'{JWT_EXPIRY}h'
        })


    # ============================================================== #
    # BOOKS
    # ============================================================== #

    @app.route('/api/books', methods=['GET'])
    def get_books():
        # Query params
        page      = max(1, int(request.args.get('page', 1)))
        per_page  = min(50, max(1, int(request.args.get('per_page', 5))))
        q         = request.args.get('q', '').strip()
        author_id = request.args.get('author_id', '').strip()
        min_year  = request.args.get('min_year', '').strip()
        max_year  = request.args.get('max_year', '').strip()
        sort_by   = request.args.get('sort_by', 'id')   # id | title | year | rating
        order     = request.args.get('order', 'asc')    # asc | desc

        allowed_sorts = {'id', 'title', 'year', 'rating'}
        if sort_by not in allowed_sorts:
            sort_by = 'id'
        if order not in ('asc', 'desc'):
            order = 'asc'

        # Build WHERE clause
        conditions = []
        params     = []

        if q:
            conditions.append("(b.title LIKE ? OR a.name LIKE ?)")
            params += [f'%{q}%', f'%{q}%']
        if author_id:
            conditions.append("b.author_id = ?")
            params.append(author_id)
        if min_year:
            conditions.append("b.year >= ?")
            params.append(min_year)
        if max_year:
            conditions.append("b.year <= ?")
            params.append(max_year)

        where = ("WHERE " + " AND ".join(conditions)) if conditions else ""

        base_query = (
            "FROM books b JOIN authors a ON b.author_id = a.id " + where
        )

        conn   = get_conn()
        total  = conn.execute(
            "SELECT COUNT(*) " + base_query, params
        ).fetchone()[0]

        offset = (page - 1) * per_page
        rows   = conn.execute(
            f"SELECT b.*, a.name as author_name {base_query} "
            f"ORDER BY b.{sort_by} {order} LIMIT ? OFFSET ?",
            params + [per_page, offset]
        ).fetchall()
        conn.close()

        books = [row_to_dict(r) for r in rows]
        return jsonify(paginate(books, page, per_page, total, 'get_books'))


    @app.route('/api/books/<int:book_id>', methods=['GET'])
    def get_book(book_id):
        conn = get_conn()
        row  = conn.execute(
            "SELECT b.*, a.name as author_name "
            "FROM books b JOIN authors a ON b.author_id = a.id "
            "WHERE b.id = ?",
            (book_id,)
        ).fetchone()
        conn.close()

        if row is None:
            return jsonify({'error': 'Book not found'}), 404
        return jsonify(row_to_dict(row))


    @app.route('/api/books', methods=['POST'])
    @jwt_required
    def create_book():
        data = request.get_json(silent=True) or {}
        err  = require_json_fields(data, 'title', 'author_id')
        if err:
            return jsonify(err), 400

        title     = str(data['title']).strip()
        author_id = int(data['author_id'])
        year      = data.get('year')
        rating    = data.get('rating')
        isbn      = str(data.get('isbn', '')).strip() or None

        if rating is not None:
            rating = float(rating)
            if not (0 <= rating <= 10):
                return jsonify({'error': 'Rating must be between 0 and 10'}), 400

        conn = get_conn()
        if not conn.execute(
            "SELECT id FROM authors WHERE id=?", (author_id,)
        ).fetchone():
            conn.close()
            return jsonify({'error': f'Author {author_id} not found'}), 404

        cur = conn.execute(
            "INSERT INTO books (title, author_id, year, rating, isbn) "
            "VALUES (?, ?, ?, ?, ?)",
            (title, author_id, year, rating, isbn)
        )
        conn.commit()
        book_id = cur.lastrowid
        row     = conn.execute(
            "SELECT b.*, a.name as author_name "
            "FROM books b JOIN authors a ON b.author_id=a.id WHERE b.id=?",
            (book_id,)
        ).fetchone()
        conn.close()

        return jsonify(row_to_dict(row)), 201


    @app.route('/api/books/<int:book_id>', methods=['PUT'])
    @jwt_required
    def update_book(book_id):
        data = request.get_json(silent=True) or {}
        conn = get_conn()
        row  = conn.execute(
            "SELECT * FROM books WHERE id=?", (book_id,)
        ).fetchone()

        if row is None:
            conn.close()
            return jsonify({'error': 'Book not found'}), 404

        book      = row_to_dict(row)
        title     = str(data.get('title',     book['title'])).strip()
        author_id = int(data.get('author_id', book['author_id']))
        year      = data.get('year',   book['year'])
        rating    = data.get('rating', book['rating'])
        isbn      = data.get('isbn',   book['isbn'])

        if rating is not None:
            rating = float(rating)
            if not (0 <= rating <= 10):
                conn.close()
                return jsonify({'error': 'Rating must be between 0 and 10'}), 400

        if not conn.execute(
            "SELECT id FROM authors WHERE id=?", (author_id,)
        ).fetchone():
            conn.close()
            return jsonify({'error': f'Author {author_id} not found'}), 404

        conn.execute(
            "UPDATE books SET title=?, author_id=?, year=?, rating=?, isbn=? WHERE id=?",
            (title, author_id, year, rating, isbn, book_id)
        )
        conn.commit()
        row = conn.execute(
            "SELECT b.*, a.name as author_name "
            "FROM books b JOIN authors a ON b.author_id=a.id WHERE b.id=?",
            (book_id,)
        ).fetchone()
        conn.close()

        return jsonify(row_to_dict(row))


    @app.route('/api/books/<int:book_id>', methods=['DELETE'])
    @jwt_required
    def delete_book(book_id):
        conn = get_conn()
        row  = conn.execute(
            "SELECT id FROM books WHERE id=?", (book_id,)
        ).fetchone()

        if row is None:
            conn.close()
            return jsonify({'error': 'Book not found'}), 404

        conn.execute("DELETE FROM books WHERE id=?", (book_id,))
        conn.commit()
        conn.close()
        return jsonify({'message': f'Book {book_id} deleted successfully'})


    # ============================================================== #
    # AUTHORS
    # ============================================================== #

    @app.route('/api/authors', methods=['GET'])
    def get_authors():
        conn = get_conn()
        rows = conn.execute(
            "SELECT a.*, COUNT(b.id) as book_count "
            "FROM authors a LEFT JOIN books b ON a.id = b.author_id "
            "GROUP BY a.id ORDER BY a.name"
        ).fetchall()
        conn.close()
        return jsonify([row_to_dict(r) for r in rows])


    @app.route('/api/authors/<int:author_id>', methods=['GET'])
    def get_author(author_id):
        conn   = get_conn()
        author = conn.execute(
            "SELECT * FROM authors WHERE id=?", (author_id,)
        ).fetchone()

        if author is None:
            conn.close()
            return jsonify({'error': 'Author not found'}), 404

        books = conn.execute(
            "SELECT * FROM books WHERE author_id=? ORDER BY year",
            (author_id,)
        ).fetchall()
        conn.close()

        result          = row_to_dict(author)
        result['books'] = [row_to_dict(b) for b in books]
        return jsonify(result)
