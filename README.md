# Distributed URL Shortener

A high-performance, distributed URL shortening service built with Docker, Cassandra, Redis, and Vue.js.

## Architecture

```
┌─────────────┐
│   Nginx     │ (Load Balancer - Port 8080)
│   (LB)      │
└──────┬──────┘
       │
       ├──► Backend (Node.js) x3 (Ports 3000-3002)
       │      │
       │      ├──► Cassandra Cluster (3 nodes)
       │      └──► Redis Cluster (Cache + Counter)
       │
       └──► Frontend (Vue.js SPA)
```

## Project Structure

```
.
├── docker-compose.yml      # Docker Compose configuration for all services
├── Dockerfile              # Backend application Dockerfile
├── nginx.conf              # Nginx load balancer configuration
├── .env                    # Environment variables (not in git)
├── .env.example            # Environment variables template
├── .dockerignore           # Docker build exclusions
├── README.md               # This file
├── DEPENDENCIES.md         # Section dependencies and execution order
│
├── backend/                # Backend Node.js application
│   ├── package.json        # Dependencies
│   ├── server.js           # Main application entry point
│   └── ...                 # Application source files
│
├── frontend/               # Vue.js frontend application
│   ├── index.html          # Main HTML file
│   ├── App.vue             # Vue component
│   └── ...                 # Frontend source files
│
├── docs/                   # Documentation
│   ├── security.md         # Security configuration and best practices
│   ├── scaling.md          # Scaling guide
│   ├── cassandra-backup.md # Cassandra backup procedures  
│   └── cassandra-queries.md # Cassandra CQL query examples
│
├── ssl/                    # SSL certificates (not committed)
│   └── .gitkeep            # Ensures directory exists in repo
│
├── scripts/                # Utility scripts
│   ├── verify-health.sh   # Health endpoint verification
│   ├── deploy-scale.sh    # Deploy and scale backend instances
│   ├── test-local.sh       # Local integration test suite
│   ├── test-local.bat      # Local test suite (Windows)
│   └── generate-ssl-certs.sh  # Self-signed SSL cert generator
│
├── nginx.conf              # Nginx config (HTTP)
├── nginx-ssl.conf          # Nginx config (HTTPS with TLS)
├── docker-compose.yml      # Base Docker Compose configuration
├── docker-compose.ssl.yml  # Docker Compose SSL override
│
└── openspec/               # OpenSpec change tracking
    └── changes/
        └── distributed-url-shortener/
            ├── proposal.md
            ├── design.md
            ├── specs/
            └── tasks.md
```

## Services

| Service     | Description                          | Port(s)           |
|-------------|--------------------------------------|-------------------|
| nginx       | Load balancer for API and frontend   | 8080 (host:80)    |
| backend     | Node.js API server (scale: 3)        | 3000 (container)  |
| cassandra   | NoSQL database cluster (scale: 3)    | Internal only     |
| redis       | Cache and atomic counter (cluster)   | Internal only     |
| frontend    | Vue.js single-page application       | Served by nginx   |

## Quick Start

### Prerequisites

- Docker
- Docker Compose

### Running the Application

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Scale backend to 3 instances
docker-compose up --scale backend=3

# Stop all services
docker-compose down
```

### Environment Variables

Create a `.env` file in the project root (see `.env.example`):

```env
CASSANDRA_NODES=cassandra
REDIS_URL=redis://redis:6379
PORT=3000
```

| Variable         | Description                                | Default                       |
|------------------|--------------------------------------------|-------------------------------|
| `CASSANDRA_NODES`| Cassandra node addresses                   | `cassandra`                   |
| `REDIS_URL`      | Redis connection URL                       | `redis://redis:6379`          |
| `PORT`           | Backend server port                        | `3000`                        |

## Documentation

See the `docs/` directory for detailed documentation:

