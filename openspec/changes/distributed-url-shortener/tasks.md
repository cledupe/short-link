## 0. Local Development Setup (Docker MVP)

**Objective**: Use Docker Compose to simulate the entire system locally before production deployment

### 0.1 Project Structure Setup
- [x] 0.1 Create root directory and initialize git repository
- [x] 0.1.2 Create `docker-compose.yml` in project root
- [x] 0.1.3 Create `Dockerfile` for backend application
- [x] 0.1.4 Create `frontend/` directory for Vue.js files
- [x] 0.1.5 Create `.dockerignore` files to optimize build context
- [x] 0.1.6 Document project structure in README.md

### 0.2 Docker Compose Definition
- [x] 0.2.1 Define `cassandra` service with 3 nodes using `--scale cassandra=3"
- [x] 0.2.2 Define `redis` service with cluster mode enabled
- [x] 0.2.3 Define `backend` service with 3 instances (scale parameter)
- [x] 0.2.4 Define `nginx` service for load balancing
- [x] 0.2.5 Define `frontend` service serving Vue.js SPA (+ create frontend/Dockerfile)
- [x] 0.2.6 Configure inter-service networking with Docker bridges
- [x] 0.2.7 Set up volume mounts for persistence (Cassandra data, Redis data)
- [x] 0.2.8 Configure ports: 8080 for nginx (load balancer), 3000-3002 for backends
- [x] 0.2.9 Document all services and their ports in compose file comments

### 0.3 Backend Dockerfile  
- [x] 0.3.1 Use Node.js official image (node:18-alpine for small size)
- [x] 0.3.2 Copy package.json and package-lock.json
- [x] 0.3.3 Run `npm install --only=production`
- [x] 0.3.4 Copy application source code
- [x] 0.3.5 Set `EXPOSE 3000` for application port
- [x] 0.3.6 Use `CMD ["node", "server.js"]` to start server
- [x] 0.3.7 Optimize image size with multi-stage build
- [x] 0.3.8 Test Docker build: `docker build -t url-shortener-backend .`

### 0.4 Frontend Vue.js Implementation (spec: frontend-vue)
- [x] 0.4.1 Create `frontend/index.html` with basic HTML structure
- [x] 0.4.2 Include Vue.js from CDN: `<script src="https://cdn.jsdelivr.net/npm/vue@3/dist/vue.global.js">`
- [x] 0.4.3 Create root div with id="app" for Vue mounting
- [x] 0.4.4 Create Vue component data properties: `longUrl`, `shortUrl`, `loading`, `error`
- [x] 0.4.5 Add v-model binding for URL input field
- [x] 0.4.6 Add @click handler for "Shorten URL" button
- [x] 0.4.7 Implement `shortenUrl()` method using fetch API to POST to `/api/v1/urls`
- [x] 0.4.8 Display loading spinner while API request in flight
- [x] 0.4.9 Display shortened URL in result section when successful
- [x] 0.4.10 Add "Copy to clipboard" button using `navigator.clipboard.writeText()`
- [x] 0.4.11 Handle errors from backend (display user-friendly message)
- [x] 0.4.12 Add client-side URL validation (basic regex)
- [x] 0.4.13 Add minimal CSS styling for responsive layout
- [x] 0.4.14 Test frontend: Open `index.html` in browser locally

### 0.5 Nginx Configuration for Frontend
- [x] 0.5.1 Create `nginx.conf` in project root
- [x] 0.5.2 Configure `upstream backend` with 3 backend instances
- [x] 0.5.3 Configure `server` block to serve frontend at `/` root
- [x] 0.5.4 Configure `/api/` location to proxy_pass to backend upstream
- [x] 0.5.5 Serve static Vue.js frontend from `/frontend` directory
- [x] 0.5.6 Add CORS headers for API endpoints
- [x] 0.5.7 Configure proper MIME types for Vue.js files
- [x] 0.5.8 Test nginx configuration: `nginx -c nginx.conf -t`

### 0.6 Docker Networking & Volumes
- [x] 0.6.1 Create Docker network `url_shortener_net` in compose file
- [x] 0.6.2 Attach all services to this network
- [x] 0.6.3 Create named volume `cassandra_data` for persistence
- [x] 0.6.4 Create named volume `redis_data` for persistence  
- [x] 0.6.5 Mount frontend files as volume for development (hot reload)
- [x] 0.6.6 Document port mappings: host-to-container
- [x] 0.6.7 Test container-to-container networking with ping

### 0.7 Local Testing & Simulation
- [x] 0.7.1 Run `docker-compose up` and verify all containers start
- [x] 0.7.2 Verify Cassandra nodes can communicate and form cluster
- [x] 0.7.3 Verify Redis accepts connections from backend instances
- [x] 0.7.4 Test backend instances can reach Cassandra and Redis
- [x] 0.7.5 Access `http://localhost:8080` and see Vue.js UI
- [x] 0.7.6 Paste URL and verify entire flow works end-to-end
- [x] 0.7.7 Test Cassandra persistence: stop containers, restart, verify data still exists
- [x] 0.7.8 Test scaling: `docker-compose up --scale backend=3` (verify load balancing)
- [x] 0.7.9 Monitor logs: `docker-compose logs -f` to check inter-service communication

