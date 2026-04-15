"""
Flask + SQLite REST API route handler helper.
Imported by flask_sqlite_api.mojo via Python.import_module().

Endpoints:
  GET    /api/books              -> list all books
  GET    /api/books/<id>         -> get one book
  GET    /api/books?genre=Sci-Fi -> filter by genre
  GET    /api/authors            -> list all authors
  POST   /api/books              -> add a new book
  PUT    /api/books/<id>         -> update a book
  DELETE /api/books/<id>         -> delete a book
  GET    /api/stats              -> summary statistics
"""

import sqlite3
from flask import Flask, jsonify, request


DB_PATH = "library.db"


def get_conn():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def row_to_dict(row):
    return dict(zip(row.keys(), tuple(row)))


def setup_routes(app):

    # ------------------------------------------------------------------ #
    # GET /api/books  or  GET /api/books?genre=Sci-Fi
    # ------------------------------------------------------------------ #
    @app.route('/api/books', methods=['GET'])
    def get_books():
        genre = request.args.get('genre')
        conn  = get_conn()
        if genre:
            rows = conn.execute(
                "SELECT b.id, b.title, a.name AS author, "
                "b.year, b.genre, b.rating "
                "FROM books b JOIN authors a ON b.author_id = a.id "
                "WHERE b.genre = ? ORDER BY b.rating DESC",
                (genre,)
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT b.id, b.title, a.name AS author, "
                "b.year, b.genre, b.rating "
                "FROM books b JOIN authors a ON b.author_id = a.id "
                "ORDER BY b.rating DESC"
            ).fetchall()
        conn.close()
        return jsonify([row_to_dict(r) for r in rows])

    # ------------------------------------------------------------------ #
    # GET /api/books/<id>
    # ------------------------------------------------------------------ #
    @app.route('/api/books/<int:book_id>', methods=['GET'])
    def get_book(book_id):
        conn = get_conn()
        row  = conn.execute(
            "SELECT b.id, b.title, a.name AS author, "
            "b.year, b.genre, b.rating "
            "FROM books b JOIN authors a ON b.author_id = a.id "
            "WHERE b.id = ?",
            (book_id,)
        ).fetchone()
        conn.close()
        if row is None:
            return jsonify({'error': 'Book not found'}), 404
        return jsonify(row_to_dict(row))

    # ------------------------------------------------------------------ #
    # GET /api/authors
    # ------------------------------------------------------------------ #
    @app.route('/api/authors', methods=['GET'])
    def get_authors():
        conn = get_conn()
        rows = conn.execute(
            "SELECT a.id, a.name, COUNT(b.id) AS book_count "
            "FROM authors a LEFT JOIN books b ON a.id = b.author_id "
            "GROUP BY a.id ORDER BY book_count DESC"
        ).fetchall()
        conn.close()
        return jsonify([row_to_dict(r) for r in rows])

    # ------------------------------------------------------------------ #
    # POST /api/books
    # Body: {"title": "...", "author": "...", "year": 1984,
    #        "genre": "...", "rating": 4.5}
    # ------------------------------------------------------------------ #
    @app.route('/api/books', methods=['POST'])
    def add_book():
        data = request.get_json()
        if not data:
            return jsonify({'error': 'JSON body required'}), 400

        required = ['title', 'author', 'year', 'genre', 'rating']
        for field in required:
            if field not in data:
                return jsonify({'error': f'Missing field: {field}'}), 400

        conn = get_conn()

        # Get or create author
        row = conn.execute(
            "SELECT id FROM authors WHERE name = ?",
            (data['author'],)
        ).fetchone()

        if row is None:
            cur = conn.execute(
                "INSERT INTO authors (name) VALUES (?)",
                (data['author'],)
            )
            author_id = cur.lastrowid
        else:
            author_id = row['id']

        cur = conn.execute(
            "INSERT INTO books (title, author_id, year, genre, rating) "
            "VALUES (?, ?, ?, ?, ?)",
            (data['title'], author_id,
             data['year'], data['genre'], data['rating'])
        )
        conn.commit()
        new_id = cur.lastrowid
        conn.close()
        return jsonify({'message': 'Book added', 'id': new_id}), 201

    # ------------------------------------------------------------------ #
    # PUT /api/books/<id>
    # Body: any subset of {title, year, genre, rating}
    # ------------------------------------------------------------------ #
    @app.route('/api/books/<int:book_id>', methods=['PUT'])
    def update_book(book_id):
        data = request.get_json()
        if not data:
            return jsonify({'error': 'JSON body required'}), 400

        allowed = ['title', 'year', 'genre', 'rating']
        fields  = {k: v for k, v in data.items() if k in allowed}
        if not fields:
            return jsonify({'error': 'No valid fields to update'}), 400

        set_clause = ', '.join(f'{k} = ?' for k in fields)
        values     = list(fields.values()) + [book_id]

        conn = get_conn()
        conn.execute(
            f"UPDATE books SET {set_clause} WHERE id = ?", values
        )
        conn.commit()
        affected = conn.execute("SELECT changes()").fetchone()[0]
        conn.close()

        if affected == 0:
            return jsonify({'error': 'Book not found'}), 404
        return jsonify({'message': 'Book updated', 'id': book_id})

    # ------------------------------------------------------------------ #
    # DELETE /api/books/<id>
    # ------------------------------------------------------------------ #
    @app.route('/api/books/<int:book_id>', methods=['DELETE'])
    def delete_book(book_id):
        conn = get_conn()
        conn.execute("DELETE FROM books WHERE id = ?", (book_id,))
        conn.commit()
        affected = conn.execute("SELECT changes()").fetchone()[0]
        conn.close()
        if affected == 0:
            return jsonify({'error': 'Book not found'}), 404
        return jsonify({'message': 'Book deleted', 'id': book_id})

    # ------------------------------------------------------------------ #
    # GET /api/stats
    # ------------------------------------------------------------------ #
    @app.route('/api/stats', methods=['GET'])
    def get_stats():
        conn  = get_conn()
        total = conn.execute("SELECT COUNT(*) FROM books").fetchone()[0]
        avg   = conn.execute("SELECT ROUND(AVG(rating),2) FROM books").fetchone()[0]
        genres = conn.execute(
            "SELECT genre, COUNT(*) as count FROM books GROUP BY genre"
        ).fetchall()
        conn.close()
        return jsonify({
            'total_books'  : total,
            'average_rating': avg,
            'by_genre'     : [row_to_dict(r) for r in genres]
        })
