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

- **Rate Limiting**: Dual-layer rate limiting — IP-based (100 req/min) at nginx level (`limit_req_zone`) AND application middleware level (`createRateLimiter`). Nginx uses a burst of 20 with nodelay for traffic spikes.
- **Request Size Limit**: `client_max_body_size 10k` prevents oversized payloads.
- **Timeouts**: Strict timeouts configured for client connections, proxy operations, and send/receive.
- **Security Headers**: X-Content-Type-Options, X-Frame-Options (DENY), X-XSS-Protection (1; mode=block), Referrer-Policy (strict-origin-when-cross-origin), Permissions-Policy (restricted) set on all responses via Express middleware (`src/middleware/security.js`).
- **TLS**: HTTPS with TLSv1.2/TLSv1.3 only, secure ciphers, HSTS preload (see nginx-ssl.conf).

## Rate Limiting Strategy

### Dual-Layer Architecture

```
Client → Nginx (Layer 1: 100r/m burst=20) → Backend (Layer 2: 100 req/min sliding window)
```

- **Layer 1 — Nginx**: Uses `limit_req_zone` with `$binary_remote_addr`. Burst capacity of 20 requests absorbs short spikes. Returns 503 when exceeded.
- **Layer 2 — Application**: In-memory sliding window rate limiter in `src/middleware/security.js:createRateLimiter()`. Returns 429 with `retryAfter` seconds.
- **Why dual-layer?**: Nginx protects the backend from traffic storms before they reach Node.js. The application layer provides more informative error responses and works even if traffic bypasses nginx (e.g., direct access in dev).

### API Key Rate Limiting (11.3)

**Not applicable** for this MVP. The shortener is a public service with no authentication. Rate limiting is IP-based only. If API keys are added in the future, each key would have its own `limit_req_zone` in nginx and a dedicated key lookup table in the application layer.

## CORS Configuration

- **Default policy**: `Access-Control-Allow-Origin: *` — all origins permitted (public service).
- **Methods**: GET, POST, DELETE, OPTIONS.
- **Headers**: Content-Type, Authorization.
- **Preflight**: OPTIONS requests return 204 immediately.
- **Applied at**: Both nginx reverse proxy AND Express middleware (`corsMiddleware`).

## Input Validation Rules

All user-supplied URLs pass through `sanitizeUrl()` in `src/middleware/security.js`:

| Rule | Enforcement |
|------|------------|
| Protocol | Only `http:` and `https:` allowed |
| Max length | 2048 characters |
| Trimming | Whitespace stripped before/after |
| Parsability | Must pass `new URL()` constructor |
| Null/type check | Rejects non-string and null values |

Both single (`POST /api/v1/urls`) and batch (`POST /api/v1/urls/batch`) endpoints use `sanitizeUrl()`.

## WAF (Web Application Firewall) Rules (11.8)

Implemented at the nginx layer via `map` directives on `$request_uri`:

| Rule ID | Pattern | Blocked Attack |
|---------|---------|----------------|
| WAF-001 | `union\s+select|select\s+.*from` | SQL injection |
| WAF-002 | `<script|alert\(|onerror=|onload=` | Cross-site scripting (XSS) |
| WAF-003 | `\.\./|\.\.\\|/etc/passwd|/proc/self` | Path traversal |
| WAF-004 | `exec\s*\(|system\s*\(|eval\s*\(` | Command injection |

Requests matching any pattern return HTTP 403 with no further processing.

## Network Security Group Configuration (11.9)

### AWS Security Groups
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
    ],
    "outbound": [
      {"port": 7000, "protocol": "tcp", "cidr": "cassandra_sg", "description": "Internode gossip"}
    ]
  },
  "redis_sg": {
    "description": "Redis cluster - internal only",
    "inbound": [
      {"port": 6379, "protocol": "tcp", "cidr": "backend_sg", "description": "Cache/Counter"},
      {"port": 16379, "protocol": "tcp", "cidr": "redis_sg", "description": "Cluster bus"}
    ],
    "outbound": [
      {"port": 16379, "protocol": "tcp", "cidr": "redis_sg", "description": "Cluster bus"}
    ]
  }
}
```

### Health Endpoint Access Restriction (11.7)
Health endpoints (`/health`, `/api/health`) are restricted to internal RFC 1918 addresses (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16) at the nginx level. External requests receive a 403 Forbidden.

## Security Event Alerting (11.11)

### Monitored Events
| Event | Detection Method | Alert Channel |
|-------|-----------------|---------------|
| Rate limit exceeded (429) | Application log pattern | Log aggregation dashboard |
| Attack blocked (403 WAF) | Nginx access log 403 count | Prometheus metric + Grafana |
| Invalid URL attempts | Application error log | Log aggregation dashboard |
| Health endpoint external access | Nginx access log (denied) | Log aggregation dashboard |
| Backend 5xx errors | Application + nginx error logs | Prometheus metric + Grafana alert |

### Alert Thresholds
- **>10 WAF blocks/min**: Medium severity — possible scanning
- **>100 rate limit hits/min**: Low severity — possible DDoS
- **>1% 5xx error rate**: High severity — potential service degradation
- **Any external health check hit**: Immediate investigation

## Security Incident Response Procedures (11.12)

### Incident Severity Levels

| Level | Example | Response Time | Escalation |
|-------|---------|---------------|------------|
| **SEV-1** | Service compromise, data breach | 15 min | VP Engineering + Security |
| **SEV-2** | DDoS, sustained high error rates | 30 min | Engineering Lead |
| **SEV-3** | Suspicious scanning, isolated WAF hits | 4 hours | On-call engineer |
| **SEV-4** | Informational (probe attempts) | Next business day | Ticket |

### Response Steps

1. **Detection**: Alert triggers via monitoring system (Prometheus/Grafana).
2. **Triage**: On-call engineer acknowledges and assesses severity within SLA.
3. **Containment**:
   - **SEV-1**: Immediately block offending IPs at nginx level via `deny` rules or cloud WAF. Rotate any exposed credentials.
   - **SEV-2**: Scale up backend instances. Enable additional rate limiting if needed.
   - **SEV-3/4**: Log details for further investigation.
4. **Investigation**: Review logs (nginx access, application, WAF blocks) to understand attack vector and impact.
5. **Eradication**: Patch vulnerability, update WAF rules, rotate keys if exposed.
6. **Recovery**: Restore from backup if data was affected. Verify all services healthy.
7. **Post-Mortem**: Document timeline, root cause, remediation steps, and preventive measures within 48 hours.

### Communication
- **Internal**: Status page update + Slack #incidents channel.
- **External** (SEV-1/SEV-2 only): Status page public update. Customer notification if user data affected.

### Post-Incident Checklist
- [ ] Root cause analysis documented
- [ ] WAF rules updated to block similar patterns
- [ ] Monitoring/alerts improved to detect recurrence faster
- [ ] Security scan triggered
- [ ] Incident report filed for compliance (if applicable)