### 0.8 Environment Configuration
- [x] 0.8.1 Create `.env` file for environment variables
- [x] 0.8.2 Define variables: CASSANDRA_NODES, REDIS_URL, ENCRYPTION_KEY
- [x] 0.8.3 Use `.env` file in docker-compose with `env_file` directive
- [x] 0.8.4 Document environment variables in README
- [x] 0.8.5 Create `.env.example` for version control (no secrets)

### 0.9 Git - Section 0 Complete (Docker MVP Setup)
- [x] 0.9.1-0.9.3 Branch, stage, commit
- [x] 0.9.9 Tag release: `git tag -a v0.1.0 -m "Docker MVP setup complete"`

## 1. Infrastructure Setup

- [x] 1.1 Deploy Cassandra cluster with 3 nodes in datacenter
- [x] 1.2 Configure Cassandra replication factor to 3 for HA
- [x] 1.3 Deploy Redis cluster with 3 nodes and AOF persistence
- [x] 1.4 Configure Redis clustering and replication
- [x] 1.5 Set up load balancer (Nginx) with least-connections algorithm
- [x] 1.6 Configure health check endpoints in load balancer
- [x] 1.7 Deploy application server instances (3 instances minimum)
- [x] 1.8 Set up SSL/TLS certificates for HTTPS endpoints
- [x] 1.9 Configure firewall rules and security groups
- [x] 1.10 Set up encryption key management system

### 1.11 Git - Section 1 Complete (Infrastructure Setup)
- [x] 1.11.1-1.11.3 Stage and commit
- [x] 1.11.9 Tag release: `git tag -a v0.2.0 -m "Infrastructure setup complete"`

## 2. Cassandra Schema Design

- [x] 2.1 Create Cassandra keyspace for URL mappings with replication_factor=3
- [x] 2.2 Design and create `url_mappings` table with columns: short_id, original_url, created_at, visit_count
- [x] 2.3 Design and create `url_metadata` table with columns: short_id, creator_ip, user_agent, created_at
- [x] 2.4 Create secondary indexes for analytics queries (created_at)
- [x] 2.5 Configure Cassandra compaction strategy to LeveledCompactionStrategy
- [x] 2.6 Set up Cassandra backup and restore procedures
- [x] 2.7 Document Cassandra CQL queries with examples

### 2.8 Git - Section 2 Complete (Cassandra Schema Design)
- [x] 2.8.1-2.8.3 Stage and commit
- [x] 2.8.9 Tag release: `git tag -a v0.3.0 -m "Cassandra schema complete"`

## 3. Core - URL Creation Service (spec: url-creation)

