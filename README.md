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

- [Security Configuration](docs/security.md) — Port mappings, firewall rules, security groups, network isolation
- [Cassandra Backup & Restore](docs/cassandra-backup.md) — Snapshot procedures, incremental strategy, automated backup/restore scripts
- [Cassandra CQL Queries](docs/cassandra-queries.md) — Complete CQL reference with INSERT, SELECT, UPDATE, BATCH, and time-range query examples

## Scaling

See [Scaling Guide](docs/scaling.md) for instructions on scaling backend instances, Cassandra nodes, and Redis cluster.

## API Endpoints

- `POST /api/v1/urls` - Create a new short URL
- `GET /:shortId` - Redirect to original URL
- `GET /health` - Health check endpoint

## License

MIT

## Testing

Run the local test suite to validate the entire stack:

### Prerequisites

- Docker and Docker Compose must be installed
- Ports 8080 (Nginx) and 3000-3002 (Backend) must be free

### Running Tests

**Linux / macOS:**
```bash
chmod +x scripts/test-local.sh
./scripts/test-local.sh
```

**Windows:**
```batch
scripts\test-local.bat
```

### Test Descriptions

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

### Expected Output

All tests print `PASS` or `FAIL` for each section. A passing run ends with:

```
[PASS] All 0.7.x tests passed successfully
```
