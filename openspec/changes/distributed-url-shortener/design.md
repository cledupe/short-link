## Context

This design implements a distributed URL shortening service built for high availability, scalability, and security. The system must handle high traffic volumes with sub-50ms response times while maintaining data integrity across distributed components.

**Key Constraints:**
- Must support horizontal scaling for both read and write operations
- Must maintain 99.9% uptime with 3-node Cassandra cluster
- Must store URLs in Cassandra for persistence and replication
- Must generate unique short URLs without collisions under concurrent load
- Must cache frequently accessed URLs to reduce database load

**Stakeholders:**
- End users: Need fast, reliable URL redirection
- API consumers: Need consistent URL creation endpoint
- DevOps: Need observable, maintainable infrastructure
- Security team: Require encryption and audit capabilities

## Goals / Non-Goals

**Goals:**
- Provide sub-10ms response time for cached URL lookups
- Maintain 99.9% availability through redundancy and failover
- Support 10k+ requests per second throughput
- Store all URLs as plaintext in Cassandra
- Generate collision-free short URLs using atomic counters
- Cache hot URLs in Redis to reduce Cassandra load
- Distribute traffic evenly across application instances

**Non-Goals:**
- Custom URL aliases (users cannot choose their own short URLs)
- Analytics dashboard (only basic visit tracking in DB)
- URL expiration/self-destruct functionality
- Custom domain support (single domain only)
- Geographic distribution / multi-region deployment (single region)
- Real-time replication across regions

## Decisions

### 1. **Database: Cassandra vs PostgreSQL/MySQL**
**Decision:** Use Cassandra with 3-node cluster

**Rationale:**
- Cassandra's distributed architecture provides inherent high availability with multi-node replication
- Tunable consistency allows balancing between read performance and data consistency
- Linear scalability as nodes are added
- No single point of failure vs traditional RDBMS primary/replica topology
- Write-optimized workload matches our URL creation pattern

**Alternatives considered:**
- PostgreSQL with streaming replicas: Simpler but single-writer bottleneck, more complex failover
- DynamoDB/Aurora: Managed but vendor lock-in, less operational control
- MongoDB: Document model fits but eventual consistency model more complex for this use case

**Trade-off:** Cassandra's eventual consistency and lack of ACID transactions require careful handling of potential edge cases during node failures.

### 2. **Cache Layer: Redis vs Memcached**
**Decision:** Use Redis for both caching and atomic counter operations

**Rationale:**
- Redis provides both caching and atomic counter operations (INCR/INCRBY) in single solution
- Atomic counter is critical for generating unique IDs without collisions
- Richer data structures if needed in future (sorted sets for analytics, etc.)
- Persistence options for counter durability
- Pub/sub capabilities for cache invalidation patterns

**Alternatives considered:**
- Memcached: Single-purpose cache, no atomic counter operations
- Database sequences: Centralized bottleneck, doesn't scale horizontally

**Trade-off:** Redis becomes a critical component - its failure impacts both caching and ID generation. Mitigated by Redis clustering.

### 3. **Key Generation: Base62 Encoding vs UUID**
**Decision:** Use Redis counter + Base62 encoding

**Rationale:**
- Base62 produces shorter URLs than UUID (6-8 chars vs 36 chars)
- Sequential counter from Redis guarantees uniqueness without collision detection
- Base62 (0-9a-zA-Z) produces compact, URL-safe strings
- Deterministic encoding means same input always produces same output

**Alternatives considered:**
- UUID/random strings: No coordination needed but longer URLs, collision probability increases
- Hash of original URL: Deterministic but potential collisions, no ordering

**Trade-off:** Sequential IDs can reveal creation volume (information leakage). Mitigated by not exposing ID sequence directly.

### 4. **URL Storage: Plaintext vs Encryption**
**Decision:** Store URLs as plaintext in Cassandra

**Rationale:**
- Eliminates encryption/decryption latency overhead (~2-5ms per operation)
- Removes key management complexity (key generation, rotation, storage)
- Simpler architecture with fewer failure modes
- For MVP, encryption adds complexity without immediate benefit
- Can be added later if compliance requirements arise

**Alternatives considered:**
- AES-256-GCM: Industry standard but adds latency and key management overhead
- ChaCha20-Poly1305: Better performance but similar complexity trade-offs

**Trade-off:** URLs are stored in plaintext. If compliance requirements change, encryption can be added at the application layer without schema changes.

### 5. **Load Balancing Algorithm**
**Decision:** Use least connections with health checks

**Rationale:**
- Least connections distributes load more evenly than round-robin when request processing times vary
- Health checks ensure traffic stops going to failed instances quickly
- Works well with connection pooling between LB and app instances

**Alternatives considered:**
- Round-robin: Simpler but can overload instances with slow requests
- IP-hash: Provides session affinity useful for rate limiting, but can create hot spots
- Random: Simple but less predictable