- [ ] 3.1 Create `/api/v1/urls` POST endpoint accepting JSON with original_url field
- [ ] 3.2 Implement URL validation (format, scheme, etc.)
- [ ] 3.3 Integrate distributed counter to get next ID from Redis
- [ ] 3.4 Implement base62 encoding function (0-9a-zA-Z)
- [ ] 3.5 Store original URL directly in Cassandra (no encryption)
- [ ] 3.6 Store original_url in Cassandra `url_mappings` table
- [ ] 3.7 Store metadata (IP, user agent, timestamp) in `url_metadata` table
- [ ] 3.8 Implement duplicate URL detection (check Cassandra before creating)
- [ ] 3.9 Return JSON response with short URL and 201 Created status
- [ ] 3.10 Return existing short URL with 200 OK for duplicates
- [ ] 3.11 Implement rate limiting (100 requests/min per IP)
- [ ] 3.12 Create `/api/v1/urls/batch` POST endpoint for batch creation (max 100 URLs)
- [ ] 3.13 Implement transaction handling for Cassandra writes (atomic operations)

### 3.14 Git - Section 3 Complete (URL Creation Service)
- [ ] 3.14.1 Create git branch: `git checkout -b feature/url-creation-service`
- [ ] 3.14.2 Stage changes: `git add .`
- [ ] 3.14.3 Commit: `git commit -m "Complete URL creation service with Redis counter and plaintext storage"`
- [ ] 3.14.4 Push branch: `git push origin feature/url-creation-service`
- [ ] 3.14.5 Create Pull Request to master
- [ ] 3.14.6 Get code review approval
- [ ] 3.14.7 Merge PR: `git checkout master && git pull && git merge feature/url-creation-service && git push`
- [ ] 3.14.8 Delete branch: `git branch -d feature/url-creation-service`
- [ ] 3.14.9 Tag release: `git tag -a v0.4.0 -m "URL creation service complete"`
- [ ] 3.14.10 Push tag: `git push origin v0.4.0`

## 4. Core - URL Redirection Service (spec: url-redirection)

- [ ] 4.1 Create `GET /:shortId` endpoint for URL redirects
- [ ] 4.2 Implement Redis cache lookup first (check if mapping exists in cache)
- [ ] 4.3 On cache miss, query Cassandra `url_mappings` table for the short_id
- [ ] 4.4 Store retrieved mapping in Redis cache with 24-hour TTL
- [ ] 4.5 Read original_url directly from Cassandra (no decryption needed)
- [ ] 4.6 Return 302 redirect response with decrypted URL in Location header
- [ ] 4.7 Return 404 Not Found for non-existent short_ids
- [ ] 4.8 Increment visit_count in Cassandra (counter column)
- [ ] 4.9 Store visit analytics in Cassandra with timestamp
- [ ] 4.10 Implement concurrent request handling for same short_id
- [ ] 4.11 Add proper caching headers for browser cache optimization

### 4.12 Git - Section 4 Complete (URL Redirection Service)
- [ ] 4.12.1 Create git branch: `git checkout -b feature/url-redirection-service`
- [ ] 4.12.2 Stage changes: `git add .`
- [ ] 4.12.3 Commit: `git commit -m "Complete URL redirection service with Redis caching"`
- [ ] 4.12.4 Push branch: `git push origin feature/url-redirection-service`
- [ ] 4.12.5 Create Pull Request to master
- [ ] 4.12.6 Get code review approval
- [ ] 4.12.7 Merge PR: `git checkout master && git pull && git merge feature/url-redirection-service && git push`
- [ ] 4.12.8 Delete branch: `git branch -d feature/url-redirection-service`
- [ ] 4.12.9 Tag release: `git tag -a v0.5.0 -m "URL redirection service complete"`
- [ ] 4.12.10 Push tag: `git push origin v0.5.0`

## 5. Distributed Counter Implementation (spec: distributed-counter)

