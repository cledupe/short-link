# Code Review — Distributed URL Shortener

**Date:** 2026-05-24
**Scope:** Full project review (backend, infrastructure, scripts, documentation, frontend)

---

## Summary

| Severity | Count |
|----------|-------|
| 🔴 CRITICAL | 17 |
| 🟡 WARNING | 25 |
| 🟢 IMPROVEMENT | 18 |
| **Total** | **60** |

---

## 🔴 CRITICAL

### Backend

- **`src/routes/urls.js:40`** — `encode(id` calls an undefined function. `base62` is imported but not destructured. Will throw `ReferenceError: encode is not defined` on every URL creation. — Fix: Use `base62.encode(id)` or `const { encode } = require('base62')`.

- **`scripts/init-cassandra.cql:6-10`** — `visit_count COUNTER` alongside `original_url TEXT` and `created_at TIMESTAMP` in the same table. Cassandra **forbids** mixing counter and regular columns. Schema creation will be rejected. — Fix: Split into two tables: `url_mappings (short_id, original_url, created_at)` and `url_visit_counts (short_id, visit_count COUNTER)`.

- **`src/services/cassandra.js:64`** — `INSERT` into a `COUNTER` column with a value of 0. Cassandra does not allow setting counters via INSERT; only `UPDATE ... SET visit_count = visit_count + 1` is allowed. — Fix: Remove `visit_count` from the insert and use the separate counter table.

- **`src/routes/urls.js:173`** — `DELETE /:shortId` only invalidates Redis cache. Never removes the row from Cassandra. The URL remains permanently in the database with no way to delete it. — Fix: Add `DELETE FROM url_mappings WHERE short_id = ?` and delete from `url_metadata` / `visit_analytics`.

- **`src/routes/urls.js:173`** — DELETE endpoint has **no authentication**. Anyone who discovers a valid shortId can delete cache entries for any URL. — Fix: Add API key check or rate-limited token.

### Infrastructure

- **`docker-compose.yml:42`** — Single-node Redis with `--cluster-enabled yes`. Redis cluster requires 3+ nodes. The container will refuse to start properly. — Fix: Remove `--cluster-enabled yes` for single-node dev, or define 3 Redis instances.

- **`docker-compose.yml:143`** — `frontend` service runs an isolated nginx with no exposed ports. Serves no purpose since the LB nginx already mounts `./frontend` and serves the SPA. — Fix: Remove the frontend service entirely.

- **`nginx-ssl.conf:87`** — SSL `/api/` block omits `limit_req` rate limiting and WAF filter that the non-SSL config has. SSL users bypass all rate limiting. — Fix: Add `limit_req zone=api_limit burst=20 nodelay;` and WAF checks.

- **`scripts/init-cassandra.cql:2`** — `SimpleStrategy` with RF=3 is not rack/DC-aware and can silently lose data during topology changes. — Fix: Use `NetworkTopologyStrategy` with `'datacenter1': 3`.

- **`scripts/init-redis-cluster.sh:58`** — `redis-cli --cluster create` with a single node will fail. Redis cluster minimum is 3 masters. — Fix: Add a check that 3+ IPs are discovered, or skip cluster creation for single-node.

- **`prometheus.yml:7`** — `targets: ['backend:3000']` — DNS round-robins to a single IP. When scaled to 3 instances, only one is scraped. — Fix: List all instances or use service discovery.

- **`scripts/test-counter.sh:4`** — Defaults to `redis://localhost:6379` but docker-compose does not expose Redis to host. Script will always fail. — Fix: Use `REDIS_URL=redis://localhost:6379` only if running locally, or add port mapping.

- **`scripts/test-failover.sh:22`** — `curl -w "%{redirect_url}"` against `/api/health` (returns 200, not 3xx) yields empty string. Load distribution test measures nothing. — Fix: Use `/health` redirect or parse JSON status.

- **`.github/workflows/deploy.yml:94`** — SSH private key written to disk as a file. If the runner is compromised, the key is persisted. — Fix: Use `webfactory/ssh-agent` action.

- **`.github/workflows/deploy.yml:139`** — `deploy-final` runs `docker run` without `--network url_shortener_net`. New container cannot reach Cassandra or Redis. — Fix: Add `--network url_shortener_net`.

### Documentation

- **`AGENTS.md:31-38`** — Declares backend components (server.js, routes, Cassandra schema, Redis, Base62, health checks) as "Not yet implemented" when they ARE fully implemented. Fatally misleads any new contributor or AI agent. — Fix: Update to reflect actual implementation status.

- **`proposal.md:14,24,40`** — References encryption as an active feature, but encryption was removed from project scope. — Fix: Remove encryption references or mark as removed.

