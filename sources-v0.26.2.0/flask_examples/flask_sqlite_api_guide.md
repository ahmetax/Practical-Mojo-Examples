# Flask + SQLite REST API — Test Guide

This document is for testing the API initialized with `flask_sqlite_api.mojo`
Contains `curl` commands that can be used.

## Initialization

```bash
mojo flask_sqlite_api.mojo
```

Server starts running at `http://localhost:8117`.
If the `library.db` file does not exist, it will be created automatically and filled with sample data.

---

## Endpoints

### GET /api/books — List all books

```bash
curl http://localhost:8117/api/books
```

### GET /api/books/\<id\> — Get single book

```bash
curl http://localhost:8117/api/books/1
curl http://localhost:8117/api/books/3
```

### GET /api/books?genre=\<genre\> — Filter by genre

```bash
curl http://localhost:8117/api/books?genre=Sci-Fi
curl "http://localhost:8117/api/books?genre=Dystopia"
curl "http://localhost:8117/api/books?genre=Alt-History"
```

### GET /api/authors — List all authors

```bash
curl http://localhost:8117/api/authors
```

### GET /api/stats — Summary statistics

```bash
curl http://localhost:8117/api/stats
```

---

### POST /api/books — Add new book

```bash
curl -X POST http://localhost:8117/api/books \
  -H "Content-Type: application/json" \
  -d '{"title":"Neuromancer","author":"William Gibson","year":1984,"genre":"Sci-Fi","rating":4.6}'
```

If a new author is found, it will be created automatically.

Required fields: `title`, `author`, `year`, `genre`, `rating`

Successful response (HTTP 201):
```json
{"id": 11, "message": "Book added"}
```

---

### PUT /api/books/\<id\> — Update a book

You can update all fields or just a portion of them.

```bash
# Just update the rating.
curl -X PUT http://localhost:8117/api/books/1 \
  -H "Content-Type: application/json" \
  -d '{"rating": 4.9}'

# Update multiple fields
curl -X PUT http://localhost:8117/api/books/4 \
  -H "Content-Type: application/json" \
  -d '{"rating": 4.6, "genre": "Sci-Fi"}'
```

Updatable fields: `title`, `year`, `genre`, `rating`

---

### DELETE /api/books/\<id\> — Delete a book

```bash
curl -X DELETE http://localhost:8117/api/books/10
```

Successful response:
```json
{"id": 10, "message": "Book deleted"}
```

---

## Example Full Test Flow

```bash
# 1. Start the server (in a separate terminal)
mojo flask_sqlite_api.mojo

# 2. List all books
curl http://localhost:8117/api/books

# 3. Add new book
curl -X POST http://localhost:8117/api/books \
  -H "Content-Type: application/json" \
  -d '{"title":"Neuromancer","author":"William Gibson","year":1984,"genre":"Sci-Fi","rating":4.6}'

# 4. Retrieve the added book (assuming id=11)
curl http://localhost:8117/api/books/11

# 5. Update rating 
curl -X PUT http://localhost:8117/api/books/11 \
  -H "Content-Type: application/json" \
  -d '{"rating": 4.7}'

#6. Confirm the update
curl http://localhost:8117/api/books/11

# 7. Delete book
curl -X DELETE http://localhost:8117/api/books/11

# 8. Confirm deletion (404 expected)
curl http://localhost:8117/api/books/11

#9. View statistics
curl http://localhost:8117/api/stats
```

---

## Error Responses

| Status | HTTP Code | Response |
|---|---|---|
| Book not found | 404 | `{"error": "Book not found"}` |
| Missing JSON body | 400 | `{"error": "JSON body required"}` |
| Missing required field | 400 | `{"error": "Missing field: <field>"}` |
| Invalid field | 400 | `{"error": "No valid fields to update"}` |

---

## Notes

- The `library.db` file is preserved when the server is stopped and restarted.
Data is not duplicated thanks to `INSERT OR IGNORE`.
- To reset the database, delete the `library.db` file.
- Instead of `curl`, you can also use [Postman](https://www.postman.com/) or
[HTTPie](https://httpie.io/).