- [API Reference](docs/api.md) — Complete API documentation with request/response examples and error codes
- [Deployment Guide](docs/deployment.md) — Build, deploy, rolling update, and rollback procedures
- [Operations Runbook](docs/runbook.md) — Startup sequence, incident response, and alert resolution
- [Troubleshooting Guide](docs/troubleshooting.md) — Common issues, log checking, and recovery steps
- [Security Configuration](docs/security.md) — Port mappings, firewall rules, security groups, network isolation
- [Monitoring & Observability](docs/monitoring.md) — Prometheus metrics, Grafana dashboards, and alert rules
- [Scalability Guide](docs/scaling.md) — Scaling backend, Cassandra, and Redis
- [Redis Key Conventions](docs/redis-keys.md) — Key naming, TTL, memory configuration
- [Cassandra CQL Queries](docs/cassandra-queries.md) — Complete CQL reference with INSERT, SELECT, UPDATE, BATCH, and time-range query examples
- [Cassandra Backup & Restore](docs/cassandra-backup.md) — Snapshot procedures, incremental strategy, automated backup/restore scripts

## Scaling

See [Scaling Guide](docs/scaling.md) for instructions on scaling backend instances, Cassandra nodes, and Redis cluster.

## API Endpoints

- `POST /api/v1/urls` - Create a new short URL
- `GET /:shortId` - Redirect to original URL
- `GET /health` - Health check endpoint

## License

MIT

## Testing

### Prerequisites

- Docker and Docker Compose must be installed
- Ports 8080 (Nginx) and 3000-3002 (Backend) must be free

### Local Infrastructure Tests

Run the local test suite to validate container startup, service communication, and basic E2E flow:

**Linux / macOS:**
```bash
chmod +x scripts/test-local.sh
./scripts/test-local.sh
```

**Windows:**
```batch
scripts\test-local.bat
```

### E2E Tests (Section 9)

Comprehensive end-to-end tests covering URL creation, redirect, rate limiting, batch creation, invalid input handling, and concurrent access:

```bash
chmod +x scripts/test-e2e.sh
./scripts/test-e2e.sh
```

Configuration:
- `BASE_URL` environment variable to target a different host (default: `http://localhost:8080`)

### Load Tests

Simple curl-based concurrency test measuring throughput and latency:

```bash
chmod +x scripts/test-load.sh
./scripts/test-load.sh
```

Configuration:
- `BASE_URL` — target host (default: `http://localhost:8080`)
- `CONCURRENCY` — parallel requests (default: 10)
- `TOTAL_REQUESTS` — requests per phase (default: 100)
- `VERIFY_URL` — pre-created short ID for GET tests (optional, auto-created if empty)

### Test Descriptions

#### Local Tests (0.7.x)

| Test | Section | Verifies |
|------|---------|----------|
| 0.7.1 | Container Startup | `docker-compose up` starts all services without errors |
| 0.7.2 | Cassandra Cluster | Cassandra nodes discover each other and form a cluster |
| 0.7.3 | Redis Connectivity | Backend instances can connect to Redis via `redis-cli ping` |
| 0.7.4 | Backend Health | Backend `/health` endpoint confirms Cassandra + Redis are reachable |
| 0.7.5 | Vue.js UI | `http://localhost:8080` returns HTTP 200 with the SPA |
| 0.7.6 | End-to-End Flow | POST a URL → receive shortId → GET redirect resolves correctly |
| 0.7.7 | Data Persistence | Stop/restart containers; previously created short URL still resolves |
| 0.7.8 | Horizontal Scaling | `--scale backend=3` launches 3 instances; all report healthy |
| 0.7.9 | Log Monitoring | `docker-compose logs -f` shows inter-service communication (manual) |

#### E2E Tests (9.x)

| Test | Section | Verifies |
|------|---------|----------|
| 9.1 | Test Environment | Health checks: backend, frontend, Redis, Cassandra connectivity |
| 9.2 | Create + Redirect | POST `/api/v1/urls` → 201, GET `/:shortId` → 302 with correct Location |
| 9.3 | Cache Miss | Clear Redis cache, GET still returns 302 (Cassandra fallback) |
| 9.4 | Concurrent GETs | 5 parallel requests for same shortId all return 302 |
| 9.6 | Concurrent POSTs | 10 parallel URL creations produce 10 unique shortIds |
| 9.10 | Rate Limiting | 110 rapid requests; some return 429 |
| 9.11 | Invalid URLs | Empty body, malformed string, missing scheme, null, non-string all return 400 |
| 9.12 | Batch Creation | POST `/api/v1/urls/batch` with 5 URLs → 201 with 5 entries; all redirect correctly |

### Expected Output

All tests print `PASS` or `FAIL` for each section. A passing E2E run ends with:

```
[PASS] All tests passed: 19 passed, 0 failed
```

A passing load test ends with:

```
[PASS] Load test completed without server errors
```