---

## 🟡 WARNING

### Backend

- **`src/routes/health.js:7`** — Creates new Redis and Cassandra connections on every health check request instead of reusing shared clients. Adds latency and can mask real issues. — Fix: Use `getClient()` from existing services.

- **`src/middleware/security.js:18`** — In-memory rate limiter Map grows unbounded. IPs with a single request and then silence forever still hold entries. Leaks memory proportional to unique IPs. — Fix: Add periodic cleanup with `setInterval` or use `rate-limiter-flexible`.

- **`src/routes/redirect.js:20`** — `pendingFetches` Map leaks rejected promises: `.delete()` is never called if the promise rejects. — Fix: Move `pendingFetches.delete(shortId)` into a `.finally()` block.

- **`src/routes/redirect.js:41`** — `incrementVisitCount` and `storeVisitAnalytics` are fire-and-forget with `.catch()`. Silent data loss if Cassandra is slow. — Fix: Use a background queue with retry logic.

- **`src/services/counter.js:31`** — `checkThreshold` performs an extra `GET` on Redis counter on every URL creation, doubling Redis round-trips. — Fix: Remove from hot path; run as a `setInterval` monitor every 60s.

- **`src/services/cassandra.js:54`** — `findUrlByOriginalUrl` uses `ALLOW FILTERING`. Forces full table scan across all nodes. Will timeout as table grows. — Fix: Create index on `original_url` or maintain a materialized view.

- **`src/services/metrics.js:56`** — `req.route.path` returns the matched pattern relative to the sub-router mount point, not the full path. — Fix: Use `req.baseUrl + req.route.path`.

- **`server.js:16`** — `/metrics` endpoint is completely open. Leaks internal system information (routes, cache hit rates, query latency). — Fix: Add IP restriction or basic auth.

- **`src/services/cassandra.js:102`** — `isReady()` only checks if client object exists (`!client`), not whether it's actually connected. — Fix: Add periodic health ping or track `connected` event.

### Infrastructure

- **`docker-compose.yml:27`** — `CASSANDRA_BROADCAST_ADDRESS=$$(hostname -f)` — `$(hostname -f)` is not evaluated at runtime; Cassandra receives the literal string. — Fix: Compute in entrypoint or use `hostname -i`.

- **`docker-compose.yml:101`** — `container_name: backend` prevents `--scale backend=3`. Same on cassandra, redis, nginx, prometheus, grafana. — Fix: Remove explicit `container_name` on scalable services.

- **`nginx.conf:70`** — `server backend:3000` repeated 3 times with identical hostname. Docker DNS resolves `backend` to same IP set for each entry. — Fix: Use single `server backend:3000` entry.

- **`nginx-ssl.conf:47`** — OCSP stapling enabled with self-signed certificates. Self-signed certs have no OCSP responder, causing nginx errors. — Fix: Disable `ssl_stapling` when using self-signed certs.

- **`.github/workflows/deploy.yml:86`** — Canary matrix `[5, 25, 50, 100]` runs all phases in parallel. 5% and 100% phases execute simultaneously. — Fix: Add `max-parallel: 1`.

- **`.github/workflows/deploy.yml:108`** — Sleep durations of 24h/48h in CI jobs waste runner minutes. — Fix: Replace with polling-based approach or shorter windows.

- **`.github/workflows/deploy.yml:101`** — `sed 's/weight=[0-9]*/weight=X/'` modifies `weight` directive, but nginx.conf uses `least_conn` (no weights). Does nothing. — Fix: Use `sed` for the correct config pattern.

- **`.github/workflows/deploy.yml:80`** — Trivy scan configured with `exit-code: 0`. Reports findings but never fails the build. — Fix: Set `exit-code: 1` for critical/high severity.

- **`scripts/init-cassandra.cql:20`** — Secondary indexes on high-cardinality `created_at` columns. Extremely inefficient and can cause coordinator timeouts. — Fix: Use materialized view or application-level queries.

- **`scripts/init-cassandra.cql:10`** — `gc_grace_seconds = 86400` (24 hours) is too aggressive. Default is 864000 (10 days). Data may resurrect if repair doesn't complete. — Fix: Use at least 864000.

- **`scripts/test-e2e.sh:101`** — Concurrent GET test launches background processes but never checks exit codes. Failed requests go undetected. — Fix: Capture and verify return codes.

- **`scripts/test-load.sh:126`** — `TOTAL_REQUESTS / TOTAL_SECONDS` divides by zero if test completes in under 1 second. — Fix: Add guard or default TOTAL_REQUESTS to 1.

- **`scripts/cassandra-backup.sh:11`** — `BACKUP_BASE="/backups"` is an absolute path not validated. — Fix: Add `mkdir -p "$BACKUP_BASE"`.