**Trade-off:** Slightly more complex than round-robin. Health check configuration critical - too sensitive causes flapping, too lenient causes failed instances receiving traffic.

## Risks / Trade-offs

**[Risk 1] Redis becomes single point of failure for ID generation**
→ **Mitigation:** Deploy Redis in cluster mode with at least 3 nodes and AOF persistence enabled. Critical operations use Redis transactions. Application implements circuit breaker pattern for Redis unavailability.

**[Risk 2] Cache inconsistency after node failures**
- **Scenario:** Cassandra write succeeds → Redis cache write fails → subsequent reads get stale cache hit
→ **Mitigation:** Use cache-aside pattern with write-through caching for critical paths. Implement cache TTL of 24 hours to bound inconsistency window. Monitor cache hit rate and Cassandra read load.

**[Risk 3] Counter ID exhaustion**
- **Scenario:** With high volume, numeric counter could eventually overflow (though practically unlikely)
→ **Mitigation:** Use 64-bit integers (max 9.2 quintillion IDs). Monitor counter value proactively. Implement alerting at 50%, 75%, 90% thresholds. Base62 encoding makes exhaustion less likely than UUID approach.

**[Risk 4] Hot partition in Cassandra**
- **Scenario:** Uneven distribution of popular URLs could create hot partitions, impacting performance
→ **Mitigation:** Use Murmur3Partitioner for even distribution. Design queries around partition key (shortId). Monitor node load distribution. Consider using LeveledCompactionStrategy for write-heavy workload.

**[Risk 5] (Removed - no encryption)**
- URLs stored as plaintext; encryption risk eliminated

**[Trade-off 1] Consistency vs Availability**
- Cassandra's eventual consistency model provides higher availability but may return slightly stale data
- **Decision:** Accept potential brief staleness (seconds) for higher availability. Use QUORUM reads/writes for critical operations.

**[Trade-off 2] Cache memory usage vs Performance**
- Large cache reduces database load but increases Redis memory costs
- **Decision:** Start with 24-hour TTL and LRU eviction for URLs accessed in last 30 days. Monitor cache hit rate and adjust TTL based on usage patterns.

**[Trade-off 3] (Removed - no encryption overhead)**
- Encryption overhead eliminated since URLs stored as plaintext

## Load Balancer Recommendation for MVP

**Recommended: Nginx (Open Source)**

For the MVP, **Nginx** provides the best balance of simplicity, performance, and features:

**Why Nginx for MVP:**
- **Easy Configuration**: Simple `upstream` block + `proxy_pass` directives. Minimal config files (~20 lines)
- **Lightweight**: Low memory footprint (~10MB per instance), fast startup
- **HTTP-Aware**: Understands HTTP semantics, handles redirects, cookies, headers correctly
- **Built-in Health Checks**: `health_check` directive with customizable intervals and thresholds
- **Least Connections**: Supports our recommended `least_conn` algorithm out of the box
- **SSL/TLS Termination**: Easy certificate management with `ssl_certificate` directive
- **Logging**: Comprehensive access logs with response times and status codes
- **Rate Limiting**: Built-in `limit_req_zone` for basic rate limiting
- **Static File Serving**: Can serve health check endpoints directly if needed

**Basic MVP Configuration (≈ 25 lines):**
```nginx
upstream backend {
    least_conn;
    server app1:8080 max_fails=3 fail_timeout=30s;
    server app2:8080 max_fails=3 fail_timeout=30s;
    server app3:8080 max_fails=3 fail_timeout=30s;
}

server {
    listen 80;
    location / {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location /health {
        access_log off;
        return 200 "OK\n";
    }
}
```

**Alternative for Rapid Local Testing: Node.js http-proxy**
For ultra-fast local development testing without infrastructure setup:
- Simple Node.js script with `http-proxy` middleware
- No config files, programmatic health checks
- Single command: `node load-balancer.js`
- **Trade-off**: Not production-grade, use only for testing

**Migration Path to Enterprise LB:**
When scaling beyond MVP, evaluate:
- **HAProxy**: More advanced algorithms, better observability, enterprise features
- **AWS ALB/NLB**: Managed service, auto-scaling, integration with AWS ecosystem
- **Traefik**: Container-native, auto-discovery, modern config (YAML/labels)

**MVP Decision:** Start with Nginx. If team has container/orchestration experience, consider Traefik. For cloud deployments, evaluate managed LB after MVP validation.

## Containerization & Frontend (MVP Scope)

### 6. **Docker & Docker Compose for Simulation**
**Decision:** Use Docker Compose to simulate the full distributed system locally for MVP development and testing