- [ ] 5.1 Implement Redis INCR command wrapper for counter incrementation
- [ ] 5.2 Implement Redis INCRBY for batch ID reservation
- [ ] 5.3 Add error handling for Redis connection failures (circuit breaker pattern)
- [ ] 5.4 Configure Redis persistence for counter durability
- [ ] 5.5 Implement counter key naming strategy (`url:counter` for URLs)
- [ ] 5.6 Create base62 encoding function converting integer → string (0-9a-zA-Z)
- [ ] 5.7 Test ID uniqueness under concurrent load (1000 simultaneous increments)
- [ ] 5.8 Implement counter recovery mechanism on Redis failover
- [ ] 5.9 Monitor counter value and alert at 50%, 75%, 90% thresholds

### 5.10 Git - Section 5 Complete (Distributed Counter)
- [ ] 5.10.1 Create git branch: `git checkout -b feature/distributed-counter`
- [ ] 5.10.2 Stage changes: `git add .`
- [ ] 5.10.3 Commit: `git commit -m "Complete distributed counter with Redis INCR"`
- [ ] 5.10.4 Push branch: `git push origin feature/distributed-counter`
- [ ] 5.10.5 Create Pull Request to master
- [ ] 5.10.6 Get code review approval
- [ ] 5.10.7 Merge PR: `git checkout master && git pull && git merge feature/distributed-counter && git push`
- [ ] 5.10.8 Delete branch: `git branch -d feature/distributed-counter`
- [ ] 5.10.9 Tag release: `git tag -a v0.6.0 -m "Distributed counter complete"`
- [ ] 5.10.10 Push tag: `git push origin v0.6.0`

## 6. Encryption Service (REMOVED)

Encryption at rest was removed from the project scope. URLs are stored as plaintext in Cassandra.

### 6.13 Git - Section 6 Complete (Encryption Service - REMOVED)
- [ ] 6.13.1 Create git branch: `git checkout -b feature/encryption-service`
- [ ] 6.13.2 Stage changes: `git add .`
- [ ] 6.13.3 Commit: `git commit -m "Remove encryption service - URLs stored as plaintext"`
- [ ] 6.13.4 Push branch: `git push origin feature/encryption-service`
- [ ] 6.13.5 Create Pull Request to master
- [ ] 6.13.6 Get code review approval
- [ ] 6.13.7 Merge PR: `git checkout master && git pull && git merge feature/encryption-service && git push`
- [ ] 6.13.8 Delete branch: `git branch -d feature/encryption-service`
- [ ] 6.13.9 Tag release: `git tag -a v0.7.0 -m "Encryption service removed"`
- [ ] 6.13.10 Push tag: `git push origin v0.7.0`

## 7. Load Balancer Integration (spec: load-balancer)

- [ ] 7.1 Implement `/health` endpoint returning 200 OK if all components healthy
- [ ] 7.2 Add component health checks (Cassandra, Redis, encryption)
- [ ] 7.3 Implement health check response within 500ms
- [ ] 7.4 Implement `/ready` endpoint for Kubernetes readiness probes
- [ ] 7.5 Configure load balancer health check interval (30 seconds)
- [ ] 7.6 Configure load balancer with least-connections algorithm
- [ ] 7.7 Test load balancer distribution under load (verify <10% variance)
- [ ] 7.8 Test failover scenario (killing one instance, verify traffic stops)
- [ ] 7.9 Test instance recovery (verify instance rejoins pool correctly)
- [ ] 7.10 Configure connection pooling between LB and app instances

### 7.11 Git - Section 7 Complete (Load Balancer Integration)
- [ ] 7.11.1 Create git branch: `git checkout -b feature/load-balancer-integration`
- [ ] 7.11.2 Stage changes: `git add .`
- [ ] 7.11.3 Commit: `git commit -m "Complete load balancer integration with health checks and failover"`
- [ ] 7.11.4 Push branch: `git push origin feature/load-balancer-integration`
- [ ] 7.11.5 Create Pull Request to master
- [ ] 7.11.6 Get code review approval
- [ ] 7.11.7 Merge PR: `git checkout master && git pull && git merge feature/load-balancer-integration && git push`
- [ ] 7.11.8 Delete branch: `git branch -d feature/load-balancer-integration`
- [ ] 7.11.9 Tag release: `git tag -a v0.8.0 -m "Load balancer integration complete"`
- [ ] 7.11.10 Push tag: `git push origin v0.8.0`

