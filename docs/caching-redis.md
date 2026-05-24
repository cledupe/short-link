# Redis Dual-Purpose Architecture

Redis serves **two distinct roles** in the URL shortener:

---

## 1. Cache Layer (URL Mappings)

### Purpose
Store shortId → original_url mappings for fast redirect lookups. On a cache hit, the redirect happens entirely from memory (~1ms) without querying Cassandra.

### Key Pattern
```
<shortId> → <original_url>
```
- **Key**: The base62-encoded short ID (e.g., `1a3B9`)
- **Value**: The original URL as plaintext (e.g., `https://example.com/very/long/path`)
- **TTL**: 24 hours (86400 seconds) — re-cached on each redirect

### Eviction Policy
- **Strategy**: `allkeys-lru`
- **Memory Limit**: 256MB
- When memory fills up, Redis evicts the least-recently-used keys (oldest accessed mappings).

### Cache Flow
1. **Read (redirect)**: `GET <shortId>` → hit → 302 redirect (no Cassandra call)
2. **Read (miss)**: `GET <shortId>` → miss → query Cassandra → `SETEX <shortId> <url> 86400` → 302 redirect
3. **Write (creation)**: Insert Cassandra → `SETEX <shortId> <url> 86400` (write-through)
4. **Invalidation (delete)**: `DEL <shortId>` → removes stale entry

---

## 2. Atomic Counter (ID Generation)

### Purpose
Generate globally unique, monotonically increasing IDs for new URLs. Works across all backend instances without coordination.

### Key Pattern
```
url:counter
```
- **Key**: Fixed string `url:counter`
- **Value**: Integer counter (e.g., `1048576`)
- **Persistence**: AOF with `appendfsync everysec`

### Counter Operations
- `INCR url:counter` → returns next unique ID
- `INCRBY url:counter <count>` → reserves a batch of IDs
- `GET url:counter` → returns current value (monitoring)

---

## Data Lifecycle

```
  URL Created
      │
      ▼
┌──────────────┐     ┌─────────────────┐
│  Cassandra    │────▶│  Redis Cache    │  Write-through
│  (persistent) │     │  TTL=24h, LRU   │
└──────────────┘     └────────┬────────┘
      ▲                       │
      │       Cache Miss      │ Cache Hit
      └───────────────────────┘
                   │
                   ▼
             302 Redirect (fast)
```

---

## Cache Hit Rate Expectations

| Scenario | Expected Hit Rate | Notes |
|----------|------------------|-------|
| Steady state (hot URLs) | >95% | Popular short links stay cached |
| Cold start | ~0% → 80%+ | Ramp-up over 24h as URLs are accessed |
| After LRU eviction | >80% | Least popular URLs evicted first |
| Expected long-term | >90% | 80/20 rule: 20% of URLs get 80% of traffic |

---

## Monitoring Commands

```bash
# Cache metrics endpoint
curl http://localhost:8080/metrics/cache

# Redis memory usage
docker exec redis redis-cli INFO memory

# Current cache keys count
docker exec redis redis-cli DBSIZE

# Counter value
docker exec redis redis-cli GET url:counter

# Cache TTL for a specific key
docker exec redis redis-cli TTL <shortId>

# LRU eviction stats
docker exec redis redis-cli INFO stats | grep evicted_keys
```

---

## Configuration

| Setting | Value | Why |
|---------|-------|-----|
| maxmemory | 256mb | Prevents Redis from consuming all host memory |
| maxmemory-policy | allkeys-lru | Evicts least-recently-used keys when full |
| TTL | 86400 (24h) | Balances freshness with cache hit rate |
| appendonly | yes | Counter durability across restarts |
| appendfsync | everysec | Balance between performance and durability |