**Rationale:**
- **Infrastructure as Code**: Single `docker-compose.yml` defines all services (Cassandra, Redis, 3 app instances, Nginx, Vue frontend)
- **Rapid Local Testing**: `docker-compose up` brings up entire system in minutes without external cloud resources
- **Consistent Environment**: Eliminates "works on my machine" issues
- **Isolated Services**: Each component runs in dedicated container with proper networking
- **Scalable Testing**: Easy to test with 1, 2, or 3 app instances by changing `scale` parameter
- **Cost-Effective**: Zero cost for local development infrastructure

**Architecture:**
```
docker-compose.yml
├── cassandra (3 nodes via scaling)
├── redis (cluster mode)  
├── app (3 instances, Node.js/Express)
├── nginx (load balancer)
└── frontend (Vue.js SPA served via nginx)
```

**Alternatives considered:**
- **Kubernetes (Minikube)**: More complex for MVP, overkill for local simulation
- **Vagrant VMs**: Heavier resource usage, slower startup
- **Direct local installation**: Dependency management complexity, environment conflicts

**Trade-off:** Add ~2-5 seconds container startup time per service. Acceptable for development convenience.

### 7. **Frontend: Vue.js SPA**
**Decision:** Simple Vue.js single-page application with no authentication for immediate usability

**Rationale:**
- **Simplicity**: Vue.js has gentle learning curve, great for MVP
- **No Backend Auth**: Eliminates user management complexity for MVP
- **SPA Architecture**: Avoids page reloads, modern UX
- **CDN Delivery**: Can be served directly from Nginx or included in docker image
- **Component-Based**: Easy to iterate and add features later
- **Dev Experience**: Hot reload, good debugging tools

**Implementation:**
- **Single Component**: URL input field + Submit button + Result display
- **API Calls**: Vanilla fetch/XHR (simple for MVP)
- **Styling**: Minimal CSS or tailwind (CDN version, no build step)
- **No Build Tool**: For MVP, use Vue via CDN to avoid npm/webpack complexity
- **Result Display**: Show shortened URL with Copy-to-clipboard button

**User Flow:**
1. User visits `/` (served by Nginx)
2. Paste long URL into input field
3. Click "Shorten"
4. Frontend calls `POST /api/v1/urls`
5. Display shortened URL: `https://short.link/abc123`
6. "Copy" button for clipboard
7. Optional: Link to statistics page (future scope)

**Code Complexity:** 
- **Backend**: Vue component mounted on a div, ~50 lines of JS
- **Template**: 20-30 lines HTML
- **No Routing**: Single page, no Vue Router needed for MVP

**Trade-off:** Limited to single functionality. No user accounts means no URL management. Acceptable for MVP validation of core shortening service.

## Migration Plan

**Phase 1: Infrastructure Setup** (1-2 weeks)
- Deploy Cassandra cluster (3 nodes minimum)
- Deploy Redis cluster (3 nodes with replication)
- Deploy application instances (2-3 for initial load balancing)
- Configure load balancer with health checks

**Phase 2: Application Deployment** (1 week)
- Deploy URL creation service with feature flag disabled
- Deploy URL redirection service with feature flag disabled
- Deploy health check endpoints
- Run integration tests against full infrastructure
- Enable monitoring and alerting

**Phase 3: Feature Launch** (gradual rollout, 1-2 weeks)
- Enable URL creation API for internal testing (5% traffic)
- Monitor performance metrics: latency, error rates, cache hit rates
- Gradually increase traffic to 25%, 50%, 100%
- Enable URL redirection for existing shortened URLs
- Validate load balancing distribution

**Phase 4: Validation and Optimization** (ongoing)
- Monitor Cassandra and Redis cluster health
- Tune cache TTL based on access patterns
- Adjust load balancer algorithms if needed
- Scale infrastructure based on actual usage

**Rollback Strategy:**
- Maintain previous URL shortening solution in parallel for 2 weeks
- If critical issues arise, update DNS/load balancer to route traffic back to old system
- Cassandra data retention allows for migration back if needed
- Feature flags allow disabling specific components independently

## Open Questions

1. **Cache Pre-warming:** Should we implement cache warming on startup or rely on lazy loading? Impact on initial response times after restart.

2. **Analytics granularity:** What level of analytics data should we capture? (per-URL, per-user, temporal analysis)

3. **Cassandra compaction strategy:** Given write-heavy workload with occasional reads, should we optimize for write throughput or read performance initially?

4. **Rate limiting scope:** Should rate limits be per-IP, per-user, per-API key, or a combination? What are sensible default limits?

5. **Cassandra compaction strategy:** Given write-heavy workload with occasional reads, should we optimize for write throughput or read performance initially?

6. **Redis persistence configuration:** AOF (Append-Only File) vs RDB snapshots for counter durability? AOF provides better durability but impacts performance.

7. **SSL termination:** At load balancer or application instances? Load balancer is simpler but can't see encrypted traffic for logging. Application termination provides better observability but increased CPU load.