## 8. Caching Implementation

 - [ ] 8.1 Configure Redis client connection pooling
- [ ] 8.2 Implement write-through caching for URL creation
- [ ] 8.3 Set cache TTL to 24 hours for URL mappings
- [ ] 8.4 Implement LRU eviction for old entries
- [ ] 8.5 Create cache metrics endpoint (hit rate, miss rate)
- [ ] 8.6 Implement cache invalidation for deleted URLs
- [ ] 8.7 Test cache hit rate optimization (>80% target)
- [ ] 8.8 Monitor cache memory usage and adjust eviction policies
- [ ] 8.9 Document Redis dual-purpose architecture (cache + atomic counter)

### 8.10 Git - Section 8 Complete (Caching Implementation)  
- [ ] 8.10.1 Create git branch: `git checkout -b feature/caching-implementation`
- [ ] 8.10.2 Stage changes: `git add .`
- [ ] 8.10.3 Commit: `git commit -m "Complete caching implementation with Redis TTL and eviction"`
- [ ] 8.10.4 Push branch: `git push origin feature/caching-implementation`
- [ ] 8.10.5 Create Pull Request to master
- [ ] 8.10.6 Get code review approval
- [ ] 8.10.7 Merge PR: `git checkout master && git pull && git merge feature/caching-implementation && git push`
- [ ] 8.10.8 Delete branch: `git branch -d feature/caching-implementation`
- [ ] 8.10.9 Tag release: `git tag -a v0.9.0 -m "Caching implementation complete"`
- [ ] 8.10.10 Push tag: `git push origin v0.9.0`

## 9. Integration & End-to-End Testing

- [ ] 9.1 Set up integration test environment with all components
- [ ] 9.2 Write E2E test: URL creation → cache storage → retrieval → redirect
- [ ] 9.3 Test cache miss scenario (verify fetch from Cassandra)
- [ ] 9.4 Test concurrent requests for same URL (consistency check)
- [ ] 9.5 Test encryption/decryption round-trip
- [ ] 9.6 Test distributed counter under concurrent load
- [ ] 9.7 Test Cassandra replication (shutdown one node, verify data availability)
- [ ] 9.8 Test Redis failover (master failure, replica promotion)
- [ ] 9.9 Test load balancer with 3 instances (traffic distribution)
- [ ] 9.10 Test rate limiting enforcement (100 req/min limit)
- [ ] 9.11 Test invalid URL rejection (malformed URLs)
- [ ] 9.12 Test batch URL creation (100 URLs in one request)

### 9.13 Git - Section 9 Complete (Integration Testing)
- [ ] 9.13.1 Create git branch: `git checkout -b feature/integration-testing`
- [ ] 9.13.2 Stage changes: `git add .`
- [ ] 9.13.3 Commit: `git commit -m "Complete integration and E2E testing suite"`
- [ ] 9.13.4 Push branch: `git push origin feature/integration-testing`
- [ ] 9.13.5 Create Pull Request to master
- [ ] 9.13.6 Get code review approval
- [ ] 9.13.7 Merge PR: `git checkout master && git pull && git merge feature/integration-testing && git push`
- [ ] 9.13.8 Delete branch: `git branch -d feature/integration-testing`
- [ ] 9.13.9 Tag release: `git tag -a v0.10.0 -m "Integration testing complete"`
- [ ] 9.13.10 Push tag: `git push origin v0.10.0`

## 10. Monitoring & Observability