### Documentation

- **`README.md:44`** — Docs directory listing shows only 4 files but `docs/` contains 14+ files. Missing: `caching-redis.md`, `performance.md`, `troubleshooting.md`, `runbook.md`, `post-launch.md`, `production-deployment.md`, `redis-keys.md`, `monitoring.md`, `api.md`, `deployment.md`. — Fix: Update the listing.

- **`README.md:25 vs 60`** — `docker-compose.yml` appears twice in the project structure diagram. Confusing. — Fix: Deduplicate.

- **`README.md:149`** — States "MIT" license but no `LICENSE` file exists. — Fix: Create a LICENSE file.

---

## 🟢 IMPROVEMENT

### Backend

- **`server.js`** — No graceful shutdown handler for `SIGTERM`/`SIGINT`. Connections dropped ungracefully on `docker-compose down`. — Fix: Add `process.on('SIGTERM', async () => { ... })`.

- **`src/routes/urls.js:104`** — Batch URL creation processes URLs sequentially with `await`. 100 URLs = 200 sequential round-trips. — Fix: Use Cassandra `batch` statement or `Promise.all`.

- **`src/routes/urls.js:27`** — `URL_REGEX` and `isValidUrl` are redundant since `sanitizeUrl()` already validates thoroughly with `new URL()`. — Fix: Remove regex and `isValidUrl`.

- **`src/routes/health.js:47`** — 500ms timeout may cause false negatives under load. — Fix: Increase to 2000ms or make configurable.

- **`src/middleware/security.js:10`** — `X-XSS-Protection: 1; mode=block` is deprecated and ignored by modern browsers. — Fix: Remove the header; rely on CSP if needed.

- **`src/routes/redirect.js:48`** — `Cache-Control: no-cache, no-store` prevents any CDN caching. For hot URLs this adds latency. — Fix: Use `Cache-Control: public, max-age=60` for successful redirects.

- **`package.json`** — No `devDependencies`, test framework, or lint config. — Fix: Add `eslint` and `jest`.

### Infrastructure

- **`docker-compose.yml`** — No services set resource limits. A single runaway container can starve the entire stack. — Fix: Add `mem_limit` and `cpus` to all services.

- **`Dockerfile:5`** — `RUN npm install` should be `RUN npm ci --only=production` for deterministic builds. — Fix: Use `npm ci`.

- **`nginx.conf:160`** — References `/404.html` and `/502.html` but no such files exist. — Fix: Create error pages or use `return` directive.

- **`frontend/Dockerfile`** — Redundant. LB nginx already serves frontend. — Fix: Remove frontend Dockerfile and service.

- **`scripts/load-test.js:44`** — `sleep(1)` caps throughput at 1 req/s per VU. With 500 VUs, max is 500 req/s. — Fix: Remove or reduce sleep for higher throughput.

- **`scripts/generate-ssl-certs.sh:16`** — Output messages in Chinese while rest of project is English. — Fix: Translate to English.

### Documentation

- **`CLAUDE.md`** — Exists at project root but undocumented. Should be listed in README or moved.

- **`backend/src/utils/`** — Directory exists but is empty. — Fix: Remove or add README explaining intent.

- **Docs content overlap** — `runbook.md`, `troubleshooting.md`, `post-launch.md`, `production-deployment.md`, `deployment.md` all overlap significantly on incident response and scaling. — Fix: Consolidate into fewer documents.

- **No OpenAPI/Swagger spec** — Only `docs/api.md` exists. No OpenAPI specification file. — Fix: Generate an `openapi.yaml` from the API docs.

- **`scripts/` under-documented** — 16 scripts exist but README only documents 3. — Fix: Document all scripts in README.

- **`frontend/index.html:234`** — Fetch uses relative `'/api/v1/urls'`. If behind reverse proxy with path rewriting, this may 404. — Fix: Use `window.location.origin` + path or configurable base URL.

---

## Top 5 Priority Fixes

| # | Severity | File | Issue |
|---|----------|------|-------|
| 1 | 🔴 CRITICAL | `src/routes/urls.js:40` | `encode` is undefined — breaks URL creation |
| 2 | 🔴 CRITICAL | `scripts/init-cassandra.cql:6-10` | Counter + regular columns in same table — schema rejected |
| 3 | 🔴 CRITICAL | `src/services/cassandra.js:64` | INSERT into COUNTER column — runtime error |
| 4 | 🔴 CRITICAL | `docker-compose.yml:42` | Redis cluster mode with single node — won't start |
| 5 | 🟡 WARNING | `src/routes/health.js:7` | New DB connections on every health check — perf issue |