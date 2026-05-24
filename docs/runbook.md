# Operations Runbook

## Startup Sequence and Verification

### Step 1: Start all services
```bash
docker-compose up -d
```

### Step 2: Verify container status
```bash
docker-compose ps
```
All services should show `Up` status.

### Step 3: Check health endpoints
```bash
# Backend health (via load balancer)
curl http://localhost:8080/api/health

# Direct backend health
curl http://localhost:3000/health

# Readiness probe
curl http://localhost:3000/ready
```

### Step 4: Verify data layer
```bash
# Cassandra cluster status
docker exec cassandra nodetool status

# Redis connectivity
docker exec redis redis-cli ping
```

### Step 5: Verify end-to-end flow
```bash
# Create a short URL
curl -X POST http://localhost:8080/api/v1/urls \
  -H "Content-Type: application/json" \
  -d '{"original_url": "https://example.com/test"}'

# Follow the redirect
curl -v http://localhost:8080/<shortId>
```

## Health Check Interpretation

| Response | Meaning |
|----------|---------|
| `200 OK` with `{"status":"ok"}` | All components healthy |
| `503 Service Unavailable` | One or more components down |
| `Connection refused` | Backend process not running |

Check individual component status via `/health` response body:
```json
{
  "status": "ok",
  "timestamp": "2025-01-15T10:30:00Z",
  "components": {
    "cassandra": "connected",
    "redis": "connected"
  }
}
```

## Scaling Up/Down Procedures

### Scale backend instances
```bash
# Scale up to 5 instances
docker-compose up -d --scale backend=5

# Scale down to 2 instances
docker-compose up -d --scale backend=2
```

### Verify scaling
```bash
docker ps --filter "name=backend"
curl http://localhost:8080/api/health
```

Refer to [Scaling Guide](scaling.md) for detailed instructions on scaling Cassandra and Redis.

## Backup and Restore Steps

### Create backup
```bash
./scripts/cassandra-backup.sh
```

### Restore from backup
```bash
./scripts/cassandra-restore.sh /backups/20250101_020000
```

Refer to [Cassandra Backup Guide](cassandra-backup.md) for detailed instructions.

## Incident Response Procedures

### Severity Levels

| Level | Response Time | Examples |
|-------|--------------|----------|
| SEV-1 | 15 minutes | Service down, data loss |
| SEV-2 | 30 minutes | High error rates, partial outage |
| SEV-3 | 4 hours | Minor issues, single instance failure |
| SEV-4 | Next business day | Informational |

### Response Steps

1. **Acknowledge** — Confirm alert and assess severity
2. **Contain** — Isolate affected components
3. **Diagnose** — Review logs and metrics
4. **Resolve** — Apply fix or workaround
5. **Verify** — Confirm service恢复正常
6. **Document** — Log timeline and actions taken

## Common Alert Resolution Steps

### Alert: High Error Rate (>1%)

```bash
# Check recent error logs
docker-compose logs --tail=100 backend | grep "ERROR"

# Check nginx error rate
docker-compose logs --tail=100 nginx | grep " 5[0-9][0-9]"

# Restart backend if needed
docker-compose restart backend
```

### Alert: Backend Instance Down

```bash
# List all backend containers
docker ps --filter "name=backend"

# Check health of unhealthy instance
docker inspect --format '{{.State.Health.Status}}' <container_name>

# Restart the unhealthy instance
docker-compose restart <container_name>
```

### Alert: High Latency (P95 > 100ms)

```bash
# Check Cassandra query latency
docker-compose logs --tail=50 backend | grep "cassandra_query"

# Check if Cassandra is under load
docker exec cassandra nodetool compactionstats
docker exec cassandra nodetool tpstats

# Check Redis latency
docker exec redis redis-cli --latency
```

### Alert: Low Cache Hit Rate (<50%)

```bash
# Check cache metrics
curl http://localhost:3000/metrics | grep cache_

# Check Redis memory usage
docker exec redis redis-cli INFO memory

# Consider increasing cache TTL or Redis memory limit
```

### Alert: Disk Usage >80%

```bash
# Check disk usage (requires node_exporter or docker system df)
docker system df

# Clean up unused Docker resources
docker system prune -f

# Remove old backup files
find /backups -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \;
```