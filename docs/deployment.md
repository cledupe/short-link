# Deployment Procedures

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (20.10+)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2+)
- Git

## Environment Setup

### 1. Clone the repository
```bash
git clone <repository-url>
cd url-shortener
```

### 2. Create environment file
```bash
cp .env.example .env
```

### 3. Configure environment variables
Edit `.env` with your environment-specific values:

```env
CASSANDRA_NODES=cassandra
REDIS_URL=redis://redis:6379
PORT=3000
```

| Variable | Description | Default |
|----------|-------------|---------|
| `CASSANDRA_NODES` | Cassandra contact points | `cassandra` |
| `REDIS_URL` | Redis connection URL | `redis://redis:6379` |
| `PORT` | Backend server port | `3000` |

### 4. Configure SSL (optional)
For production with HTTPS, generate certificates:

```bash
chmod +x scripts/generate-ssl-certs.sh
./scripts/generate-ssl-certs.sh
```

## Build and Deploy

### Standard deployment
```bash
# Build and start all services
docker-compose up -d

# View startup logs
docker-compose logs -f
```

### With SSL (production)
```bash
docker-compose -f docker-compose.yml -f docker-compose.ssl.yml up -d
```

### Rebuild after code changes
```bash
docker-compose build backend
docker-compose up -d
```

## Verification Steps After Deployment

### 1. Check all containers are running
```bash
docker-compose ps
```

### 2. Verify health endpoints
```bash
curl http://localhost:8080/api/health
curl http://localhost:8080/api/ready
```

### 3. Test end-to-end flow
```bash
# Create a URL
curl -X POST http://localhost:8080/api/v1/urls \
  -H "Content-Type: application/json" \
  -d '{"original_url": "https://example.com/verify"}'

# Follow redirect
curl -v http://localhost:8080/<shortId>
```

### 4. Verify monitoring endpoints
```bash
curl http://localhost:3000/metrics
```

### 5. Check Cassandra cluster
```bash
docker exec cassandra nodetool status
```

### 6. Check Redis
```bash
docker exec redis redis-cli ping
docker exec redis redis-cli GET url:counter
```

## Rolling Update Procedure

### Backend update (zero-downtime)
```bash
# Build new image
docker-compose build backend

# Recreate instances one at a time
docker-compose up -d --no-deps --scale backend=1 --no-recreate backend
sleep 5

# Scale back up
docker-compose up -d --no-deps --scale backend=3 backend
```

### Configuration update (nginx, compose)
```bash
# Update config file, then reload service
docker-compose restart nginx
```

## Rollback Procedure

### Full rollback to previous state
```bash
# Stop all services
docker-compose down

# Revert code
git checkout <previous-stable-tag>

# Rebuild and deploy
docker-compose up -d --build
```

### Quick rollback (backend only)
```bash
# If using a previous image tag
docker-compose up -d backend:<previous-tag>
```