# Distributed URL Shortener

## Overview

High-performance, distributed URL shortening service built with Node.js, Cassandra, Redis, and Vue.js. Designed for horizontal scaling, sub-10ms cached lookups, and 10k+ req/s throughput.

## Architecture

```
┌─────────────┐
│   Nginx     │  Load Balancer (Port 8080)
│   (LB)      │  Serves Vue.js SPA + proxies /api
└──────┬──────┘
       │
       ├──► Backend (Node.js) x3  (Ports 3000-3002)
       │      │
       │      ├──► Cassandra Cluster (3 nodes, RF=3)
       │      └──► Redis Cluster (Cache + Atomic Counter)
       │
       └──► Frontend (Vue.js SPA via CDN/Nginx)
```

## Current State

- Docker Compose skeleton defined (Cassandra, Redis, Backend, Nginx, Frontend)
- Backend Dockerfile created (Node.js 18 Alpine)
- Frontend directory initialized
- OpenSpec proposal and 15-section task plan created
- README with architecture diagram and quick-start guide

**Not yet implemented:**
- Backend source code (server.js, routes, models)
- Frontend Vue.js components
- Nginx configuration (nginx.conf)
- Cassandra schema (keyspace, tables)
- Redis integration (cache + INCR counter)
- Encryption service (AES-256-GCM)
- Base62 encoding / distributed counter
- Health checks and load balancer wiring

## Target Architecture

### Services

| Service   | Role                                   | Scale |
|-----------|----------------------------------------|-------|
| nginx     | Load balancer, static file server      | 1     |
| backend   | Node.js API (REST)                     | 3+    |
| cassandra | NoSQL storage (url_mappings, metadata) | 3+    |
| redis     | Cache (TTL 24h) + atomic ID counter    | 3+    |
| frontend  | Vue.js SPA (no auth)                   | 1     |

### Data Flow

1. **Create URL:** `POST /api/v1/urls`
   - Validate URL → Redis INCR (unique ID) → base62 encode → AES-256-GCM encrypt → Cassandra write → Redis cache
2. **Redirect:** `GET /:shortId`
   - Redis cache lookup → (miss) Cassandra query → decrypt → 302 redirect → update visit_count

### Key Design Decisions

- **Dual-purpose Redis:** cache for hot URLs AND atomic counter via `INCR`
- **Encryption at rest:** all original URLs encrypted with AES-256-GCM + per-row IV
- **No authentication:** simple public SPA; rate-limit by IP (100 req/min)
- **Docker-first:** entire stack runnable locally via `docker-compose up --scale backend=3`

## Tech Stack

- **Runtime:** Node.js 18 (Alpine)
- **Frontend:** Vue.js 3 (CDN), HTML5
- **Database:** Cassandra 4.1 (GossipingPropertyFileSnitch)
- **Cache/Counter:** Redis 7 (cluster mode, AOF)
- **Load Balancer:** Nginx (least-connections)
- **Crypto:** Node.js `crypto` (AES-256-GCM)
- **Ops:** Docker, Docker Compose, Prometheus, Grafana (future)

## Project Structure

```
.
├── docker-compose.yml      # Full stack orchestration
├── Dockerfile              # Backend image
├── nginx.conf              # LB + static asset rules
├── backend/
│   ├── server.js           # Entry point
│   ├── package.json
│   └── src/                # Routes, models, crypto, counter
├── frontend/
│   ├── index.html
│   ├── App.vue
│   └── ...
└── openspec/               # Change tracking (proposal, design, tasks)
```

## Development Notes

- Use `.env` for `ENCRYPTION_KEY` (32 chars); never commit secrets
- Scale backend: `docker-compose up --scale backend=3`
- Scale Cassandra: `docker-compose up --scale cassandra=3`
- All services attach to `url_shortener_net` bridge network
- Named volumes: `cassandra_data`, `redis_data`
