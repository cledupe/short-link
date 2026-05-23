# Distributed URL Shortener — Claude Context

## What This Is

A production-grade, distributed URL shortener. Node.js backend, Vue.js frontend, Cassandra for persistence, Redis for caching and atomic ID generation. Runs entirely in Docker Compose for local simulation.

## Architecture

```
User → Nginx (8080) → Backend (Node.js) x3
              ↓              ↓
         Frontend      Cassandra (3 nodes)
         (Vue.js)      Redis (cache + counter)
```

Nginx serves the Vue.js SPA and proxies `/api` to the backend pool. Redis has two roles: hot URL cache (24h TTL) and atomic counter (`INCR`) for collision-free short ID generation. Cassandra stores encrypted URLs with replication factor 3.

## Current State

**Done:**
- Docker Compose file with all services defined
- Backend Dockerfile (Node.js 18 Alpine)
- Frontend directory scaffolded
- OpenSpec proposal and 15-section task breakdown
- README with quick-start and architecture diagram

**Missing:**
- `backend/server.js` and all source modules
- `frontend/index.html`, `App.vue`
- `nginx.conf`
- Cassandra CQL schema
- Redis client integration
- AES-256-GCM encryption layer
- Base62 encoder / distributed counter logic
- Health check endpoints

## How It Will Work

### URL Creation
`POST /api/v1/urls` → validate → Redis INCR → base62 → encrypt → Cassandra write → cache in Redis → return 201

### Redirection
`GET /:shortId` → Redis get → (miss) Cassandra read → decrypt → 302 redirect → increment visit counter

### Security
- AES-256-GCM with random 12-byte IV per URL
- Encryption key from `ENCRYPTION_KEY` env var
- Rate limit: 100 req/min per IP
- Input validation on all URLs

## Key Files to Create

| File | Purpose |
|------|---------|
| `backend/server.js` | Express/Fastify entry, routes, middleware |
| `backend/src/crypto.js` | AES-256-GCM encrypt/decrypt |
| `backend/src/counter.js` | Redis INCR + base62 |
| `backend/src/db.js` | Cassandra driver setup |
| `backend/src/cache.js` | Redis get/set with TTL |
| `frontend/index.html` | Vue 3 SPA shell |
| `frontend/App.vue` | URL input, result, copy-to-clipboard |
| `nginx.conf` | Upstream backend, static root, CORS |

## Conventions

- Use `async/await` for all I/O (Cassandra, Redis)
- Return JSON with consistent shape: `{ success, data, error }`
- Cache misses must log and populate Redis
- All errors return appropriate HTTP status codes
- Keep business logic pure; isolate side effects in driver modules
- Docker-first: every service must start cleanly with `docker-compose up`
