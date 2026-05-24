## Why

We need a robust, distributed URL shortening service capable of handling high traffic with low latency while ensuring data integrity and security. Current solutions lack proper distribution mechanisms, caching strategies, and security controls necessary for production-scale deployment.

## What Changes

- **Containerization**: Use Docker and Docker Compose to simulate the entire distributed system locally
- **Frontend**: Simple Vue.js interface (no authentication) allowing users to paste a URL and get shortened result
- **New distributed architecture**: Implement load-balanced endpoints for read/write operations
- **Distributed storage**: Integrate Cassandra cluster with 3+ nodes for high availability and fault tolerance
- **Caching layer**: Add Redis caching for URL lookups to reduce database load and improve response times
- **Key generation**: Implement Redis atomic counter (INCR) with base62 encoding for short URL generation
- **Dual-purpose Redis**: Redis serves as both (1) a high-speed cache for URL lookups AND (2) an atomic counter for unique ID generation
- **Security layer**: URLs stored as plaintext (no encryption needed for short URLs)
- **High availability**: Ensure service remains operational during node failures with proper replication and failover

**BREAKING**: This is a new service. No existing APIs are affected.

## Capabilities

### New Capabilities
- `url-redirection`: Handle HTTP redirects from short URLs to original destinations with Redis caching
- `url-creation`: Create new short URLs via the write endpoint, generating unique base62-encoded identifiers
- `distributed-counter`: Atomic ID generation using Redis INCR to prevent collisions across multiple nodes
- `encryption-service`: _(removed — URLs stored as plaintext, no encryption needed)_
- `load-balancer`: Distribute incoming traffic across multiple application instances
- `frontend-vue`: Simple single-page Vue.js component allowing users to paste URLs and see shortened result
- `docker-compose`: Container orchestration for local development and simulation

### Modified Capabilities
- None: This is a greenfield service with no existing capabilities to modify.

## Impact

- **New Infrastructure**: Requires Cassandra cluster (3+ nodes), Redis cluster, and load balancer setup
- **New APIs**: Creates REST endpoints for URL creation (`POST /api/v1/urls`) and redirection (`GET /:shortId`)
- **Dependencies**: Adds Cassandra driver, Redis client
- **Dev Tools**: Adds Docker, Docker Compose, Vue.js runtime
- **Data Model**: Establishes new Cassandra tables for URL mappings and visit analytics
- **Security**: Rate limiting, CORS, security headers, WAF rules
- **Performance**: Expected sub-10ms response times for cached lookups, <50ms for database lookups
- **Scalability**: Designed to handle 10k+ requests/second with horizontal scaling
- **Frontend**: Simple Vue.js UI served directly from backend or CDN