- [ ] 10.1 Set up Prometheus metrics collection
- [ ] 10.2 Export metrics: HTTP request latency, error rates, throughput
- [ ] 10.3 Export metrics: Redis cache hit/miss rates
- [ ] 10.4 Export metrics: Cassandra read/write latency
- [ ] 10.5 Export metrics: Encryption operation duration
- [ ] 10.6 Set up distributed tracing (OpenTelemetry/Jaeger)
- [ ] 10.7 Set up log aggregation (ELK/Fluentd)
- [ ] 10.8 Set up Grafana dashboards for key metrics
- [ ] 10.9 Configure alerts: High error rate (>1%), high latency p95 (>100ms)
- [ ] 10.10 Configure alerts: Node failures (Cassandra, Redis, app instances)
- [ ] 10.11 Configure alerts: Low cache hit rate (<50%)
- [ ] 10.12 Configure alerts: Encryption failures, decryption failures
- [ ] 10.13 Monitor disk usage on all nodes and set alerts at 80%

### 10.14 Git - Section 10 Complete (Monitoring)
- [ ] 10.14.1 Create git branch: `git checkout -b feature/monitoring-observability`
- [ ] 10.14.2 Stage changes: `git add .`
- [ ] 10.14.3 Commit: `git commit -m "Complete monitoring and observability setup"`
- [ ] 10.14.4 Push branch: `git push origin feature/monitoring-observability`
- [ ] 10.14.5 Create Pull Request to master
- [ ] 10.14.6 Get code review approval
- [ ] 10.14.7 Merge PR: `git checkout master && git pull && git merge feature/monitoring-observability && git push`
- [ ] 10.14.8 Delete branch: `git branch -d feature/monitoring-observability`
- [ ] 10.14.9 Tag release: `git tag -a v0.11.0 -m "Monitoring setup complete"`
- [ ] 10.14.10 Push tag: `git push origin v0.11.0`

## 11. Security & Hardening

- [ ] 11.1 Enable request logging with IP and user agent
- [ ] 11.2 Rate limit based on IP address
- [ ] 11.3 Rate limit based on API key (if applicable)
- [ ] 11.4 Implement CORS policies for API endpoints
- [ ] 11.5 Add security headers: X-XSS-Protection, X-Frame-Options, CSP
- [ ] 11.6 Validate and sanitize all user inputs (URLs)
- [ ] 11.7 Restrict access to health endpoints (internal only)
- [ ] 11.8 Set up WAF (Web Application Firewall) rules
- [ ] 11.9 Configure network security groups correctly
- [ ] 11.10 Rotate encryption keys (manual first rotation)
- [ ] 11.11 Set up security event alerting (decryption failures, brute force)
- [ ] 11.12 Document security incident response procedures

### 11.13 Git - Section 11 Complete (Security Hardening)
- [ ] 11.13.1 Create git branch: `git checkout -b feature/security-hardening`
- [ ] 11.13.2 Stage changes: `git add .`
- [ ] 11.13.3 Commit: `git commit -m "Complete security hardening and WAF rules"`
- [ ] 11.13.4 Push branch: `git push origin feature/security-hardening`
- [ ] 11.13.5 Create Pull Request to master
- [ ] 11.13.6 Get code review approval
- [ ] 11.13.7 Merge PR: `git checkout master && git pull && git merge feature/security-hardening && git push`
- [ ] 11.13.8 Delete branch: `git branch -d feature/security-hardening`
- [ ] 11.13.9 Tag release: `git tag -a v0.12.0 -m "Security hardening complete"`
- [ ] 11.13.10 Push tag: `git push origin v0.12.0`

## 12. Performance Testing & Optimization

- [ ] 12.1 Set up load testing environment (JMeter/Gatling/k6)
- [ ] 12.2 Test with 100 concurrent users (baseline performance)
- [ ] 12.3 Test with 1000 concurrent users (cache performance)
- [ ] 12.4 Test with 10,000 concurrent users (scale test)
- [ ] 12.5 Measure p50, p95, p99 latency for each endpoint
- [ ] 12.6 Measure throughput (requests/second)
- [ ] 12.7 Identify performance bottlenecks
- [ ] 12.8 Optimize slow queries in Cassandra
- [ ] 12.9 Optimize Redis operations (pipeline where possible)
- [ ] 12.10 Tune connection pool settings
- [ ] 12.11 Profile encryption/decryption for CPU bottlenecks
- [ ] 12.12 Tune JVM settings for heap and GC (if using Java)

