# Production Deployment Guide

This document outlines the complete production deployment process for the distributed URL shortener, including infrastructure provisioning, canary rollout strategy, monitoring, backup configuration, and CI/CD pipeline setup.

---

## Table of Contents

- [Infrastructure Requirements](#infrastructure-requirements)
- [Environment Preparation](#environment-preparation)
- [Security Configuration](#security-configuration)
- [Deployment Steps](#deployment-steps)
- [Canary Release Strategy](#canary-release-strategy)
- [Monitoring During Rollout](#monitoring-during-rollout)
- [Rollback Procedures](#rollback-procedures)
- [Backup Configuration](#backup-configuration)
- [CI/CD Pipeline](#cicd-pipeline)

---

## Infrastructure Requirements

### Cassandra Cluster (3 nodes)

| Node   | Spec                  | Storage  | Network     |
|--------|-----------------------|----------|-------------|
| node-1 | 4 vCPU, 16 GB RAM     | 100 GB SSD | 1 Gbps    |
| node-2 | 4 vCPU, 16 GB RAM     | 100 GB SSD | 1 Gbps    |
| node-3 | 4 vCPU, 16 GB RAM     | 100 GB SSD | 1 Gbps    |

- **Replication factor:** 3
- **Consistency level:** QUORUM for reads/writes
- **Compaction:** LeveledCompactionStrategy
- **Backup:** Daily snapshots to object storage, 30-day retention

### Redis Cluster (3 nodes)

| Node   | Spec                  | Storage  | Network     |
|--------|-----------------------|----------|-------------|
| node-1 | 2 vCPU, 8 GB RAM      | 20 GB SSD  | 1 Gbps    |
| node-2 | 2 vCPU, 8 GB RAM      | 20 GB SSD  | 1 Gbps    |
| node-3 | 2 vCPU, 8 GB RAM      | 20 GB SSD  | 1 Gbps    |

- **Persistence:** AOF (append-only file) with fsync every second
- **Eviction:** allkeys-lru
- **Max memory:** 6 GB per node (75% of total)

### Load Balancer (Nginx)

| Spec              | Value            |
|-------------------|------------------|
| Instance type     | 2 vCPU, 4 GB RAM |
| Algorithm         | least_connections |
| SSL termination   | Yes              |
| Health checks     | /health every 30s |

### Application Servers (minimum 3)

| Spec              | Value            |
|-------------------|------------------|
| Instance type     | 2 vCPU, 4 GB RAM |
| Container runtime | Docker           |
| Instances         | 3 (scalable)     |
| Port              | 3000             |

---

## Environment Preparation

### 1. Clone Repository

```bash
git clone <repository-url>
cd url-shortener
git checkout <release-tag>
```

### 2. Configure Environment Variables

Create `.env` with production values:

```env
# Cassandra
CASSANDRA_NODES=cassandra-node1,cassandra-node2,cassandra-node3
CASSANDRA_KEYSPACE=url_shortener
CASSANDRA_REPLICATION_FACTOR=3

# Redis
REDIS_URL=redis://redis-node1:6379
REDIS_CLUSTER_MODE=true

# Application
NODE_ENV=production
PORT=3000
LOG_LEVEL=info

# Rate Limiting
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX_REQUESTS=100
```

### 3. Initialize Cassandra Schema

```bash
cqlsh cassandra-node1 -f scripts/init-cassandra.cql
```

### 4. Verify Connectivity

```bash
# Test Cassandra
cqlsh cassandra-node1 -e "SELECT * FROM system.peers;"

# Test Redis
redis-cli -h redis-node1 ping

# Test app health
curl http://localhost:3000/health
```

---

## Security Configuration

### Firewall Rules

| Source         | Destination  | Port(s)        | Protocol | Purpose          |
|----------------|--------------|----------------|----------|------------------|
| Internet       | LB           | 80, 443        | TCP      | Web traffic      |
| LB             | App nodes    | 3000           | TCP      | API traffic      |
| App nodes      | Cassandra    | 9042           | TCP      | CQL queries      |
| App nodes      | Redis        | 6379           | TCP      | Cache/counter    |
| App nodes      | Cassandra    | 7000, 7001     | TCP      | Inter-node comm  |
| Cassandra      | Cassandra    | 7000, 7001     | TCP      | Gossip/replication |
| Admin IPs      | All nodes    | 22             | TCP      | SSH (restricted) |
| Monitoring     | All nodes    | 9100, 3000     | TCP      | Metrics scraping |

### SSL/TLS Certificates

```bash
# Obtain Let's Encrypt cert for load balancer
certbot --nginx -d shortlink.example.com

# Auto-renewal cron (daily)
0 3 * * * certbot renew --quiet --post-hook "systemctl reload nginx"
```

### Application Security Headers

Configured in Nginx:

```nginx
add_header X-XSS-Protection "1; mode=block";
add_header X-Frame-Options "DENY";
add_header X-Content-Type-Options "nosniff";
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";
add_header Content-Security-Policy "default-src 'self'";
```

---

## Deployment Steps

### Step 1: Provision Infrastructure

```bash
# Using cloud provider CLI or Terraform
terraform apply -auto-approve

# Verify all nodes are healthy
./scripts/verify-infra.sh
```

### Step 2: Deploy Cassandra Schema

```bash
./scripts/deploy-schema.sh
```

### Step 3: Build and Push Docker Image

```bash
docker build -t registry.example.com/url-shortener:${TAG} .
docker push registry.example.com/url-shortener:${TAG}
```

### Step 4: Deploy Application

```bash
# Pull and run on each app node
docker pull registry.example.com/url-shortener:${TAG}
docker run -d --name url-shortener \
  --restart=always \
  -p 3000:3000 \
  --env-file .env \
  registry.example.com/url-shortener:${TAG}
```

### Step 5: Deploy Nginx Configuration

```bash
scp nginx.conf lb-node:/etc/nginx/nginx.conf
ssh lb-node "nginx -t && systemctl reload nginx"
```

### Step 6: Verify Deployment

```bash
# Health check
curl https://shortlink.example.com/health

# Smoke test: create a URL
curl -X POST https://shortlink.example.com/api/v1/urls \
  -H "Content-Type: application/json" \
  -d '{"original_url":"https://example.com/test"}'

# Smoke test: redirect
curl -v https://shortlink.example.com/abc123
```

---

## Canary Release Strategy

The canary release gradually shifts traffic to the new version while monitoring for errors and performance degradation.

### Phase 1: 5% Traffic (24h monitoring)

```nginx
# Nginx canary config — 5% of traffic to new backend
upstream backend-stable {
    server app-node1:3000 weight=95;
    server app-node2:3000 weight=95;
    server app-node3:3000 weight=95;
}

upstream backend-canary {
    server app-node4:3000 weight=5;
    server app-node5:3000 weight=5;
}
```

**Validation criteria:**
- Error rate < 0.1%
- p95 latency < 100ms
- Cache hit rate > 80%
- No 5xx errors from canary nodes

### Phase 2: 25% Traffic (48h monitoring after Phase 1)

Adjust weights to 75/25 split. Same validation criteria as Phase 1.

### Phase 3: 50% Traffic (48h monitoring after Phase 2)

Adjust weights to 50/50 split.

### Phase 4: 100% Traffic (after 1 week of stable monitoring)

Move all traffic to new version and decommission old nodes.

### Endpoint-Specific Phasing

1. **URL creation endpoint** (POST /api/v1/urls):
   - Start at 5% → 25% → 50% → 100%

2. **URL redirection endpoint** (GET /:shortId):
   - Start at 5% (after creation is at 100%) → ramp to 100%
   - Separate phasing because redirection has higher traffic volume

---

## Monitoring During Rollout

### Key Metrics to Watch

| Metric              | Warning      | Critical    | Action                                    |
|---------------------|--------------|-------------|-------------------------------------------|
| Error rate (5xx)    | > 0.5%      | > 1%        | Pause rollout, investigate                |
| p95 latency         | > 80ms      | > 150ms     | Check resource utilization, scale up      |
| Cache hit rate      | < 70%       | < 50%       | Review cache TTL and eviction policy      |
| CPU usage           | > 70%       | > 90%       | Add more instances or upgrade             |
| Memory usage        | > 75%       | > 90%       | Check for leaks, add memory               |
| Disk usage          | > 70%       | > 85%       | Clean up logs, expand storage             |
| Cassandra latency   | > 50ms      | > 100ms     | Check compaction, optimize queries        |

### Automated Rollback Triggers

The CI/CD pipeline automatically rolls back if any of the following occur within 10 minutes of deployment:

- Error rate exceeds 1% for > 2 consecutive minutes
- p99 latency exceeds 200ms for > 5 consecutive minutes
- Health check fails on > 2 consecutive attempts
- Any node reports "unhealthy" status

---

## Rollback Procedures

### Quick Rollback (Docker-based)

```bash
# Stop current version
docker stop url-shortener && docker rm url-shortener

# Run previous version
docker run -d --name url-shortener \
  --restart=always \
  -p 3000:3000 \
  --env-file .env \
  registry.example.com/url-shortener:${PREVIOUS_TAG}
```

### Full Rollback (Infrastructure)

```bash
# Revert Nginx config to previous version
scp nginx.conf.bak lb-node:/etc/nginx/nginx.conf
ssh lb-node "nginx -t && systemctl reload nginx"

# Revert application on all nodes
for node in app-node1 app-node2 app-node3; do
  ssh $node "docker stop url-shortener && docker rm url-shortener"
  ssh $node "docker run -d --name url-shortener -p 3000:3000 --env-file .env registry.example.com/url-shortener:${PREVIOUS_TAG}"
done

# Verify rollback
curl https://shortlink.example.com/health
```

### Database Rollback

Cassandra schema changes are forward-compatible. If a rollback is needed:

1. Restore from snapshot (see [Cassandra Backup](cassandra-backup.md))
2. Verify data integrity with `nodetool verify`

---

## Backup Configuration

### Cassandra Backups

**Frequency:** Daily (full snapshot) + incremental (every 6 hours)
**Retention:** 30 days
**Destination:** Object storage (S3-compatible)

```bash
# crontab entry — daily snapshot at 2 AM
0 2 * * * /opt/scripts/cassandra-backup.sh >> /var/log/backup.log 2>&1

# crontab entry — incremental every 6 hours
0 6,12,18 * * * /opt/scripts/cassandra-incremental.sh >> /var/log/backup.log 2>&1
```

### Redis Backups

**Frequency:** Every 6 hours (AOF rewrite + dump.rdb copy)
**Retention:** 7 days
**Destination:** Object storage

```bash
# AOF rewrite (triggers automatically by Redis)
# Copy dump.rdb to backup storage
0 */6 * * * cp /var/lib/redis/dump.rdb /backups/redis/dump-$(date +\%Y\%m\%d\%H\%M).rdb
```

### Backup Verification

```bash
# Monthly restore test
0 0 1 * * /opt/scripts/test-restore.sh >> /var/log/restore-test.log 2>&1
```

### Disaster Recovery

| Scenario                | RPO       | RTO        | Action                                  |
|-------------------------|-----------|------------|-----------------------------------------|
| Single node failure     | 0         | < 5 min    | Auto-replace via orchestrator           |
| Multi-node failure      | < 1 hour  | < 2 hours  | Restore from snapshots                  |
| Full region failure     | < 24 hours| < 4 hours  | Deploy to secondary region, restore     |
| Data corruption         | < 24 hours| < 2 hours  | Point-in-time recovery from backups     |

---

## CI/CD Pipeline

### GitHub Actions Workflow

The CI/CD pipeline is defined in `.github/workflows/deploy.yml` and is triggered by version tags (`v*`).

**Pipeline stages:**

1. **Checkout** — Clone repository at tag
2. **Build** — Build Docker image with tag label
3. **Test** — Run integration/E2E tests
4. **Push** — Push image to container registry
5. **Deploy** — Deploy to production (staged rollout)

### Pre-Deployment Checks

```bash
# Lint check
npm run lint

# Unit tests
npm test

# Integration tests
docker-compose up -d && ./scripts/test-e2e.sh && docker-compose down

# Security scan
docker scan registry.example.com/url-shortener:${TAG}
```

### Post-Deployment Checks

```bash
# Health check
curl -f https://shortlink.example.com/health

# Smoke test
./scripts/smoke-test.sh

# Metrics check
./scripts/check-metrics.sh --error-rate --latency-p95
```