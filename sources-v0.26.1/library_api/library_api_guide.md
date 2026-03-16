# Library REST API — Test Guide

Base URL: `http://localhost:8117`

Start the server:
```bash
pip install flask bcrypt pyjwt
mojo library_api.mojo
```

---

## Auth

### Register
```bash
curl -s -X POST http://localhost:8117/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"ahmet","password":"secret123"}' | python3 -m json.tool
```

### Login — save token
```bash
TOKEN=$(curl -s -X POST http://localhost:8117/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"ahmet","password":"secret123"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

echo $TOKEN
```

---

## Books

### List all books (page 1, 5 per page)
```bash
curl -s "http://localhost:8117/api/books" | python3 -m json.tool
```

### Pagination
```bash
curl -s "http://localhost:8117/api/books?page=2&per_page=3" | python3 -m json.tool
```

### Search by title or author name
```bash
curl -s "http://localhost:8117/api/books?q=foundation" | python3 -m json.tool
```

### Filter by author
```bash
curl -s "http://localhost:8117/api/books?author_id=4" | python3 -m json.tool
```

### Filter by year range
```bash
curl -s "http://localhost:8117/api/books?min_year=1950&max_year=1953" | python3 -m json.tool
```

### Sort by rating descending
```bash
curl -s "http://localhost:8117/api/books?sort_by=rating&order=desc" | python3 -m json.tool
```

### Combine filters
```bash
curl -s "http://localhost:8117/api/books?q=the&min_year=1940&sort_by=year&order=asc" | python3 -m json.tool
```

### Get a single book
```bash
curl -s "http://localhost:8117/api/books/1" | python3 -m json.tool
```

### Create a book (JWT required)
```bash
curl -s -X POST http://localhost:8117/api/books \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "title"    : "The End of Eternity",
    "author_id": 4,
    "year"     : 1955,
    "rating"   : 8.4,
    "isbn"     : "978-0765319197"
  }' | python3 -m json.tool
```

### Update a book (JWT required)
```bash
curl -s -X PUT http://localhost:8117/api/books/8 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"rating": 8.7}' | python3 -m json.tool
```

### Delete a book (JWT required)
```bash
curl -s -X DELETE http://localhost:8117/api/books/8 \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

---

## Authors

### List all authors (with book count)
```bash
curl -s "http://localhost:8117/api/authors" | python3 -m json.tool
```

### Get author with their books
```bash
curl -s "http://localhost:8117/api/authors/4" | python3 -m json.tool
```

---

## Error responses

| Status | Meaning                        |
|--------|--------------------------------|
| 400    | Bad request / missing fields   |
| 401    | Unauthorized / invalid token   |
| 404    | Resource not found             |
| 409    | Conflict (duplicate username)  |

### Missing field error
```bash
curl -s -X POST http://localhost:8117/api/books \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"title":"No Author"}' | python3 -m json.tool
# {"error": "Missing required fields: author_id"}
```

### Invalid token error
```bash
curl -s -X DELETE http://localhost:8117/api/books/1 \
  -H "Authorization: Bearer invalidtoken" | python3 -m json.tool
# {"error": "Invalid token"}
```

### No token error
```bash
curl -s -X POST http://localhost:8117/api/books \
  -H "Content-Type: application/json" \
  -d '{"title":"Test"}' | python3 -m json.tool
# {"error": "Missing or invalid Authorization header"}
```

---

## Pagination envelope

```json
{
  "data": [ {...}, {...} ],
  "pagination": {
    "page"       : 1,
    "per_page"   : 5,
    "total"      : 7,
    "total_pages": 2,
    "has_prev"   : false,
    "has_next"   : true
  }
}
```
