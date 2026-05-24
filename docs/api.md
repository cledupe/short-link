# API Documentation

## Base URL
`http://localhost:8080`

## Endpoints

### POST /api/v1/urls
Create a new short URL.

**Request:**
```json
{
  "original_url": "https://example.com/very/long/url"
}
```

**Response (201 Created):**
```json
{
  "short_url": "http://localhost:8080/abc123"
}
```

**Response (200 OK - duplicate):**
```json
{
  "short_url": "http://localhost:8080/abc123",
  "existing": true
}
```

**Response (400 Bad Request):**
```json
{
  "error": "Invalid URL format"
}
```

### POST /api/v1/urls/batch
Create multiple short URLs at once.

**Request:**
```json
{
  "urls": [
    "https://example.com/1",
    "https://example.com/2"
  ]
}
```

**Response:**
```json
{
  "results": [
    { "original_url": "https://example.com/1", "short_url": "http://localhost:8080/abc123" },
    { "original_url": "https://example.com/2", "short_url": "http://localhost:8080/def456" }
  ]
}
```

### GET /:shortId
Redirect to the original URL.

**Response:** 302 Redirect with `Location` header.

### DELETE /api/v1/urls/:shortId
Delete a short URL.

**Response:** 200 OK

### GET /health
Health check endpoint.

### GET /ready
Readiness probe.

### GET /metrics
Prometheus metrics endpoint.

## Rate Limiting
- 100 requests per minute per IP
- Returns 429 Too Many Requests when exceeded

## Error Codes
| Status | Description |
|--------|-------------|
| 200 | Success (duplicate URL) |
| 201 | Created |
| 302 | Redirect |
| 400 | Bad Request |
| 404 | Not Found |
| 429 | Too Many Requests |
| 500 | Internal Server Error |