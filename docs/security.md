# Security Configuration

## Required Open Ports

| Port | Service  | Protocol | Purpose                  | External Access |
|------|----------|----------|--------------------------|-----------------|
| 8080 | nginx    | HTTP     | Load balancer entry point| Yes (or 443 with SSL) |
| 443  | nginx    | HTTPS    | TLS termination          | Yes (preferred) |
| 3000 | backend  | HTTP     | Backend API              | No (internal Docker network) |
| 9042 | cassandra| CQL      | Cassandra native transport| No (internal)  |
| 6379 | redis    | TCP      | Redis Cache & Counter    | No (internal)  |

## Security Group Recommendations (Cloud Deployment)

### AWS Security Group
```json
{
  "nginx_sg": {
    "description": "Nginx load balancer - public-facing",
    "inbound": [
      {"port": 80,   "protocol": "tcp", "cidr": "0.0.0.0/0", "description": "HTTP"},
      {"port": 443,  "protocol": "tcp", "cidr": "0.0.0.0/0", "description": "HTTPS"}
    ],
    "outbound": [
      {"port": 3000, "protocol": "tcp", "cidr": "backend_sg", "description": "Backend API"}
    ]
  },
  "backend_sg": {
    "description": "Backend API - internal only",
    "inbound": [
      {"port": 3000, "protocol": "tcp", "cidr": "nginx_sg", "description": "Nginx proxy traffic"}
    ],
    "outbound": [
      {"port": 9042, "protocol": "tcp", "cidr": "cassandra_sg", "description": "Cassandra"},
      {"port": 6379, "protocol": "tcp", "cidr": "redis_sg", "description": "Redis"}
    ]
  },
  "cassandra_sg": {
    "description": "Cassandra cluster - internal only",
    "inbound": [
      {"port": 9042, "protocol": "tcp", "cidr": "backend_sg", "description": "CQL queries"},
      {"port": 7000, "protocol": "tcp", "cidr": "cassandra_sg", "description": "Internode cluster"}
    ]
  },
  "redis_sg": {
    "description": "Redis cluster - internal only",
    "inbound": [
      {"port": 6379, "protocol": "tcp", "cidr": "backend_sg", "description": "Cache/Counter"},
      {"port": 16379, "protocol": "tcp", "cidr": "redis_sg", "description": "Cluster bus"}
    ]
  }
}
```

### Azure NSG (equivalent)

- **nginx-nsg**: Allow HTTP(80) and HTTPS(443) from Internet.
- **backend-nsg**: Allow port 3000 from nginx-nsg only. Service endpoints to Cassandra/Redis.
- **data-nsg**: Allow Cassandra(9042) and Redis(6379) from backend-nsg only.
- All NSGs: Deny all inbound by default.

## Network Isolation

### Tier Architecture

```
[Internet]
    |
[Public DMZ]   nginx (load balancer)
    |
[App Tier]     backend (Node.js API)
    |
[Data Tier]    cassandra + redis
```

- **Public DMZ**: Only nginx is directly accessible from the internet.
- **App Tier**: Backend containers are only reachable from nginx via Docker internal network.
- **Data Tier**: Cassandra and Redis have no host port exposure; only accessible within the Docker network.

### Docker Network Isolation

Docker Compose already handles internal network isolation via the `url_shortener_net` bridge network. Services only communicate within this network unless explicitly exposed via `ports:`.

To verify isolation:
```bash
# Backend can reach Cassandra and Redis
docker exec backend ping cassandra
docker exec backend ping redis

# External containers cannot reach internal services (default)
docker run --rm alpine ping redis  # FAILS
```

## Additional Security Measures

- **Rate Limiting**: IP-based rate limiting (100 req/min) configured at nginx level.
- **Request Size Limit**: `client_max_body_size 10k` prevents oversized payloads.
- **Timeouts**: Strict timeouts configured for client connections, proxy operations, and send/receive.
- **Security Headers**: X-Content-Type-Options, X-Frame-Options, X-XSS-Protection set on all responses.
- **TLS**: HTTPS with TLSv1.2/TLSv1.3 only, secure ciphers, HSTS preload (see nginx-ssl.conf).