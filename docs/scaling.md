# Scaling Guide

This document explains how to scale each service in the distributed URL shortener stack.

---

## Table of Contents

- [Backend Instances](#backend-instances)
- [Cassandra Cluster](#cassandra-cluster)
- [Redis Cluster](#redis-cluster)
- [Monitoring Scaling Health](#monitoring-scaling-health)
- [Troubleshooting](#troubleshooting)

---

## Backend Instances

The Node.js API server is stateless and scales horizontally. Each instance connects to the same Cassandra and Redis backends.

### Scale Up

```bash
docker-compose up -d --scale backend=3
```

Increase the number to scale further:

```bash
docker-compose up -d --scale backend=5
```

Docker Compose DNS automatically resolves the `backend` hostname to all container IPs. Nginx's `least_conn` algorithm distributes requests across all available instances.

### Scale Down

```bash
docker-compose up -d --scale backend=1
```

### Verify Scaling

```bash
# Check container count
docker ps --filter "name=backend"

# Check health of all instances
curl http://localhost:8080/api/health

# View per-instance logs
docker-compose logs backend
```

### Zero-Downtime Rolling Deploy (Future Enhancement)

For production, replace `docker-compose` scaling with a rolling update strategy:

1. Deploy new image to a subset of instances
2. Wait for health checks to pass
3. Remove old instances

---

## Cassandra Cluster

Cassandra is natively designed for horizontal scaling. The compose file configures a single seed node.

> **Important:** The current setup uses a single container. Multi-node Cassandra clusters require careful seed node configuration and `CASSANDRA_SEEDS` updates.

### Recommended Approach

1. **Build a custom image** with pre-configured `cassandra-rackdc.properties` and `cassandra.yaml`
2. **Scale via Docker Compose:**
   ```bash
   docker-compose up -d --scale cassandra=3
   ```
3. **Verify the cluster:**
   ```bash
   docker exec cassandra nodetool status
   ```

### Seed Node Configuration

When scaling Cassandra:

1. Set `CASSANDRA_SEEDS` to a comma-separated list of seed node DNS names
2. Ensure all nodes share the same `CASSANDRA_CLUSTER_NAME`
3. Use `GossipingPropertyFileSnitch` for multi-datacenter deployments

### Data Distribution

- Keyspace `url_shortener` uses `SimpleStrategy` with `RF=3`
- Each node stores a replica of every row
- On node failure, Cassandra serves from remaining replicas

---

## Redis Cluster

Redis runs in cluster mode with AOF persistence.

### Scale Redis (Manual)

Redis cluster mode uses a hash slot architecture (16384 slots). Docker Compose does not auto-configure Redis cluster membership.

To scale Redis:

1. **Start additional Redis nodes:**
   ```bash
   docker-compose up -d --scale redis=3
   ```

2. **Meet the nodes** (from any Redis container):
   ```bash
   redis-cli --cluster add-node <new-node-ip>:6379 <existing-node-ip>:6379
   ```

3. **Reshard slots** across all nodes:
   ```bash
   redis-cli --cluster rebalance <existing-node-ip>:6379
   ```

4. **Verify the cluster:**
   ```bash
   redis-cli --cluster check <any-node-ip>:6379
   ```

### Redis Cache Behavior

- Cached URLs expire after 24 hours (configurable via backend)
- Atomic ID counter (`INCR short_id_counter`) runs on the primary node
- On Redis restart, the counter persists via AOF

---

## Monitoring Scaling Health

### Service Health Endpoints

| Endpoint               | What It Tests                            |
|------------------------|------------------------------------------|
| `GET /health`          | Nginx returns 200 directly               |
| `GET /api/health`      | Backend reachable through load balancer  |

### Docker Health Checks

Each backend container has a Docker healthcheck:

```yaml
healthcheck:
  test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000/health"]
  interval: 15s
  timeout: 5s
  retries: 3
  start_period: 30s
```

View health status:

```bash
docker ps --filter "name=backend" --format "table {{.Names}}\t{{.Status}}"
```

### Checking Distribution

Test that nginx balances across all backend instances:

```bash
# Run multiple requests and check upstream headers
for i in $(seq 1 10); do
  curl -sI http://localhost:8080/api/health | grep -i "x-upstream"
done
```

### Logs

```bash
# All backend logs
docker-compose logs -f backend

# Nginx access log (shows upstream times)
docker-compose logs -f nginx

# Specific instance (when scaled)
docker logs backend_1
docker logs backend_2
docker logs backend_3
```

---

## Troubleshooting

### Backend instances fail to start

```bash
# Check container logs
docker-compose logs backend

# Verify Cassandra is ready
docker exec cassandra nodetool status

# Verify Redis is ready
docker exec redis redis-cli ping
```

### Health checks fail after scaling

```bash
# List all backend containers
docker ps --filter "name=backend"

# Check individual container health
docker inspect --format '{{.State.Health.Status}}' backend_1

# Restart nginx to refresh DNS cache
docker-compose restart nginx
```

### Load balancer not distributing evenly

Nginx `least_conn` requires multiple concurrent connections to show balanced distribution. Low-traffic testing may appear skewed — this is normal.

To force even testing, send concurrent requests:

```bash
seq 1 20 | xargs -P 10 -I {} curl -s http://localhost:8080/api/health > /dev/null
```

---

## References

- [Docker Compose Scale](https://docs.docker.com/compose/reference/up/)
- [Cassandra Multi-Node Docker](https://cassandra.apache.org/doc/latest/cassandra/getting_started/configuring.html)
- [Redis Cluster Tutorial](https://redis.io/topics/cluster-tutorial)
- [Nginx Upstream Module](http://nginx.org/en/docs/http/ngx_http_upstream_module.html)