### 12.13 Git - Section 12 Complete (Performance Testing)
- [ ] 12.13.1 Create git branch: `git checkout -b feature/performance-testing`
- [ ] 12.13.2 Stage changes: `git add .`
- [ ] 12.13.3 Commit: `git commit -m "Complete performance testing and optimizations"`
- [ ] 12.13.4 Push branch: `git push origin feature/performance-testing`
- [ ] 12.13.5 Create Pull Request to master
- [ ] 12.13.6 Get code review approval
- [ ] 12.13.7 Merge PR: `git checkout master && git pull && git merge feature/performance-testing && git push`
- [ ] 12.13.8 Delete branch: `git branch -d feature/performance-testing`
- [ ] 12.13.9 Tag release: `git tag -a v0.13.0 -m "Performance testing complete"`
- [ ] 12.13.10 Push tag: `git push origin v0.13.0`

## 13. Documentation

- [ ] 13.1 Write API documentation (Swagger/OpenAPI)
- [ ] 13.2 Document Cassandra schema with examples
- [ ] 13.3 Document Redis key naming conventions
- [ ] 13.4 Document deployment procedures
- [ ] 13.5 Document monitoring and alerting guide
- [ ] 13.6 Document backup and restore procedures
- [ ] 13.7 Document troubleshooting guide
- [ ] 13.8 Document scaling procedures (adding nodes)
- [ ] 13.9 Write runbook for common issues
- [ ] 13.10 Document security hardening checklist

### 13.11 Git - Section 13 Complete (Documentation)
- [ ] 13.11.1 Create git branch: `git checkout -b feature/documentation`
- [ ] 13.11.2 Stage changes: `git add .`
- [ ] 13.11.3 Commit: `git commit -m "Complete project documentation: API, schema, deployment, and runbooks"`
- [ ] 13.11.4 Push branch: `git push origin feature/documentation`
- [ ] 13.11.5 Create Pull Request to master
- [ ] 13.11.6 Get code review approval
- [ ] 13.11.7 Merge PR: `git checkout master && git pull && git merge feature/documentation && git push`
- [ ] 13.11.8 Delete branch: `git branch -d feature/documentation`
- [ ] 13.11.9 Tag release: `git tag -a v0.14.0 -m "Documentation complete"`
- [ ] 13.11.10 Push tag: `git push origin v0.14.0`

## 14. Production Deployment

- [ ] 14.1 Provision production Cassandra cluster (minimum 3 nodes)
- [ ] 14.2 Provision production Redis cluster (minimum 3 nodes)
- [ ] 14.3 Provision production load balancer
- [ ] 14.4 Deploy application to production (feature flags off)
- [ ] 14.5 Run smoke tests in production environment
- [ ] 14.6 Enable URL creation endpoint for 5% traffic (canary)
- [ ] 14.7 Monitor for 24 hours, validate metrics
- [ ] 14.8 Increase to 25% traffic
- [ ] 14.9 After 48h validation, increase to 50% traffic
- [ ] 14.10 Enable URL redirection endpoint for 5% traffic
- [ ] 14.11 Gradually increase redirection traffic to 100%
- [ ] 14.12 After 1 week of monitoring, enable 100% for all endpoints
- [ ] 14.13 Configure production backups and retention policies
- [ ] 14.14 Set up automated deployment pipeline (CI/CD)

## 15. Post-Launch & Maintenance

- [ ] 15.1 Create post-mortem document after first week
- [ ] 15.2 Review performance metrics and optimize
- [ ] 15.3 Tune cache TTL based on real usage patterns
- [ ] 15.4 Optimize Cassandra compaction based on write volume
- [ ] 15.5 Review security logs and adjust WAF rules
- [ ] 15.6 Monitor and plan capacity based on growth
- [ ] 15.7 Document lessons learned
- [ ] 15.8 Plan next phase features (if any)
